import Cocoa
import SwiftUI
import ComposableArchitecture

@MainActor
final class IdleSubtitleService {
    static let settingKey = "idleSubtitleMinutes"

    private let store: StoreOf<AppReducer>
    private var timer: Timer?
    private var downloadTask: Task<Void, Never>?
    private var currentProcess: Process?
    private var isDownloading = false
    private var skippedIds: Set<String> = []
    private var processedCount = 0
    private var sessionCompletedNotified = false

    init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    private func logAndNotify(_ message: String, title: String? = nil, systemImage: String? = nil, tint: Color? = nil) {
        ActivityLogStore.shared.append(message)
        if let title {
            IdleNotificationPresenter.shared.show(
                title: title,
                message: message,
                systemImage: systemImage ?? "star.fill",
                tint: tint ?? .blue
            )
        } else {
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] \(message)")
            #endif
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkIdle() }
        }
        Task { @MainActor [weak self] in self?.checkIdle() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancelIfDownloading()
    }

    // MARK: - Idle check

    private func currentThresholdMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Self.settingKey)
        return [5, 10, 30].contains(stored) ? stored : 0
    }

    private func systemIdleSeconds() -> TimeInterval {
        let eventTypes: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged]
        let idle = eventTypes.map {
            CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0)
        }.min() ?? 0
        return idle
    }

    private func checkIdle() {
        let threshold = currentThresholdMinutes()
        guard threshold > 0 else {
            cancelIfDownloading()
            return
        }
        let isSystemIdle = systemIdleSeconds() >= Double(threshold) * 60
        if isSystemIdle || isTubeKeepIdle() {
            startIfNeeded()
        } else {
            cancelIfDownloading()
        }
    }

    private func isTubeKeepIdle() -> Bool {
        if store.state.downloadQueue.hasActiveDownloads { return false }
        if AppDelegate.shared?.isPlayerPlaying ?? false { return false }
        if ChannelUpdateService.shared?.isRunning ?? false { return false }
        if AITaskTracker.shared.isBusy { return false }
        return true
    }

    private func startIfNeeded() {
        guard !isDownloading else { return }
        let items = LibraryCacheService.shared.loadItems()
            .filter { !LibraryReducer.hasSubtitles(for: $0.id) && !skippedIds.contains($0.id) }
            .sorted(by: Self.subtitleSortPredicate)
        guard let first = items.first else {
            if processedCount > 0, !sessionCompletedNotified {
                sessionCompletedNotified = true
                logAndNotify(
                    "총 \(processedCount)개 처리 완료. 유휴 시 다시 실행됩니다",
                    title: "자동화 완료",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            }
            return
        }
        isDownloading = true
        processedCount = 0
        sessionCompletedNotified = false
        logAndNotify(
            "유휴 자동화 시작 - 총 \(items.count)개 영상 대기",
            title: "자동화 시작",
            systemImage: "play.circle.fill",
            tint: .green
        )
        downloadTask = Task { [weak self] in
            guard let self else { return }
            await self.process(video: first)
            self.isDownloading = false
            self.downloadTask = nil
            guard !Task.isCancelled else { return }
            self.checkIdle()
        }
    }

    static func subtitleSortPredicate(_ a: LibraryItem, _ b: LibraryItem) -> Bool {
        switch Settings.loadSettings().idleSubtitleSort {
        case "upload":
            let au = a.uploadDate ?? .distantPast
            let bu = b.uploadDate ?? .distantPast
            return au > bu
        case "oldest":
            return a.downloadDate < b.downloadDate
        default:
            return a.downloadDate > b.downloadDate
        }
    }

    private func process(video: LibraryItem) async {
        let mode = Settings.loadSettings().idleSubtitleMode
        var hasSubtitle = false
        switch mode {
        case "download":
            hasSubtitle = await downloadSubtitle(for: video)
        case "whisper":
            hasSubtitle = await generateWithWhisper(for: video)
            if !hasSubtitle {
                hasSubtitle = await downloadSubtitle(for: video)
            }
        default:
            hasSubtitle = await downloadSubtitle(for: video)
            if !hasSubtitle {
                hasSubtitle = await generateWithWhisper(for: video)
            }
        }
        guard !Task.isCancelled else { return }
        processedCount += 1
        if hasSubtitle {
            await runAutoAI(for: video)
        } else {
            skippedIds.insert(video.id)
            DatabaseManager.shared.markSubtitleFailed(videoId: video.id)
            store.send(.statusBar(.updateStatusText("자막 처리 실패")))
            store.send(.statusBar(.updateStatusDetail(video.title)))
            logAndNotify("자막 획득 실패 - \(video.title), 다음 영상으로 계속", systemImage: "exclamationmark.triangle.fill", tint: .orange)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            store.send(.statusBar(.updateStatusText("")))
            store.send(.statusBar(.updateStatusDetail("")))
        }
    }

    private func cancelIfDownloading() {
        guard isDownloading else { return }
        currentProcess?.terminate()
        currentProcess = nil
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        skippedIds.removeAll()
        store.send(.statusBar(.updateStatusText("")))
        store.send(.statusBar(.updateStatusDetail("")))

        guard !Task.isCancelled else { return }
        if processedCount > 0 {
            logAndNotify(
                "사용 재개로 유휴 자동화 중단 - 완료 \(processedCount)개",
                title: "자동화 중단",
                systemImage: "stop.circle.fill",
                tint: .orange
            )
        }
    }

    // MARK: - Subtitle download

    private func downloadSubtitle(for item: LibraryItem) async -> Bool {
        let videoURL = "https://www.youtube.com/watch?v=\(item.id)"
        store.send(.statusBar(.updateStatusText("자막 자동 다운로드")))
        store.send(.statusBar(.updateStatusDetail(item.title)))
        ActivityLogStore.shared.append("자막 다운로드 시작 - \(item.title)")

        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_idle_subs_\(UUID().uuidString.prefix(8))")
        try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let subLangs = LanguageService.subtitleLanguages
        #if DEBUG
        DebugLogManager.shared?.append("[IdleSub] 자막 다운로드: \(item.title)")
        #endif
        let process = Process()
        let outputTemplate = tmpDir.appendingPathComponent("%(id)s.%(ext)s").path
        var args = [
            "--write-subs",
            "--sub-langs", subLangs,
            "--skip-download",
            "--no-warnings",
            "-o", outputTemplate,
            videoURL
        ]
        if Constants.ytDlpPath.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: Constants.ytDlpPath)
            process.arguments = args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            args.insert(Constants.ytDlpPath, at: 0)
            process.arguments = args
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        currentProcess = process

        do {
            try process.run()
            let deadline = ContinuousClock.now + .seconds(120)
            while process.isRunning && !Task.isCancelled {
                if ContinuousClock.now >= deadline {
                    process.terminate()
                    break
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            if process.isRunning { process.terminate() }
        } catch {
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] yt-dlp 실행 실패: \(error)")
            #endif
        }
        currentProcess = nil
        if Task.isCancelled { return false }

        let files = (try? fm.contentsOfDirectory(atPath: tmpDir.path)) ?? []
        var saved = false
        for file in files {
            let path = tmpDir.appendingPathComponent(file)
            let content = try? String(contentsOf: path, encoding: .utf8)
            guard let content else { continue }
            let text: String
            let lang: String
            if file.hasSuffix(".vtt") {
                text = SummarizationService.parseVTT(content)
                lang = file.contains(".ko.") ? "ko" : "en"
            } else if file.hasSuffix(".srt") {
                text = SummarizationService.parseSRT(content)
                lang = file.contains(".ko.") ? "ko" : "en"
            } else {
                continue
            }
            if !text.isEmpty {
                DatabaseManager.shared.updateTranscript(videoId: item.id, transcript: text, language: lang, source: "downloaded")
                saved = true
            }
        }
        try? fm.removeItem(at: tmpDir)

        #if DEBUG
        DebugLogManager.shared?.append("[IdleSub] \(saved ? "✅ 저장 완료" : "⚠️ 자막 없음") - \(item.title)")
        #endif
        ActivityLogStore.shared.append(saved ? "자막 다운로드 완료 - \(item.title)" : "정식 자막 없음 - \(item.title)")
        if saved {
            NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
        }
        store.send(.statusBar(.updateStatusText("")))
        store.send(.statusBar(.updateStatusDetail("")))
        return saved
    }

    // MARK: - Whisper fallback

    private func generateWithWhisper(for item: LibraryItem) async -> Bool {
        let settings = Settings.loadSettings()
        let whisperService = WhisperService.shared
        let modelSize = settings.whisperModelSize
        guard whisperService.isModelDownloaded(modelSize) else {
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] Whisper 모델 미설치 — \(modelSize)")
            #endif
            return false
        }
        guard FileManager.default.fileExists(atPath: item.filePath) else {
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] 로컬 파일 없음: \(item.filePath)")
            #endif
            return false
        }
        store.send(.statusBar(.updateStatusText("Whisper 자막 생성")))
        store.send(.statusBar(.updateStatusDetail(item.title)))
        ActivityLogStore.shared.append("Whisper 자막 생성 시작 - \(item.title)")
        #if DEBUG
        DebugLogManager.shared?.append("[IdleSub] Whisper 자막 생성: \(item.title)")
        #endif
        do {
            let audioPath = try await whisperService.extractAudio(videoPath: item.filePath)
            defer { try? FileManager.default.removeItem(atPath: audioPath) }
            guard !Task.isCancelled else { return false }
            let cues = try await whisperService.transcribe(
                audioPath: audioPath,
                modelSize: modelSize,
                progressHandler: { _ in }
            )
            guard !Task.isCancelled else { return false }
            let text = cues.map(\.text).joined(separator: "\n")
            guard !text.isEmpty else {
                ActivityLogStore.shared.append("Whisper 자막 비어 있음 - \(item.title)")
                #if DEBUG
                DebugLogManager.shared?.append("[IdleSub] ⚠️ Whisper 자막이 비어 있음 — \(item.title)")
                #endif
                return false
            }
            DatabaseManager.shared.updateTranscript(
                videoId: item.id,
                transcript: text,
                language: LanguageService.systemLanguageCode,
                source: "whisper",
                subtitlesJson: try? JSONEncoder().encode(cues)
            )
            NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
            ActivityLogStore.shared.append("Whisper 자막 생성 완료 - \(item.title) (\(text.count)자)")
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] ✅ Whisper 자막 생성 완료 — \(item.title) (\(text.count)자)")
            #endif
            return true
        } catch {
            ActivityLogStore.shared.append("Whisper 자막 생성 실패 - \(item.title): \(error.localizedDescription)")
            #if DEBUG
            DebugLogManager.shared?.append("[IdleSub] ❌ Whisper 실패 — \(item.title): \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Auto AI batch

    private func runAutoAI(for item: LibraryItem) async {
        let settings = Settings.loadSettings()
        guard settings.idleAutoSummary || settings.idleAutoPodcast else { return }
        store.send(.statusBar(.updateStatusText("유휴 AI 자동 생성")))
        store.send(.statusBar(.updateStatusDetail(item.title)))
        ActivityLogStore.shared.append("AI 자동 생성 시작 - \(item.title)")
        let keys = Settings.loadAPIKeys()

        if settings.idleAutoSummary, !Task.isCancelled {
            store.send(.statusBar(.updateStatusDetail("요약 생성 중... \(item.title)")))
            let service = SummarizationService()
            do {
                let result = try await service.summarizeVideo(
                    videoId: item.id,
                    title: item.title,
                    channel: item.channelName,
                    openRouterAPIKey: keys.openRouter,
                    ax4APIKey: keys.ax4,
                    geminiAPIKey: keys.gemini
                )
                guard !Task.isCancelled else { return }
                if result.provider != "cached" {
                    ActivityLogStore.shared.append("요약 생성 완료 - \(item.title)")
                    let joined = "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n")
                    let chaptersData = try? JSONEncoder().encode(result.chapters)
                    var updated = item
                    updated.summary = joined
                    updated.chapters = chaptersData
                    await LibraryCacheService.shared.updateItem(updated)
                    DatabaseManager.shared.updateSummary(videoId: item.id, summary: joined)
                    DatabaseManager.shared.updateChapters(videoId: item.id, chapters: chaptersData ?? Data())
                    NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
                }
                if !Task.isCancelled {
                    store.send(.statusBar(.updateStatusDetail("태그 생성 중... \(item.title)")))
                    let tag = await TaggingService().classify(
                        title: item.title,
                        channel: item.channelName,
                        openRouterAPIKey: keys.openRouter,
                        ax4APIKey: keys.ax4,
                        geminiAPIKey: keys.gemini
                    )
                    var tagged = item
                    tagged.tags = [tag]
                    await LibraryCacheService.shared.updateItem(tagged)
                    ActivityLogStore.shared.append("태그 생성 완료 - \(item.title) (\(tag))")
                }
            } catch {
                ActivityLogStore.shared.append("자동 요약 실패 - \(item.title): \(error.localizedDescription)")
                #if DEBUG
                DebugLogManager.shared?.append("[IdleSub] 자동 요약 실패 — \(item.title): \(error.localizedDescription)")
                #endif
            }
        }

        if settings.idleAutoPodcast, !Task.isCancelled {
            store.send(.statusBar(.updateStatusDetail("팟캐스트 생성 중... \(item.title)")))
            let data = DatabaseManager.shared.loadVideoAIData(videoId: item.id)
            if let transcript = data?.transcript, !transcript.isEmpty {
                do {
                    _ = try await PodcastService.shared.generatePodcast(
                        videoId: item.id,
                        title: item.title,
                        channel: item.channelName,
                        transcript: transcript,
                        openRouterAPIKey: keys.openRouter,
                        progress: nil
                    )
                    ActivityLogStore.shared.append("팟캐스트 생성 완료 - \(item.title)")
                } catch {
                    ActivityLogStore.shared.append("팟캐스트 생성 실패 - \(item.title): \(error.localizedDescription)")
                    #if DEBUG
                    DebugLogManager.shared?.append("[IdleSub] 자동 팟캐스트 실패 — \(item.title): \(error.localizedDescription)")
                    #endif
                }
            }
        }

        store.send(.statusBar(.updateStatusText("")))
        store.send(.statusBar(.updateStatusDetail("")))
    }
}
