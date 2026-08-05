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

    /// 검색어가 등장하는 자막/트랜스크립트 위치의 재생 시간(초)을 반환.
    /// 우선순위: DB 자막(SubtitleCue) 정확 매칭 → transcript 문자 오프셋 비율 추정.
    static func locateMatch(videoId: String, query: String, duration: Double) async -> Double? {
        let db = DatabaseManager.shared
        let data = db.loadVideoAIData(videoId: videoId)

        if let subtitlesData = data?.subtitlesData,
           let cues = try? JSONDecoder().decode([SubtitleCue].self, from: subtitlesData) {
            for term in Self.searchTerms(from: query) {
                if let cue = cues.first(where: { $0.text.localizedCaseInsensitiveContains(term) }) {
                    return cue.startTime
                }
            }
        }

        if let transcript = data?.transcript, !transcript.isEmpty, duration > 0 {
            for term in Self.searchTerms(from: query) {
                if let range = transcript.range(of: term, options: .caseInsensitive) {
                    let pos = transcript.distance(from: transcript.startIndex, to: range.lowerBound)
                    let ratio = Double(pos) / Double(transcript.count)
                    return min(max(ratio * duration, 0), duration)
                }
            }
        }

        return nil
    }

    private static func searchTerms(from query: String) -> [String] {
        query.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { $0.count >= 2 }
    }
}
