import XCTest
@testable import TubeKeep

final class PodcastModelTests: XCTestCase {

    func testDecodePodcastScript() {
        let json = """
        {
            "segments": [
                {"speaker": "진행자A", "text": "안녕하세요, 오늘 영상에서는 SwiftUI에 대해 알아보겠습니다."},
                {"speaker": "진행자B", "text": "네, SwiftUI는 정말 강력한 프레임워크입니다."},
                {"speaker": "진행자A", "text": "특히 TCA와 함께 사용하면 더 좋습니다."}
            ]
        }
        """
        let data = Data(json.utf8)
        let script = try! JSONDecoder().decode(PodcastScript.self, from: data)
        XCTAssertEqual(script.segments.count, 3)
        XCTAssertEqual(script.segments[0].speaker, "진행자A")
        XCTAssertTrue(script.segments[1].text.contains("SwiftUI"))
        XCTAssertEqual(script.segments[2].speaker, "진행자A")
    }

    func testPodcastScriptEmptySegments() {
        let json = """
        {"segments": []}
        """
        let data = Data(json.utf8)
        let script = try! JSONDecoder().decode(PodcastScript.self, from: data)
        XCTAssertTrue(script.segments.isEmpty)
    }

    func testSingleSegment() {
        let json = """
        {"segments": [{"speaker": "Host", "text": "Hello world"}]}
        """
        let data = Data(json.utf8)
        let script = try! JSONDecoder().decode(PodcastScript.self, from: data)
        XCTAssertEqual(script.segments.count, 1)
        XCTAssertEqual(script.segments[0].speaker, "Host")
        XCTAssertEqual(script.segments[0].text, "Hello world")
    }

    func testSegmentEquality() {
        let a = PodcastSegment(speaker: "A", text: "Hello")
        let b = PodcastSegment(speaker: "A", text: "Hello")
        XCTAssertEqual(a, b)
    }

    func testSegmentInequality() {
        let a = PodcastSegment(speaker: "A", text: "Hello")
        let b = PodcastSegment(speaker: "B", text: "Hello")
        XCTAssertNotEqual(a, b)
    }

    func testScriptEquality() {
        let a = PodcastScript(segments: [
            PodcastSegment(speaker: "A", text: "T1"),
            PodcastSegment(speaker: "B", text: "T2")
        ])
        let b = PodcastScript(segments: [
            PodcastSegment(speaker: "A", text: "T1"),
            PodcastSegment(speaker: "B", text: "T2")
        ])
        XCTAssertEqual(a, b)
    }

    func testEncodeDecodeRoundTrip() {
        let original = PodcastScript(segments: [
            PodcastSegment(speaker: "Host", text: "Welcome"),
            PodcastSegment(speaker: "Guest", text: "Thanks")
        ])
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(PodcastScript.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
