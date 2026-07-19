import XCTest
@testable import TubeKeep

final class ConstantsTests: XCTestCase {

    func testSanitizeFolderNameRemovesSlashes() {
        let result = Constants.sanitizeFolderName("My/Channel")
        XCTAssertFalse(result.contains("/"), "Should not contain slash")
    }

    func testSanitizeFolderNameRemovesColons() {
        let result = Constants.sanitizeFolderName("Test: Name")
        XCTAssertFalse(result.contains(":"), "Should not contain colon")
    }

    func testSanitizeFolderNameRemovesSpecialChars() {
        let result = Constants.sanitizeFolderName("Test@#$%Name")
        XCTAssertFalse(result.contains("@"), "Should not contain @")
        XCTAssertFalse(result.contains("#"), "Should not contain #")
    }

    func testSanitizeFolderNameKeepsKorean() {
        let result = Constants.sanitizeFolderName("한국어 채널")
        XCTAssertEqual(result, "한국어 채널")
    }

    func testSanitizeFolderNameKeepsAlphanumeric() {
        let result = Constants.sanitizeFolderName("ABC123")
        XCTAssertEqual(result, "ABC123")
    }

    func testSanitizeFolderNameKeepsSpaces() {
        let result = Constants.sanitizeFolderName("My Channel")
        XCTAssertEqual(result, "My Channel")
    }

    func testSanitizeFolderNameKeepsDashes() {
        let result = Constants.sanitizeFolderName("My-Channel")
        XCTAssertEqual(result, "My-Channel")
    }

    func testSanitizeFolderNameKeepsParentheses() {
        let result = Constants.sanitizeFolderName("Channel (Official)")
        XCTAssertEqual(result, "Channel (Official)")
    }

    func testSanitizeFolderNameTrimsWhitespace() {
        let result = Constants.sanitizeFolderName("  trimmed  ")
        XCTAssertEqual(result, "trimmed")
    }

    func testSanitizeFolderNameEmpty() {
        let result = Constants.sanitizeFolderName("")
        XCTAssertEqual(result, "")
    }

    func testIsChannelURLHandle() {
        XCTAssertTrue(Constants.isChannelURL("https://www.youtube.com/@channelname"))
        XCTAssertTrue(Constants.isChannelURL("youtube.com/@channelname/videos"))
        XCTAssertTrue(Constants.isChannelURL("youtube.com/@channelname/shorts"))
    }

    func testIsChannelURLChannelID() {
        XCTAssertTrue(Constants.isChannelURL("https://www.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw"))
    }

    func testIsChannelURLCustom() {
        XCTAssertTrue(Constants.isChannelURL("https://www.youtube.com/c/ChannelName"))
    }

    func testIsChannelURLVideo() {
        XCTAssertFalse(Constants.isChannelURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    func testIsChannelURLShorts() {
        XCTAssertFalse(Constants.isChannelURL("https://www.youtube.com/shorts/abc123"))
    }

    func testChannelIDFromURLDirect() {
        let result = Constants.channelIDFromURL("https://www.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw")
        XCTAssertEqual(result, "UCuAXFkgsw1L7xaCfnd5JJOw")
    }

    func testChannelIDFromURLHandle() {
        let result = Constants.channelIDFromURL("https://www.youtube.com/@channelname")
        XCTAssertNil(result, "Handle URLs need yt-dlp resolution")
    }

    func testDefaultValues() {
        XCTAssertEqual(Constants.appName, "TubeKeep")
        XCTAssertEqual(Constants.defaultResolution, 480)
        XCTAssertEqual(Constants.defaultConcurrentDownloads, 2)
        XCTAssertEqual(Constants.minConcurrentDownloads, 1)
        XCTAssertEqual(Constants.maxConcurrentDownloads, 5)
        XCTAssertEqual(Constants.defaultMaxRetries, 3)
    }
}
