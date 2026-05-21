import SwiftUI

/// Liquid glass-style button used throughout the interpreter.
/// Uses SwiftUI materials for the frosted glass effect.
struct GlassButton: View {
    let icon: GlassButtonIcon
    let size: CGFloat
    let isActive: Bool
    let action: () -> Void

    init(
        icon: GlassButtonIcon,
        size: CGFloat = 72,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.isActive = isActive
        self.action = action
    }

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Dual ripple rings — only rendered while recording
                if isActive {
                    Circle()
                        .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                        .scaleEffect(pulse ? 1.75 : 1.0)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.3).repeatForever(autoreverses: false),
                            value: pulse
                        )

                    Circle()
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        .scaleEffect(pulse ? 2.1 : 1.0)
                        .opacity(pulse ? 0 : 0.4)
                        .animation(
                            .easeOut(duration: 1.3).delay(0.3).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }

                // Glass base
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isActive ? 0.6 : 0.3),
                                        .white.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: isActive ? 16 : 8, y: isActive ? 6 : 3)

                // Inner icon
                icon.view(isActive: isActive)
            }
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .onChange(of: isActive) { _, active in
            pulse = false
            if active {
                // Let the scale spring settle before starting the ripple
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { pulse = true }
            }
        }
    }
}

/// Icon types for the glass buttons
enum GlassButtonIcon {
    case record       // Red dot
    case play         // Black triangle
    case stop         // Black square
    case speaker      // Speaker icon
    case speakerOff   // Speaker muted

    @ViewBuilder
    func view(isActive: Bool) -> some View {
        switch self {
        case .record:
            Circle()
                .fill(isActive ? Color.red : Color.red.opacity(0.85))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 16
                            )
                        )
                )
                .shadow(color: .red.opacity(isActive ? 0.6 : 0.3), radius: isActive ? 8 : 4)

        case .play:
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
                .opacity(isActive ? 1.0 : 0.85)
                .offset(x: 2) // Optical center for play triangle

        case .stop:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.85))
                .frame(width: 18, height: 18)

        case .speaker:
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))

        case .speakerOff:
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Small glass pill button (for secondary actions)

struct GlassPillButton: View {
    let label: String
    let icon: String?
    let action: () -> Void

    init(_ label: String, icon: String? = nil, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
