import SwiftUI

/// LibrarySidebarView의 선택 가능한 행 공통 컴포넌트.
/// nav/filter/category/history/profile 행이 반복하던 HStack+배경+선택 스타일을 한 곳으로 통일한다.
struct SidebarSelectableRow: View {
    let isSelected: Bool
    let title: String
    let icon: String?
    let count: Int?
    let iconSize: CGFloat
    let iconFrame: CGFloat
    var trailing: (() -> AnyView)?

    private let action: () -> Void
    @State private var isHovering = false

    init(
        title: String,
        isSelected: Bool,
        icon: String? = nil,
        count: Int? = nil,
        iconSize: CGFloat = 12,
        iconFrame: CGFloat = 20,
        trailing: (() -> AnyView)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.icon = icon
        self.count = count
        self.iconSize = iconSize
        self.iconFrame = iconFrame
        self.trailing = trailing
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .frame(width: iconFrame, height: iconFrame)
                }

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if let trailing {
                    trailing()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return AppColors.selectedContentBackground
        }
        if isHovering {
            return AppColors.hoverRow
        }
        return .clear
    }
}