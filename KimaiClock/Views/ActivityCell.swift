import SwiftUI

struct ActivityCell: View {
    let activity: Activity
    let isActive: Bool
    let canBeRemoved: Bool
    let setActive: () -> Void
    let remove: (() -> Void)?

    var body: some View {
        Button(action: {
            setActive()
        }) {
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .padding(.trailing, 4)
                    .foregroundColor(activity.activityColor)
                // single line: the activity name wins, the project is truncated
                Text(activity.name)
                    .font(.headline)
                    .foregroundColor(activity.activityColor)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(" / " + (activity.parentTitle ?? "-"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
        .buttonStyle(.plain)
        .if(canBeRemoved) { view in
                    view.contextMenu {
                        Button(role: .destructive) {
                            remove?()
                        } label: {
                            Text(NSLocalizedString("remove_activity", comment: ""))
                            Image(systemName: "trash")
                        }
                    }
                }
    }
}
