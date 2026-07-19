import XCTest
@testable import TubeKeep

final class QAModelTests: XCTestCase {

    func testDecodeQAResponse() {
        let json = """
        {
            "question": "이 영상의 주요 내용은?",
            "answer": "SwiftUI와 TCA를 사용한 앱 개발 방법을 설명합니다.",
            "timestamps": [
                {"time": "0:30", "startTime": 30.0, "description": "SwiftUI 소개"},
                {"time": "2:15", "startTime": 135.0, "description": "TCA 패턴 설명"}
            ]
        }
        """
        let data = Data(json.utf8)
        let response = try! JSONDecoder().decode(QAResponse.self, from: data)
        XCTAssertEqual(response.question, "이 영상의 주요 내용은?")
        XCTAssertTrue(response.answer.contains("SwiftUI"))
        XCTAssertEqual(response.timestamps.count, 2)
        XCTAssertEqual(response.timestamps[0].time, "0:30")
        XCTAssertEqual(response.timestamps[0].startTime, 30.0)
        XCTAssertEqual(response.timestamps[0].description, "SwiftUI 소개")
    }

    func testQAResponseNoTimestamps() {
        let json = """
        {
            "question": "간단한 질문",
            "answer": "간단한 답변",
            "timestamps": []
        }
        """
        let data = Data(json.utf8)
        let response = try! JSONDecoder().decode(QAResponse.self, from: data)
        XCTAssertEqual(response.question, "간단한 질문")
        XCTAssertEqual(response.answer, "간단한 답변")
        XCTAssertTrue(response.timestamps.isEmpty)
    }

    func testQATimestampIdentifier() {
        let ts = QATimestamp(time: "1:23", startTime: 83.0, description: "테스트")
        XCTAssertEqual(ts.id, "83.0")
    }

    func testQAResponseEquality() {
        let a = QAResponse(
            question: "Q", answer: "A",
            timestamps: [QATimestamp(time: "0:10", startTime: 10.0, description: "D")]
        )
        let b = QAResponse(
            question: "Q", answer: "A",
            timestamps: [QATimestamp(time: "0:10", startTime: 10.0, description: "D")]
        )
        XCTAssertEqual(a, b)
    }

    func testQAResponseInequality() {
        let a = QAResponse(question: "Q1", answer: "A", timestamps: [])
        let b = QAResponse(question: "Q2", answer: "A", timestamps: [])
        XCTAssertNotEqual(a, b)
    }

    func testEncodeDecodeRoundTrip() {
        let original = QAResponse(
            question: "테스트 질문",
            answer: "테스트 답변",
            timestamps: [
                QATimestamp(time: "1:00", startTime: 60.0, description: "1분")
            ]
        )
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(QAResponse.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
