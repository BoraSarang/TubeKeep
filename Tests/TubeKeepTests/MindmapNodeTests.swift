import XCTest
@testable import TubeKeep

final class MindmapNodeTests: XCTestCase {

    private let sampleJSON = """
    {
        "label": "영상 요약",
        "children": [
            {
                "label": "주요 내용",
                "children": [
                    {"label": "SwiftUI로 UI 구현", "children": []},
                    {"label": "TCA 패턴 적용", "children": []}
                ]
            },
            {
                "label": "결론",
                "children": []
            }
        ]
    }
    """

    func testDecodeFromJSONWithoutId() {
        let data = Data(sampleJSON.utf8)
        let node = try! JSONDecoder().decode(MindmapNode.self, from: data)
        XCTAssertEqual(node.label, "영상 요약")
        XCTAssertEqual(node.children.count, 2)
        XCTAssertEqual(node.children[0].label, "주요 내용")
        XCTAssertEqual(node.children[0].children.count, 2)
        XCTAssertEqual(node.children[1].label, "결론")
        XCTAssertEqual(node.children[1].children.count, 0)
    }

    func testDecodeGeneratesUniqueIds() {
        let data = Data(sampleJSON.utf8)
        let node = try! JSONDecoder().decode(MindmapNode.self, from: data)
        let allIds = collectAllIds(node)
        let uniqueIds = Set(allIds)
        XCTAssertEqual(allIds.count, uniqueIds.count, "모든 노드는 고유한 UUID를 가져야 함")
    }

    func testEncodeDecodeRoundTrip() {
        let original = MindmapNode(
            label: "루트",
            children: [
                MindmapNode(label: "자식1"),
                MindmapNode(label: "자식2", children: [
                    MindmapNode(label: "손자")
                ])
            ]
        )
        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(MindmapNode.self, from: data)
        XCTAssertEqual(decoded.label, "루트")
        XCTAssertEqual(decoded.children.count, 2)
        XCTAssertEqual(decoded.children[1].children.count, 1)
        XCTAssertEqual(decoded.children[1].children[0].label, "손자")
    }

    func testEncodeDoesNotIncludeId() {
        let node = MindmapNode(label: "테스트")
        let data = try! JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("id"), "JSON에 id 필드가 없어야 함")
        XCTAssertFalse(json.contains("UUID"), "JSON에 UUID 필드가 없어야 함")
    }

    func testSingleNode() {
        let json = """
        {"label": "루트", "children": []}
        """
        let data = Data(json.utf8)
        let node = try! JSONDecoder().decode(MindmapNode.self, from: data)
        XCTAssertEqual(node.label, "루트")
        XCTAssertTrue(node.children.isEmpty)
    }

    func testDeeplyNestedTree() {
        let json = """
        {
            "label": "L0",
            "children": [
                {
                    "label": "L1",
                    "children": [
                        {
                            "label": "L2",
                            "children": [
                                {"label": "L3", "children": []}
                            ]
                        }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)
        let node = try! JSONDecoder().decode(MindmapNode.self, from: data)
        XCTAssertEqual(node.label, "L0")
        XCTAssertEqual(node.children[0].label, "L1")
        XCTAssertEqual(node.children[0].children[0].label, "L2")
        XCTAssertEqual(node.children[0].children[0].children[0].label, "L3")
    }

    func testEqualityIgnoresId() {
        let a = MindmapNode(label: "A", children: [MindmapNode(label: "B")])
        let b = MindmapNode(label: "A", children: [MindmapNode(label: "B")])
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.children[0], b.children[0])
    }

    func testInequality() {
        let a = MindmapNode(label: "A")
        let b = MindmapNode(label: "B")
        XCTAssertNotEqual(a, b)
    }

    private func collectAllIds(_ node: MindmapNode) -> [UUID] {
        var ids = [node.id]
        for child in node.children {
            ids.append(contentsOf: collectAllIds(child))
        }
        return ids
    }
}
