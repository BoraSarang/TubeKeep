import Foundation

actor TaggingService {
    let predefinedTags = [
        "기술/IT", "음악", "게임", "뉴스/시사",
        "스포츠", "엔터테인먼트", "교육/강의",
        "요리/음식", "여행/일상", "과학",
    ]

    func classify(title: String, channel: String, apiKey: String) async -> String {
        guard !apiKey.isEmpty else {
            return autoClassify(title: title, channel: channel)
        }
        let prompt = """
        Classify the following YouTube video into exactly ONE category.
        Choose only from: \(predefinedTags.joined(separator: ", "))

        Title: \(title)
        Channel: \(channel)

        Return ONLY the category name, nothing else.
        """

        guard let tag = try? await queryGemini(prompt: prompt, apiKey: apiKey) else {
            return autoClassify(title: title, channel: channel)
        }

        let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if predefinedTags.contains(cleaned) {
            return cleaned
        }

        return autoClassify(title: title, channel: channel)
    }

    private func autoClassify(title: String, channel: String) -> String {
        let lowerTitle = title.lowercased()
        let lowerChannel = channel.lowercased()

        let rules: [(String, [String])] = [
            ("기술/IT", ["review", "tech", "apple", "microsoft", "google", "mac", "iphone", "ipad", "ios",
                         "리뷰", "테크", "기술", "개발", "프로그래밍", "코딩", "swift", "ai",
                         "9to5mac", "it", "전자기기", "갤럭시", "아이폰", "맥북"]),
            ("음악", ["music", "song", "album", "mv", "오디오", "music video", "official audio",
                      "노래", "음악", "가사", "lyrics", "cover", "remix", "live performance",
                      "k-pop", "kpop"]),
            ("게임", ["game", "gaming", "gameplay", "playthrough", "walkthrough",
                      "게임", "플레이", "롤", "로스트아크", "배그", "발로란트"]),
            ("뉴스/시사", ["news", "breaking", "kbs", "mbc", "sbs", "ytn", "연합뉴스",
                          "뉴스", "속보", "시사", "정치", "경제"]),
            ("스포츠", ["sports", "sport", "football", "soccer", "baseball", "basketball",
                        "스포츠", "축구", "야구", "농구", "하이라이트"]),
            ("엔터테인먼트", ["entertainment", "예능", "방송", "tv", "쇼", "프로그램",
                            "연예", "연예인", "영화", "드라마"]),
            ("교육/강의", ["tutorial", "course", "lecture", "lesson", "guide", "how to",
                          "강의", "교육", "배움", "학습", "튜토리얼"]),
            ("요리/음식", ["cook", "recipe", "food", "요리", "레시피", "음식", "먹방", "쿡방"]),
            ("여행/일상", ["travel", "vlog", "daily", "일상", "여행", "vlog"]),
            ("과학", ["science", "physics", "chemistry", "biology", "space", "과학", "물리", "화학", "생물"]),
        ]

        for (tag, keywords) in rules {
            for keyword in keywords {
                if lowerTitle.contains(keyword) || lowerChannel.contains(keyword) {
                    return tag
                }
            }
        }

        return "기타"
    }

    private func queryGemini(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { throw SummarizationService.SummaryError.apiUnavailable("Gemini API 오류") }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let result = firstPart["text"] as? String
        else { throw SummarizationService.SummaryError.summaryFailed("Gemini API 응답 파싱 실패") }
        return result
    }
}
