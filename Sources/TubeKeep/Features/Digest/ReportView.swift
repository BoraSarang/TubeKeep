import SwiftUI
import ComposableArchitecture

struct ReportView: View {
    let store: StoreOf<LibraryReducer>

    @State private var period: ReportPeriod = .week

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.report.loading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("통계 계산 중...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else if let stats = store.report.stats {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards(stats)
                        channelAndCategory(stats)
                        if !stats.categoryDeltas.isEmpty {
                            categoryDeltasSection(stats)
                        }
                        if let narrative = stats.aiNarrative, !narrative.isEmpty {
                            narrativeSection(narrative)
                        }
                    }
                    .padding(16)
                }
            } else {
                Spacer()
                Text("기간을 선택하고 리포트를 확인하세요")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: period) { _, newPeriod in
            store.send(.report(.generateReport(newPeriod)))
        }
        .onAppear {
            store.send(.report(.generateReport(period)))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
            Text("📊 리포트")
                .font(.system(size: 13, weight: .bold))
            Spacer()
            Picker("", selection: $period) {
                ForEach(ReportPeriod.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button {
                store.send(.report(.generateReport(period)))
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("새로고침")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Summary Cards

    private func summaryCards(_ stats: DigestStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                icon: "arrow.down.to.line",
                label: "다운로드",
                value: "\(stats.videosDownloaded)개",
                color: .blue
            )
            statCard(
                icon: "externaldrive",
                label: "용량",
                value: ByteCountFormatter.string(fromByteCount: stats.totalSizeBytes, countStyle: .file),
                color: .green
            )
            statCard(
                icon: "text.bubble",
                label: "AI 요약",
                value: "\(stats.summaryCount)회",
                color: .purple
            )
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Channel & Category

    private func channelAndCategory(_ stats: DigestStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person")
                        .font(.system(size: 10))
                    Text("인기 채널")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(stats.topChannel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                    Text("인기 카테고리")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(stats.topCategory)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Category Deltas

    private func categoryDeltasSection(_ stats: DigestStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 카테고리 증감 (전주기 대비)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(Array(stats.categoryDeltas.prefix(10)), id: \.0) { cat, delta in
                    HStack(spacing: 8) {
                        Text(cat)
                            .font(.system(size: 11))
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: geo.size.width, height: 12)

                                let width = min(abs(CGFloat(delta)) / 100 * geo.size.width, geo.size.width)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(delta >= 0 ? Color.green.opacity(0.6) : Color.red.opacity(0.6))
                                    .frame(width: width, height: 12)
                                    .offset(x: delta >= 0 ? geo.size.width / 2 : geo.size.width / 2 - width)
                            }
                        }
                        .frame(height: 12)

                        Text("\(delta >= 0 ? "+" : "")\(String(format: "%.0f", delta))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(delta >= 0 ? .green : .red)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Narrative

    private func narrativeSection(_ narrative: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "text.quote")
                    .font(.system(size: 10))
                Text("AI 리포트")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(narrative)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
