import Foundation

actor RecommendationService {
    static func recommendedSearchQueries(from profile: UserProfile) -> [String] {
        let top = profile.categoryDistribution.prefix(3)
        if top.isEmpty {
            return ["오늘 인기 영상"]
        }
        return top.map { cat in
            let searchTerms: [String: String] = [
                "기술/IT": "개발자 기술 리뷰",
                "음악": "신곡 음악",
                "게임": "최신 게임 플레이",
                "뉴스/정치": "오늘의 뉴스",
                "스포츠": "스포츠 하이라이트",
                "엔터테인먼트": "연예 방송",
                "교육": "강의 교육",
                "요리": "요리 레시피",
                "여행": "여행 브이로그",
                "과학": "과학 기술",
            ]
            return searchTerms[cat.category, default: cat.category]
        }
    }

    static func recommendFromLibrary(
        from allItems: [LibraryItem],
        exclude: String? = nil
    ) -> [LibraryItem] {
        var tagCount: [String: Int] = [:]
        for item in allItems {
            for tag in item.tags {
                tagCount[tag, default: 0] += 1
            }
        }
        let topTags = Set(tagCount.sorted { $0.value > $1.value }.prefix(3).map(\.key))

        let scored = allItems.filter { item in
            guard item.id != exclude else { return false }
            guard FileManager.default.fileExists(atPath: item.filePath) else { return false }
            return !item.tags.isEmpty && topTags.intersection(item.tags).count > 0
        }.sorted { a, b in
            let aScore = topTags.intersection(a.tags).count
            let bScore = topTags.intersection(b.tags).count
            if aScore != bScore { return aScore > bScore }
            return a.downloadDate > b.downloadDate
        }

        return Array(scored.prefix(10))
    }
}
