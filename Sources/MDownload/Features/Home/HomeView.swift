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
                    .onChange(of: store.urlString) { newValue in
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

                #if DEBUG
                Button("조회 테스트") {
                    store.send(.debugTestFetch)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.isFetching)
                #endif
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
                            .onChange(of: store.fetchLogs.count) { _ in
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
                .frame(width: 130)

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
        AsyncImage(url: URL(string: info.thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.tertiary)
                    )
            case .empty:
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView().scaleEffect(0.4))
            @unknown default:
                EmptyView()
            }
        }
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

    let videoHosts = [
        "vimeo.com", "dailymotion.com",
        "twitch.tv", "www.twitch.tv",
    ]
    return videoHosts.contains { hostStr.contains($0) }
}
