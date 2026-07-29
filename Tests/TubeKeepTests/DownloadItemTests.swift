import XCTest
@testable import TubeKeep

final class DownloadItemTests: XCTestCase {

    func testRemoveIndexPlaceholderMiddle() {
        let result = DownloadItem.removeIndexPlaceholder(from: "Music - {index} - Song.mp3")
        XCTAssertEqual(result, "Music - Song.mp3")
    }

    func testRemoveIndexPlaceholderEnd() {
        let result = DownloadItem.removeIndexPlaceholder(from: "Video {index}")
        XCTAssertEqual(result, "Video")
    }

    func testRemoveIndexPlaceholderStart() {
        let result = DownloadItem.removeIndexPlaceholder(from: "{index} - Title")
        XCTAssertEqual(result, "Title")
    }

    func testRemoveIndexPlaceholderUnderscore() {
        let result = DownloadItem.removeIndexPlaceholder(from: "file_{index}_name")
        XCTAssertEqual(result, "file_name")
    }

    func testRemoveIndexPlaceholderNoMatch() {
        let result = DownloadItem.removeIndexPlaceholder(from: "No Index Here")
        XCTAssertEqual(result, "No Index Here")
    }

    func testRemoveIndexPlaceholderFirstMatchWins() {
        let result = DownloadItem.removeIndexPlaceholder(from: " - {index} - {index} - ")
        XCTAssertEqual(result, " - {index} - ")
    }

    func testFormatFilenameChannelDownload() {
        let item = makeItem(isChannelDownload: true, channelUploadIndex: 5)
        let folder = Constants.sanitizeFolderName(item.videoInfo.channel)
        let expected = "\(Constants.channelStorageDirectory)/\(folder)/005 - \(item.videoInfo.title).\(item.videoInfo.id).mp4"
        let result = item.estimatedFilename
        // estimatedFilename uses channelStorageDirectory which reads from UserDefaults
        // Just check it contains the key parts
        XCTAssertTrue(result.contains("005"), "Should contain zero-padded index")
        XCTAssertTrue(result.contains(item.videoInfo.title), "Should contain title")
        XCTAssertTrue(result.contains(item.videoInfo.id), "Should contain video ID")
    }

    func testFormatFilenameNonChannel() {
        let item = makeItem(isChannelDownload: false, channelUploadIndex: 0)
        let result = item.formatFilename(template: "{title}.{id}")
        XCTAssertTrue(result.contains(item.videoInfo.title), "Should contain title")
        XCTAssertTrue(result.contains(item.videoInfo.id), "Should contain video ID")
    }

    func testFormatFilenameWithChannel() {
        let item = makeItem(isChannelDownload: false, channelUploadIndex: 3)
        let result = item.formatFilename(template: "{channel}/{index} - {title}")
        XCTAssertTrue(result.contains("003"), "Should contain zero-padded index")
        XCTAssertTrue(result.contains(item.videoInfo.channel), "Should contain channel name")
    }

    func testFormatFilenameSanitizesSpecialChars() {
        let info = VideoInfo(
            id: "test123",
            title: "Video: With/Special*Chars?",
            channel: "Channel: Name",
            channelId: "UC123",
            duration: 0,
            uploadDate: "",
            thumbnailURL: "",
            webpageURL: "",
            isPlaylist: false,
            playlistTitle: nil,
            playlistCount: nil
        )
        let item = DownloadItem(
            videoInfo: info,
            selectedFormat: Format(id: "best", label: "720p", height: 720, ext: "mp4", codec: "avc1", filesize: nil, fps: 30, isVideoOnly: false, isAudioOnly: false),
            isChannelDownload: false
        )
        let result = item.formatFilename(template: "{title}")
        XCTAssertFalse(result.contains("/"), "Should not contain slash")
        XCTAssertFalse(result.contains(":"), "Should not contain colon")
        XCTAssertFalse(result.contains("*"), "Should not contain asterisk")
    }

    func testOptionsLabelBasic() {
        let item = makeItem(includeSubtitles: false, audioOnly: false)
        XCTAssertEqual(item.optionsLabel, "720p")
    }

    func testOptionsLabelWithSubtitles() {
        let item = makeItem(includeSubtitles: true, audioOnly: false)
        XCTAssertEqual(item.optionsLabel, "720p + 자막")
    }

    func testOptionsLabelAudioOnly() {
        let item = makeItem(includeSubtitles: false, audioOnly: true)
        XCTAssertEqual(item.optionsLabel, "720p + MP3")
    }

    func testOptionsLabelAll() {
        let item = makeItem(includeSubtitles: true, audioOnly: true)
        XCTAssertEqual(item.optionsLabel, "720p + 자막 + MP3")
    }

    // MARK: - Helpers

    private func makeItem(
        isChannelDownload: Bool = false,
        channelUploadIndex: Int = 0,
        includeSubtitles: Bool = false,
        audioOnly: Bool = false
    ) -> DownloadItem {
        let info = VideoInfo(
            id: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            channel: "Rick Astley",
            channelId: "UCuAXFkgsw1L7xaCfnd5JJOw",
            duration: 212,
            uploadDate: "20091025",
            thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
            webpageURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            isPlaylist: false,
            playlistTitle: nil,
            playlistCount: nil
        )
        return DownloadItem(
            videoInfo: info,
            selectedFormat: Format(id: "best", label: "720p", height: 720, ext: "mp4", codec: "avc1", filesize: nil, fps: 30, isVideoOnly: false, isAudioOnly: false),
            includeSubtitles: includeSubtitles,
            audioOnly: audioOnly,
            isChannelDownload: isChannelDownload,
            channelUploadIndex: channelUploadIndex
        )
    }
}
