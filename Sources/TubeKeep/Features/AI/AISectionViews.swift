import SwiftUI
import AppKit
import ComposableArchitecture

// MARK: - AI 공용 섹션 컴포넌트 (AI 창 + 플레이어 AI 패널 공유)

enum AISectionHelper {
    static func currentItem(_ store: StoreOf<AppReducer>) -> LibraryItem? {
        guard let videoId = store.library.librarySummaryVideoId ?? store.library.qna.selectedVideoId else { return nil }
        return store.library.items.first(where: { $0.id == videoId })
    }

    static func stripChaptersSection(_ text: String) -> String {
        let patterns = ["챕터:", "챕터 :", "Chapters:", "chapters:"]
        var result = text
        for pattern in patterns {
            if let range = result.range(of: pattern) {
                result = String(result[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return result
    }

    static func chaptersForItem(_ item: LibraryItem, summaryText: String?) -> [ChapterInfo]? {
        if let chaptersData = item.chapters,
           let chapters = try? JSONDecoder().decode([ChapterInfo].self, from: chaptersData),
           !chapters.isEmpty {
            return chapters
        }
        if let summaryText = summaryText {
            return extractChaptersFromSummary(summaryText)
        }
        if let summaryText = item.summary {
            return extractChaptersFromSummary(summaryText)
        }
        return nil
    }

    static func extractChaptersFromSummary(_ text: String) -> [ChapterInfo]? {
        var chapters: [ChapterInfo] = []
        let lines = text.components(separatedBy: .newlines)
        var foundChapters = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("챕터:") || trimmed.hasPrefix("챕터 :") || trimmed.hasPrefix("Chapters:") || trimmed.hasPrefix("chapters:") {
                foundChapters = true
                continue
            }
            if foundChapters {
                if let chapter = SummaryParser.parseChapterLine(trimmed) {
                    chapters.append(chapter)
                } else if !trimmed.isEmpty && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("-") {
                    break
                }
            }
        }
        return chapters.isEmpty ? nil : chapters
    }
}

// MARK: - 요약

struct AISummarySection: View {
    let store: StoreOf<AppReducer>

    private var summaryText: String? {
        store.library.librarySummaryText ?? AISectionHelper.currentItem(store)?.summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("요약 정보")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let text = summaryText, !text.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("요약 복사")
                }
                if let videoId = store.library.librarySummaryVideoId {
                    Button {
                        store.send(.library(.resummarize(videoId)))
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("다시 요약")
                }
            }

            if store.library.librarySummaryLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("요약 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let text = summaryText, !text.isEmpty {
                ScrollView {
                    Text(AISectionHelper.stripChaptersSection(text))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                Text("요약 없음")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.trailing, 4)
    }
}

// MARK: - 챕터

struct AIChapterSection: View {
    let store: StoreOf<AppReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("챕터")
                .font(.system(size: 12, weight: .semibold))

            if let item = AISectionHelper.currentItem(store),
               let chapters = AISectionHelper.chaptersForItem(item, summaryText: store.library.librarySummaryText) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(chapters) { chapter in
                            Button {
                                store.send(.library(.qna(.seekToTimestamp(chapter.startTime))))
                            } label: {
                                HStack(spacing: 6) {
                                    Text(chapter.startTimeFormatted)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 42, alignment: .leading)
                                    Text(chapter.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("챕터 없음")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - 마인드맵

struct AIMindmapSection: View {
    let store: StoreOf<AppReducer>
    let videoId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("마인드맵")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if store.library.mindmap.node == nil, !store.library.mindmap.loading {
                    Button {
                        store.send(.library(.mindmap(.generateMindmap(videoId))))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 11))
                            Text("마인드맵 생성")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            if store.library.mindmap.node == nil, !store.library.mindmap.loading {
                Text("마인드맵 생성 버튼을 눌러 생성하세요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            }

            if store.library.mindmap.loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("마인드맵 생성 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let node = store.library.mindmap.node {
                ScrollView {
                    MindmapTreeView(node: node, store: store)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let error = store.library.mindmap.error {
                ErrorBanner(message: error)
            }
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Q&A

struct AIQnASection: View {
    let store: StoreOf<AppReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("질문")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            QAInputBar(store: store)

            if store.library.qna.loading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("답변 생성 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if let error = store.library.qna.error {
                ErrorBanner(message: error)
            }

            if store.library.qna.historyItems.isEmpty && !store.library.qna.loading {
                Text("질문을 입력해주세요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.library.qna.historyItems) { item in
                            qaHistoryItem(item)
                        }
                    }
                }
            }
        }
        .padding(.leading, 8)
    }

    @ViewBuilder
    private func qaHistoryItem(_ item: QAHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Q: \(item.question)")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                Button {
                    store.send(.library(.qna(.deleteQnAHistoryItem(item.id))))
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("질문 삭제")
            }

            if !item.timestamps.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(item.timestamps) { ts in
                        Button {
                            store.send(.library(.qna(.seekToTimestamp(ts.startTime))))
                        } label: {
                            HStack(alignment: .top, spacing: 4) {
                                Text(ts.time)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 30, alignment: .leading)
                                Text(ts.description.isEmpty ? item.answer : ts.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("A: \(item.answer)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(6)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}