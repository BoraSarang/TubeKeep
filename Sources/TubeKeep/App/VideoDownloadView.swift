import SwiftUI
import ComposableArchitecture

struct VideoDownloadView: View {
    let store: StoreOf<AppReducer>
    @State private var alwaysOnTop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeView(
                store: store.scope(
                    state: \.home,
                    action: \.home
                )
            )

            Divider()

            DownloadQueueView(
                store: store.scope(
                    state: \.downloadQueue,
                    action: \.downloadQueue
                )
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .alwaysOnTop(alwaysOnTop)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    alwaysOnTop.toggle()
                } label: {
                    Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                }
                .help(alwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")
            }
        }
    }
}
