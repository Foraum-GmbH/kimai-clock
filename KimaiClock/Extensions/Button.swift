import SwiftUI

struct AdaptiveButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    var isDanger: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(!isDisabled && (isProminent || isDanger) ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isDisabled ? Color.secondary.opacity(0.15) :
                        isDanger ? Color.red :
                        isProminent ? Color.kimami :
                        Color.secondary.opacity(0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
