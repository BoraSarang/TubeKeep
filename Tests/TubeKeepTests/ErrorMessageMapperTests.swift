import XCTest
@testable import TubeKeep

final class ErrorMessageMapperTests: XCTestCase {

    func testNilInput() {
        XCTAssertEqual(ErrorMessageMapper.map(nil), "알 수 없는 오류가 발생했습니다")
    }

    func testEmptyInput() {
        XCTAssertEqual(ErrorMessageMapper.map(""), "알 수 없는 오류가 발생했습니다")
    }

    func testHTTP403() {
        let result = ErrorMessageMapper.map("ERROR: HTTP Error 403: Forbidden")
        XCTAssertEqual(result, "영상에 접근할 수 없습니다 (권한 필요). 다른 영상을 시도해 보세요.")
    }

    func testHTTP403CaseInsensitive() {
        let result = ErrorMessageMapper.map("http error 403 forbidden")
        XCTAssertTrue(result.contains("권한"))
    }

    func testHTTP404() {
        let result = ErrorMessageMapper.map("ERROR: HTTP Error 404 Not Found")
        XCTAssertEqual(result, "영상을 찾을 수 없습니다. 주소를 확인해 주세요.")
    }

    func testHTTP410() {
        let result = ErrorMessageMapper.map("HTTP Error 410 Gone")
        XCTAssertEqual(result, "영상이 삭제되었습니다.")
    }

    func testHTTP429() {
        let result = ErrorMessageMapper.map("ERROR: HTTP Error 429 Too Many Requests")
        XCTAssertEqual(result, "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.")
    }

    func testFFmpegError() {
        let result = ErrorMessageMapper.map("ffmpeg returned non-zero exit code 1")
        XCTAssertEqual(result, "파일 변환 중 오류가 발생했습니다. 다시 시도해 주세요.")
    }

    func testMuxError() {
        let result = ErrorMessageMapper.map("ERROR: muxing failed")
        XCTAssertEqual(result, "파일 변환 중 오류가 발생했습니다. 다시 시도해 주세요.")
    }

    func testMergerError() {
        let result = ErrorMessageMapper.map("[Merger] Merging formats ERROR: failed")
        XCTAssertEqual(result, "파일 변환 중 오류가 발생했습니다. 다시 시도해 주세요.")
    }

    func testAgeRestriction() {
        let result = ErrorMessageMapper.map("sign in to confirm your age")
        XCTAssertTrue(result.contains("연령"))
    }

    func testPrivateVideo() {
        let result = ErrorMessageMapper.map("ERROR: This is a private video")
        XCTAssertEqual(result, "비공개 영상입니다.")
    }

    func testCopyright() {
        let result = ErrorMessageMapper.map("Video removed due to copyright takedown")
        XCTAssertEqual(result, "저작권 문제로 다운로드할 수 없는 영상입니다.")
    }

    func testUnavailable() {
        let result = ErrorMessageMapper.map("Video is unavailable")
        XCTAssertEqual(result, "영상을 사용할 수 없습니다.")
    }

    func testLiveEnded() {
        let result = ErrorMessageMapper.map("Live stream has ended")
        XCTAssertEqual(result, "라이브 방송은 다운로드할 수 없습니다.")
    }

    func testPremiere() {
        let result = ErrorMessageMapper.map("This video is a premiere")
        XCTAssertEqual(result, "프리미어 영상은 다운로드할 수 없습니다.")
    }

    func testMembersOnly() {
        let result = ErrorMessageMapper.map("members-only content")
        XCTAssertEqual(result, "멤버십 전용 영상입니다.")
    }

    func testNoFormats() {
        let result = ErrorMessageMapper.map("ERROR: no formats available")
        XCTAssertEqual(result, "다운로드 가능한 포맷이 없습니다.")
    }

    func testRequestedFormatNotAvailable() {
        let result = ErrorMessageMapper.map("Requested format is not available")
        // "not available" matches the unavailable rule first
        XCTAssertEqual(result, "영상을 사용할 수 없습니다.")
    }

    func testDownloadDenied() {
        let result = ErrorMessageMapper.map("download denied by server")
        XCTAssertEqual(result, "다운로드가 차단되었습니다.")
    }

    func testLongMessageTruncation() {
        let long = String(repeating: "a", count: 200)
        let result = ErrorMessageMapper.map(long)
        XCTAssertTrue(result.count <= 125, "Truncated message should be ≤125 chars, got \(result.count)")
        XCTAssertTrue(result.hasSuffix("..."))
    }

    func testUnknownErrorPassesThrough() {
        let result = ErrorMessageMapper.map("some random error xyz")
        XCTAssertEqual(result, "some random error xyz")
    }

    func testERRORPrefixStripped() {
        let result = ErrorMessageMapper.map("ERROR: something went wrong")
        XCTAssertEqual(result, "something went wrong")
    }
}
