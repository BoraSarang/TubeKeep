import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: StoreOf<HomeReducer>
    @State private var elapsedSeconds: Int = 0
    @State private var showFullLog = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            urlInputSection

            if store.isFetching {
                fetchingIndicator
            }

            if let error = store.errorMessage {
                errorBanner(error)
            }

            if let info = store.videoInfo, !store.isFetching {
                videoInfoCard(info)
            }
        }
        .padding(16)
        .onReceive(timer) { _ in
            guard store.isFetching, let start = store.fetchStartTime else {
                elapsedSeconds = 0
                return
            }
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        .alert("Gemini API 키 필요", isPresented: Binding(
            get: { store.showGeminiKeyAlert },
            set: { store.send(.setGeminiKeyAlert($0)) }
        )) {
            Button("키 발급 받기") {
                NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")!)
            }
            Button("설정 열기") {
                store.send(.openSettingsForGeminiKey)
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("Google Gemini 모드에서는 API 키가 필요합니다.\n설정에서 API 키를 입력하거나 yTeaser 모드로 전환해 주세요.")
        }
    }

    private var urlInputSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    TextField(
                        "YouTube URL을 입력하거나 붙여넣기 하세요 (⌘V)",
                        text: Binding(
                            get: { store.urlString },
                            set: { store.send(.urlChanged($0)) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .id(store.urlString)
                    .onChange(of: store.urlString) { _, newValue in
                        guard isVideoURL(newValue),
                              newValue != store.lastAutoFetchedURL
                        else { return }
                        store.send(.autoFetchInfo(newValue))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

                Button {
                    store.send(.toggleClipboardMonitoring)
                } label: {
                    Image(systemName: store.clipboardMonitoring
                        ? "doc.on.clipboard.fill"
                        : "doc.on.clipboard")
                        .font(.system(size: 13))
                        .foregroundStyle(store.clipboardMonitoring
                            ? Color.accentColor
                            : Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
                .help(store.clipboardMonitoring
                    ? "클립보드 감시 켜짐"
                    : "클립보드 감시 꺼짐")

                Button("조회") {
                    store.send(.fetchInfoTapped)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.urlString.trimmingCharacters(in: .whitespaces).isEmpty || store.isFetching)

            }

            dragDropArea
        }
    }

    private var dragDropArea: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundStyle(.tertiary)
            .frame(height: 32)
            .overlay(
                Text("또는 URL을 여기에 드래그 앤 드롭")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            )
            .onDrop(of: [.text], isTargeted: nil) { providers in
                providers.first?.loadObject(ofClass: NSString.self) { str, _ in
                    if let url = str as? String, isVideoURL(url) {
                        DispatchQueue.main.async {
                            store.send(.autoFetchInfo(url))
                        }
                    }
                }
                return true
            }
    }

    private var fetchingIndicator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)

                Text("정보를 불러오는 중... \(elapsedSeconds)초")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("취소") {
                    store.send(.cancelFetch)
                    elapsedSeconds = 0
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            #if DEBUG
            if !store.fetchLogs.isEmpty {
                let allLogs = Array(store.fetchLogs.suffix(30).enumerated())
                if showFullLog {
                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 2) {
                                    ForEach(allLogs, id: \.offset) { i, log in
                                        Text(log)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .id(i)
                                            .textSelection(.enabled)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 50)
                            .onChange(of: store.fetchLogs.count) { _, _ in
                                let lastIdx = store.fetchLogs.suffix(30).count - 1
                                guard lastIdx >= 0 else { return }
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 50_000_000)
                                    withAnimation {
                                        proxy.scrollTo(lastIdx, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        Button("접기") {
                            withAnimation { showFullLog = false }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                    }
                } else {
                    HStack {
                        if let last = store.fetchLogs.last {
                            Text(last)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button("펼치기") {
                            withAnimation { showFullLog = true }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    }
                }
            }
            #endif
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
            Button("✕") {
                store.send(.clearError)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private func videoInfoCard(_ info: VideoInfo) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                thumbnailView(info)
                    .frame(width: 80, height: 45)

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 8))
                        Text(info.channel)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Label(info.formattedDuration, systemImage: "clock")
                        Label(info.formattedDate, systemImage: "calendar")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Picker("", selection: Binding(
                    get: { store.selectedFormatId ?? "" },
                    set: { store.send(.formatSelected($0)) }
                )) {
                    ForEach(store.availableFormats) { format in
                        Text("\(format.label) (\(format.filesizeFormatted))")
                            .tag(format.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 200)

                Spacer()

                if !store.audioOnly {
                    Toggle("자막 포함", isOn: Binding(
                        get: { store.includeSubtitles },
                        set: { store.send(.subtitlesToggled($0)) }
                    ))
                    .font(.system(size: 10))
                    .toggleStyle(.checkbox)
                }

                Toggle("오디오만 추출 (MP3)", isOn: Binding(
                    get: { store.audioOnly },
                    set: { store.send(.audioOnlyToggled($0)) }
                ))
                .font(.system(size: 10))
                .toggleStyle(.checkbox)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Button(action: { store.send(.addToQueueTapped) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 11))
                        Text("다운로드 추가")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canAddToQueue)

                Button {
                    store.send(.toggleSummaryPopover)
                } label: {
                    HStack(spacing: 4) {
                        if store.summaryLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Image(systemName: "text.bubble")
                            .font(.system(size: 11))
                        Text(store.summaryLoading ? "요약 중..." : "AI 요약")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 110)
                    .frame(height: 28)
                }
                .buttonStyle(.bordered)
                .disabled(!store.canAddToQueue)
                .popover(isPresented: Binding(
                    get: { store.showSummaryPopover },
                    set: { if !$0 { store.send(.dismissSummary) } }
                ), arrowEdge: .leading) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("AI 요약", systemImage: "text.bubble")
                                .font(.system(size: 14, weight: .semibold))
                            if let provider = store.summaryProvider {
                                Text(provider)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if let text = store.summaryText {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            Button {
                                store.send(.dismissSummary)
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        if store.summaryLoading {
                            VStack {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                    Text("AI 요약 중...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else if let text = store.summaryText {
                            VStack(spacing: 8) {
                                ScrollView {
                                    Text(text)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        } else {
                            Spacer()
                        }
                    }
                    .padding(24)
                    .frame(width: 380, height: 320)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private func thumbnailView(_ info: VideoInfo) -> some View {
        CachedThumbnailView(videoId: info.id, url: info.thumbnailURL)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

}

func isVideoURL(_ string: String) -> Bool {
    guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
          let host = url.host
    else { return false }
    let hostStr = host.lowercased()

    if hostStr.contains("youtu.be") {
        return true
    }

    if hostStr.contains("youtube.com") {
        let path = url.path.lowercased()
        return path == "/watch" || path.hasPrefix("/watch/")
    }

    return false
}
