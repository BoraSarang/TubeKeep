import SwiftUI
import ComposableArchitecture

struct ChannelContentView: View {
    let store: StoreOf<AppReducer>
    let channel: SubscribedChannel?
    let videos: [ChannelVideoItem]
    let isLoading: Bool
    var onRefresh: (() -> Void)?
    var onDropURL: ((String) -> Void)?

    @State private var searchText = ""
    @State private var sortOrder: ChannelSortOrder = .dateDesc
    @State private var selectedIDs: Set<String> = Set()
    @State private var displayCount = 50
    @State private var presetResolution: Int = Constants.defaultResolution
    @State private var presetSubtitles = false
    @State private var presetAudioOnly = false
    @State private var isAddingDownloads = false

    private var filteredVideos: [ChannelVideoItem] {
        var result = videos
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortOrder {
        case .dateDesc:
            result.sort { $0.playlistIndex < $1.playlistIndex }
        case .dateAsc:
            result.sort { $0.playlistIndex > $1.playlistIndex }
        }
        return result
    }

    private var displayedVideos: [ChannelVideoItem] {
        Array(filteredVideos.prefix(displayCount))
    }

    private var downloadedIDs: Set<String> {
        guard let c = channel else { return [] }
        return ChannelDownloadCache.loadDownloadedIDs(channelName: c.name)
    }

    private var downloadableCount: Int {
        let downloaded = downloadedIDs
        return filteredVideos.filter { !downloaded.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if let channel = channel {
                channelHeader(channel)
                Divider()
                filterSortBar
                Divider()
                if isLoading {
                    Spacer()
                    ProgressView("채널 영상 목록을 불러오는 중...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    videoList
                    Divider()
                    presetAndDownload
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("채널을 선택하거나 추가해주세요")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    Text("YouTube URL을 드래그하여 추가")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: ["public.url", "public.plain-text"], isTargeted: nil) { providers in
                    handleDrop(providers)
                    return true
                }
                Spacer()
            }
        }
    }

    // MARK: - Channel Header

    private func channelHeader(_ channel: SubscribedChannel) -> some View {
        HStack(spacing: 12) {
            if !channel.avatarURL.isEmpty, let url = URL(string: channel.avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.circle.fill").resizable()
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .onTapGesture { openChannel(channel) }
                .help("YouTube 채널 열기")
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .foregroundStyle(.secondary)
                    .onTapGesture { openChannel(channel) }
                    .help("YouTube 채널 열기")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 16, weight: .bold))
                    .onTapGesture { openChannel(channel) }
                Text(metaString(channel))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button("↻") {
                guard let c = self.channel else { return }
                ChannelDownloadCache.removeChannel(c.name)
                displayCount = 50
                selectedIDs = []
                onRefresh?()
            }
            .buttonStyle(.plain)
            .font(.system(size: 16))
            .help("새로고침")
        }
        .padding(12)
    }

    private func openChannel(_ channel: SubscribedChannel) {
        let urlString: String
        if let handle = channel.handle {
            urlString = "https://youtube.com/\(handle)"
        } else {
            urlString = "https://youtube.com/channel/\(channel.id)"
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                          text.contains("youtube.com") || text.contains("youtu.be")
                    else { return }
                    DispatchQueue.main.async {
                        self.onDropURL?(text)
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url?.absoluteString else { return }
                    DispatchQueue.main.async {
                        self.onDropURL?(url)
                    }
                }
                return
            }
        }
    }

    private func metaString(_ channel: SubscribedChannel) -> String {
        var parts: [String] = []
        if let handle = channel.handle {
            parts.append(handle)
        }
        if let subs = channel.subscriberCount {
            parts.append("구독자 \(formatCount(subs))명")
        }
        parts.append("동영상 \(formattedNumber(channel.videoCount))개")
        return parts.joined(separator: " · ")
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.2f만", Double(n) / 10000)
        }
        if n >= 1000 {
            return String(format: "%.2f천", Double(n) / 1000)
        }
        return "\(n)"
    }

    private func formattedNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Filter / Sort

    private var filterSortBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("검색", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(6)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("전체 \(filteredVideos.count)개")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if selectedIDs.count > 0 {
                Text("\(selectedIDs.count)개 선택")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            Picker("", selection: $sortOrder) {
                ForEach(ChannelSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 90)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Video List

    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedVideos) { item in
                    let isDownloaded = downloadedIDs.contains(item.id)
                    ChannelVideoRow(
                        item: item,
                        isSelected: selectedIDs.contains(item.id),
                        isDownloaded: isDownloaded
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard isDownloaded, let channel else { return }
                        revealVideoFile(item: item, channel: channel)
                    }
                    .onTapGesture {
                        guard !isDownloaded else { return }
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    }
                    Divider()
                }

                if displayCount < filteredVideos.count {
                    Button("더 보기 (\(filteredVideos.count - displayCount)개)") {
                        displayCount += 50
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Preset & Download

    private var presetAndDownload: some View {
        VStack(spacing: 8) {
            GroupBox {
                HStack {
                    Text("해상도")
                        .font(.system(size: 11))
                    Picker("", selection: $presetResolution) {
                        ForEach([144, 240, 360, 480, 720, 1080, 1440, 2160], id: \.self) { h in
                            Text("\(h)p").tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 80)

                    Spacer()

                    Toggle("자막", isOn: $presetSubtitles)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 11))
                        .disabled(presetAudioOnly)

                    Toggle("MP3", isOn: $presetAudioOnly)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 12)

            Button {
                addSelectedToQueue()
            } label: {
                if isAddingDownloads {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("추가 중...")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                } else {
                    let n = selectedIDs.count
                    Text("선택한 \(n)개 다운로드")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .disabled(selectedIDs.isEmpty || channel == nil)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func addSelectedToQueue() {
        guard let channel = channel else { return }
        let downloaded = downloadedIDs
        let selected = videos.filter { selectedIDs.contains($0.id) && !downloaded.contains($0.id) }
        guard !selected.isEmpty else { return }

        isAddingDownloads = true

        let items = selected.map { item in
            let format = Format(
                id: "best[height<=\(presetResolution)]",
                label: "\(presetResolution)p",
                height: presetResolution,
                ext: "mp4",
                codec: "avc1",
                filesize: nil,
                fps: nil,
                isVideoOnly: false,
                isAudioOnly: false
            )

            let videoInfo = VideoInfo(
                id: item.id,
                title: item.title,
                channel: channel.name,
                channelId: channel.id,
                duration: 0,
                uploadDate: item.uploadDate ?? "",
                thumbnailURL: item.thumbnailURL,
                webpageURL: "https://youtube.com/watch?v=\(item.id)",
                isPlaylist: false,
                playlistTitle: nil,
                playlistCount: nil
            )

            return DownloadItem(
                videoInfo: videoInfo,
                selectedFormat: format,
                includeSubtitles: presetSubtitles,
                audioOnly: presetAudioOnly,
                isChannelDownload: true,
                channelUploadIndex: videos.count - item.playlistIndex + 1,
                playlistIndex: item.playlistIndex
            )
        }

        store.send(.downloadQueue(.addItems(items)))

        // Open downloader window via notification
        NotificationCenter.default.post(name: Constants.openDownloaderWindowNotification, object: nil)

        isAddingDownloads = false
    }

    private func revealVideoFile(item: ChannelVideoItem, channel: SubscribedChannel) {
        let folder = Constants.sanitizeFolderName(channel.name)
        let channelDir = "\(Constants.channelOutputDirectory)/\(folder)"
        guard FileManager.default.fileExists(atPath: channelDir),
              let files = try? FileManager.default.contentsOfDirectory(atPath: channelDir)
        else { return }
        if let match = files.first(where: { $0.contains(item.id) }) {
            let url = URL(fileURLWithPath: "\(channelDir)/\(match)")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

// MARK: - Video Row

private struct ChannelVideoRow: View {
    let item: ChannelVideoItem
    let isSelected: Bool
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDownloaded
                ? "checkmark.circle.fill"
                : (isSelected ? "checkmark.circle.fill" : "circle"))
                .foregroundStyle(isDownloaded ? .green : (isSelected ? .accentColor : .secondary))
                .font(.system(size: 14))
                .frame(width: 16)

            AsyncImage(url: URL(string: item.thumbnailURLStandard)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().foregroundStyle(.quaternary)
                }
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if item.viewCount > 0 {
                        Text("조회수 \(item.displayViewCount)")
                    }
                    if item.duration > 0 {
                        Text(item.displayDuration)
                    }
                    if item.uploadDate != nil {
                        Text(item.displayDate)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isDownloaded {
                Text("완료")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .opacity(isDownloaded ? 0.5 : 1.0)
    }
}
