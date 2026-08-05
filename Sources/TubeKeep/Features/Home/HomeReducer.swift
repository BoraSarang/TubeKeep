import Foundation
import ComposableArchitecture

enum CancelID: Hashable {
    case fetch
    case fetchTimer
}

@Reducer
struct HomeReducer {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss

    @ObservableState
    struct State: Equatable {
        @Presents var playlistSelection: PlaylistSelectionReducer.State?

        var urlString: String = ""
        var isFetching: Bool = false
        var fetchStartTime: Date?
        var fetchLogs: [String] = []
        var videoInfo: VideoInfo?
        var availableFormats: [Format] = []
        var selectedFormatId: String?
        var includeSubtitles: Bool = false
        var audioOnly: Bool = false
        var errorMessage: String?
        var lastAutoFetchedURL: String = ""
        var clipboardMonitoring: Bool = true
        var summaryText: String?
        var summaryProvider: String?
        var summaryLoading = false
        var showSummaryPopover = false
        var showGeminiKeyAlert = false

        var selectedFormat: Format? {
            guard let id = selectedFormatId else { return nil }
            return availableFormats.first { $0.id == id }
        }

        var isPlaylistURL: Bool {
            guard let url = URL(string: urlString),
                  let host = url.host else { return false }
            return host.contains("youtube.com") &&
                (url.path.contains("playlist") || url.query?.contains("list=") == true)
        }

        var canAddToQueue: Bool {
            videoInfo != nil && selectedFormatId != nil && !isFetching
        }
    }

    enum Action: Equatable {
        case urlChanged(String)
        case setURL(String)
        case fetchInfoTapped
        case autoFetchInfo(String)
        case cancelFetch
        case fetchProgressLog(String)
        case infoResponse(VideoInfo, [Format])
        case infoFailed(String)
        case formatSelected(String)
        case subtitlesToggled(Bool)
        case audioOnlyToggled(Bool)
        case addToQueueTapped
        case addToQueueResponse(DownloadItem)
        case playlistSelection(PresentationAction<PlaylistSelectionReducer.Action>)
        case requestSummary
        case summaryLoaded(videoId: String, text: String, provider: String)
        case summaryFailed(videoId: String, error: String)
        case toggleSummaryPopover
        case dismissSummary
        case setGeminiKeyAlert(Bool)
        case openSettingsForGeminiKey
        case clearError
        case resetInfo
        case toggleClipboardMonitoring
        #if DEBUG

        #endif
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .urlChanged(url):
                state.urlString = url
                state.errorMessage = nil
                return .none

            case let .setURL(url):
                state.urlString = url
                state.errorMessage = nil
                state.lastAutoFetchedURL = ""
                return .none

            case .fetchInfoTapped:
                guard !state.urlString.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.errorMessage = "URL을 입력해 주세요"
                    return .none
                }
                return .merge(
                    .cancel(id: CancelID.fetch),
                    startFetch(url: state.urlString, state: &state)
                )

            case let .autoFetchInfo(url):
                state.urlString = url
                state.lastAutoFetchedURL = url
                return .merge(
                    .cancel(id: CancelID.fetch),
                    startFetch(url: url, state: &state)
                )

            case .cancelFetch:
                state.isFetching = false
                state.videoInfo = nil
                state.availableFormats = []
                state.selectedFormatId = nil
                state.errorMessage = nil
                state.fetchStartTime = nil
                state.fetchLogs = []
                state.urlString = ""
                state.lastAutoFetchedURL = ""
                return .cancel(id: CancelID.fetch)

            case let .fetchProgressLog(log):
                for line in log.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    if state.fetchLogs.last != trimmed {
                        state.fetchLogs.append(trimmed)
                    }
                }
                return .none

            case let .infoResponse(info, formats):
                state.isFetching = false
                state.fetchStartTime = nil

                if info.isPlaylist, state.playlistSelection == nil {
                    state.playlistSelection = PlaylistSelectionReducer.State(
                        playlistURL: state.urlString,
                        playlistTitle: info.playlistTitle ?? "재생목록",
                        videoCount: info.playlistCount ?? 0
                    )
                }

                state.videoInfo = info
                state.summaryText = nil
                state.summaryProvider = nil
                state.showSummaryPopover = false
                state.summaryLoading = false
                state.availableFormats = formats
                state.audioOnly = false
                state.includeSubtitles = false
                state.urlString = ""
                state.lastAutoFetchedURL = ""

                let defaultFormat = Format.best(forHeight: Constants.defaultResolution, from: formats)
                state.selectedFormatId = defaultFormat?.id

                if formats.isEmpty {
                    state.errorMessage = "다운로드 가능한 포맷이 없습니다"
                }

                return .none

            case let .infoFailed(error):
                state.isFetching = false
                state.fetchStartTime = nil
                state.videoInfo = nil
                state.availableFormats = []
                state.selectedFormatId = nil
                state.errorMessage = error
                state.urlString = ""
                state.lastAutoFetchedURL = ""
                state.summaryText = nil
                state.summaryProvider = nil
                state.showSummaryPopover = false
                state.summaryLoading = false
                return .run { send in
                    try? await Task.sleep(for: .seconds(5))
                    await send(.clearError)
                }
                .cancellable(id: CancelID.fetch)

            case let .formatSelected(id):
                state.selectedFormatId = id
                return .none

            case let .subtitlesToggled(value):
                state.includeSubtitles = value
                return .none

            case let .audioOnlyToggled(value):
                state.audioOnly = value
                if value {
                    state.includeSubtitles = false
                }
                return .none

            case .addToQueueTapped:
                guard let info = state.videoInfo,
                      let format = state.selectedFormat
                else { return .none }

                if state.isPlaylistURL {
                    return .run { send in
                        await send(.playlistSelection(.presented(.startFetch)))
                    }
                }

                let item = DownloadItem(
                    videoInfo: info,
                    selectedFormat: format,
                    includeSubtitles: state.includeSubtitles,
                    audioOnly: state.audioOnly,
                    channelUploadIndex: 0
                )
                return .send(.addToQueueResponse(item))

            case .addToQueueResponse:
                return .none

            case .playlistSelection:
                return .none

            case .requestSummary:
                guard let info = state.videoInfo else { return .none }
                state.summaryLoading = true
                state.summaryText = nil
                state.showSummaryPopover = true
                let videoId = info.id
                return .run { send in
                    let service = SummarizationService()
                    let keys = Settings.loadAPIKeys()
                    do {
                        let result = try await service.summarizeVideo(videoId: videoId, title: info.title, channel: info.channel, openRouterAPIKey: keys.openRouter, ax4APIKey: keys.ax4, geminiAPIKey: keys.gemini)
                        await send(.summaryLoaded(videoId: videoId, text: "\(result.overview)\n\n" + result.keyPoints.map { "• \($0)" }.joined(separator: "\n"), provider: result.provider))
                    } catch let error as SummarizationService.SummaryError {
                        if case .quotaExceeded = error { await send(.setGeminiKeyAlert(true)) }
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    } catch {
                        await send(.summaryFailed(videoId: videoId, error: error.localizedDescription))
                    }
                }

            case let .summaryLoaded(videoId, text, provider):
                guard videoId == state.videoInfo?.id else { return .none }
                state.summaryLoading = false
                state.summaryText = text
                state.summaryProvider = provider
                return .none

            case let .summaryFailed(videoId, error):
                guard videoId == state.videoInfo?.id else { return .none }
                state.summaryLoading = false
                state.summaryText = "요약 실패\n\n\(error)"
                return .none

            case .toggleSummaryPopover:
                if state.summaryText == nil && !state.summaryLoading {
                    return .send(.requestSummary)
                }
                state.showSummaryPopover.toggle()
                return .none

            case .dismissSummary:
                state.showSummaryPopover = false
                state.summaryText = nil
                state.summaryProvider = nil
                state.summaryLoading = false
                return .none

            case let .setGeminiKeyAlert(show):
                state.showGeminiKeyAlert = show
                return .none

            case .openSettingsForGeminiKey:
                state.showGeminiKeyAlert = false
                return .run { _ in await MainActor.run {
                    NotificationCenter.default.post(name: Constants.openSettingsWindowNotification, object: nil)
                }}

            case .clearError:
                state.errorMessage = nil
                return .none

            case .resetInfo:
                state.videoInfo = nil
                state.availableFormats = []
                state.selectedFormatId = nil
                state.errorMessage = nil
                state.isFetching = false
                state.fetchStartTime = nil
                state.fetchLogs = []
                state.playlistSelection = nil
                state.summaryText = nil
                state.summaryProvider = nil
                state.showSummaryPopover = false
                state.summaryLoading = false
                return .cancel(id: CancelID.fetch)

            case .toggleClipboardMonitoring:
                state.clipboardMonitoring.toggle()
                return .none

            }
        }
        .ifLet(\.$playlistSelection, action: \.playlistSelection) {
            PlaylistSelectionReducer()
        }
    }

    private func startFetch(url: String, state: inout State) -> Effect<Action> {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "tubekeep://", with: "https://")
            .replacingOccurrences(of: "tubekeep:", with: "https://")
        state.isFetching = true
        state.fetchStartTime = Date()
        state.errorMessage = nil
        state.videoInfo = nil
        state.availableFormats = []
        state.fetchLogs = ["진행상태: 정보 조회 시작..."]
        state.summaryText = nil
        state.summaryProvider = nil
        state.showSummaryPopover = false
        state.summaryLoading = false

        return .run { send in
            let service = YouTubeDLService()
            do {
                let (info, formats) = try await service.fetchVideoInfo(
                    url: trimmed,
                    progressHandler: { log in
                        let trimmed = log.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty,
                              !trimmed.hasPrefix("[debug]") else { return }
                        Task { await send(.fetchProgressLog("진행상태: \(trimmed)")) }
                    }
                )
                await send(.fetchProgressLog("진행상태: 조회 완료"))
                await send(.infoResponse(info, formats))
            } catch {
                await send(.fetchProgressLog("진행상태: 오류 발생"))
                await send(.infoFailed(error.localizedDescription))
            }
        }
        .cancellable(id: CancelID.fetch)
    }
}
