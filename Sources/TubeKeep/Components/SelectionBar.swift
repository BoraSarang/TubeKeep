import SwiftUI

struct SelectionBar: View {
    let count: Int
    let isAllSelected: Bool
    let onToggleSelectAll: () -> Void
    let onClearSelection: () -> Void
    let onReveal: () -> Void
    var onOpen: (() -> Void)? = nil
    let onDelete: () -> Void
    var showsDeselect: Bool = true

    var body: some View {
        HStack {
            Text("\(count)개 선택됨")
                .font(AppFont.count.weight(.medium))
                .foregroundColor(AppColors.accent)

            Spacer()

            Button {
                onToggleSelectAll()
            } label: {
                Image(systemName: isAllSelected ? "checkmark.circle.fill" : "checkmark.circle")
                Text("전체 선택")
            }
            .font(AppFont.count)
            .buttonStyle(.plain)
            .foregroundColor(AppColors.accent)

            Button {
                onReveal()
            } label: {
                Image(systemName: "folder")
                Text("Finder에서 보기")
            }
            .font(AppFont.count)
            .buttonStyle(.plain)
            .foregroundColor(AppColors.accent)

            if let onOpen {
                Button {
                    onOpen()
                } label: {
                    Image(systemName: "play.fill")
                    Text("열기")
                }
                .font(AppFont.count)
                .buttonStyle(.plain)
                .foregroundColor(AppColors.accent)
            }

            if showsDeselect {
                Button("선택 해제") {
                    onClearSelection()
                }
                .font(AppFont.count)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                Text("선택 삭제")
            }
            .font(AppFont.count)
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, AppMetrics.paddingStandard)
        .padding(.vertical, 4)
    }
}
