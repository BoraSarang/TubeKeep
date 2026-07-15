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
        case clearError
        case resetInfo
        case toggleClipboardMonitoring
        #if DEBUG
        case debugTestFetch
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
                    state.errorMessage = "URL을 입력해주세요"
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
                state.videoInfo = info
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

                if info.isPlaylist, state.playlistSelection == nil {
                    state.playlistSelection = PlaylistSelectionReducer.State(
                        playlistURL: state.urlString,
                        playlistTitle: info.playlistTitle ?? "재생목록",
                        videoCount: info.playlistCount ?? 0
                    )
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
                return .cancel(id: CancelID.fetch)

            case .toggleClipboardMonitoring:
                state.clipboardMonitoring.toggle()
                return .none

            #if DEBUG
            case .debugTestFetch:
                state.isFetching = true
                state.fetchStartTime = Date()
                state.lastAutoFetchedURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                state.urlString = state.lastAutoFetchedURL
                state.fetchLogs = ["진행상태: 테스트 정보 조회 시작..."]
                let mockInfo = VideoInfo(
                    id: "dQw4w9WgXcQ",
                    title: "Rick Astley - Never Gonna Give You Up (Official Music Video)",
                    channel: "Rick Astley",
                    channelId: "UCuAXFkgsw1L7xaCfnd5JJOw",
                    duration: 212,
                    uploadDate: "20091025",
                    thumbnailURL: "",
                    webpageURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    isPlaylist: false,
                    playlistTitle: nil,
                    playlistCount: nil
                )
                let mockFormats: [Format] = [
                    Format(id: "137", label: "1080p", height: 1080, ext: "mp4", codec: "h264 (avc1)", filesize: 45_000_000, fps: 30, isVideoOnly: false, isAudioOnly: false),
                    Format(id: "136", label: "720p", height: 720, ext: "mp4", codec: "h264 (avc1)", filesize: 25_000_000, fps: 30, isVideoOnly: false, isAudioOnly: false),
                    Format(id: "135", label: "480p", height: 480, ext: "mp4", codec: "h264 (avc1)", filesize: 15_000_000, fps: 30, isVideoOnly: false, isAudioOnly: false),
                    Format(id: "134", label: "360p", height: 360, ext: "mp4", codec: "h264 (avc1)", filesize: 8_000_000, fps: 30, isVideoOnly: false, isAudioOnly: false),
                ]
                return .run { send in
                    try await Task.sleep(for: .milliseconds(600))
                    await send(.fetchProgressLog("진행상태: [info] 테스트 영상 정보를 찾았습니다"))
                    try await Task.sleep(for: .milliseconds(400))
                    await send(.fetchProgressLog("진행상태: [info] 4개 포맷을 불러왔습니다"))
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.infoResponse(mockInfo, mockFormats))
                }
                .cancellable(id: CancelID.fetch)
            #endif
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
