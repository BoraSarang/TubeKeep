import Foundation

struct MindmapNode: Codable, Equatable, Identifiable {
    var id: UUID
    var label: String
    var children: [MindmapNode]

    init(id: UUID = UUID(), label: String, children: [MindmapNode] = []) {
        self.id = id
        self.label = label
        self.children = children
    }

    enum CodingKeys: String, CodingKey {
        case label, children
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.label = try container.decode(String.self, forKey: .label)
        self.children = try container.decode([MindmapNode].self, forKey: .children)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(children, forKey: .children)
    }
}

struct MindmapResult: Equatable {
    let root: MindmapNode
    let formatVersion: Int
}
