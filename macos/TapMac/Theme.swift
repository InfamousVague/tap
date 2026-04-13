import SwiftUI

// MARK: - Stash Design System

extension Color {
    // Backgrounds
    static let stashBgPrimary = Color(red: 9/255, green: 9/255, blue: 11/255)       // #09090B  gray[1]
    static let stashBgSecondary = Color(red: 17/255, green: 17/255, blue: 19/255)    // #111113  gray[2]
    static let stashBgElevated = Color(red: 25/255, green: 25/255, blue: 29/255)     // #19191D  gray[3]
    static let stashBgHover = Color.white.opacity(0.06)                               // overlay for hover

    // Text
    static let stashTextPrimary = Color(red: 250/255, green: 250/255, blue: 250/255) // #FAFAFA  gray[12]
    static let stashTextSecondary = Color(red: 155/255, green: 155/255, blue: 167/255) // #9B9BA7  gray[9]
    static let stashTextTertiary = Color(red: 112/255, green: 112/255, blue: 124/255) // #70707C  gray[8]
    static let stashTextDisabled = Color(red: 62/255, green: 62/255, blue: 68/255)    // #3E3E44  gray[6]

    // Borders
    static let stashBorder = Color.white.opacity(0.08)
    static let stashBorderStrong = Color.white.opacity(0.14)

    // Accent / Brand
    static let stashAmber = Color(red: 245/255, green: 158/255, blue: 11/255)        // #F59E0B
    static let stashAmber400 = Color(red: 251/255, green: 191/255, blue: 36/255)     // #FBBF24
    static let stashAmber600 = Color(red: 217/255, green: 119/255, blue: 6/255)      // #D97706
    static let stashAmber700 = Color(red: 180/255, green: 83/255, blue: 9/255)       // #B45309

    // Semantic
    static let stashError = Color(red: 248/255, green: 113/255, blue: 113/255)       // #F87171
    static let stashSuccess = Color(red: 74/255, green: 222/255, blue: 128/255)      // #4ADE80
    static let stashWarning = Color(red: 251/255, green: 191/255, blue: 36/255)      // #FBBF24
    static let stashInfo = Color(red: 96/255, green: 165/255, blue: 250/255)         // #60A5FA
}

// MARK: - Radii

enum StashRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 16
    static let full: CGFloat = 9999
}

// MARK: - Status Color Helper

enum StashStatus {
    static func color(for status: String) -> Color {
        switch status.lowercased() {
        case "online", "active", "up":
            return .stashSuccess
        case "offline", "down":
            return .stashError
        case "provisioning":
            return .stashWarning
        default:
            return .stashTextTertiary
        }
    }
}

// MARK: - Button Styles

/// Primary button — amber bg, dark text. Main CTA.
struct StashPrimaryButton: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.stashBgPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(disabled ? Color.stashAmber.opacity(0.4) : Color.stashAmber)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button — elevated bg, border, light text. For secondary actions.
struct StashSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.stashTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(configuration.isPressed ? Color.stashBgHover : Color.stashBgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .stroke(configuration.isPressed ? Color.stashBorderStrong : Color.stashBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Ghost button — transparent, shows bg on hover. For toolbar & inline actions.
struct StashGhostButton: ButtonStyle {
    var color: Color = .stashTextSecondary
    var activeColor: Color = .stashTextPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(configuration.isPressed ? activeColor : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(configuration.isPressed ? Color.stashBgHover : Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Icon-only button — square, ghost style. For toolbar icons.
struct StashIconButton: ButtonStyle {
    var color: Color = .stashTextSecondary
    var size: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(configuration.isPressed ? .stashTextPrimary : color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(configuration.isPressed ? Color.stashBgHover : Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Destructive button — red tint. For delete actions.
struct StashDestructiveButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(configuration.isPressed ? .stashError : .stashError.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(configuration.isPressed ? Color.stashError.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Reusable View Modifiers

struct StashCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.stashBgElevated)
            .cornerRadius(StashRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.md)
                    .stroke(Color.stashBorder, lineWidth: 1)
            )
    }
}

extension View {
    func stashCard() -> some View {
        modifier(StashCardStyle())
    }
}

// MARK: - Reusable Components

/// Section header — uppercase, small, tracking, tertiary color
struct StashSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(.stashTextTertiary)
    }
}

/// Styled text field with label
struct StashField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 300
    var isMonospaced: Bool = false

    var body: some View {
        LabeledContent {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .padding(8)
                .background(Color.stashBgPrimary)
                .cornerRadius(StashRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: StashRadius.sm)
                        .stroke(Color.stashBorderStrong, lineWidth: 1)
                )
                .frame(width: width)
        } label: {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.stashTextSecondary)
        }
    }
}

/// Styled secure field with label
struct StashSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 300

    var body: some View {
        LabeledContent {
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.stashBgPrimary)
                .cornerRadius(StashRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: StashRadius.sm)
                        .stroke(Color.stashBorderStrong, lineWidth: 1)
                )
                .frame(width: width)
        } label: {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.stashTextSecondary)
        }
    }
}

/// Badge — small colored pill for status indicators (PINNED, CONFIRM, etc.)
struct StashBadge: View {
    let text: String
    var color: Color = .stashAmber
    var variant: Variant = .subtle

    enum Variant {
        case solid   // colored bg, white text
        case subtle  // tinted bg, colored text
        case outline // transparent bg, colored border
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.full)
                    .stroke(borderColor, lineWidth: variant == .outline ? 1 : 0)
            )
            .cornerRadius(StashRadius.full)
    }

    private var foregroundColor: Color {
        switch variant {
        case .solid: return .stashBgPrimary
        case .subtle, .outline: return color
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .solid: return color
        case .subtle: return color.opacity(0.15)
        case .outline: return .clear
        }
    }

    private var borderColor: Color {
        variant == .outline ? color : .clear
    }
}

/// Status dot — small colored circle
struct StashStatusDot: View {
    let status: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(StashStatus.color(for: status))
            .frame(width: size, height: size)
    }
}

/// Status pill — labeled status indicator
struct StashStatusPill: View {
    let status: String

    var body: some View {
        let color = StashStatus.color(for: status)
        Text(status.capitalized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(StashRadius.sm)
    }
}
