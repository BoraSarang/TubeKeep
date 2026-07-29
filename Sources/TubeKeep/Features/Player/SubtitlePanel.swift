import SwiftUI

struct SubtitlePanel: View {
    let cues: [SubtitleCue]
    let currentTime: Double
    let isLoading: Bool
    let subtitleAvailable: Bool?
    let errorMessage: String?
    let isTranscribing: Bool
    let transcribeError: String?
    let whisperProgressMessage: String?
    let onSeek: (Double) -> Void
    let onDownloadSubtitles: (() -> Void)?
    let onTranscribe: (() -> Void)?
    let onDeleteSubtitles: (() -> Void)?
    let onOpenWhisperSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if isTranscribing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(whisperProgressMessage ?? errorMessage ?? "자막 생성 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("자막 확인 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = transcribeError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    if let onOpenWhisperSettings {
                        Button("Settings 열기") {
                            onOpenWhisperSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cues.isEmpty, let available = subtitleAvailable {
                if available {
                    VStack(spacing: 8) {
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("자막이 있습니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if let onDownloadSubtitles {
                                Button("자막 다운로드") {
                                    onDownloadSubtitles()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            if let onTranscribe {
                                Button("Whisper로 자막 생성") {
                                    onTranscribe()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("자막이 없습니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let onTranscribe {
                            Button("Whisper로 자막 생성") {
                                onTranscribe()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if cues.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("자막이 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let onTranscribe {
                        Button("Whisper로 자막 생성") {
                            onTranscribe()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        if onTranscribe != nil || onDeleteSubtitles != nil {
                            Menu("자막 관리") {
                                if let onTranscribe {
                                    Button("Whisper로 자막 재생성") { onTranscribe() }
                                }
                                if let onDeleteSubtitles {
                                    Button("등록된 자막 삭제", role: .destructive) { onDeleteSubtitles() }
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                    ScrollViewReader { proxy in
                        List(Array(cues.enumerated()), id: \.element.id) { index, cue in
                            let isActive = cue.startTime <= currentTime && cue.endTime >= currentTime
                            Button {
                                onSeek(cue.startTime)
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(formatTime(cue.startTime))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                                        .frame(width: 44, alignment: .trailing)
                                    Text(cue.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(isActive ? .primary : .secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .id(cue.id)
                        }
                        .listStyle(.plain)
                        .onChange(of: currentTime) { _, _ in
                            if let activeCue = cues.first(where: { $0.startTime <= currentTime && $0.endTime >= currentTime }) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    proxy.scrollTo(activeCue.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
