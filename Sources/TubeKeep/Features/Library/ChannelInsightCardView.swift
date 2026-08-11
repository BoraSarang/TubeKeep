import SwiftUI

struct ChannelInsightCardView: View {
    let channelId: String
    let channelName: String
    let items: [LibraryItem]

    @State private var stats: ChannelInsightStats = .init()
    @State private var summary: String?
    @State private var isLoading = false
    @State private var summaryError: String?

    private let service = ChannelInsightService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("채널 인사이트")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }

            statsRow

            if !stats.topCategories.isEmpty {
                categoryRow
            }

            if let top = stats.topViewedVideo {
                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 10))
                    Text("최고 조회 \(top.title)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(formatCount(top.viewCount))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            summarySection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
        .onAppear { load() }
        .onChange(of: items.map(\.id)) { _, _ in
            load()
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statItem(value: "\(stats.videoCount)", label: "보관 영상")
            if stats.averageDuration > 0 {
                statDivider
                statItem(value: "\(stats.averageDuration / 60)분", label: "평균 길이")
            }
            if stats.totalMinutes > 0 {
                statDivider
                statItem(value: stats.totalDurationText, label: "총 재생시간")
            }
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 18)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Category

    private var categoryRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: 10))
            Text("주요 카테고리")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            ForEach(stats.topCategories.prefix(3), id: \.0) { name, count in
                Text("\(name) \(count)")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 6) {
                Label("AI 채널 소개", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    regenerate()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("다시 생성")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        } else if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("채널을 분석하는 중…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else if stats.videoCount >= ChannelInsightService.minimumVideosForAI {
            VStack(alignment: .leading, spacing: 6) {
                Text("보관 영상 데이터를 분석해 채널을 한눈에 소개해 드려요.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if let error = summaryError {
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }
                Button {
                    generateSummary()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("채널 소개 생성")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func load() {
        stats = ChannelInsightService.compute(channelId: channelId, items: items)
        if stats.videoCount >= ChannelInsightService.minimumVideosForAI {
            if let cached = service.cachedSummary(channelId: channelId) {
                summary = cached
            }
        } else {
            // 영상 수가 기준 미달로 줄어들면 기존 요약 제거
            summary = nil
            summaryError = nil
        }
    }

    private func generateSummary() {
        isLoading = true
        summaryError = nil
        Task {
            let generated = await service.summarize(
                channelId: channelId,
                channelName: channelName,
                stats: stats,
                items: items
            )
            await MainActor.run {
                isLoading = false
                if let generated, !generated.isEmpty {
                    summary = generated
                    service.saveSummary(channelId: channelId, summary: generated)
                } else {
                    summaryError = "요약 생성에 실패했습니다. API 키를 확인해 주세요."
                }
            }
        }
    }

    private func regenerate() {
        summary = nil
        service.invalidateCache(channelId: channelId)
        generateSummary()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f만", Double(count) / 10000)
        }
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

private extension ChannelInsightStats {
    var totalDurationText: String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    }
}