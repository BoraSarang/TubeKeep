import SwiftUI
import ComposableArchitecture

struct QAView: View {
    let store: StoreOf<AppReducer>
    let videoId: String
    let videoTitle: String
    @State private var question = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            Divider()
            if store.library.qna.loading {
                loadingSection
            } else if let error = store.library.qna.error {
                errorSection(error)
            }
            questionInputSection
            Divider()
            historySection
        }
        .padding(20)
        .frame(width: 420, height: 500)
        .onAppear {
            store.send(.library(.qna(.loadQnAHistory(videoId))))
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Label("Q&A", systemImage: "questionmark.circle")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                store.send(.library(.qna(.close)))
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        Text(videoTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var loadingSection: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.9)
            Text("답변 생성 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func errorSection(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var questionInputSection: some View {
        HStack(spacing: 8) {
            TextField("영상에 대해 질문하세요...", text: $question)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .focused($isInputFocused)
                .onSubmit {
                    askQuestion()
                }
            Button {
                askQuestion()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.library.qna.loading)
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if store.library.qna.historyItems.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("질문이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.library.qna.historyItems) { item in
                        historyItemView(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historyItemView(_ item: QAHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.question)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                Button {
                    store.send(.library(.qna(.deleteQnAHistoryItem(item.id))))
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            Text(item.answer)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !item.timestamps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.timestamps) { ts in
                        Button {
                            store.send(.library(.qna(.seekToTimestamp(ts.startTime))))
                        } label: {
                            Text(ts.time)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(formatDate(item.createdAt))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func askQuestion() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.send(.library(.qna(.askQuestion(videoId: videoId, question: trimmed))))
        question = ""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
