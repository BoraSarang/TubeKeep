import SwiftUI
import ComposableArchitecture

enum BatchStatus: Equatable {
    case pending
    case fetching
    case added
    case skipped(String)
    case failed(String)
}

struct BatchURLItem: Identifiable {
    let id = UUID()
    let url: String
    var status: BatchStatus
    var videoTitle: String?
    var thumbnailURL: String?
    var videoId: String?

    var isSkipped: Bool {
        if case .skipped = status { return true }
        return false
    }
}

enum ProcessingPhase: Equatable {
    case idle
    case processing
    case completed
}

struct BatchDownloadView: View {
    let store: StoreOf<AppReducer>

    @State private var urlText = ""
    @State private var processingPhase: ProcessingPhase = .idle
    @State private var progressText = ""
    @State private var urlItems: [BatchURLItem] = []
    @State private var alwaysOnTop = false
    @State private var fetchLogs: [String] = []
    @State private var showFullLog = false

    private let resolutionOptions: [(label: String, value: Int)] = [
        ("4K", 2160), ("2K", 1440),
        ("1080p", 1080), ("720p", 720), ("480p", 480),
        ("360p", 360), ("240p", 240), ("144p", 144),
    ]

    @State private var selectedResolution: Int

    init(store: StoreOf<AppReducer>) {
        self.store = store
        _selectedResolution = State(initialValue: store.settings.defaultResolution)
    }
    @State private var includeSubtitles = false
    @State private var audioOnly = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(.tint)
                        .font(.system(size: 11))
                    Text("일괄 다운로드")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)

                if processingPhase != .idle {
                    urlStatusList
                } else {
                    urlInputEditor
                }

                GroupBox {
                    VStack(spacing: 8) {
                        presetRow("해상도") {
                            Picker("", selection: $selectedResolution) {
                                ForEach(resolutionOptions, id: \.value) { opt in
                                    Text(opt.label).tag(opt.value)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                            .frame(width: 100)
                        }

                        presetRow("자막 포함") {
                            Toggle("", isOn: $includeSubtitles)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .disabled(audioOnly || processingPhase != .idle)
                        }

                        presetRow("오디오만 MP3") {
                            Toggle("", isOn: Binding(
                                get: { audioOnly },
                                set: {
                                    audioOnly = $0
                                    if $0 { includeSubtitles = false }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .disabled(processingPhase != .idle)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text("일괄 다운로드 프리셋")
                        .font(.caption)
                }

                if processingPhase == .processing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else if processingPhase == .completed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 8) {
                    Button(action: startBatchDownload) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 12))
                            Text("일괄 다운로드")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || processingPhase != .idle)
 
                }
            }
            .padding(16)
        }
        .frame(width: 480)
        .frame(minHeight: 340)
        .alwaysOnTop(alwaysOnTop, windowIdentifier: "batch")
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
        .background(.regularMaterial)
    }

    private var urlInputEditor: some View {
        TextEditor(text: $urlText)
            .font(.system(size: 12, design: .monospaced))
            .frame(minHeight: 100)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if urlText.isEmpty {
                    Text("URL을 한 줄에 하나씩 입력하세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
    }

    private var urlStatusList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(urlItems) { item in
                    HStack(spacing: 8) {
                        thumbnailView(item.thumbnailURL, videoId: item.videoId ?? item.id.uuidString)
                            .frame(width: 48, height: 27)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                statusIcon(item.status)
                                    .font(.system(size: 10))

                                Text(item.url)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(statusForeground(item.status))
                                    .strikethrough(item.isSkipped)
                            }

                            if let title = item.videoTitle {
                                Text(title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(statusForeground(item.status))
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusBackground(item.status))
                    )
                }
            }
            .padding(4)
        }
        .frame(minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func thumbnailView(_ urlString: String?, videoId: String) -> some View {
        if let urlString = urlString, !urlString.isEmpty {
            CachedThumbnailView(videoId: videoId, url: urlString)
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Color.gray.opacity(0.2)
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: BatchStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .fetching:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
        case .added:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "forward.slash")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func statusForeground(_ status: BatchStatus) -> Color {
        switch status {
        case .added: return .primary
        case .failed: return .red
        case .skipped: return .secondary
        case .fetching: return .primary
        case .pending: return .secondary
        }
    }

    private func statusBackground(_ status: BatchStatus) -> Color {
        switch status {
        case .added: return .green.opacity(0.08)
        case .failed: return .red.opacity(0.08)
        case .skipped: return .orange.opacity(0.06)
        case .fetching: return .blue.opacity(0.06)
        case .pending: return .clear
        }
    }

    @ViewBuilder
    private func presetRow(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            control()
        }
    }

    private func startBatchDownload() {
        let rawURLs = urlText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && isVideoURL($0) }

        guard !rawURLs.isEmpty else {
            progressText = "유효한 URL이 없습니다"
            return
        }

        let presetRes = selectedResolution
        let presetSubs = includeSubtitles
        let presetAudio = audioOnly

        urlItems = rawURLs.map { BatchURLItem(url: $0, status: .pending, videoTitle: nil, thumbnailURL: nil) }
        processingPhase = .processing
        fetchLogs = ["진행상태: 일괄 다운로드 시작 (\(rawURLs.count)개)"]
        progressText = "0/\(rawURLs.count) 처리 중..."

        let ytService = YouTubeDLService()
        let uploadService = UploadOrderService()

        Task {
            var allItems: [DownloadItem] = []

            for (index, url) in rawURLs.enumerated() {
                await MainActor.run {
                    urlItems[index].status = .fetching
                    fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 정보 조회 중...")
                }

                do {
                    let (info, formats) = try await ytService.fetchVideoInfo(
                        url: url,
                        progressHandler: { log in
                            let trimmed = log.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty, !trimmed.hasPrefix("[debug]") else { return }
                            Task { @MainActor in
                                fetchLogs.append("진행상태: \(trimmed)")
                            }
                        }
                    )

                    await MainActor.run {
                        urlItems[index].videoTitle = info.title
                        urlItems[index].thumbnailURL = info.thumbnailURL
                        urlItems[index].videoId = info.id
                        fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] \(info.title)")
                        progressText = "\(index + 1)/\(rawURLs.count) 추가됨: \(info.title)"
                    }

                    let format = Format.bestForDownload(upTo: presetRes, from: formats)

                    guard let selectedFormat = format else {
                        await MainActor.run {
                            urlItems[index].status = .failed("포맷 없음")
                            fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 포맷 없음")
                            progressText = "\(index + 1)/\(rawURLs.count) 실패"
                        }
                        continue
                    }

                    if info.isPlaylist {
                        await MainActor.run {
                            urlItems[index].status = .skipped("플레이리스트")
                            fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 플레이리스트 제외")
                            progressText = "\(index + 1)/\(rawURLs.count) 제외"
                        }
                        continue
                    }

                    await MainActor.run {
                        fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 업로드 순번 조회 중...")
                        progressText = "\(index + 1)/\(rawURLs.count) 순번 조회 중..."
                    }
                    let uploadIndex = (try? await uploadService.fetchUploadIndex(
                        channelId: info.channelId,
                        targetVideoId: info.id
                    )) ?? 0

                    let item = DownloadItem(
                        videoInfo: info,
                        selectedFormat: selectedFormat,
                        includeSubtitles: presetSubs,
                        audioOnly: presetAudio,
                        channelUploadIndex: uploadIndex
                    )
                    allItems.append(item)

                    await MainActor.run {
                        urlItems[index].status = .added
                        fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 추가됨 ✓")
                        progressText = "\(index + 1)/\(rawURLs.count) 추가됨"
                    }
                } catch {
                    await MainActor.run {
                        urlItems[index].status = .failed(error.localizedDescription)
                        fetchLogs.append("진행상태: [\(index + 1)/\(rawURLs.count)] 실패: \(error.localizedDescription)")
                        progressText = "\(index + 1)/\(rawURLs.count) 실패"
                    }
                }
            }

            guard !allItems.isEmpty else {
                await MainActor.run {
                    fetchLogs.append("진행상태: 추가된 항목이 없습니다")
                    processingPhase = .idle
                    urlItems = []
                    progressText = "추가된 항목이 없습니다"
                }
                return
            }

            let count = allItems.count
            await MainActor.run {
                store.send(.downloadQueue(.addItems(allItems)))
                store.send(.home(.resetInfo))
                processingPhase = .completed
                progressText = "모두 다운로드 목록에 추가되었습니다 (5초 후 자동 종료)"
                fetchLogs.append("진행상태: \(count)개 추가 완료 ✓")
            }
            for remaining in stride(from: 4, through: 1, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    progressText = "모두 다운로드 목록에 추가되었습니다 (\(remaining)초 후 자동 종료)"
                }
            }
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                if let batchWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "batch" }) {
                    batchWindow.close()
                }
                NotificationCenter.default.post(
                    name: Constants.openLibraryWindowNotification,
                    object: nil
                )
            }
        }
    }
}
