import SwiftUI
import AppKit
import ComposableArchitecture

struct MainView: View {
    let store: StoreOf<AppReducer>
    @State private var isPinned = false
    @State private var playbackTime: TimeInterval = 0
    @State private var playbackDuration: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            LibrarySidebarView(store: store)
                .frame(width: 200)

            Divider()

            switch store.library.sidebarMode {
            case .library:
                switch store.library.viewMode {
                case .grid:
                    LibraryGridView(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .list:
                    LibraryListView(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .discover:
                DiscoverView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .history:
                HistoryView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .profile:
                ProfileView(store: store.scope(state: \.profile, action: \.profile))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .report:
                ReportView(store: store.scope(state: \.library, action: \.library))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if store.library.showDigest, let stats = store.library.digestStats {
                digestBanner(stats)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            if let toast = store.library.subtitleToast {
                ToastOverlay(toast: toast, videoId: store.library.subtitleToastVideoId) {
                    store.send(.library(.dismissSubtitleToast))
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.25), value: toast.id)
                .onAppear { HoverPreviewPanel.isSuppressed = true }
                .onDisappear { HoverPreviewPanel.isSuppressed = false }
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.downloadQueue.toastMessage {
                ToastBanner(toast: toast) {
                    store.send(.downloadQueue(.dismissToast))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: toast.id)
            }
        }
        .alert("Gemini API 키 필요", isPresented: Binding(
            get: { store.library.showGeminiKeyAlert },
            set: { store.send(.library(.setGeminiKeyAlert($0))) }
        )) {
            Button("키 발급 받기") {
                NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")!)
            }
            Button("설정 열기") {
                store.send(.library(.openSettingsForGeminiKey))
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("Google Gemini 모드에서는 API 키가 필요합니다.\n설정에서 API 키를 입력하거나 yTeaser 모드로 전환해 주세요.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu("영상 다운로드") {
                    Button("영상 다운로더") {
                        NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)
                    }
                    Button("일괄 다운로더") {
                        NotificationCenter.default.post(name: Constants.openBatchWindowNotification, object: nil)
                    }
                    Button("채널 다운로더") {
                        NotificationCenter.default.post(name: Constants.openChannelWindowNotification, object: nil)
                    }
                }

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

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("프로그램 종료")
            }
        }
        .onAppear {
            store.send(.library(.loadFromDisk))
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.videoAIDidChangeNotification)) { _ in
            store.send(.library(.loadFromDisk))
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.libraryDataDidChangeNotification)) { _ in
            store.send(.library(.loadFromDisk))
        }
    }

    private func digestBanner(_ stats: DigestStats) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("📊 이번 주 TubeKeep 리포트")
                    .font(.system(size: 12, weight: .semibold))

                if let narrative = stats.aiNarrative {
                    Text(narrative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                HStack(spacing: 12) {
                    Label("\(stats.videosDownloaded)개 다운로드", systemImage: "arrow.down.to.line")
                        .font(.system(size: 10))
                    Label(formatBytes(stats.totalSizeBytes), systemImage: "externaldrive")
                        .font(.system(size: 10))
                    if stats.summaryCount > 0 {
                        Label("\(stats.summaryCount)회 요약", systemImage: "text.bubble")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                store.send(.library(.dismissDigest))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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

// MARK: - Q&A Inline Components

struct QAInputBar: View {
    let store: StoreOf<AppReducer>
    @State private var question = ""
    private enum FocusField { case textField }
    @FocusState private var focusedField: FocusField?

    var body: some View {
        HStack(spacing: 8) {
            TextField("질문하세요...", text: $question)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .focused($focusedField, equals: .textField)
                .onSubmit { askQuestion() }
            Button {
                askQuestion()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.library.qna.loading)
        }
    }

    private func askQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let videoId = store.library.qna.selectedVideoId else { return }
        store.send(.library(.qna(.askQuestion(videoId: videoId, question: trimmed))))
        question = ""
    }
}