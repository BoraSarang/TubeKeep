import Foundation
import AppKit
import ComposableArchitecture

@Reducer
struct PlayerReducer {
    @ObservableState
    struct State: Equatable {
        var playerItem: PlayerItem
        var streamURL: URL?
        var isStreamLoading = false
        var currentTime: Double = 0
        var duration: Double = 0
        var subtitles: [SubtitleCue] = []
        var subtitleLoading = false
        var subtitleError: String?
        var subtitleAvailable: Bool?
        var isPlaying = false
        var showSubtitleOverlay = false
        var showSubtitlePanel = false
        var isAlwaysOnTop = false
        var isTranscribing = false
        var transcribeError: String?
        var whisperProgressMessage: String?

        // Up Next
        var recommendations: [LibraryItem] = []
        var showUpNext = false
        var autoPlayCountdown = 0
        var playerItemId: UUID = UUID()
        var fileMissing = false

        // Similar Videos (v3.3)
        var showSimilarVideos = false
        var similarVideos: [TrendingVideo] = []
        var isLoadingSimilar = false
        var similarError: String? = nil

        // v3.0 Phase B
        var playbackRate: Double = 1.0
        var aLoop: Double?
        var bLoop: Double?
        var queue: [PlayerItem] = []
        var queueIndex: Int = -1
        var showQueue: Bool = false

        // Clip (A-B 저장)
        var isSavingClip = false
        var lastClipSaved = false
        var clipSaveMessage: String?
        var clipProgress: Double?

        // v3.2 이어보기: 5초 간격 저장용 마지막 저장 시점
        var lastPlaybackSaveTime: Double?
    }

    enum Action: Equatable {
        case loadVideo(PlayerItem)
        case streamURLFetched(URL)
        case streamFetchFailed
        case timeUpdated(Double)
        case durationUpdated(Double)
        case videoDidEnd
        case loadRecommendations
        case recommendationsLoaded([LibraryItem])
        case startAutoPlay(String)
        case cancelAutoPlay
        case updateCountdown(Int)
        case toggleSubtitleOverlay
        case toggleSubtitlePanel
        case checkSubtitlesAvailability
        case subtitlesAvailable(Bool)
        case downloadSubtitles
        case subtitlesLoaded([SubtitleCue])
        case subtitlesFailed(String)
        case transcribeWithWhisper
        case whisperProgress(String)
        case whisperLoaded([SubtitleCue])
        case whisperFailed(String)
        case deleteSubtitles
        case fileMissing
        case removeFromLibrary(String)
        case toggleAlwaysOnTop
        case playingChanged(Bool)

        // v3.0 Phase B
        case setPlaybackRate(Double)
        case cyclePlaybackRate
        case setALoop(Double)
        case setBLoop(Double)
        case clearABLoop
            case setQueue([PlayerItem], startIndex: Int)
            case appendToQueue(PlayerItem)
            case playNext
        case playPrevious
        case playAtQueue(Int)
        case toggleQueue
        case loadSimilarVideos
        case similarVideosLoaded([TrendingVideo])
        case similarVideosFailed(String)
        case toggleSimilarVideos
        case clearSimilarVideos

        // Clip (A-B 저장)
        case saveClip
        case clipProgressUpdated(Double)
        case clipSaveFinished
        case clipSaveFailed(String)
        case clipSaveIndicatorExpired
        case clipSaveMessageExpired
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadVideo(item):
                #if DEBUG
                let vid = item.videoId ?? "nil"
                Task { @MainActor in DebugLogManager.shared?.append("[Player] loadVideo: videoId=\(vid) fileURL=\(item.fileURL?.lastPathComponent ?? "nil")") }
                #endif
                state.playerItem = item
                state.streamURL = nil
                state.currentTime = 0
                state.duration = 0
                state.subtitles = []
                state.subtitleLoading = false
                state.subtitleError = nil
                state.subtitleAvailable = nil
                state.showUpNext = false
                state.autoPlayCountdown = 0
                state.recommendations = []
                state.playerItemId = UUID()
                state.aLoop = nil
                state.bLoop = nil
                if item.fileURL != nil {
                    state.isStreamLoading = false
                    return .none
                }
                guard item.videoId != nil else {
                    state.isStreamLoading = false
                    return .none
                }
                state.isStreamLoading = true
                return .run { send in
                    let res = Self.readResolution()
                    let url = "https://www.youtube.com/watch?v=\(item.videoId!)"
                    do {
                        let service = YouTubeDLService()
                        let streamURL = try await service.fetchStreamingURL(url: url, resolution: res)
                        await send(.streamURLFetched(streamURL))
                    } catch {
                        #if DEBUG
                        Task { @MainActor in DebugLogManager.shared?.append("[Player] 스트리밍 URL 실패: \(error)") }
                        #endif
                        await send(.streamFetchFailed)
                    }
                }
                .cancellable(id: "streamFetch", cancelInFlight: true)

            case let .streamURLFetched(url):
                #if DEBUG
                Task { @MainActor in DebugLogManager.shared?.append("[Player] streamURLFetched: \(url.absoluteString.prefix(80))") }
                #endif
                state.streamURL = url
                state.isStreamLoading = false
                return .none

            case .streamFetchFailed:
                #if DEBUG
                let failedId = state.playerItem.videoId
                Task { @MainActor in DebugLogManager.shared?.append("[Player] streamFetchFailed: \(failedId ?? "?")") }
                #endif
                state.isStreamLoading = false
                return .none

            case .fileMissing:
                state.isStreamLoading = false
                state.fileMissing = true
                return .none

            case let .removeFromLibrary(videoId):
                state.fileMissing = false
                let title = state.playerItem.title
                return .run { _ in
                    await MainActor.run {
                        LibraryCacheService.shared.removeItem(id: videoId)
                        NotificationCenter.default.post(name: Constants.libraryDataDidChangeNotification, object: nil)
                        if let window = NSApp.keyWindow, window.identifier?.rawValue == "player" {
                            window.close()
                        } else if let window = NSApp.windows.first(where: { $0.title == title }) {
                            window.close()
                        }
                    }
                }

            case .videoDidEnd:
                state.showUpNext = true
                state.lastPlaybackSaveTime = nil
                if let videoId = state.playerItem.videoId {
                    return .merge(
                        .send(.loadRecommendations),
                        .run { _ in
                            await MainActor.run { LibraryCacheService.shared.clearPlaybackPosition(videoId: videoId) }
                        }
                    )
                }
                return .send(.loadRecommendations)

            case .loadRecommendations:
                return .run { [videoId = state.playerItem.videoId] send in
                    let items = await MainActor.run { LibraryCacheService.shared.loadItems() }
                    guard !items.isEmpty else {
                        await send(.recommendationsLoaded([]))
                        return
                    }
                    let scored = RecommendationService.recommendFromLibrary(from: items, exclude: videoId)
                    await send(.recommendationsLoaded(scored))
                }

            case let .recommendationsLoaded(items):
                state.recommendations = items
                state.autoPlayCountdown = 5
                return .run { [items] send in
                    guard let first = items.first, let videoId = first.id as String? else { return }
                    for remaining in stride(from: 5, through: 1, by: -1) {
                        await send(.updateCountdown(remaining))
                        try? await Task.sleep(for: .seconds(1))
                    }
                    await send(.startAutoPlay(videoId))
                }
                .cancellable(id: "autoPlayCountdown", cancelInFlight: true)

            case let .startAutoPlay(videoId):
                state.showUpNext = false
                state.autoPlayCountdown = 0
                return .run { send in
                    let data = await MainActor.run { () -> (filePath: String, title: String, id: String, duration: Int?)? in
                        guard let item = LibraryCacheService.shared.loadItems().first(where: { $0.id == videoId }) else { return nil }
                        return (item.filePath, item.title, item.id, item.duration)
                    }
                    guard let data else { return }
                    let playerItem = PlayerItem(
                        fileURL: URL(fileURLWithPath: data.filePath),
                        title: data.title,
                        videoId: data.id,
                        duration: Double(data.duration ?? 0)
                    )
                    await send(.appendToQueue(playerItem))
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: Constants.openPlayerWindowNotification,
                            object: playerItem,
                            userInfo: ["suppressBringToFront": true]
                        )
                    }
                }

            case let .appendToQueue(item):
                state.queue.append(item)
                state.queueIndex = state.queue.count - 1
                return .none

            case .cancelAutoPlay:
                state.showUpNext = false
                state.autoPlayCountdown = 0
                return .cancel(id: "autoPlayCountdown")

            case let .updateCountdown(value):
                state.autoPlayCountdown = value
                return .none

            case let .timeUpdated(time):
                state.currentTime = time
                guard let videoId = state.playerItem.videoId else { return .none }
                if state.lastPlaybackSaveTime == nil || abs(time - state.lastPlaybackSaveTime!) >= 5 {
                    state.lastPlaybackSaveTime = time
                    return .run { _ in
                        await MainActor.run { LibraryCacheService.shared.updatePlaybackPosition(videoId: videoId, position: time) }
                    }
                }
                return .none

            case let .durationUpdated(duration):
                let hadZeroDuration = state.duration == 0 && duration > 0
                state.duration = duration
                if hadZeroDuration && state.playerItem.videoId != nil {
                    state.subtitles = []
                    state.subtitleError = nil
                    state.subtitleAvailable = nil
                    return .send(.checkSubtitlesAvailability)
                }
                return .none

            case .toggleSubtitleOverlay:
                state.showSubtitleOverlay.toggle()
                return .none

            case .toggleSubtitlePanel:
                state.showSubtitlePanel.toggle()
                if state.showSubtitlePanel { state.showQueue = false }
                return .none

            case .checkSubtitlesAvailability:
                guard let videoId = state.playerItem.videoId else { return .none }
                state.subtitleError = nil
                state.transcribeError = nil

                let data = DatabaseManager.shared.loadVideoAIData(videoId: videoId)
                if let subtitlesData = data?.subtitlesData,
                   let cues = try? JSONDecoder().decode([SubtitleCue].self, from: subtitlesData),
                   !cues.isEmpty {
                    state.subtitles = cues
                    state.subtitleAvailable = nil
                    return .none
                }
                if let transcript = data?.transcript, !transcript.isEmpty {
                    let duration = state.duration
                    if duration > 0 {
                        let estimated = PlayerReducer().estimateSubtitles(from: transcript, duration: duration)
                        if !estimated.isEmpty {
                            state.subtitles = estimated
                            state.subtitleAvailable = nil
                            return .none
                        }
                    }
                    let fallback = PlayerReducer().fallbackCues(from: transcript)
                    if !fallback.isEmpty {
                        state.subtitles = fallback
                        state.subtitleAvailable = nil
                        return .none
                    }
                }

                state.subtitleLoading = true
                return .run { send in
                    let available = await YouTubeDLService().checkSubtitlesAvailability(videoId: videoId)
                    await send(.subtitlesAvailable(available))
                }
                .cancellable(id: "checkSubtitlesAvailability", cancelInFlight: true)

            case let .subtitlesAvailable(available):
                state.subtitleLoading = false
                state.subtitleAvailable = available
                if !available {
                    state.subtitleError = "자막이 없습니다"
                }
                return .none

            case .downloadSubtitles:
                guard let videoId = state.playerItem.videoId else { return .none }
                state.subtitleLoading = true
                state.subtitleError = nil
                return .run { send in
                    do {
                        let cues = try await YouTubeDLService().fetchSubtitles(videoId: videoId)
                        await send(.subtitlesLoaded(cues))
                    } catch {
                        await send(.subtitlesFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: "downloadSubtitles", cancelInFlight: true)

            case .transcribeWithWhisper:
                guard let fileURL = state.playerItem.fileURL else {
                    state.transcribeError = "로컬 파일만 Whisper 자막을 생성할 수 있습니다"
                    return .none
                }
                #if DEBUG
                DebugLogManager.shared?.append("[Player] transcribeWithWhisper: \(fileURL.path)")
                #endif
                state.isTranscribing = true
                state.transcribeError = nil
                state.whisperProgressMessage = nil
                state.subtitles = []
                let modelSize = Settings.loadSettings().whisperModelSize
                #if DEBUG
                DebugLogManager.shared?.append("[Player] whisper model size: \(modelSize)")
                #endif
                return .run { send in
                    do {
                        let service = WhisperService.shared
                        await send(.whisperProgress("오디오 추출 중..."))
                        #if DEBUG
                        DebugLogManager.shared?.append("[Player] starting audio extraction...")
                        #endif
                        let audioPath = try await service.extractAudio(videoPath: fileURL.path)
                        #if DEBUG
                        DebugLogManager.shared?.append("[Player] audio extracted: \(audioPath)")
                        #endif
                        await send(.whisperProgress("자막 생성 중..."))
                        #if DEBUG
                        DebugLogManager.shared?.append("[Player] starting whisper transcription...")
                        #endif
                        let cues = try await service.transcribe(
                            audioPath: audioPath,
                            modelSize: modelSize,
                            progressHandler: { msg in
                                Task { await send(.whisperProgress(msg)) }
                            }
                        )
                        try? FileManager.default.removeItem(atPath: audioPath)
                        #if DEBUG
                        DebugLogManager.shared?.append("[Player] whisper done: \(cues.count) cues")
                        #endif
                        await send(.whisperLoaded(cues))
                    } catch {
                        #if DEBUG
                        DebugLogManager.shared?.append("[Player] whisper error: \(error.localizedDescription)")
                        #endif
                        await send(.whisperFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: "transcribeWithWhisper", cancelInFlight: true)

            case let .subtitlesLoaded(cues):
                state.subtitleLoading = false
                state.subtitleAvailable = nil
                state.subtitles = cues
                #if DEBUG
                DebugLogManager.shared?.append("[Player] 자막 로딩 완료: \(cues.count)개")
                #endif
                return .none

            case let .subtitlesFailed(error):
                state.subtitleLoading = false
                state.subtitleError = error
                #if DEBUG
                DebugLogManager.shared?.append("[Player] 자막 로딩 실패: \(error)")
                #endif
                return .none

            case let .whisperProgress(msg):
                state.subtitleLoading = true
                state.subtitleError = nil
                state.whisperProgressMessage = msg
                return .none

            case let .whisperLoaded(cues):
                state.isTranscribing = false
                state.subtitleLoading = false
                state.subtitleError = nil
                state.subtitleAvailable = nil
                state.whisperProgressMessage = nil
                state.subtitles = cues
                if let videoId = state.playerItem.videoId {
                    let text = cues.map { $0.text }.joined(separator: "\n")
                    var data = DatabaseManager.shared.loadVideoAIData(videoId: videoId) ?? VideoAIData(videoId: videoId)
                    data.transcript = text
                    data.transcriptLanguage = "ko"
                    data.subtitlesData = try? JSONEncoder().encode(cues)
                    DatabaseManager.shared.saveVideoAIData(data)
                }
                return .none

            case let .whisperFailed(error):
                state.isTranscribing = false
                state.subtitleLoading = false
                state.transcribeError = error
                state.whisperProgressMessage = nil
                return .none

            case .deleteSubtitles:
                if let videoId = state.playerItem.videoId {
                    DatabaseManager.shared.deleteVideoAIData(videoId: videoId)
                }
                state.subtitles = []
                state.subtitleError = "자막이 삭제되었습니다"
                return .none

            case .toggleAlwaysOnTop:
                state.isAlwaysOnTop.toggle()
                return .none

            case let .playingChanged(value):
                state.isPlaying = value
                if !value, let videoId = state.playerItem.videoId, state.currentTime > 0 {
                    let pos = state.currentTime
                    state.lastPlaybackSaveTime = pos
                    return .run { _ in
                        await MainActor.run { LibraryCacheService.shared.updatePlaybackPosition(videoId: videoId, position: pos) }
                    }
                }
                return .none

            // v3.0 Phase B
            case let .setPlaybackRate(rate):
                state.playbackRate = rate
                return .none

            case .cyclePlaybackRate:
                let rates: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]
                let idx = rates.firstIndex(of: state.playbackRate) ?? 1
                state.playbackRate = rates[(idx + 1) % rates.count]
                return .none

            case let .setALoop(time):
                state.aLoop = time
                if let b = state.bLoop, b <= time { state.bLoop = nil }
                return .none

            case let .setBLoop(time):
                state.bLoop = time
                if let a = state.aLoop, a >= time { state.aLoop = nil }
                return .none

            case .clearABLoop:
                state.aLoop = nil
                state.bLoop = nil
                return .none

            // Clip (A-B 저장)
            case .saveClip:
                guard let a = state.aLoop, let b = state.bLoop, a < b,
                      let fileURL = state.playerItem.fileURL else { return .none }
                state.isSavingClip = true
                state.lastClipSaved = false
                state.clipSaveMessage = nil
                state.clipProgress = 0
                let videoId = state.playerItem.videoId ?? "unknown"
                let title = state.playerItem.title
                return .run { send in
                    let channelName = await MainActor.run {
                        LibraryCacheService.shared.findItem(id: videoId)?.channelName
                    }
                    do {
                        _ = try await ClipService.shared.saveClip(
                            videoId: videoId,
                            channelName: channelName,
                            title: title,
                            sourcePath: fileURL.path,
                            start: a,
                            end: b,
                            progress: { p in send(.clipProgressUpdated(p)) }
                        )
                        await send(.clipSaveFinished)
                    } catch {
                        await send(.clipSaveFailed(error.localizedDescription))
                    }
                }

            case .clipProgressUpdated(let progress):
                state.clipProgress = progress
                return .none

            case .clipSaveFinished:
                state.isSavingClip = false
                state.lastClipSaved = true
                state.clipProgress = 1
                return .run { send in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await send(.clipSaveIndicatorExpired)
                }

            case .clipSaveFailed(let message):
                state.isSavingClip = false
                state.clipProgress = nil
                state.clipSaveMessage = message
                #if DEBUG
                Task { @MainActor in DebugLogManager.shared?.append("[Clip] saveFailed: \(message)") }
                #endif
                return .run { send in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await send(.clipSaveMessageExpired)
                }

            case .clipSaveIndicatorExpired:
                state.lastClipSaved = false
                state.clipProgress = nil
                return .none

            case .clipSaveMessageExpired:
                state.clipSaveMessage = nil
                return .none

            case let .setQueue(queue, startIndex):
                state.queue = queue
                state.queueIndex = startIndex
                return .none

            case .playNext:
                guard !state.queue.isEmpty else { return .none }
                let idx = state.queueIndex + 1
                guard idx < state.queue.count else { return .none }
                state.queueIndex = idx
                return .send(.loadVideo(state.queue[idx]))

            case .playPrevious:
                guard !state.queue.isEmpty else { return .none }
                let idx = state.queueIndex - 1
                guard idx >= 0 else { return .none }
                state.queueIndex = idx
                return .send(.loadVideo(state.queue[idx]))

            case let .playAtQueue(index):
                guard index >= 0, index < state.queue.count else { return .none }
                state.queueIndex = index
                return .send(.loadVideo(state.queue[index]))

            case .toggleQueue:
                state.showQueue.toggle()
                if state.showQueue { state.showSubtitlePanel = false }
                return .none

            case .loadSimilarVideos:
                guard let videoId = state.playerItem.videoId else {
                    state.similarError = "네트워크 영상에서만 비슷한 영상을 찾을 수 있습니다"
                    return .none
                }
                state.isLoadingSimilar = true
                state.similarError = nil
                let title = state.playerItem.title
                return .run { send in
                    let keys = Settings.loadAPIKeys()
                    let context = await MainActor.run { () -> (channel: String, tags: [String], summary: String?)? in
                        guard let item = LibraryCacheService.shared.findItem(id: videoId) else { return nil }
                        let summary = DatabaseManager.shared.loadVideoAIData(videoId: videoId)?.summary ?? item.summary
                        return (item.channelName, item.tags, summary)
                    }
                    let service = SimilarVideoService.shared
                    let queries = await service.generateQueries(
                        videoId: videoId, title: title,
                        channel: context?.channel ?? "",
                        tags: context?.tags ?? [],
                        summary: context?.summary,
                        keys: keys
                    )
                    do {
                        let videos = try await service.searchSimilar(videoId: videoId, queries: queries)
                        await send(.similarVideosLoaded(videos))
                    } catch {
                        await send(.similarVideosFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: "similarVideos", cancelInFlight: true)

            case let .similarVideosLoaded(videos):
                state.isLoadingSimilar = false
                state.similarError = nil
                state.similarVideos = videos
                return .none

            case let .similarVideosFailed(error):
                state.isLoadingSimilar = false
                state.similarError = error
                return .none

            case .toggleSimilarVideos:
                state.showSimilarVideos.toggle()
                if state.showSimilarVideos {
                    state.showQueue = false
                    state.showSubtitlePanel = false
                    if state.similarVideos.isEmpty, state.similarError == nil {
                        return .send(.loadSimilarVideos)
                    }
                }
                return .none

            case .clearSimilarVideos:
                state.isLoadingSimilar = false
                state.similarVideos = []
                state.similarError = nil
                return .none
            }
        }
    }

    static func readResolution() -> Int {
        Settings.loadSettings().defaultResolution
    }

    private func estimateSubtitles(from transcript: String, duration: Double) -> [SubtitleCue] {
        guard duration > 0 else { return [] }
        let sentences = transcript.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
        if sentences.count <= 1 {
            let fallback = transcript.components(separatedBy: ". ")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !fallback.isEmpty else { return [] }
            let avgCueDuration = max(3.0, duration / Double(fallback.count))
            return fallback.enumerated().map { i, text in
                SubtitleCue(
                    startTime: Double(i) * avgCueDuration,
                    endTime: Double(i + 1) * avgCueDuration,
                    text: Self.decodeHTMLEntities(text.hasSuffix(".") ? text : text + ".")
                )
            }
        }
        guard !sentences.isEmpty else { return [] }
        let targetCueCount = max(3, Int(duration / 6))
        let sentencesPerCue = max(1, sentences.count / targetCueCount)
        var cues: [SubtitleCue] = []
        var chunk: [String] = []
        for sentence in sentences {
            chunk.append(sentence)
            if chunk.count >= sentencesPerCue {
                let text = Self.decodeHTMLEntities(chunk.joined(separator: ". ") + ".")
                cues.append(SubtitleCue(startTime: 0, endTime: 0, text: text))
                chunk = []
            }
        }
        if !chunk.isEmpty {
            let text = Self.decodeHTMLEntities(chunk.joined(separator: ". ") + ".")
            cues.append(SubtitleCue(startTime: 0, endTime: 0, text: text))
        }
        let segDuration = duration / Double(cues.count)
        for i in cues.indices {
            cues[i] = SubtitleCue(
                startTime: Double(i) * segDuration,
                endTime: Double(i + 1) * segDuration,
                text: cues[i].text
            )
        }
        return cues
    }

    private func fallbackCues(from transcript: String) -> [SubtitleCue] {
        var lines = transcript.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
        if lines.count <= 1 {
            lines = transcript.components(separatedBy: ". ")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { $0.hasSuffix(".") ? $0 : $0 + "." }
        }
        let chunkCount = max(10, lines.count / 3)
        let groupSize = max(1, lines.count / chunkCount)
        var cues: [SubtitleCue] = []
        var chunk: [String] = []
        for line in lines {
            chunk.append(line)
            if chunk.count >= groupSize {
                let text = Self.decodeHTMLEntities(chunk.joined(separator: " "))
                cues.append(SubtitleCue(startTime: 0, endTime: 0, text: text))
                chunk = []
            }
        }
        if !chunk.isEmpty {
            let text = Self.decodeHTMLEntities(chunk.joined(separator: " "))
            cues.append(SubtitleCue(startTime: 0, endTime: 0, text: text))
        }
        let secPerCue = max(3, min(8, 600 / cues.count))
        return cues.enumerated().map { i, cue in
            SubtitleCue(startTime: Double(i) * Double(secPerCue), endTime: Double(i + 1) * Double(secPerCue), text: cue.text)
        }
    }

    fileprivate static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            "&amp;": "&",
            "&gt;": ">",
            "&lt;": "<",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " ",
            "&apos;": "'",
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        result = cleanSubtitleMarkers(result)
        return result
    }

    fileprivate static func cleanSubtitleMarkers(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: ">>", with: "")
        result = result.replacingOccurrences(of: "> ", with: " ")
        result = result.replacingOccurrences(of: "♪", with: "")
        result = result.replacingOccurrences(of: "[Music]", with: "")
        result = result.replacingOccurrences(of: "[음악]", with: "")
        result = result.replacingOccurrences(of: "[Applause]", with: "")
        result = result.replacingOccurrences(of: "[박수]", with: "")
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(of: "\r", with: "")
        while let range = result.range(of: "<[^>]+>", options: .regularExpression) {
            result.removeSubrange(range)
        }
        while let range = result.range(of: "\\[\\d{1,2}:\\d{2}(:\\d{2})?\\]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}

extension YouTubeDLService {
    func checkSubtitlesAvailability(videoId: String) async -> Bool {
        let url = "https://www.youtube.com/watch?v=\(videoId)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            Constants.ytDlpPath,
            "--skip-download",
            "--list-subs",
            url,
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        guard (try? process.run()) != nil else { return false }
        let deadline = ContinuousClock.now + .seconds(10)
        while process.isRunning {
            if Task.isCancelled { process.terminate(); break }
            if ContinuousClock.now >= deadline { process.terminate(); break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let subLangs = LanguageService.subtitleLanguages.components(separatedBy: ",")
        for lang in subLangs {
            let trimmed = lang.trimmingCharacters(in: .whitespaces)
            if output.range(of: "\n\(trimmed) ") != nil || output.range(of: "\n\(trimmed)\t") != nil {
                return true
            }
        }
        return false
    }

    func fetchSubtitles(videoId: String) async throws -> [SubtitleCue] {
        let url = "https://www.youtube.com/watch?v=\(videoId)"
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("tubekeep_subs_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let subLangs = LanguageService.subtitleLanguages
        #if DEBUG
        Task { @MainActor in DebugLogManager.shared?.append("[Player] --sub-langs: \(subLangs)") }
        #endif
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            Constants.ytDlpPath,
            "--skip-download",
            "--write-subs", "--write-auto-subs",
            "--sub-langs", subLangs,
            "--convert-subs", "srt",
            "-o", tmpDir.appendingPathComponent("%(id)s.%(ext)s").path,
        ] + [url]
        let tmpLog = fm.temporaryDirectory.appendingPathComponent("ytdlp_subs_\(UUID().uuidString).log")
        fm.createFile(atPath: tmpLog.path, contents: nil)
        defer { try? fm.removeItem(at: tmpLog) }
        let logHandle = try? FileHandle(forWritingTo: tmpLog)
        process.standardOutput = logHandle ?? FileHandle.nullDevice
        process.standardError = logHandle ?? FileHandle.nullDevice
        try process.run()
        let deadline = ContinuousClock.now + .seconds(30)
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                break
            }
            if ContinuousClock.now >= deadline {
                process.terminate()
                throw YTDLPError.infoFetchFailed("자막 다운로드 타임아웃 (30초)")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        try? logHandle?.close()

        let stderr = (try? String(contentsOf: tmpLog, encoding: .utf8)) ?? ""
        #if DEBUG
        Task { @MainActor in DebugLogManager.shared?.append("[Player] 자막 다운로드 종료 (exit: \(process.terminationStatus))") }
        #endif

        guard let files = try? fm.contentsOfDirectory(atPath: tmpDir.path) else {
            throw YTDLPError.infoFetchFailed("자막 다운로드 실패: \(stderr.prefix(200))")
        }

        let sortedFiles = files.sorted { a, b in
            let aIsKo = a.contains(".ko.")
            let bIsKo = b.contains(".ko.")
            if aIsKo != bIsKo { return aIsKo }
            return a < b
        }

        for file in sortedFiles {
            guard file.hasSuffix(".vtt") || file.hasSuffix(".srt") else { continue }
            let path = tmpDir.appendingPathComponent(file).path
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            if file.hasSuffix(".vtt") {
                let cues = parseVTTTimed(content)
                if !cues.isEmpty { return cues }
            } else {
                let cues = parseSRTTimed(content)
                if !cues.isEmpty { return cues }
            }
        }
        throw YTDLPError.infoFetchFailed("자막을 찾을 수 없습니다 (\(files.count)개 파일)")
    }

    private func parseVTTTimed(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.contains("-->") {
                let parts = line.components(separatedBy: " --> ")
                if parts.count == 2 {
                    let start = parseVTTTime(parts[0])
                    let end = parseVTTTime(parts[1])
                    var text = ""
                    i += 1
                    while i < lines.count {
                        let next = lines[i].trimmingCharacters(in: .whitespaces)
                        if next.isEmpty || next.contains("-->") { break }
                        if !text.isEmpty { text += "\n" }
                        text += next
                        i += 1
                    }
                    if !text.isEmpty {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: PlayerReducer.decodeHTMLEntities(text)))
                    }
                    continue
                }
            }
            i += 1
        }
        return cues
    }

    private func parseSRTTimed(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }
            guard let timingLine = lines.first(where: { $0.contains("-->") }) else { continue }
            let parts = timingLine.components(separatedBy: " --> ")
            guard parts.count == 2 else { continue }
            let start = parseSRTTime(parts[0])
            let end = parseSRTTime(parts[1])
            var seenTiming = false
            let text = lines.filter { line in
                if line.contains("-->") { seenTiming = true; return false }
                if !seenTiming, Int(line) != nil { return false }
                return true
            }.joined(separator: "\n")
            if !text.isEmpty {
                cues.append(SubtitleCue(startTime: start, endTime: end, text: PlayerReducer.decodeHTMLEntities(text)))
            }
        }
        return cues
    }

    private func parseVTTTime(_ string: String) -> Double {
        let clean = string.trimmingCharacters(in: .whitespaces)
        let parts = clean.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
            return h * 3600 + m * 60 + s
        }
        return 0
    }

    private func parseSRTTime(_ string: String) -> Double {
        let clean = string.trimmingCharacters(in: .whitespaces)
        let parts = clean.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
            return h * 3600 + m * 60 + s
        }
        return 0
    }
}
