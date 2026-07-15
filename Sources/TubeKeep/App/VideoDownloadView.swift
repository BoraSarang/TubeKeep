import SwiftUI
import ComposableArchitecture

struct VideoDownloadView: View {
    let store: StoreOf<AppReducer>

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
        .alwaysOnTop(store.alwaysOnTop)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.send(.toggleAlwaysOnTop)
                } label: {
                    Image(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
                }
                .help(store.alwaysOnTop ? "최상위 고정 해제" : "항상 최상위로 표시")

                Button {
                    NSApp.keyWindow?.orderOut(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("창 닫기")

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("프로그램 종료")
            }
        }
    }
}
