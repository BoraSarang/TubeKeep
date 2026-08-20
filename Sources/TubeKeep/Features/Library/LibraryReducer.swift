import Foundation
import AppKit
import ComposableArchitecture

enum LibrarySidebarMode: String, Equatable {
    case library = "Library"
    case discover = "Discover"
    case history = "History"
    case profile = "Profile"
    case report = "Report"
    case clips = "Clips"
    case diskCleanup = "Disk Cleanup"
    case trash = "Trash"
}

@Reducer
struct LibraryReducer {
    @Dependency(\.continuousClock) private var clock

    @ObservableState
    struct State: Equatable {
        var items: [LibraryItem] = []
        var trashItems: [LibraryItem] = []
        var showTrash = false
        var searchText = ""
        var selectedChannel: String? = nil
        var selectedCategory: String? = nil
        var sortOrder: LibrarySortOrder = .dateDesc
        var filterMode: LibraryFilterMode = .all
        var viewMode: LibraryViewMode = .grid
        var showThumbnailPreview: Bool = true
        var isLoading = false
        var selectedIds: Set<String> = []
        var searchResults: [SearchResult] = []
        var subtitleDownloadingIds: Set<String> = []
        var subtitleAvailableIds: Set<String> = []
        var summaryAvailableIds: Set<String> = []
        var subtitleToast: ToastMessage?
        var subtitleToastVideoId: String?
        var diskUsageBytes: Int64 = 0

        // Navigation
        var sidebarMode: LibrarySidebarMode = .library

        // Discover
        var discoverCategory: TrendingCategory = .all
        var discoverVideos: [TrendingCategory: [TrendingVideo]] = [:]
        var discoverLoading: Bool = false
        var discoverError: String?
        var discoverSearchText = ""
        var discoverSearchResults: [TrendingVideo] = []
        var discoverSearching = false

        // Discover Summary
        var discoverSummaryVideoId: String?
        var discoverSummaryText: String?
        var discoverSummaryProvider: String?
        var discoverSummaryLoading = false

        // Digest
        var digestStats: DigestStats?
        var showDigest = false

        // Report
        var report = ReportReducer.State()

        // Profile Recommendations
        var isShowingProfileRecommendations = false
        var profileRecommendations: [TrendingVideo] = []
        var profileRecommendationsLoading = false

        // History
        var historyFilterChannel: String? = nil
        var historySearchText = ""

        // Library Summary
        var librarySummaryVideoId: String?
        var librarySummaryText: String?
        var librarySummaryProvider: String?
        var librarySummaryLoading = false
        var summaryProgressMessage = ""

        // Podcast (v2.5.2)
        var podcast = PodcastReducer.State()

        // Q&A (v2.5.3)
        var qna = QnAReducer.State()

        // Mindmap (v2.5.4)
        var mindmap = MindmapReducer.State()

        // Gemini API Key Alert
        var showGeminiKeyAlert = false

        init() {
            let saved = UserDefaults.standard.string(forKey: Constants.libraryViewModeKey) ?? "grid"
            viewMode = LibraryViewMode(rawValue: saved) ?? .grid
            showThumbnailPreview = UserDefaults.standard.object(forKey: "showThumbnailPreview") as? Bool ?? true
        }

        var filteredItems: [LibraryItem] {
            var result = items

            if filterMode == .recent {
                let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                result = result.filter { $0.downloadDate >= cutoff }
            }

            if let channelId = selectedChannel {
                // 같은 채널이 실제 ID/핸들 형식으로 중복 저장된 경우 이름 토큰으로도 포함
                let selectedName = items.first(where: { $0.channelId == channelId })?.channelName
                result = result.filter { item in
                    if item.channelId == channelId { return true }
                    guard let name = selectedName else { return false }
                    return LibraryCacheService.nameTokensMatch(item.channelName, name)
                }
            }

            if let category = selectedCategory {
                result = result.filter { $0.tags.contains(category) }
            }

            if !searchText.isEmpty {
                result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            }

            switch sortOrder {
            case .dateDesc:
                result.sort { $0.downloadDate > $1.downloadDate }
            case .dateAsc:
                result.sort { $0.downloadDate < $1.downloadDate }
            case .titleAsc:
                result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            case .channelAsc:
                result.sort { $0.channelName.localizedCompare($1.channelName) == .orderedAscending }
            case .uploadDateDesc:
                result.sort {
                    guard let a = $0.uploadDate, let b = $1.uploadDate else {
                        return $0.uploadDate != nil && $1.uploadDate == nil
                    }
                    return a > b
                }
            case .uploadDateAsc:
                result.sort {
                    guard let a = $0.uploadDate, let b = $1.uploadDate else {
                        return $0.uploadDate != nil && $1.uploadDate == nil
                    }
                    return a < b
                }
            case .indexAsc:
                result.sort {
                    guard let a = $0.channelUploadIndex, let b = $1.channelUploadIndex else {
                        return $0.channelUploadIndex != nil && $1.channelUploadIndex == nil
                    }
                    return a < b
                }
            case .indexDesc:
                result.sort {
                    guard let a = $0.channelUploadIndex, let b = $1.channelUploadIndex else {
                        return $0.channelUploadIndex != nil && $1.channelUploadIndex == nil
                    }
                    return a > b
                }
            }

            return result
        }
    }

    enum Action: Equatable {
        case loadFromDisk
        case itemsLoaded([LibraryItem])
        case addItem(LibraryItem)
        case removeItem(String)
        case removeItems([String])
        case removeItemsByChannel(channelId: String, channelName: String)
        case removeSelected
        // v3.5 휴지통
        case trashItem(String)
        case trashItems([String])
        case trashChannelItems(channelId: String, channelName: String)
        case loadTrash
        case trashLoaded([LibraryItem])
        case setShowTrash(Bool)
        case restoreItem(String)
        case deletePermanently(String)
        case deleteTrashItems([String])
        case emptyTrash
        case revealSelectedInFinder
        case openSelected
        case checkDigest
        case digestLoaded(DigestStats)
        case dismissDigest
        case setSearchText(String)
        case searchResultsUpdated([SearchResult])
        case playSearchMatch(String)
        case setSelectedChannel(String?)
        case setSelectedCategory(String?)
        case setSortOrder(LibrarySortOrder)
        case setFilterMode(LibraryFilterMode)
        case setViewMode(LibraryViewMode)
        case toggleThumbnailPreview
        case openFile(String)
        case revealInFinder(String)
        case downloadSubtitles(String)
        case subtitleResult(videoId: String, success: Bool, errorMessage: String)
        case showSubtitleToastToast(ToastMessage)
        case dismissSubtitleToast
        case toggleSelection(String)
        case selectAll
        case clearSelection
        case openChannelDownload(channelId: String, channelName: String)
        case calculateDiskUsage
        case diskUsageUpdated(Int64)

        // Navigation
        case setSidebarMode(LibrarySidebarMode)
        case setHistoryFilterChannel(String?)
        case setHistorySearchText(String)

        // Discover
        case selectDiscoverCategory(TrendingCategory)
        case selectProfileRecommendations
        case profileRecommendationsLoaded([TrendingVideo])
        case fetchTrending
        case trendingLoaded(category: TrendingCategory, videos: [TrendingVideo])
        case trendingFailed(String)
        case refreshTrending

        // Discover Search
        case setDiscoverSearchText(String)
        case discoverSearch
        case discoverSearchLoaded([TrendingVideo])
        case discoverSearchFailed(String)
        case discoverRequestSummary(videoId: String, title: String, channel: String)
        case discoverSummaryLoaded(videoId: String, text: String, provider: String)
        case discoverSummaryFailed(videoId: String, error: String)
        case discoverDismissSummary

        // Summary
        case showSummary(String)
        case showSummaryInPanel(String)
        case resummarize(String)
        case summaryResult(videoId: String, overview: String, keyPoints: [String], chapters: [ChapterInfo], provider: String)
        case summaryFailed(videoId: String, error: String)
        case summaryProgressUpdate(videoId: String, message: String)
        case dismissLibrarySummary
        case setGeminiKeyAlert(Bool)
        case openSettingsForGeminiKey

        // Tagging
        case tagItem(videoId: String, title: String, channel: String)
        case itemTagged(videoId: String, tag: String)

        // Podcast (v2.5.2)
        case podcast(PodcastReducer.Action)

        // Q&A (v2.5.3)
        case openQnA(String)
        case qna(QnAReducer.Action)

        // Mindmap (v2.5.4)
        case mindmap(MindmapReducer.Action)

        // Report
        case report(ReportReducer.Action)
    }

    static func hasSubtitles(for videoId: String) -> Bool {
        let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId)
        let hasTranscript = data?.transcript != nil && !(data?.transcript?.isEmpty ?? true)
        return hasTranscript
    }

    nonisolated static func hasPodcast(for videoId: String) -> Bool {
        MainActor.assumeIsolated {
            PodcastService.shared.getPodcastPath(videoId: videoId) != nil
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.report, action: \.report) { ReportReducer() }
        Scope(state: \.mindmap, action: \.mindmap) { MindmapReducer() }
        Scope(state: \.qna, action: \.qna) { QnAReducer() }
        Scope(state: \.podcast, action: \.podcast) { PodcastReducer() }
        Reduce { state, action in
            switch action {
            case .loadFromDisk:
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    SearchService.rebuildIndex(items: items.filter { $0.trashedAt == nil })
                    await send(.itemsLoaded(items))
                }

            case .itemsLoaded(let items):
                state.items = items.filter { $0.trashedAt == nil }
                state.trashItems = items.filter { $0.trashedAt != nil }
                state.subtitleAvailableIds = Set(items.filter { Self.hasSubtitles(for: $0.id) }.map(\.id))
                state.summaryAvailableIds = Set(items.filter { $0.summary != nil && !($0.summary?.isEmpty ?? true) }.map(\.id))
                let podcastIds = Set(items.filter { Self.hasPodcast(for: $0.id) }.map(\.id))
                return .merge(.send(.podcast(.setAvailableIds(podcastIds))), .send(.checkDigest))

            case .addItem(let item):
                state.items.insert(item, at: 0)
                return .run { _ in
                    await LibraryCacheService.shared.addItem(item)
                }

            case .removeItem(let id):
                state.items.removeAll { $0.id == id }
                state.subtitleAvailableIds.remove(id)
                return .run { _ in
                    await LibraryCacheService.shared.removeItem(id: id)
                }

            case .removeItems(let ids):
                state.items.removeAll { ids.contains($0.id) }
                state.subtitleAvailableIds.subtract(ids)
                return .run { _ in
                    await LibraryCacheService.shared.removeItems(ids: ids)
                }

            case .removeItemsByChannel(let channelId, let channelName):
                let ids = state.items.filter { $0.channelId == channelId || $0.channelName == channelName }.map(\.id)
                state.items.removeAll { ids.contains($0.id) }
                state.subtitleAvailableIds.subtract(ids)
                return .merge(
                    .run { _ in
                        await LibraryCacheService.shared.removeItems(ids: ids)
                    },
                    .send(.calculateDiskUsage)
                )

case .trashItem(let id):
                state.items.removeAll { $0.id == id }
                state.subtitleAvailableIds.remove(id)
                return .run { send in
                    await LibraryCacheService.shared.trashItem(id: id)
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .trashItems(let ids):
                state.items.removeAll { ids.contains($0.id) }
                state.subtitleAvailableIds.subtract(ids)
                return .run { send in
                    await LibraryCacheService.shared.trashItems(ids: ids)
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .trashChannelItems(let channelId, let channelName):
                let ids = state.items.filter { $0.channelId == channelId || $0.channelName == channelName }.map(\.id)
                state.items.removeAll { ids.contains($0.id) }
                state.subtitleAvailableIds.subtract(ids)
                return .run { send in
                    await LibraryCacheService.shared.trashItems(ids: ids)
                    DatabaseManager.shared.deleteDownloadHistory(channel: channelName)
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .loadTrash:
                return .run { send in
                    let items = await LibraryCacheService.shared.trashedItems()
                    await send(.trashLoaded(items))
                }

            case .trashLoaded(let items):
                state.trashItems = items
                return .none

            case .setShowTrash(let show):
                state.showTrash = show
                if show {
                    return .send(.loadTrash)
                }
                return .none

            case .restoreItem(let id):
                return .run { send in
                    await LibraryCacheService.shared.restoreItem(id: id)
                    await send(.loadFromDisk)
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .deletePermanently(let id):
                state.trashItems.removeAll { $0.id == id }
                return .run { send in
                    await LibraryCacheService.shared.permanentlyDeleteItem(id: id)
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .deleteTrashItems(let ids):
                state.trashItems.removeAll { ids.contains($0.id) }
                return .run { send in
                    for id in ids {
                        await LibraryCacheService.shared.permanentlyDeleteItem(id: id)
                    }
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .emptyTrash:
                return .run { send in
                    await LibraryCacheService.shared.emptyTrash()
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .setSearchText(let text):
                state.searchText = text
                state.selectedIds = []
                if text.count >= 2 {
                    let query = text
                    let items = state.items
                    return .run { send in
                        try await clock.sleep(for: .milliseconds(300))
                        let results = SearchService.search(query: query, in: items)
                        await send(.searchResultsUpdated(results))
                    }
                    .cancellable(id: "librarySearch", cancelInFlight: true)
                } else {
                    state.searchResults = []
                    return .none
                }

            case let .searchResultsUpdated(results):
                state.searchResults = results
                return .none

            case let .playSearchMatch(videoId):
                guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
                let query = state.searchText
                let duration = Double(item.duration ?? 0)
                let playerItem = PlayerItem(
                    fileURL: URL(fileURLWithPath: item.filePath),
                    title: item.title,
                    videoId: item.id,
                    duration: duration
                )
                return .run { send in
                    let time = await SearchService.locateMatch(videoId: videoId, query: query, duration: duration)
                    await MainActor.run {
                        var seekItem = playerItem
                        if let time, time > 0 {
                            seekItem = PlayerItem(
                                fileURL: playerItem.fileURL,
                                title: playerItem.title,
                                videoId: playerItem.videoId,
                                duration: playerItem.duration,
                                initialSeekTime: time
                            )
                        }
                        NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: seekItem)
                    }
                }

            case .setSelectedChannel(let channelId):
                state.selectedChannel = channelId
                state.selectedCategory = nil
                state.selectedIds = []
                if channelId != nil {
                    state.sortOrder = .indexDesc
                } else {
                    state.sortOrder = .dateDesc
                }
                return .none

            case .setSelectedCategory(let category):
                state.selectedCategory = category
                state.selectedChannel = nil
                state.filterMode = .all
                state.selectedIds = []
                state.sortOrder = .dateDesc
                return .none

            case .setSortOrder(let order):
                state.sortOrder = order
                return .none

            case .setViewMode(let mode):
                state.viewMode = mode
                return .run { _ in
                    UserDefaults.standard.set(mode.rawValue, forKey: Constants.libraryViewModeKey)
                }

            case .toggleThumbnailPreview:
                state.showThumbnailPreview.toggle()
                let newValue = state.showThumbnailPreview
                return .run { _ in
                    UserDefaults.standard.set(newValue, forKey: "showThumbnailPreview")
                }

            case .setFilterMode(let mode):
                state.filterMode = mode
                state.selectedCategory = nil
                state.selectedIds = []
                return .none

            case .removeSelected:
                let ids = state.selectedIds
                state.items.removeAll { ids.contains($0.id) }
                state.selectedIds = []
                state.subtitleAvailableIds.subtract(ids)
                return .run { send in
                    await LibraryCacheService.shared.trashItems(ids: Array(ids))
                    await send(.loadTrash)
                    await send(.calculateDiskUsage)
                }

            case .revealSelectedInFinder:
                let urls = state.items
                    .filter { state.selectedIds.contains($0.id) }
                    .map { URL(fileURLWithPath: $0.filePath) }
                return .run { _ in await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }}

            case .openSelected:
                let settings = Settings.loadSettings()
                let itemData = state.items
                    .filter { state.selectedIds.contains($0.id) }
                    .map { (filePath: $0.filePath, title: $0.title, id: $0.id, duration: $0.duration, seek: $0.resumePosition) }
                return .run { _ in await MainActor.run {
                    for data in itemData {
                        if settings.playerMode == .systemDefault {
                            NSWorkspace.shared.open(URL(fileURLWithPath: data.filePath))
                        } else {
                            let playerItem = PlayerItem(
                                fileURL: URL(fileURLWithPath: data.filePath),
                                title: data.title,
                                videoId: data.id,
                                duration: Double(data.duration ?? 0),
                                initialSeekTime: data.seek
                            )
                            NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
                        }
                    }
                }}

            case .toggleSelection(let id):
                if state.selectedIds.contains(id) {
                    state.selectedIds.remove(id)
                } else {
                    state.selectedIds.insert(id)
                }
                return .none

            case .selectAll:
                state.selectedIds = Set(state.filteredItems.map(\.id))
                return .none

            case .clearSelection:
                state.selectedIds = []
                return .none

            case .openFile(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let url = URL(fileURLWithPath: item.filePath)
                let settings = Settings.loadSettings()
                if settings.playerMode == .systemDefault {
                    NSWorkspace.shared.open(url)
                } else {
                    let playerItem = PlayerItem(
                        fileURL: url,
                        title: item.title,
                        videoId: item.id,
                        duration: Double(item.duration ?? 0),
                        initialSeekTime: item.resumePosition
                    )
                    let queue = state.filteredItems.map { item in
                        PlayerItem(
                            fileURL: URL(fileURLWithPath: item.filePath),
                            title: item.title,
                            videoId: item.id,
                            duration: Double(item.duration ?? 0),
                            initialSeekTime: item.resumePosition
                        )
                    }
                    let startIndex = queue.firstIndex { $0.videoId == id } ?? 0
                    NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem, userInfo: ["queue": queue, "startIndex": startIndex])
                }
                return .none

            case .revealInFinder(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let url = URL(fileURLWithPath: item.filePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return .none

            case .downloadSubtitles(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let videoURL = "https://www.youtube.com/watch?v=\(item.id)"
                state.subtitleDownloadingIds.insert(id)
                return .run { send in
                    do {
                        let fm = FileManager.default
                        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_subs_\(UUID().uuidString.prefix(8))")
                        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                        let subLangs = LanguageService.subtitleLanguages
                        #if DEBUG
                        Task { @MainActor in DebugLogManager.shared?.append("[Library] --sub-langs: \(subLangs)") }
                        #endif
                        let process = Process()
                        let outputTemplate = tmpDir.appendingPathComponent("%(id)s.%(ext)s").path
                        var args = [
                            "--write-subs",
                            "--sub-langs", subLangs,
                            "--skip-download",
                            "--no-warnings",
                            "-o", outputTemplate,
                        ]
                        args.append(videoURL)
                        if Constants.ytDlpPath.hasPrefix("/") {
                            process.executableURL = URL(fileURLWithPath: Constants.ytDlpPath)
                            process.arguments = args
                        } else {
                            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                            process.arguments = [Constants.ytDlpPath] + args
                        }
                        let stderrPipe = Pipe()
                        process.standardOutput = Pipe()
                        process.standardError = stderrPipe
                        try process.run()
                        process.waitUntilExit()

                        let files = (try? fm.contentsOfDirectory(atPath: tmpDir.path)) ?? []
                        var saved = false
                        for file in files {
                            let path = tmpDir.appendingPathComponent(file)
                            let content = try String(contentsOf: path, encoding: .utf8)
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
                                DatabaseManager.shared.updateTranscript(videoId: id, transcript: text, language: lang, source: "downloaded")
                                saved = true
                            }
                        }
                        try? fm.removeItem(at: tmpDir)

                        let success = process.terminationStatus == 0 && saved
                        let errMsg: String
                        if !success && files.isEmpty {
                            errMsg = "자막 파일 없음"
                        } else if !success {
                            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            errMsg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "알 수 없는 오류"
                        } else {
                            errMsg = ""
                        }
                        await send(.subtitleResult(videoId: id, success: success, errorMessage: errMsg))
                    } catch {
                        await send(.subtitleResult(videoId: id, success: false, errorMessage: error.localizedDescription))
                    }
                }

            case .subtitleResult(let videoId, let success, let errorMessage):
                state.subtitleDownloadingIds.remove(videoId)
                if success {
                    state.subtitleAvailableIds.insert(videoId)
                }
                let message: String
                if success {
                    message = "자막 다운로드 완료"
                } else {
                    let reason: String
                    if errorMessage.contains("429") {
                        reason = "\nYouTube 요청 제한 (429)\n잠시 후 다시 시도하세요"
                    } else if errorMessage.isEmpty {
                        reason = ""
                    } else {
                        reason = "\n\(errorMessage)"
                    }
                    message = "자막 다운로드 실패\(reason)"
                }
                let toast = ToastMessage(id: UUID(), message: message, type: success ? .success : .error)
                state.subtitleToast = toast
                state.subtitleToastVideoId = success ? videoId : nil
                return .merge(
                    .run { send in
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.dismissSubtitleToast)
                    },
                    .send(.showSubtitleToastToast(toast))
                )

            case .showSubtitleToastToast:
                return .none

            case .dismissSubtitleToast:
                state.subtitleToast = nil
                state.subtitleToastVideoId = nil
                return .none

            case .openChannelDownload(let channelId, let channelName):
                // 창을 즉시 열고, 채널 정보 조회는 ChannelDownloaderView가 백그라운드에서 처리한다.
                return .run { _ in
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Constants.openChannelWithIdNotification,
                            object: nil,
                            userInfo: ["channelId": channelId, "channelName": channelName]
                        )
                    }
                }
            case .calculateDiskUsage:
                return .run { send in
                    let bytes = LibraryCacheService.calculateDiskUsage()
                    await send(.diskUsageUpdated(bytes))
                }
            case let .diskUsageUpdated(bytes):
                state.diskUsageBytes = bytes
                return .none

            case .checkDigest:
                let lastDigest = UserDefaults.standard.object(forKey: "lastDigestDate") as? Date ?? .distantPast
                if Date().timeIntervalSince(lastDigest) < 7 * 86400 { return .none }
                let items = state.items
                let history = DatabaseManager.shared.loadDownloadHistory()
                return .run { send in
                    let stats = await DigestService.collectStats(period: .week, items: items, history: history)
                    let narrative = await DigestService.generateNarrative(stats: stats)
                    var s = stats
                    s.aiNarrative = narrative
                    await send(.digestLoaded(s))
                }

            case let .digestLoaded(stats):
                state.digestStats = stats
                state.showDigest = true
                UserDefaults.standard.set(Date(), forKey: "lastDigestDate")
                return .none

            case .dismissDigest:
                state.showDigest = false
                return .none

            // Report (reducer-scoped)
            case .report:
                return .none

            // Navigation
            case let .setSidebarMode(mode):
                state.isShowingProfileRecommendations = false
                state.sidebarMode = mode
                if mode != .history { state.historyFilterChannel = nil }
                if mode == .discover, state.discoverVideos.isEmpty {
                    return .send(.fetchTrending)
                }
                return .none

            case .selectProfileRecommendations:
                state.isShowingProfileRecommendations = true
                state.discoverCategory = .all
                state.profileRecommendationsLoading = true
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    let channels = await MainActor.run { SubscribedChannel.loadAll() }
                    let history = DatabaseManager.shared.loadDownloadHistory()
                    let diskUsage = LibraryCacheService.calculateDiskUsage()
                    let profile = ProfileService.calculate(items: items, channels: channels, history: history, diskUsage: diskUsage)
                    let queries = RecommendationService.recommendedSearchQueries(from: profile)
                    let service = TrendingService()
                    var allVideos: [TrendingVideo] = []
                    for query in queries {
                        if let results = try? await service.search(query: query, maxResults: 10) {
                            allVideos.append(contentsOf: results)
                        }
                    }
                    let downloadedIds = Set(items.map(\.id))
                    allVideos = allVideos.filter { !downloadedIds.contains($0.id) }
                    await send(.profileRecommendationsLoaded(allVideos))
                }

            case let .profileRecommendationsLoaded(videos):
                state.profileRecommendations = videos
                state.profileRecommendationsLoading = false
                return .none

            case let .setHistoryFilterChannel(channel):
                state.historyFilterChannel = channel
                return .none

            case let .setHistorySearchText(text):
                state.historySearchText = text
                return .none

            // Discover
            case let .selectDiscoverCategory(category):
                state.isShowingProfileRecommendations = false
                state.discoverCategory = category
                if state.discoverVideos[category] == nil {
                    return .send(.fetchTrending)
                }
                return .none

            case .fetchTrending:
                state.discoverLoading = true
                state.discoverError = nil
                return .run { [category = state.discoverCategory] send in
                    let service = TrendingService()
                    do {
                        let videos = try await service.fetch(category: category)
                        await send(.trendingLoaded(category: category, videos: videos))
                    } catch {
                        await send(.trendingFailed(error.localizedDescription))
                    }
                }

            case let .trendingLoaded(category, videos):
                state.discoverLoading = false
                state.discoverVideos[category] = videos
                return .none

            case let .trendingFailed(error):
                state.discoverLoading = false
                state.discoverError = error
                return .none

            case .refreshTrending:
                state.discoverVideos.removeAll()
                state.discoverSearchText = ""
                state.discoverSearchResults = []
                return .send(.fetchTrending)

            // Discover Search
            case let .setDiscoverSearchText(text):
                state.discoverSearchText = text
                if text.isEmpty {
                    state.discoverSearchResults = []
                    state.discoverSearching = false
                }
                return .none

            case .discoverSearch:
                let query = state.discoverSearchText
                guard !query.isEmpty else { return .none }
                state.discoverSearching = true
                state.discoverError = nil
                return .run { send in
                    let service = TrendingService()
                    do {
                        let videos = try await service.search(query: query)
                        await send(.discoverSearchLoaded(videos))
                    } catch {
                        await send(.discoverSearchFailed(error.localizedDescription))
                    }
                }

            case let .discoverSearchLoaded(videos):
                state.discoverSearching = false
                state.discoverSearchResults = videos
                return .none

            case let .discoverSearchFailed(error):
                state.discoverSearching = false
                state.discoverError = error
                return .none

            // Discover Summary
            case let .discoverRequestSummary(videoId, title, channel):
                state.discoverSummaryVideoId = videoId
                state.discoverSummaryLoading = true
                state.discoverSummaryText = nil
                return .run { send in
                    let service = SummarizationService()
                    let keys = Settings.loadAPIKeys()
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: title, channel: channel, openRouterAPIKey: keys.openRouter, geminiAPIKey: keys.gemini)
                        await send(.discoverSummaryLoaded(videoId: videoId, text: "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n"), provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.discoverSummaryFailed(videoId: videoId, error: error.localizedDescription))
                    } catch {
                        await send(.discoverSummaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .discoverSummaryLoaded(videoId, text, provider):
                guard videoId == state.discoverSummaryVideoId else { return .none }
                state.discoverSummaryLoading = false
                state.discoverSummaryText = text
                state.discoverSummaryProvider = provider
                return .none

            case let .discoverSummaryFailed(videoId, error):
                guard videoId == state.discoverSummaryVideoId else { return .none }
                state.discoverSummaryLoading = false
                state.discoverSummaryText = "요약 실패\n\n\(error)"
                return .none

            case .discoverDismissSummary:
                state.discoverSummaryVideoId = nil
                state.discoverSummaryText = nil
                state.discoverSummaryProvider = nil
                state.discoverSummaryLoading = false
                return .none

            // Summary
            case let .showSummary(videoId):
                return handleShowSummary(state: &state, videoId: videoId, openWindow: true)

            case let .showSummaryInPanel(videoId):
                return handleShowSummary(state: &state, videoId: videoId, openWindow: false)

            case let .resummarize(videoId):
                guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
                state.librarySummaryVideoId = videoId
                state.librarySummaryLoading = true
                state.summaryProgressMessage = "자막 확인 중..."
                state.librarySummaryText = nil
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].summary = nil
                }
                let resummaryTitle = item.title
                let resummaryChannel = item.channelName
                return .run { send in
                    DatabaseManager.shared.updateSummary(videoId: videoId, summary: nil)
                    let progress: @Sendable (String) -> Void = { message in
                        Task { @MainActor in
                            await send(.summaryProgressUpdate(videoId: videoId, message: message))
                        }
                    }
                    let service = SummarizationService()
                    let keys = Settings.loadAPIKeys()
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: resummaryTitle, channel: resummaryChannel, openRouterAPIKey: keys.openRouter, geminiAPIKey: keys.gemini, progress: progress)
                        await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    } catch {
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .summaryResult(videoId, overview, keyPoints, chapters, provider):
                state.summaryProgressMessage = ""
                let joined = "\(overview)\n\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
                if videoId == state.librarySummaryVideoId {
                    state.librarySummaryLoading = false
                    state.librarySummaryProvider = provider
                    state.librarySummaryText = joined
                }
                state.summaryAvailableIds.insert(videoId)
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].summary = joined
                    let chaptersData = try? JSONEncoder().encode(chapters)
                    state.items[idx].chapters = chaptersData
                    let updated = state.items[idx]
                    return .run { _ in
                        await LibraryCacheService.shared.updateItem(updated)
                        DatabaseManager.shared.updateSummary(videoId: videoId, summary: joined)
                        DatabaseManager.shared.updateChapters(videoId: videoId, chapters: chaptersData ?? Data())
                    }
                }
                return .none

            case let .summaryProgressUpdate(videoId, message):
                if videoId == state.librarySummaryVideoId {
                    state.summaryProgressMessage = message
                }
                return .none

            case let .summaryFailed(videoId, error):
                state.summaryProgressMessage = ""
                if videoId == state.librarySummaryVideoId {
                    state.librarySummaryLoading = false
                    state.librarySummaryText = "요약 실패\n\n\(error)"
                }
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].summary = "요약 실패: \(error)"
                }
                return .none

            case .dismissLibrarySummary:
                state.librarySummaryVideoId = nil
                state.librarySummaryText = nil
                state.summaryProgressMessage = ""
                state.librarySummaryProvider = nil
                state.librarySummaryLoading = false
                return .none

            case let .setGeminiKeyAlert(show):
                state.showGeminiKeyAlert = show
                return .none

            case .openSettingsForGeminiKey:
                state.showGeminiKeyAlert = false
                return .run { _ in await MainActor.run {
                    NotificationCenter.default.post(name: Constants.openSettingsWindowNotification, object: nil)
                }}

            // Tagging
            case let .tagItem(videoId, title, channel):
                return .run { send in
                    let service = TaggingService()
                    let keys = Settings.loadAPIKeys()
                    let tag = await service.classify(title: title, channel: channel, openRouterAPIKey: keys.openRouter, geminiAPIKey: keys.gemini)
                    await send(.itemTagged(videoId: videoId, tag: tag))
                }

            case let .itemTagged(videoId, tag):
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].tags = [tag]
                    let updated = state.items[idx]
                    return .run { _ in
                        await LibraryCacheService.shared.updateItem(updated)
                    }
                }
                return .none

            // Podcast (reducer-scoped)
            case let .podcast(action):
                switch action {
                case let .generatePodcast(videoId):
                    if let item = state.items.first(where: { $0.id == videoId }) {
                        state.librarySummaryVideoId = videoId
                        state.librarySummaryLoading = false
                        if let existing = item.summary, !existing.isEmpty, !existing.hasPrefix("요약 실패") {
                            state.librarySummaryText = existing
                        } else {
                            state.librarySummaryText = nil
                        }
                    }
                default:
                    break
                }
                return .none

            // Q&A (reducer-scoped)
            case let .openQnA(videoId):
                return .merge(
                    .send(.qna(.open(videoId))),
                    .send(.showSummary(videoId))
                )

            case .qna:
                return .none

            // Mindmap (reducer-scoped)
            case .mindmap:
                return .none
            }
        }
    }

    private func handleShowSummary(state: inout State, videoId: String, openWindow: Bool) -> Effect<Action> {
        guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
        state.librarySummaryVideoId = videoId
        // 기존 요약이 있으면 API 호출 없이 표시
        if let existing = item.summary, !existing.isEmpty, !existing.hasPrefix("요약 실패") {
            state.librarySummaryText = existing
            state.librarySummaryLoading = false
            return .merge(
                .send(.mindmap(.resetForVideo(videoId))),
                .send(.qna(.resetForVideo(videoId))),
                .run { _ in
                    await MainActor.run {
                        if openWindow {
                            NotificationCenter.default.post(name: Constants.openAIWindowNotification, object: nil)
                        }
                    }
                }
            )
        }
        state.librarySummaryLoading = true
        state.summaryProgressMessage = "자막 확인 중..."
        state.librarySummaryText = nil
        let summaryTitle = item.title
        let summaryChannel = item.channelName
        return .merge(
            .send(.mindmap(.resetForVideo(videoId))),
            .send(.qna(.resetForVideo(videoId))),
            .run { send in
                await MainActor.run {
                    if openWindow {
                        NotificationCenter.default.post(name: Constants.openAIWindowNotification, object: nil)
                    }
                }
                let progress: @Sendable (String) -> Void = { message in
                    Task { @MainActor in
                        await send(.summaryProgressUpdate(videoId: videoId, message: message))
                    }
                }
                let service = SummarizationService()
                let keys = Settings.loadAPIKeys()
                do {
                    let result = try await service.summarizeVideo(videoId: videoId, title: summaryTitle, channel: summaryChannel, openRouterAPIKey: keys.openRouter, geminiAPIKey: keys.gemini, progress: progress)
                    await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: result.provider))
                } catch let error as SummarizationService.SummaryError {
                    if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                    await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                } catch {
                    await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                }
            }
        )
    }
}
