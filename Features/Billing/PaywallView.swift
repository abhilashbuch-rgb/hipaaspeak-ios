import SwiftUI
import StoreKit

/// Shown when a user tries to start a session without active billing access.
/// Presents the three purchase options and handles the full StoreKit flow.
struct PaywallView: View {
    @Environment(BillingService.self) private var billing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {

                    // Brand header
                    VStack(spacing: 12) {
                        AppLogoLockup(size: .medium)
                            .padding(.top, 8)

                        Text("On-device clinical translation.\nNo cloud. No PHI ever transmitted.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Product cards
                    if billing.products.isEmpty {
                        ProgressView("Loading plans…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(billing.products, id: \.id) { product in
                                ProductCard(product: product) {
                                    Task { await billing.purchase(product) }
                                }
                            }
                        }
                    }

                    // Error
                    if let error = billing.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Fine print
                    VStack(spacing: 6) {
                        Button("Restore purchases") {
                            Task { await billing.restorePurchases() }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        Text("Subscriptions auto-renew unless cancelled.\nBAA available on request for subscribers.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom)
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .task { await billing.loadProducts() }
            .onChange(of: billing.hasAccess) { _, hasAccess in
                // Auto-dismiss once a purchase completes
                if hasAccess { dismiss() }
            }
        }
    }
}

// MARK: - Product card

private struct ProductCard: View {
    let product: Product
    let onPurchase: () -> Void

    @Environment(BillingService.self) private var billing

    private var isRecommended: Bool { product.id == BillingService.ProductID.monthly }

    private var subtitle: String {
        switch product.id {
        case BillingService.ProductID.daySession:
            return "30-minute time bank, valid for 7 days. Use across multiple encounters — pick up right where you left off."
        case BillingService.ProductID.monthly:
            return "Unlimited sessions every day. Cancel any time."
        case BillingService.ProductID.annual:
            return "Same unlimited access — ~20% off when you pay for the year."
        default:
            return product.description
        }
    }

    private var badge: String? {
        switch product.id {
        case BillingService.ProductID.monthly: return "Most popular"
        case BillingService.ProductID.annual:  return "Best value"
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Badge
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppLogo.brandPurple)
                    .clipShape(Capsule())
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                // Price + buy button
                VStack(alignment: .trailing, spacing: 6) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundStyle(isRecommended ? AppLogo.brandPurple : .primary)

                    Button(action: onPurchase) {
                        Group {
                            if billing.isPurchasing {
                                ProgressView()
                                    .frame(width: 72, height: 32)
                            } else {
                                Text(product.type == .consumable ? "Buy" : "Subscribe")
                                    .frame(width: 88, height: 32)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .background(isRecommended ? AppLogo.brandPurple : Color(.systemGray2))
                        .clipShape(Capsule())
                    }
                    .disabled(billing.isPurchasing)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isRecommended ? AppLogo.brandPurple.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}
