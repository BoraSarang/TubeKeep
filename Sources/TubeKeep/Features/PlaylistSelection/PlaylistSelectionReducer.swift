import Foundation
import ComposableArchitecture

@Reducer
struct PlaylistSelectionReducer {
    @ObservableState
    struct State: Equatable {
        let playlistURL: String
        var playlistTitle: String
        var videoCount: Int
        var videos: [VideoInfo] = []
        var selectedIds: Set<String> = []
        var isFetching: Bool = false
        var errorMessage: String?
        var sortOrder: SortOrder = .uploadDateDesc

        enum SortOrder: String, Equatable, CaseIterable {
            case uploadDateDesc = "업로드 날짜순 (최신)"
            case uploadDateAsc = "업로드 날짜순 (오래된)"
        }

        var sortedVideos: [VideoInfo] {
            switch sortOrder {
            case .uploadDateDesc:
                return videos.sorted { $0.uploadDate > $1.uploadDate }
            case .uploadDateAsc:
                return videos.sorted { $0.uploadDate < $1.uploadDate }
            }
        }

        var isAllSelected: Bool {
            !videos.isEmpty && selectedIds.count == videos.count
        }
    }

    enum Action: Equatable {
        case startFetch
        case playlistResponse([VideoInfo])
        case playlistFailed(String)
        case toggleVideo(String)
        case selectAll
        case deselectAll
        case changeSortOrder(State.SortOrder)
        case confirmSelection
        case cancel
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startFetch:
                state.isFetching = true
                state.errorMessage = nil
                return .run { [url = state.playlistURL] send in
                    let service = YouTubeDLService()
                    do {
                        let videos = try await service.fetchPlaylist(url: url)
                        await send(.playlistResponse(videos))
                    } catch {
                        await send(.playlistFailed(error.localizedDescription))
                    }
                }

            case let .playlistResponse(videos):
                state.isFetching = false
                state.videos = videos
                state.selectedIds = Set(videos.map { $0.id })
                return .none

            case let .playlistFailed(error):
                state.isFetching = false
                state.errorMessage = error
                return .none

            case let .toggleVideo(id):
                if state.selectedIds.contains(id) {
                    state.selectedIds.remove(id)
                } else {
                    state.selectedIds.insert(id)
                }
                return .none

            case .selectAll:
                state.selectedIds = Set(state.videos.map { $0.id })
                return .none

            case .deselectAll:
                state.selectedIds = []
                return .none

            case let .changeSortOrder(order):
                state.sortOrder = order
                return .none

            case .confirmSelection:
                return .none

            case .cancel:
                return .none
            }
        }
    }
}
