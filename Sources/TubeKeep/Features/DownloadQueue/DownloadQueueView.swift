import SwiftUI
import ComposableArchitecture

struct DownloadQueueView: View {
    @ObservedObject var store: StoreOf<DownloadQueueReducer>

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader

            if !store.items.isEmpty {
                queueStatusFooter
            }

            if store.items.isEmpty {
                emptyState
                    .frame(maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let toast = store.toastMessage {
                toastBanner(toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.toastMessage?.id)
    }

    private var sectionHeader: some View {
        HStack {
            Label("다운로드 목록", systemImage: "arrow.down.circle")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if store.pendingCount > 0, !store.hasActiveDownloads {
                Button {
                    store.send(.startAll)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("시작")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.info)
            }

            if store.hasActiveDownloads {
                Button {
                    store.send(.stopAll)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("중지")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.danger)
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("다운로드할 영상을 추가해 주세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var queueStatusFooter: some View {
        HStack(spacing: 10) {
            Spacer()

            if store.activeCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(AppColors.success).frame(width: 5, height: 5)
                    Text("\(store.activeCount)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    if !store.aggregateSpeed.isEmpty {
                        Text(store.aggregateSpeed)
                            .font(.system(size: 10).monospacedDigit())
                    }
                    if !store.aggregateETA.isEmpty {
                        Text("\(store.aggregateETA) 남음")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if store.pendingCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("대기 \(store.pendingCount)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if store.failedCount > 0 {
                Button {
                    store.send(.retryAllFailed)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("재시도 \(store.failedCount)")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.warning)
            }

            if store.completedCount > 0 {
                Button {
                    store.send(.clearCompleted)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("완료 \(store.completedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                let outputDir = Settings.loadSettings().storageDirectory
                NSWorkspace.shared.open(URL(fileURLWithPath: outputDir))
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("저장 폴더")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppColors.controlBackground)
        .overlay(Divider(), alignment: .top)
    }

    private var listContent: some View {
        List {
            Color.clear
                .frame(height: 4)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            ForEach(Array(store.items.enumerated()).reversed(), id: \.element.id) { _, item in
                DownloadRow(item: item, store: store)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                if item.id != store.items.first?.id {
                    Divider()
                        .padding(.leading, 48)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
            .onMove { source, destination in
                var display = Array(store.items.reversed())
                display.move(fromOffsets: source, toOffset: destination)
                store.send(.setItems(Array(display.reversed())))
            }
        }
        .listStyle(.plain)
        .help("항목을 드래그하여 순서를 변경할 수 있습니다")
    }

    private func toastBanner(_ toast: ToastMessage) -> some View {
        ToastBanner(toast: toast) {
            store.send(.dismissToast)
        }
    }

}

struct DownloadRow: View {
    let item: DownloadItem
    let store: StoreOf<DownloadQueueReducer>
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                CachedThumbnailView(videoId: item.videoInfo.id, url: item.videoInfo.thumbnailURL)
                    .frame(width: 48, height: 27)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(item.status == .completed ? 0.5 : 1)

                if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                        .font(.system(size: 14))
                } else {
                    statusIcon
                        .font(.system(size: 10))
                        .padding(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.videoInfo.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if item.status == .completed {
                        Text(item.optionsLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.success)
                    } else {
                        Text(item.optionsLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        if item.status == .downloading {
                            if !item.downloadSpeed.isEmpty {
                                Text(item.downloadSpeed)
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(Int(item.progress * 100))%")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(AppColors.info)
                            if !item.etaText.isEmpty {
                                Text(item.etaText)
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        } else if item.status == .pending {
                            Text("대기 중")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if item.status == .paused {
                            Text("일시정지")
                                .font(.caption)
                                .foregroundStyle(AppColors.warning)
                        } else if item.status == .retrying {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(AppColors.info)
                                .font(.system(size: 10))
                            Text("재시도 \(item.retryCount)/\(store.maxRetries)...")
                                .font(.caption)
                                .foregroundStyle(AppColors.info)
                        } else if item.status == .failed {
                            Text("실패")
                                .font(.caption)
                                .foregroundStyle(AppColors.danger)
                            if let err = item.errorMessage, !err.isEmpty {
                                Text(err.prefix(60))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if item.status == .downloading {
                    ProgressView(value: max(0, min(1, item.progress)))
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .tint(AppColors.info)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                if item.status == .downloading {
                    Button {
                        store.send(.pauseDownload(item.id))
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.warning)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("일시정지")
                }

                if item.status == .paused {
                    Button {
                        store.send(.resumeDownload(item.id))
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.info)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("재개")
                }

                if item.status == .failed || item.status == .retrying {
                    Button {
                        store.send(.retryDownload(item.id))
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.info)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("재시도")
                }

                Button {
                    store.send(.removeItem(item.id))
                } label: {
                    Image(systemName: isHovering ? "trash.fill" : "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(isHovering ? .red : AppColors.tertiaryLabel)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.4)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            if item.status == .completed {
                store.send(.revealInFinder(item.id))
            }
        }
        .background(
            GeometryReader { geo in
                if item.status == .downloading {
                    Rectangle()
                        .fill(AppColors.progressActive)
                        .frame(width: (geo.size.width - 58) * max(0, min(1, item.progress)))
                        .offset(x: 58)
                        .animation(.linear(duration: 0.3), value: item.progress)
                } else if item.status == .completed {
                    Rectangle()
                        .fill(AppColors.progressCompleted)
                        .frame(width: geo.size.width - 58)
                        .offset(x: 58)
                }
            }
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(AppColors.info)
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.tertiary)
        case .retrying:
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(AppColors.info)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(AppColors.warning)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.danger)
        }
    }
}

struct WaveProgress: View {
    let progress: Double
    let width: CGFloat
    let offsetX: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.03)) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 2
                let barWidth = size.width * max(0, min(1, progress))
                guard barWidth > 0 else { return }

                let rect = CGRect(x: offsetX, y: 0, width: barWidth, height: size.height)

                // Base gradient fill
                let baseGradient = Gradient(colors: AppColors.waveBaseGradient)
                var basePath = Path()
                basePath.addRect(rect)
                context.fill(basePath, with: .linearGradient(
                    baseGradient,
                    startPoint: CGPoint(x: rect.minX, y: 0),
                    endPoint: CGPoint(x: rect.maxX, y: rect.height)
                ))

                // Shimmer highlight sweeping right
                let shimmerX = ((phase * 60).truncatingRemainder(dividingBy: barWidth + 80) - 40)
                let shimmerGradient = Gradient(colors: [
                    .clear,
                    .white.opacity(0.12),
                    .white.opacity(0.2),
                    .white.opacity(0.12),
                    .clear,
                ])
                var shimmerPath = Path()
                let shimmerRect = CGRect(
                    x: offsetX + shimmerX,
                    y: 0,
                    width: 60,
                    height: rect.height
                )
                shimmerPath.addRect(shimmerRect)
                context.fill(shimmerPath, with: .linearGradient(
                    shimmerGradient,
                    startPoint: CGPoint(x: shimmerRect.minX, y: 0),
                    endPoint: CGPoint(x: shimmerRect.maxX, y: 0)
                ))

                // Bottom accent line
                var linePath = Path()
                linePath.move(to: CGPoint(x: rect.minX, y: rect.height - 1))
                linePath.addLine(to: CGPoint(x: rect.maxX, y: rect.height - 1))
                context.stroke(linePath, with: .color(AppColors.waveAccentLine), lineWidth: 1.5)
            }
        }
    }
}
