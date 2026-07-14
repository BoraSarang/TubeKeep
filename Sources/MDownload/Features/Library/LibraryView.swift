import SwiftUI
import ComposableArchitecture

struct LibraryView: View {
    let store: StoreOf<AppReducer>
    @State private var isPinned = false

    var body: some View {
        HStack(spacing: 0) {
            LibrarySidebarView(store: store)
                .frame(width: 200)

            Divider()

            switch store.library.viewMode {
            case .grid:
                LibraryGridView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .list:
                LibraryListView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("영상 다운로더") {
                    NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)
                }
                .help("영상 다운로더 열기")

                Button("일괄 다운로더") {
                    NotificationCenter.default.post(name: Constants.openBatchWindowNotification, object: nil)
                }
                .help("일괄 다운로더 열기")

                Button("채널 다운로더") {
                    NotificationCenter.default.post(name: Constants.openChannelWindowNotification, object: nil)
                }
                .help("채널 다운로더 열기")

                Spacer()

                AlwaysOnTopToggle(isPinned: $isPinned, windowIdentifier: "main")

                Button {
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                        window.close()
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("창 닫기")
            }
        }
        .onAppear {
            store.send(.library(.loadFromDisk))
        }
    }
}

struct AlwaysOnTopToggle: View {
    @Binding var isPinned: Bool
    let windowIdentifier: String

    var body: some View {
        Button {
            isPinned.toggle()
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowIdentifier }) {
                window.level = isPinned ? .floating : .normal
            }
        } label: {
            Image(systemName: isPinned ? "pin.fill" : "pin")
        }
        .help("항상 위에 고정")
    }
}
