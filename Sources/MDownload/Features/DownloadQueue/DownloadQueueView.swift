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
                            .font(.system(size: 8))
                        Text("시작")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            if store.hasActiveDownloads {
                Button {
                    store.send(.stopAll)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8))
                        Text("중지")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }

            #if DEBUG
            Button("Mock 테스트") {
                store.send(.startTestDownload)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.orange)
            #endif
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
            Text("다운로드할 영상을 추가해주세요")
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
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text("\(store.activeCount)")
                        .font(.system(size: 10, design: .monospaced).weight(.semibold))
                    if !store.aggregateSpeed.isEmpty {
                        Text(store.aggregateSpeed)
                            .font(.system(size: 9, design: .monospaced))
                    }
                    if !store.aggregateETA.isEmpty {
                        Text("\(store.aggregateETA) 남음")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if store.pendingCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
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
                            .font(.system(size: 9))
                        Text("재시도 \(store.failedCount)")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }

            if store.completedCount > 0 {
                Button {
                    store.send(.clearCompleted)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text("완료 \(store.completedCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                let outputDir = UserDefaults.standard.string(forKey: Constants.settingsSaveKey)
                    .flatMap { try? JSONDecoder().decode(Settings.self, from: Data($0.utf8)) }
                    .map { $0.outputDirectory } ?? Constants.defaultOutputDirectory
                NSWorkspace.shared.open(URL(fileURLWithPath: outputDir))
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("출력 폴더")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let toast = store.toastMessage {
                    toastBanner(toast)
                }

                ForEach(store.items.reversed()) { item in
                    DownloadRow(item: item, store: store)
                    if item.id != store.items.reversed().last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func toastBanner(_ toast: ToastMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: toast.type == .success
                ? "checkmark.circle.fill"
                : toast.type == .error
                ? "exclamationmark.triangle.fill"
                : "arrow.clockwise"
            )
            .foregroundStyle(toast.type == .success
                ? .green
                : toast.type == .error
                ? .red
                : .blue
            )
            .font(.system(size: 11))

            Text(toast.message)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.send(.dismissToast)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(toast.type == .error ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    let store: StoreOf<DownloadQueueReducer>
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                AsyncImage(url: URL(string: item.videoInfo.thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay(
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            )
                    case .empty:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay(ProgressView().scaleEffect(0.3))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 48, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(item.status == .completed ? 0.5 : 1)

                if item.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14))
                } else {
                    statusIcon
                        .font(.system(size: 9))
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
                            .foregroundStyle(.green)
                    } else {
                        Text(item.optionsLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        if item.status == .downloading {
                            if !item.downloadSpeed.isEmpty {
                                Text(item.downloadSpeed)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(Int(item.progress * 100))%")
                                .font(.system(size: 10, design: .monospaced).weight(.semibold))
                                .foregroundStyle(.blue)
                            if !item.etaText.isEmpty {
                                Text(item.etaText)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        } else if item.status == .pending {
                            Text("대기 중")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if item.status == .paused {
                            Text("일시정지")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if item.status == .retrying {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.blue)
                                .font(.system(size: 10))
                            Text("재시도 \(item.retryCount)/\(store.maxRetries)...")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else if item.status == .failed {
                            Text("실패")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Button {
                store.send(.removeItem(item.id))
            } label: {
                Image(systemName: isHovering ? "trash.fill" : "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(isHovering ? .red : Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.4)
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
                        .fill(.blue.opacity(0.08))
                        .frame(width: (geo.size.width - 58) * max(0, min(1, item.progress)))
                        .offset(x: 58)
                        .animation(.linear(duration: 0.3), value: item.progress)
                } else if item.status == .completed {
                    Rectangle()
                        .fill(.green.opacity(0.06))
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
                .foregroundStyle(.blue)
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.tertiary)
        case .retrying:
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(.blue)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
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
                let baseGradient = Gradient(colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.9).opacity(0.35),
                    Color(red: 0.0, green: 0.6, blue: 0.8).opacity(0.25),
                    Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.35),
                ])
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
                context.stroke(linePath, with: .color(
                    Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.5)
                ), lineWidth: 1.5)
            }
        }
    }
}
