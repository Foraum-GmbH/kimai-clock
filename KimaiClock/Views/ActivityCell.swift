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
                Text(activity.name)
                    .font(.headline)
                    .foregroundColor(activity.activityColor)
                Text(" / " + activity.parentTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
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
