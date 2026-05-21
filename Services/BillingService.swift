import Foundation
import StoreKit
import os
import Observation

/// Manages all billing: StoreKit 2 purchases, subscription entitlements,
/// and the day session time bank.
///
/// Day session bank: $9.99 buys 30 minutes (1800 seconds) valid for the current
/// calendar day. Remaining seconds are stored in Keychain (billing state, not PHI —
/// persistent storage is permitted per ARCHITECTURE.md §1). The bank expires at
/// midnight local time regardless of remaining seconds. See ADR-007.
///
/// Monthly/annual subscribers bypass the bank entirely — unlimited sessions.
@Observable
@MainActor
final class BillingService {

    private let logger = Logger(subsystem: "com.hipaaspeak", category: "BillingService")

    // MARK: - Product IDs (must match App Store Connect configuration)

    enum ProductID {
        static let daySession = "com.hipaaspeak.app.session.day"
        static let monthly    = "com.hipaaspeak.app.subscription.monthly"
        static let annual     = "com.hipaaspeak.app.subscription.annual"
        static var all: Set<String> { [daySession, monthly, annual] }
    }

    // MARK: - Public state

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var daySessionSecondsRemaining: Int = 0
    private(set) var isPurchasing = false
    private(set) var purchaseError: String?

    /// True if the user can start an interpretation session right now.
    var hasAccess: Bool { isSubscribed || daySessionSecondsRemaining > 0 }

    /// True if the user is on a day session (not a subscriber) and has time left.
    var hasDaySession: Bool { !isSubscribed && daySessionSecondsRemaining > 0 }

    /// Formatted time remaining for day session users — shown in the interpreter UI.
    var timeRemainingFormatted: String {
        let m = daySessionSecondsRemaining / 60
        let s = daySessionSecondsRemaining % 60
        return String(format: "%d:%02d remaining", m, s)
    }

    // MARK: - Private

    private var sessionTimer: Timer?
    // nonisolated(unsafe): assigned once in init, cancelled in deinit.
    // Task.cancel() is thread-safe so this is correct to access from deinit.
    nonisolated(unsafe) private var transactionListenerTask: Task<Void, Error>?

    // Keychain keys — billing state only, never PHI. ARCHITECTURE.md §1.
    private enum BankKey {
        static let date    = "bank_date"
        static let seconds = "bank_seconds"
    }

    // MARK: - Init / deinit

    init() {
        loadBankFromKeychain()
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Display order: day session → monthly → annual
            let order = [ProductID.daySession, ProductID.monthly, ProductID.annual]
            products = loaded.sorted {
                (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
            logger.info("Loaded \(loaded.count) StoreKit products.")
        } catch {
            logger.error("Product load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
            case .pending:
                logger.info("Purchase pending external action.")
            case .userCancelled:
                logger.info("User cancelled purchase.")
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Purchase error: \(error.localizedDescription)")
        }

        isPurchasing = false
    }

    // MARK: - Entitlement check (call on app launch)

    func checkEntitlements() async {
        isSubscribed = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if (transaction.productID == ProductID.monthly ||
                transaction.productID == ProductID.annual),
               transaction.revocationDate == nil {
                isSubscribed = true
            }
        }

        logger.info("Entitlements checked. Subscribed=\(self.isSubscribed)")
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
            logger.info("Purchases restored.")
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Day session time tracking

    /// Call when an interpretation session starts.
    /// No-op for subscribers — they have unlimited access.
    func beginSessionTracking() {
        guard hasDaySession else { return }

        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.daySessionSecondsRemaining > 0 {
                    self.daySessionSecondsRemaining -= 1
                    self.saveBankToKeychain()
                } else {
                    // Time exhausted — stop the timer. InterpreterView observes
                    // hasAccess and will end the session.
                    self.sessionTimer?.invalidate()
                    self.sessionTimer = nil
                    self.logger.info("Day session bank exhausted.")
                }
            }
        }
        logger.info("Day session tracking started. Remaining=\(self.daySessionSecondsRemaining)s")
    }

    /// Call when a session ends or is wiped (any trigger).
    func endSessionTracking() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        saveBankToKeychain()
        logger.info("Day session tracking stopped. Remaining=\(self.daySessionSecondsRemaining)s")
    }

    // MARK: - Private helpers

    private func handleTransaction(_ transaction: Transaction) async {
        switch transaction.productType {
        case .consumable:
            guard transaction.productID == ProductID.daySession else { return }
            // Credit 30 minutes for today
            let today = todayString()
            KeychainHelper.save(key: BankKey.date, value: today)
            KeychainHelper.save(key: BankKey.seconds, value: "1800")
            daySessionSecondsRemaining = 1800
            logger.info("Day session purchased. 1800s credited for \(today).")

        case .autoRenewable:
            await checkEntitlements()

        default:
            break
        }
    }

    private func loadBankFromKeychain() {
        let today = todayString()
        guard
            let savedDate = KeychainHelper.load(key: BankKey.date),
            savedDate == today,
            let secondsStr = KeychainHelper.load(key: BankKey.seconds),
            let seconds = Int(secondsStr),
            seconds > 0
        else {
            daySessionSecondsRemaining = 0
            return
        }
        daySessionSecondsRemaining = seconds
        logger.info("Day session bank loaded. Remaining=\(seconds)s")
    }

    private func saveBankToKeychain() {
        KeychainHelper.save(key: BankKey.date, value: todayString())
        KeychainHelper.save(key: BankKey.seconds, value: "\(daySessionSecondsRemaining)")
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    /// Verifies a StoreKit transaction is genuinely from Apple.
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw BillingError.failedVerification
        case .verified(let value): return value
        }
    }

    /// Background task that processes any transactions that arrive while the app is running.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Errors

    enum BillingError: LocalizedError {
        case failedVerification
        var errorDescription: String? {
            "Purchase verification failed. Please contact support@hipaaspeak.com."
        }
    }
}
