import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    @State private var isExpanded: Bool = false
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            if isExpanded {
                content()
            }
        }
        .padding(.vertical, 4)
    }
}
