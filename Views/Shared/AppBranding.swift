import SwiftUI

/// The purple asterisk — HIPAAspeak's brand mark.
/// Used in onboarding, the app header, and as the conceptual app icon.
///
/// App icon note: The actual app icon (Assets.xcassets/AppIcon) must be
/// created as a 1024x1024 PNG in Xcode. Design: purple asterisk (*) centered
/// on a white or very light background. Use the brand purple below.
struct AppLogo: View {
    var size: CGFloat = 64

    /// Brand purple — used throughout the app
    static let brandPurple = Color(red: 0.45, green: 0.20, blue: 0.75)

    var body: some View {
        Text("*")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(AppLogo.brandPurple)
    }
}

/// Full logo lockup: asterisk + wordmark
struct AppLogoLockup: View {
    var size: LogoSize = .large

    enum LogoSize {
        case small, medium, large

        var asteriskSize: CGFloat {
            switch self {
            case .small: 28
            case .medium: 44
            case .large: 72
            }
        }

        var wordmarkSize: CGFloat {
            switch self {
            case .small: 18
            case .medium: 24
            case .large: 32
            }
        }

        var subtitleSize: CGFloat {
            switch self {
            case .small: 10
            case .medium: 12
            case .large: 14
            }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            AppLogo(size: size.asteriskSize)

            Text("HIPAAspeak")
                .font(.system(size: size.wordmarkSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if size == .large {
                Text("Clinical translation. On-device. Private.")
                    .font(.system(size: size.subtitleSize, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
