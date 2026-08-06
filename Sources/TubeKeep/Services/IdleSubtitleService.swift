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
        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        currentProcess = process
        try? process.run()
        process.waitUntilExit()
        currentProcess = nil

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
}
