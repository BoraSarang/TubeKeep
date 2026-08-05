import Foundation

struct SearchResult: Equatable, Identifiable {
    let item: LibraryItem
    let snippet: String?

    var id: String { item.id }

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.item.id == rhs.item.id
    }
}

enum SearchService {
    static func rebuildIndex(items: [LibraryItem]) {
        DatabaseManager.shared.rebuildFTSIndex(items: items)
    }

    static func search(query: String, in items: [LibraryItem]) -> [SearchResult] {
        guard query.count >= 2 else { return [] }

        let db = DatabaseManager.shared
        let ftsResults = db.searchFTS(query: query)

        var itemMap: [String: LibraryItem] = [:]
        for item in items {
            itemMap[item.id] = item
        }

        var seen = Set<String>()
        var results: [SearchResult] = []

        for (videoId, snippet) in ftsResults {
            guard !seen.contains(videoId), let item = itemMap[videoId] else { continue }
            seen.insert(videoId)
            results.append(SearchResult(item: item, snippet: snippet))
        }

        if results.isEmpty {
            for item in items where item.title.localizedCaseInsensitiveContains(query) {
                guard !seen.contains(item.id) else { continue }
                seen.insert(item.id)
                results.append(SearchResult(item: item, snippet: nil))
            }
        }

        return results
    }
}
