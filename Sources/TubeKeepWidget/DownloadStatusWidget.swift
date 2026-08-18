import WidgetKit
import SwiftUI
import AppKit

// MARK: - Snapshot (App Group 공유 데이터)

struct WidgetSnapshot: Codable {
    struct Active: Codable {
        let title: String
        let progress: Double
        let speed: String
    }
    struct Recent: Codable {
        let title: String
        let completedAt: Date
    }
    var active: [Active] = []
    var waiting: Int = 0
    var recentCompleted: [Recent] = []
    var updatedAt: Date = Date()
}

// MARK: - Provider

struct Provider: TimelineProvider {
    static let groupID = "6GPJQ7BQC9.com.borasarang.tubekeep"
    static let snapshotKey = "widget_snapshot"

    func placeholder(in context: Context) -> DownloadEntry {
        DownloadEntry(snapshot: WidgetSnapshot(
            active: [.init(title: "동영상 다운로드", progress: 0.42, speed: "12.5 MB/s")],
            waiting: 3,
            recentCompleted: [.init(title: "완료된 영상", completedAt: Date())]
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (DownloadEntry) -> Void) {
        completion(DownloadEntry(snapshot: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadEntry>) -> Void) {
        let entry = DownloadEntry(snapshot: load())
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: Self.groupID),
              let data = defaults.data(forKey: Self.snapshotKey),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return snap
    }
}

struct DownloadEntry: TimelineEntry {
    let date: Date = Date()
    let snapshot: WidgetSnapshot
}

// MARK: - Widget

@main
struct TubeKeepWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadStatusWidget()
    }
}

struct DownloadStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DownloadStatus", provider: Provider()) { entry in
            DownloadStatusView(entry: entry)
        }
        .configurationDisplayName("다운로드 상태")
        .description("진행 중인 다운로드와 대기 항목을 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct DownloadStatusView: View {
    let entry: DownloadEntry

    var body: some View {
        if entry.snapshot.active.isEmpty, entry.snapshot.recentCompleted.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle").font(.title2).foregroundColor(.green)
                Text("다운로드 없음").font(.caption)
            }
            .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header
                ForEach(entry.snapshot.active.prefix(2), id: \.title) { item in
                    ActiveRow(item: item)
                }
                if entry.snapshot.waiting > 0 {
                    Label("대기 \(entry.snapshot.waiting)개", systemImage: "clock")
                        .font(.caption2).foregroundColor(.secondary)
                }
                if entry.snapshot.active.isEmpty, let recent = entry.snapshot.recentCompleted.first {
                    Label(recent.title, systemImage: "checkmark.circle.fill")
                        .font(.caption2).lineLimit(1).foregroundColor(.green)
                }
                Spacer(minLength: 0)
            }
            .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill").foregroundColor(.accentColor)
            Text("TubeKeep").font(.caption).bold()
            Spacer()
            Text(entry.snapshot.updatedAt, style: .time).font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct ActiveRow: View {
    let item: WidgetSnapshot.Active

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.title).font(.caption).lineLimit(1)
                Spacer()
                Text("\(Int(item.progress * 100))%").font(.caption2).monospacedDigit().foregroundColor(.secondary)
            }
            ProgressView(value: item.progress).progressViewStyle(.linear).tint(.accentColor)
        }
    }
}
