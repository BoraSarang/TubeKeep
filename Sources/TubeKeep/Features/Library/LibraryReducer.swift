import Foundation
import AppKit
import ComposableArchitecture

enum LibrarySidebarMode: String, Equatable {
    case library = "Library"
    case discover = "Discover"
    case history = "History"
}

@Reducer
struct LibraryReducer {
    @ObservableState
    struct State: Equatable {
        var items: [LibraryItem] = []
        var searchText = ""
        var selectedChannel: String? = nil
        var sortOrder: LibrarySortOrder = .dateDesc
        var filterMode: LibraryFilterMode = .all
        var viewMode: LibraryViewMode = .grid
        var showThumbnailPreview: Bool = true
        var isLoading = false
        var selectedIds: Set<String> = []
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
        var podcastGeneratingIds: Set<String> = []
        var podcastProgressMessage = ""
        var podcastPlayingId: String?
        var podcastError: String?
        var podcastAvailableIds: Set<String> = []
        var podcastLastEngine: String?

        // Q&A (v2.5.3)
        var qnaHistoryItems: [QAHistoryItem] = []
        var qnaLoading = false
        var qnaError: String?
        var qnaSelectedVideoId: String?
        var qnaShowSheet = false

        // Mindmap (v2.5.4)
        var mindmapNode: MindmapNode?
        var mindmapLoading = false
        var mindmapError: String?
        var mindmapShow = false

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
                result = result.filter { $0.channelId == channelId }
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
        case removeItemsByChannel(channelId: String, channelName: String)
        case removeSelected
        case revealSelectedInFinder
        case openSelected
        case setSearchText(String)
        case setSelectedChannel(String?)
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
        case discoverSummaryLoaded(text: String, provider: String)
        case discoverSummaryFailed(String)
        case discoverDismissSummary

        // Summary
        case showSummary(String)
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
        case generatePodcast(String)
        case podcastProgressUpdate(videoId: String, message: String)
        case podcastGenerated(String, PodcastResult)
        case podcastGenerationFailed(String, String)
        case playPodcast(String)
        case pausePodcast
        case stopPodcast
        case deletePodcast(String)

        // Q&A (v2.5.3)
        case openQnA(String)
        case closeQnA
        case askQuestion(videoId: String, question: String)
        case qnaResponseReceived(QAResponse)
        case qnaFailed(String)
        case loadQnAHistory(String)
        case qnaHistoryLoaded([QAHistoryItem])
        case deleteQnAHistoryItem(Int64)
        case deleteAllQnAHistory(String)
        case seekToTimestamp(Double)

        // Mindmap (v2.5.4)
        case generateMindmap(String)
        case mindmapResult(MindmapNode)
        case mindmapFailed(String)
        case toggleMindmap
    }

    static func loadSettings() -> Settings {
        guard let json = UserDefaults.standard.string(forKey: Constants.settingsSaveKey),
              let data = json.data(using: .utf8),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return settings
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
        Reduce { state, action in
            switch action {
            case .loadFromDisk:
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    await send(.itemsLoaded(items))
                }

            case .itemsLoaded(let items):
                state.items = items
                state.subtitleAvailableIds = Set(items.filter { Self.hasSubtitles(for: $0.id) }.map(\.id))
                state.summaryAvailableIds = Set(items.filter { $0.summary != nil && !($0.summary?.isEmpty ?? true) }.map(\.id))
                state.podcastAvailableIds = Set(items.filter { Self.hasPodcast(for: $0.id) }.map(\.id))
                return .none

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

            case .setSearchText(let text):
                state.searchText = text
                state.selectedIds = []
                return .none

            case .setSelectedChannel(let channelId):
                state.selectedChannel = channelId
                state.selectedIds = []
                if channelId != nil {
                    state.sortOrder = .indexDesc
                } else {
                    state.sortOrder = .dateDesc
                }
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
                state.selectedIds = []
                return .none

            case .removeSelected:
                let ids = state.selectedIds
                state.items.removeAll { ids.contains($0.id) }
                state.selectedIds = []
                state.subtitleAvailableIds.subtract(ids)
                return .merge(
                    .run { _ in
                        await LibraryCacheService.shared.removeItems(ids: Array(ids))
                    },
                    .send(.calculateDiskUsage)
                )

            case .revealSelectedInFinder:
                let urls = state.items
                    .filter { state.selectedIds.contains($0.id) }
                    .map { URL(fileURLWithPath: $0.filePath) }
                return .run { _ in await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }}

            case .openSelected:
                let settings = Self.loadSettings()
                let itemData = state.items
                    .filter { state.selectedIds.contains($0.id) }
                    .map { (filePath: $0.filePath, title: $0.title, id: $0.id, duration: $0.duration) }
                return .run { _ in await MainActor.run {
                    for data in itemData {
                        if settings.playerMode == .systemDefault {
                            NSWorkspace.shared.open(URL(fileURLWithPath: data.filePath))
                        } else {
                            let playerItem = PlayerItem(
                                fileURL: URL(fileURLWithPath: data.filePath),
                                title: data.title,
                                videoId: data.id,
                                duration: Double(data.duration ?? 0)
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
                let settings = Self.loadSettings()
                if settings.playerMode == .systemDefault {
                    NSWorkspace.shared.open(url)
                } else {
                    let playerItem = PlayerItem(
                        fileURL: url,
                        title: item.title,
                        videoId: item.id,
                        duration: Double(item.duration ?? 0)
                    )
                    NotificationCenter.default.post(name: Constants.openPlayerWindowNotification, object: playerItem)
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
                            "--write-subs", "--write-auto-subs",
                            "--sub-langs", subLangs,
                            "--skip-download",
                            "--no-warnings",
                            "-o", outputTemplate,
                        ]
                        let cookies = LanguageService.cookiesArgs
                        if !cookies.isEmpty { args += cookies }
                        #if DEBUG
                        if !cookies.isEmpty { Task { @MainActor in DebugLogManager.shared?.append("[Library] 쿠키 적용: \(cookies.joined(separator: " "))") } }
                        #endif
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
                                DatabaseManager.shared.updateTranscript(videoId: id, transcript: text, language: lang)
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
                return .run { _ in
                    let existingInfo = await MainActor.run { () -> [String: Any]? in
                        let channels = SubscribedChannel.loadAll()
                        guard let existing = channels.first(where: { $0.id == channelId || $0.name == channelName }) else { return nil }
                        return [
                            "channelId": existing.id,
                            "channelName": existing.name,
                            "channelHandle": existing.handle ?? "",
                            "channelAvatarURL": existing.avatarURL,
                            "channelSubscriberCount": existing.subscriberCount ?? 0,
                            "channelVideoCount": existing.videoCount,
                        ]
                    }
                    if let info = existingInfo {
                        await MainActor.run {
                            NotificationCenter.default.post(name: Constants.openChannelWithIdNotification, object: nil, userInfo: info)
                        }
                    } else {
                        let service = ChannelFetchService()
                        let url: String
                        if channelId.hasPrefix("UC") {
                            url = "https://www.youtube.com/channel/\(channelId)"
                        } else if channelId.hasPrefix("@") {
                            url = "https://www.youtube.com/\(channelId)/videos"
                        } else {
                            url = "https://www.youtube.com/@\(channelName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? channelName)/videos"
                        }
                        if let channel = try? await service.fetchChannelInfo(from: url) {
                            let chId = channel.id
                            let chName = channel.name
                            let chHandle = channel.handle
                            let chAvatar = channel.avatarURL
                            let chSubs = channel.subscriberCount
                            let chVids = channel.videoCount
                            let info: [String: Any] = [
                                "channelId": chId,
                                "channelName": chName,
                                "channelHandle": chHandle ?? "",
                                "channelAvatarURL": chAvatar,
                                "channelSubscriberCount": chSubs ?? 0,
                                "channelVideoCount": chVids,
                            ]
                            await MainActor.run {
                                var updated = SubscribedChannel.loadAll()
                                updated.removeAll { $0.name == chName }
                                let newChannel = SubscribedChannel(id: chId, name: chName, handle: chHandle, avatarURL: chAvatar, subscriberCount: chSubs, videoCount: chVids)
                                updated.insert(newChannel, at: 0)
                                SubscribedChannel.saveAll(updated)
                                NotificationCenter.default.post(name: Constants.openChannelWithIdNotification, object: nil, userInfo: info)
                            }
                        } else {
                            await MainActor.run {
                                NotificationCenter.default.post(name: Constants.openChannelWithIdNotification, object: nil, userInfo: ["channelId": channelId, "channelName": channelName])
                            }
                        }
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

            // Navigation
            case let .setSidebarMode(mode):
                state.sidebarMode = mode
                if mode != .history { state.historyFilterChannel = nil }
                if mode == .discover, state.discoverVideos.isEmpty {
                    return .send(.fetchTrending)
                }
                return .none

            case let .setHistoryFilterChannel(channel):
                state.historyFilterChannel = channel
                return .none

            case let .setHistorySearchText(text):
                state.historySearchText = text
                return .none

            // Discover
            case let .selectDiscoverCategory(category):
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
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    let ax4Key = UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey
                    let geminiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: title, channel: channel, openRouterAPIKey: openRouterKey, ax4APIKey: ax4Key, geminiAPIKey: geminiKey)
                        await send(.discoverSummaryLoaded(text: "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n"), provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.discoverSummaryFailed(error.localizedDescription))
                    } catch {
                        await send(.discoverSummaryFailed(error.localizedDescription))
                    }
                }

            case let .discoverSummaryLoaded(text, provider):
                state.discoverSummaryLoading = false
                state.discoverSummaryText = text
                state.discoverSummaryProvider = provider
                return .none

            case let .discoverSummaryFailed(error):
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
                guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
                if state.librarySummaryVideoId != videoId {
                    state.qnaHistoryItems = []
                }
                state.librarySummaryVideoId = videoId
                state.qnaSelectedVideoId = videoId
                state.mindmapNode = nil
                state.mindmapError = nil
                state.mindmapLoading = false
                state.mindmapShow = false
                // 기존 마인드맵이 있으면 로드
                if let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                   let mindmapData = data.mindmap,
                   let existing = try? JSONDecoder().decode(MindmapNode.self, from: mindmapData) {
                    state.mindmapNode = existing
                    state.mindmapShow = true
                }
                // 기존 요약이 있으면 API 호출 없이 표시
                if let existing = item.summary, !existing.isEmpty, !existing.hasPrefix("요약 실패") {
                    state.librarySummaryText = existing
                    state.librarySummaryLoading = false
                    return .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(name: Constants.openAIWindowNotification, object: nil)
                        }
                    }
                }
                state.librarySummaryLoading = true
                state.summaryProgressMessage = "자막 확인 중..."
                state.librarySummaryText = nil
                let summaryTitle = item.title
                let summaryChannel = item.channelName
                return .run { send in
                    await MainActor.run {
                        NotificationCenter.default.post(name: Constants.openAIWindowNotification, object: nil)
                    }
                    let progress: @Sendable (String) -> Void = { message in
                        Task { @MainActor in
                            await send(.summaryProgressUpdate(videoId: videoId, message: message))
                        }
                    }
                    let service = SummarizationService()
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    let ax4Key = UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey
                    let geminiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: summaryTitle, channel: summaryChannel, openRouterAPIKey: openRouterKey, ax4APIKey: ax4Key, geminiAPIKey: geminiKey, progress: progress)
                        await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    } catch {
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

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
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    let ax4Key = UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey
                    let geminiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: resummaryTitle, channel: resummaryChannel, openRouterAPIKey: openRouterKey, ax4APIKey: ax4Key, geminiAPIKey: geminiKey, progress: progress)
                        await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints, chapters: result.chapters, provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    } catch {
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .summaryResult(videoId, overview, keyPoints, chapters, provider):
                state.librarySummaryLoading = false
                state.summaryProgressMessage = ""
                state.librarySummaryProvider = provider
                let joined = "\(overview)\n\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
                state.librarySummaryText = joined
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

            case .summaryProgressUpdate(_, let message):
                state.summaryProgressMessage = message
                return .none

            case let .summaryFailed(videoId, error):
                state.librarySummaryLoading = false
                state.summaryProgressMessage = ""
                state.librarySummaryText = "요약 실패\n\n\(error)"
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
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    let ax4Key = UserDefaults.standard.string(forKey: "ax4APIKey") ?? Constants.defaultAX4APIKey
                    let geminiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    let tag = await service.classify(title: title, channel: channel, openRouterAPIKey: openRouterKey, ax4APIKey: ax4Key, geminiAPIKey: geminiKey)
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

            // Podcast
            case let .generatePodcast(videoId):
                guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
                state.podcastGeneratingIds.insert(videoId)
                state.podcastError = nil
                // 요약 팝업 열기
                state.librarySummaryVideoId = videoId
                state.librarySummaryLoading = false
                if let existing = item.summary, !existing.isEmpty, !existing.hasPrefix("요약 실패") {
                    state.librarySummaryText = existing
                } else {
                    state.librarySummaryText = nil
                }
                let podcastTitle = item.title
                let podcastChannel = item.channelName
                return .run { send in
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    do {
                        let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId)
                        guard let transcript = data?.transcript, !transcript.isEmpty else {
                            await send(.podcastGenerationFailed(videoId, "자막이 없어 팟캐스트를 생성할 수 없습니다."))
                            return
                        }
                        let progress: @MainActor @Sendable (String) -> Void = { msg in
                            Task { @MainActor in
                                await send(.podcastProgressUpdate(videoId: videoId, message: msg))
                            }
                        }
                        let result = try await PodcastService.shared.generatePodcast(
                            videoId: videoId,
                            title: podcastTitle,
                            channel: podcastChannel,
                            transcript: transcript,
                            openRouterAPIKey: openRouterKey,
                            progress: progress
                        )
                        await send(.podcastGenerated(videoId, result))
                    } catch {
                        await send(.podcastGenerationFailed(videoId, error.localizedDescription))
                    }
                }

            case .podcastProgressUpdate(_, let message):
                state.podcastProgressMessage = message
                return .none

            case let .podcastGenerated(videoId, result):
                state.podcastGeneratingIds.remove(videoId)
                state.podcastProgressMessage = ""
                state.podcastAvailableIds.insert(videoId)
                state.podcastLastEngine = result.engineName
                return .none

            case let .podcastGenerationFailed(videoId, error):
                state.podcastGeneratingIds.remove(videoId)
                state.podcastProgressMessage = ""
                state.podcastError = error
                return .none

            case let .playPodcast(videoId):
                state.podcastPlayingId = videoId
                return .merge(
                    .run { _ in
                        do {
                            try await PodcastService.shared.playPodcast(videoId: videoId)
                        } catch {
                            #if DEBUG
                            Task { @MainActor in
                                DebugLogManager.shared?.append("[Podcast] 재생 실패: \(error.localizedDescription)")
                            }
                            #endif
                        }
                    },
                    .run { send in
                        for await _ in NotificationCenter.default.notifications(named: .podcastPlaybackFinished) {
                            await send(.stopPodcast)
                        }
                    }
                )

            case .pausePodcast:
                return .run { _ in
                    await PodcastService.shared.pausePodcast()
                }

            case .stopPodcast:
                state.podcastPlayingId = nil
                return .run { _ in
                    await PodcastService.shared.stopPodcast()
                }

            case let .deletePodcast(videoId):
                // 재생 중이면 중지
                if state.podcastPlayingId == videoId {
                    state.podcastPlayingId = nil
                }
                state.podcastAvailableIds.remove(videoId)
                return .run { _ in
                    try? await PodcastService.shared.deletePodcast(videoId: videoId)
                }

            // Q&A (v2.5.3)
            case let .openQnA(videoId):
                state.qnaSelectedVideoId = videoId
                state.qnaHistoryItems = []
                state.qnaShowSheet = true
                return .send(.showSummary(videoId))

            case .closeQnA:
                state.qnaShowSheet = false
                state.qnaSelectedVideoId = nil
                state.qnaHistoryItems = []
                return .none

            case let .askQuestion(videoId, question):
                state.qnaLoading = true
                state.qnaError = nil
                return .run { send in
                    guard let item = await LibraryCacheService.shared.loadItems().first(where: { $0.id == videoId }),
                          let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                          let transcript = data.transcript, !transcript.isEmpty else {
                        await send(.qnaFailed("자막이 없습니다"))
                        return
                    }
                    let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                    do {
                        let response = try await QAService.shared.ask(
                            videoId: videoId,
                            question: question,
                            transcript: transcript,
                            title: item.title,
                            openRouterAPIKey: openRouterKey
                        )
                        await send(.qnaResponseReceived(response))
                    } catch {
                        await send(.qnaFailed(error.localizedDescription))
                    }
                }

            case .qnaResponseReceived:
                state.qnaLoading = false
                if let videoId = state.qnaSelectedVideoId {
                    return .send(.loadQnAHistory(videoId))
                }
                return .none

            case let .qnaFailed(error):
                state.qnaLoading = false
                state.qnaError = error
                return .none

            case let .loadQnAHistory(videoId):
                return .run { send in
                    let items = await QAService.shared.loadHistory(videoId: videoId)
                    await send(.qnaHistoryLoaded(items))
                }

            case let .qnaHistoryLoaded(items):
                state.qnaHistoryItems = items
                return .none

            case let .deleteQnAHistoryItem(id):
                let selectedVideoId = state.qnaSelectedVideoId
                return .run { send in
                    await QAService.shared.deleteHistory(id: id)
                    if let videoId = selectedVideoId {
                        await send(.loadQnAHistory(videoId))
                    }
                }

            case let .deleteAllQnAHistory(videoId):
                return .run { send in
                    await QAService.shared.deleteAllHistory(videoId: videoId)
                    await send(.qnaHistoryLoaded([]))
                }

            case let .seekToTimestamp(time):
                NotificationCenter.default.post(name: .seekToTime, object: time)
                return .none

            // Mindmap (v2.5.4)
            case let .generateMindmap(videoId):
                guard let item = state.items.first(where: { $0.id == videoId }),
                      let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId),
                      let transcript = data.transcript, !transcript.isEmpty else {
                    state.mindmapError = "자막이 없습니다"
                    return .none
                }
                if let mindmapData = data.mindmap,
                   let existing = try? JSONDecoder().decode(MindmapNode.self, from: mindmapData) {
                    state.mindmapNode = existing
                    state.mindmapShow = true
                    return .none
                }
                state.mindmapLoading = true
                state.mindmapError = nil
                state.mindmapShow = true
                let openRouterKey = UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? ""
                let mindmapTitle = item.title
                let mindmapChannel = item.channelName
                return .run { send in
                    do {
                        let node = try await MindmapService.shared.generate(
                            videoId: videoId,
                            transcript: transcript,
                            title: mindmapTitle,
                            channel: mindmapChannel,
                            openRouterAPIKey: openRouterKey
                        )
                        await send(.mindmapResult(node))
                    } catch {
                        await send(.mindmapFailed(error.localizedDescription))
                    }
                }

            case let .mindmapResult(node):
                state.mindmapLoading = false
                state.mindmapNode = node
                return .none

            case let .mindmapFailed(error):
                state.mindmapLoading = false
                state.mindmapError = error
                print("[MindmapRedux] ❌ mindmapFailed — \(error)")
                return .none

            case .toggleMindmap:
                state.mindmapShow.toggle()
                if !state.mindmapShow {
                    state.mindmapNode = nil
                    state.mindmapError = nil
                }
                return .none
            }
        }
    }
}
