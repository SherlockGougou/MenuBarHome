import SwiftUI

struct CameraControlMenuOption: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
}

/// Camera controls use the same selected treatment as the camera switcher: a cyan fill,
/// cyan outline and brighter text. The shared `PillActionButtonStyle` stays unchanged because
/// its quiet selected state is intentional elsewhere in the app.
struct CameraControlButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.effectiveReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            if isSelected {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 5, height: 5)
            }
            configuration.label
        }
        .font(.system(size: DesignTokens.TypeSize.caption, weight: isSelected ? .semibold : .medium))
        .foregroundStyle(.white.opacity(isSelected ? 0.92 : 0.76))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                isSelected ? Color.cyan.opacity(0.20) : Color.white.opacity(0.08)
            )
        )
        .overlay(
            Capsule().strokeBorder(
                isSelected ? Color.cyan.opacity(0.55) : Color.white.opacity(0.10),
                lineWidth: 1
            )
        )
        .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
        .animation(reduceMotion ? nil : AppleMotion.pressFeedback, value: configuration.isPressed)
    }
}

/// A compact camera setting with one current value and several alternatives.
struct CameraControlMenu: View {
    let title: String
    let value: String
    let isActive: Bool
    let options: [CameraControlMenuOption]
    let onSelect: (CameraControlMenuOption) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Text(value)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .buttonStyle(CameraControlButtonStyle(isSelected: isActive || isPresented))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CameraControlMenuList(options: options) { option in
                onSelect(option)
                isPresented = false
            }
        }
    }
}

/// Popover content kept separate so its layout can be snapshotted without opening a window.
struct CameraControlMenuList: View {
    let options: [CameraControlMenuOption]
    let onSelect: (CameraControlMenuOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(option.isSelected ? Color.cyan : Color.clear)
                            .frame(width: 5, height: 5)
                        Text(option.title)
                            .font(.system(size: 11.5, weight: option.isSelected ? .semibold : .medium))
                            .foregroundStyle(.white.opacity(option.isSelected ? 0.96 : 0.78))
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(option.isSelected ? Color.cyan.opacity(0.18) : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(minWidth: 140)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .preferredColorScheme(.dark)
    }
}
