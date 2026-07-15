import SwiftUI
import ComposableArchitecture

struct MainView: View {
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
        .overlay {
            if let toast = store.library.subtitleToast {
                subtitleToastView(toast)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.25), value: toast.id)
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.downloadQueue.toastMessage {
                toastBanner(toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: toast.id)
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

                AlwaysOnTopToggle(isPinned: $isPinned, windowIdentifier: "lib")

                Button {
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "lib" }) {
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

    @ViewBuilder
    private func subtitleToastView(_ toast: ToastMessage) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: toast.type == .success
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
                )
                .font(.system(size: 64))
                .foregroundStyle(toast.type == .success ? .green : .red)

                Text(toast.message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                if toast.type == .success,
                   let videoId = store.library.subtitleToastVideoId,
                   let item = store.library.items.first(where: { $0.id == videoId }) {
                    Button("Finder에서 보기") {
                        let url = URL(fileURLWithPath: item.filePath)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
            }
            .padding(40)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 6)
        }
        .onAppear {
            HoverPreviewPanel.isSuppressed = true
        }
        .onDisappear {
            HoverPreviewPanel.isSuppressed = false
        }
    }

    @ViewBuilder
    private func toastBanner(_ toast: ToastMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: toast.type == .success
                ? "checkmark.circle.fill"
                : toast.type == .error
                ? "exclamationmark.triangle.fill"
                : "arrow.clockwise"
            )
            .foregroundStyle(toast.type == .success
                ? .green
                : toast.type == .error
                ? .red
                : .blue
            )
            .font(.system(size: 11))

            Text(toast.message)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.send(.downloadQueue(.dismissToast))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
