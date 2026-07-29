import SwiftUI
import ComposableArchitecture

struct MindmapTreeView: View {
    let node: MindmapNode
    let store: StoreOf<AppReducer>

    var body: some View {
        MindmapNodeView(node: node, depth: 0, store: store)
    }
}

struct MindmapNodeView: View {
    let node: MindmapNode
    let depth: Int
    let store: StoreOf<AppReducer>
    @State private var expanded: Bool

    init(node: MindmapNode, depth: Int, store: StoreOf<AppReducer>) {
        self.node = node
        self.depth = depth
        self.store = store
        self._expanded = State(initialValue: depth < 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Indentation
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 12)
                }

                // Expand/collapse indicator
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 10)
                }

                // Node label
                Text(node.label)
                    .font(.system(size: depth == 0 ? 12 : 11, weight: depth == 0 ? .bold : .regular))
                    .foregroundStyle(depth == 0 ? .primary : .secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 2)

            if expanded {
                ForEach(node.children) { child in
                    MindmapNodeView(node: child, depth: depth + 1, store: store)
                }
            }
        }
    }
}

