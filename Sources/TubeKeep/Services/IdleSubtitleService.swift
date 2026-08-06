import Cocoa
import ComposableArchitecture

@MainActor
final class IdleSubtitleService {
    static let settingKey = "idleSubtitleMinutes"

    private let store: StoreOf<AppReducer>
    private var timer: Timer?
    private var downloadTask: Task<Void, Never>?
    private var currentProcess: Process?
    private var isDownloading = false

    init(store: StoreOf<AppReducer>) {
        self.store = store
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
        if systemIdleSeconds() >= Double(threshold) * 60 {
            startIfNeeded()
        } else {
            cancelIfDownloading()
        }
    }

    private func startIfNeeded() {
        guard !isDownloading else { return }
        let items = LibraryCacheService.shared.loadItems()
            .sorted { $0.downloadDate > $1.downloadDate }
        guard let first = items.first(where: { !LibraryReducer.hasSubtitles(for: $0.id) }) else { return }
        isDownloading = true
        downloadTask = Task { [weak self] in
            guard let self else { return }
            await self.downloadSubtitle(for: first)
            guard !Task.isCancelled else {
                self.isDownloading = false
                self.downloadTask = nil
                return
            }
            await self.runAutoAI(for: first)
            guard !Task.isCancelled else {
                self.isDownloading = false
                self.downloadTask = nil
                return
            }
            self.isDownloading = false
            self.downloadTask = nil
            self.checkIdle()
        }
    }

    private func cancelIfDownloading() {
        guard isDownloading else { return }
        currentProcess?.terminate()
        currentProcess = nil
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        store.send(.statusBar(.updateStatusText("")))
        store.send(.statusBar(.updateStatusDetail("")))
    }

    // MARK: - Subtitle download

    private func downloadSubtitle(for item: LibraryItem) async {
        let videoURL = "https://www.youtube.com/watch?v=\(item.id)"
        store.send(.statusBar(.updateStatusText("자막 자동 다운로드")))
        store.send(.statusBar(.updateStatusDetail(item.title)))

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
            "--write-subs", "--write-auto-subs",
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
        if Task.isCancelled { return }

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
                DatabaseManager.shared.updateTranscript(videoId: item.id, transcript: text, language: lang)
                saved = true
            }
        }
        try? fm.removeItem(at: tmpDir)

        #if DEBUG
        DebugLogManager.shared?.append("[IdleSub] \(saved ? "✅ 저장 완료" : "⚠️ 자막 없음") - \(item.title)")
        #endif
        if saved {
            NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
        }
        store.send(.statusBar(.updateStatusText("")))
        store.send(.statusBar(.updateStatusDetail("")))
    }

    // MARK: - Auto AI batch

    private func runAutoAI(for item: LibraryItem) async {
        let settings = Settings.loadSettings()
        guard settings.idleAutoSummary || settings.idleAutoPodcast else { return }
        store.send(.statusBar(.updateStatusText("유휴 AI 자동 생성")))
        store.send(.statusBar(.updateStatusDetail(item.title)))
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
                }
            } catch {
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
                } catch {
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
