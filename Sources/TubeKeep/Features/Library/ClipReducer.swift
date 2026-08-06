import Foundation
import ComposableArchitecture

@Reducer
struct ClipReducer {
    @ObservableState
    struct State: Equatable {
        var clips: [ClipItem] = []
        var savingClip = false
        var lastError: String?
    }

    enum Action: Equatable {
        case load
        case clipsLoaded([ClipItem])
        case saveClip(videoId: String, channelName: String?, title: String, sourcePath: String, start: Double, end: Double)
        case clipSaved(ClipItem)
        case saveFailed(String)
        case deleteClip(ClipItem)
        case deleteClipsForVideo(String)
        case clipsDeletedForVideo(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .load:
                return .run { send in
                    let clips = await MainActor.run { ClipService.shared.allClips() }
                    await send(.clipsLoaded(clips))
                }

            case let .clipsLoaded(clips):
                state.clips = clips
                return .none

            case let .saveClip(videoId, channelName, title, sourcePath, start, end):
                state.savingClip = true
                state.lastError = nil
                return .run { send in
                    do {
                        let clip = try await ClipService.shared.saveClip(
                            videoId: videoId,
                            channelName: channelName,
                            title: title,
                            sourcePath: sourcePath,
                            start: start,
                            end: end
                        )
                        await send(.clipSaved(clip))
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case let .clipSaved(clip):
                state.savingClip = false
                state.clips.insert(clip, at: 0)
                return .none

            case let .saveFailed(message):
                state.savingClip = false
                state.lastError = message
                return .none

            case let .deleteClip(clip):
                return .run { send in
                    await MainActor.run { ClipService.shared.deleteClip(clip) }
                    await send(.load)
                }

            case let .deleteClipsForVideo(videoId):
                return .run { send in
                    let count = await MainActor.run { ClipService.shared.deleteClips(for: videoId) }
                    await send(.clipsDeletedForVideo(videoId))
                }

            case .clipsDeletedForVideo:
                return .none
            }
        }
    }
}
