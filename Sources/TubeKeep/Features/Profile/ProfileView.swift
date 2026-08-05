import SwiftUI
import ComposableArchitecture

struct ProfileView: View {
    let store: StoreOf<ProfileReducer>

    var body: some View {
        VStack(spacing: 16) {
            if store.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                Text("프로필 분석 중...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let p = store.profile {
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection(p)
                        categorySection(p)
                        topChannelsSection(p)
                        statsSection(p)
                        timeHistogramSection(p)
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("보관함 데이터를 분석하여 취향 프로필을 만들어 드립니다")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button("프로필 보기") {
                        store.send(.refresh)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            store.send(.refresh)
        }
    }

    private func headerSection(_ p: UserProfile) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)
            Text("내 시청 성향")
                .font(.system(size: 18, weight: .bold))
            Text("\(p.totalVideos)개 영상 · \(p.totalChannels)개 채널 · \(formatBytes(p.totalStorageBytes))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func categorySection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("📊 카테고리 분포")
            if p.categoryDistribution.isEmpty {
                Text("분석할 태그 데이터가 없습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(p.categoryDistribution, id: \.category) { cat in
                    HStack(spacing: 8) {
                        Text(cat.category)
                            .font(.system(size: 12))
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 16)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor)
                                    .frame(width: max(geo.size.width * CGFloat(cat.percentage) / 100, 4), height: 16)
                            }
                        }
                        .frame(height: 16)
                        Text("\(Int(cat.percentage))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func topChannelsSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("📺 TOP 채널")
            if p.topChannels.isEmpty {
                Text("채널 데이터가 없습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(p.topChannels.enumerated()), id: \.element.name) { i, ch in
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(ch.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text("\(ch.count)개")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func statsSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("📈 시청 통계")
            HStack(spacing: 16) {
                statBox(title: "평균 영상 길이", value: formatDuration(Int(p.averageDuration)))
                statBox(title: "선호 해상도", value: p.preferredResolution > 0 ? "\(p.preferredResolution)p" : "-")
                statBox(title: "요약 사용률", value: "\(Int(p.summaryUsageRate * 100))%")
            }
        }
    }

    private func timeHistogramSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("🕐 활동 시간대")
            if p.downloadTimeHistogram.isEmpty {
                Text("히스토리 데이터가 없습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                let maxCount = max(p.downloadTimeHistogram.values.max() ?? 1, 1)
                let sorted = (0..<24).map { h -> (hour: Int, count: Int) in
                    (h, p.downloadTimeHistogram[h] ?? 0)
                }
                VStack(spacing: 4) {
                    ForEach(sorted, id: \.hour) { slot in
                        HStack(spacing: 6) {
                            Text(String(format: "%02d시", slot.hour))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(slot.count > 0 ? Color.accentColor : Color.primary.opacity(0.04))
                                    .frame(width: max(geo.size.width * CGFloat(slot.count) / CGFloat(maxCount), slot.count > 0 ? 6 : 0), height: 12)
                            }
                            .frame(height: 12)
                            Text("\(slot.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "-" }
        let m = seconds / 60
        if m >= 60 {
            let h = m / 60
            let r = m % 60
            return "\(h)시간 \(r)분"
        }
        return "\(m)분"
    }
}
