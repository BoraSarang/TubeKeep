import SwiftUI

struct LibrarySortBar: View {
    let itemCount: Int
    let showThumbnailPreview: Bool
    let sortOrder: LibrarySortOrder
    let isGrid: Bool
    let onToggleThumbnailPreview: () -> Void
    let onSetSortOrder: (LibrarySortOrder) -> Void
    let onToggleViewMode: () -> Void

    var body: some View {
        HStack {
            Text("\(itemCount)개 항목")
                .font(AppFont.count)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onToggleThumbnailPreview()
            } label: {
                Label {
                    Text("썸네일")
                        .font(AppFont.count)
                } icon: {
                    Image(systemName: showThumbnailPreview ? "checkmark.square.fill" : "square")
                        .font(AppFont.count)
                }
                .foregroundStyle(showThumbnailPreview ? AppColors.accent : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AppColors.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerSmall))
            }
            .buttonStyle(.plain)
            .help(showThumbnailPreview ? "썸네일 미리보기 끄기" : "썸네일 미리보기 켜기")

            Picker("정렬", selection: Binding(
                get: { sortOrder },
                set: { onSetSortOrder($0) }
            )) {
                ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .font(AppFont.count)
            .fixedSize()

            Button {
                onToggleViewMode()
            } label: {
                Image(systemName: isGrid ? "list.bullet.rectangle" : "square.grid.2x2")
                    .font(AppFont.count)
            }
            .buttonStyle(.plain)
            .help(isGrid ? "목록 보기" : "그리드 보기")
        }
    }
}
