import Foundation
import AppKit
import ComposableArchitecture

enum LibrarySidebarMode: String, Equatable {
    case library = "Library"
    case discover = "Discover"
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
        var isLoading = false
        var selectedIds: Set<String> = []
        var subtitleDownloadingIds: Set<String> = []
        var subtitleAvailableIds: Set<String> = []
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
        var discoverSummaryLoading = false

        // Library Summary
        var librarySummaryVideoId: String?
        var librarySummaryText: String?
        var librarySummaryLoading = false

        // Gemini API Key Alert
        var showGeminiKeyAlert = false

        init() {
            let saved = UserDefaults.standard.string(forKey: Constants.libraryViewModeKey) ?? "grid"
            viewMode = LibraryViewMode(rawValue: saved) ?? .grid
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
        case openFile(String)
        case revealInFinder(String)
        case downloadSubtitles(String)
        case subtitleResult(videoId: String, success: Bool, errorMessage: String)
        case dismissSubtitleToast
        case toggleSelection(String)
        case selectAll
        case clearSelection
        case openChannelDownload(channelId: String, channelName: String)
        case calculateDiskUsage
        case diskUsageUpdated(Int64)

        // Navigation
        case setSidebarMode(LibrarySidebarMode)

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
        case discoverSummaryLoaded(text: String)
        case discoverSummaryFailed(String)
        case discoverDismissSummary

        // Summary
        case showSummary(String)
        case summaryResult(videoId: String, overview: String, keyPoints: [String])
        case summaryFailed(videoId: String, error: String)
        case dismissLibrarySummary
        case setGeminiKeyAlert(Bool)
        case openSettingsForGeminiKey

        // Tagging
        case tagItem(videoId: String, title: String, channel: String)
        case itemTagged(videoId: String, tag: String)
    }

    static func hasSubtitles(for filePath: String) -> Bool {
        let dir = (filePath as NSString).deletingLastPathComponent
        let basename = ((filePath as NSString).lastPathComponent as NSString).deletingPathExtension
        let comps = basename.components(separatedBy: ".")
        guard let videoId = comps.last, !videoId.isEmpty,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return false }
        let subPatterns = [".en.srt", ".ko.srt", ".en.vtt", ".ko.vtt"]
        return subPatterns.contains { pattern in
            files.contains { $0.hasSuffix("\(videoId)\(pattern)") }
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
                state.subtitleAvailableIds = Set(items.filter { Self.hasSubtitles(for: $0.filePath) }.map(\.id))
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
                let items = state.items.filter { state.selectedIds.contains($0.id) }
                return .run { _ in await MainActor.run {
                    for item in items {
                        let url = URL(fileURLWithPath: item.filePath)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }}

            case .openSelected:
                let items = state.items.filter { state.selectedIds.contains($0.id) }
                return .run { _ in await MainActor.run {
                    for item in items {
                        let url = URL(fileURLWithPath: item.filePath)
                        NSWorkspace.shared.open(url)
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
                NSWorkspace.shared.open(url)
                return .none

            case .revealInFinder(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let url = URL(fileURLWithPath: item.filePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return .none

            case .downloadSubtitles(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let videoURL = "https://www.youtube.com/watch?v=\(item.id)"
                let basePath = (item.filePath as NSString).deletingPathExtension
                state.subtitleDownloadingIds.insert(id)
                return .run { send in
                    do {
                        let process = Process()
                        let args = [
                            "--write-subs", "--write-auto-subs",
                            "--sub-langs", "en,ko",
                            "--skip-download",
                            "--no-warnings",
                            "-o", "\(basePath).%(ext)s",
                            videoURL,
                        ]
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
                        let success = process.terminationStatus == 0
                        let errMsg: String
                        if !success {
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
                state.subtitleToast = ToastMessage(id: UUID(), message: message, type: success ? .success : .error)
                state.subtitleToastVideoId = success ? videoId : nil
                return .run { send in
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await send(.dismissSubtitleToast)
                }

            case .dismissSubtitleToast:
                state.subtitleToast = nil
                state.subtitleToastVideoId = nil
                return .none

            case .openChannelDownload(let channelId, let channelName):
                return .run { _ in
                    let channels = SubscribedChannel.loadAll()
                    var targetChannel: SubscribedChannel?

                    if let existing = channels.first(where: { $0.id == channelId || $0.name == channelName }) {
                        targetChannel = existing
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
                            var updated = SubscribedChannel.loadAll()
                            updated.removeAll { $0.name == channel.name }
                            updated.insert(channel, at: 0)
                            SubscribedChannel.saveAll(updated)
                            targetChannel = channel
                        }
                    }
                    let channelData = targetChannel
                    await MainActor.run {
                        let info: [String: Any]
                        if let ch = channelData {
                            info = [
                                "channelId": ch.id,
                                "channelName": ch.name,
                                "channelHandle": ch.handle ?? "",
                                "channelAvatarURL": ch.avatarURL,
                                "channelSubscriberCount": ch.subscriberCount ?? 0,
                                "channelVideoCount": ch.videoCount,
                            ]
                        } else {
                            info = ["channelId": channelId, "channelName": channelName]
                        }
                        NotificationCenter.default.post(
                            name: Constants.openChannelWithIdNotification,
                            object: nil,
                            userInfo: info
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

            // Navigation
            case let .setSidebarMode(mode):
                state.sidebarMode = mode
                if mode == .discover, state.discoverVideos.isEmpty {
                    return .send(.fetchTrending)
                }
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
                    let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    do {
                        let result = try await service.summarizeWithYTeaser(videoId: videoId, title: title, channel: channel)
                        await send(.discoverSummaryLoaded(text: "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n")))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error, !apiKey.isEmpty {
                            do {
                                let result = try await service.summarize(videoId: videoId, title: title, channel: channel, apiKey: apiKey)
                                await send(.discoverSummaryLoaded(text: "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n")))
                            } catch {
                                await send(.discoverSummaryFailed(error.localizedDescription))
                            }
                        } else {
                            if case .quotaExceeded = error {
                                await send(.setGeminiKeyAlert(true))
                            }
                            await send(.discoverSummaryFailed(error.localizedDescription))
                        }
                    } catch {
                        await send(.discoverSummaryFailed(error.localizedDescription))
                    }
                }

            case let .discoverSummaryLoaded(text):
                state.discoverSummaryLoading = false
                state.discoverSummaryText = text
                return .none

            case let .discoverSummaryFailed(error):
                state.discoverSummaryLoading = false
                state.discoverSummaryText = "요약 실패\n\n\(error)"
                return .none

            case .discoverDismissSummary:
                state.discoverSummaryVideoId = nil
                state.discoverSummaryText = nil
                state.discoverSummaryLoading = false
                return .none

            // Summary
            case let .showSummary(videoId):
                guard let item = state.items.first(where: { $0.id == videoId }) else { return .none }
                state.librarySummaryVideoId = videoId
                state.librarySummaryLoading = true
                state.librarySummaryText = nil
                let title = item.title
                let channel = item.channelName
                let filePath = item.filePath
                return .run { send in
                    let service = SummarizationService()
                    let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    do {
                        let result = try await service.summarizeWithYTeaser(videoId: videoId, title: title, channel: channel)
                        await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error, !apiKey.isEmpty {
                            do {
                                let result: SummarizationService.SummaryResult
                                if FileManager.default.fileExists(atPath: filePath) {
                                    result = try await service.summarizeFromLocalFile(videoPath: filePath, title: title, channel: channel, apiKey: apiKey)
                                } else {
                                    result = try await service.summarize(videoId: videoId, title: title, channel: channel, apiKey: apiKey)
                                }
                                await send(.summaryResult(videoId: videoId, overview: result.overview, keyPoints: result.keyPoints))
                            } catch {
                                await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                            }
                        } else {
                            if case .quotaExceeded = error {
                                await send(.setGeminiKeyAlert(true))
                            }
                            await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                        }
                    } catch {
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .summaryResult(videoId, overview, keyPoints):
                state.librarySummaryLoading = false
                let joined = "\(overview)\n\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n")
                state.librarySummaryText = joined
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].summary = joined
                    let updated = state.items[idx]
                    return .run { _ in
                        await LibraryCacheService.shared.updateItem(updated)
                    }
                }
                return .none

            case let .summaryFailed(videoId, error):
                state.librarySummaryLoading = false
                state.librarySummaryText = "요약 실패\n\n\(error)"
                if let idx = state.items.firstIndex(where: { $0.id == videoId }) {
                    state.items[idx].summary = "요약 실패: \(error)"
                }
                return .none

            case .dismissLibrarySummary:
                state.librarySummaryVideoId = nil
                state.librarySummaryText = nil
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
                    let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
                    let tag = await service.classify(title: title, channel: channel, apiKey: apiKey)
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
            }
        }
    }
}
