import SwiftUI
import AppKit

enum SettingsComponents {
    static func divider() -> some View {
        Divider()
            .padding(.leading, 8)
    }

    static func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    static func sectionSubHeader() -> some View {
        HStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 0.5)
                .padding(.leading, 8)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - SettingsRow

struct SettingsRow<Control: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let control: () -> Control

    init(title: String, description: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.description = description
        self.control = control
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                control()
            }

            if let description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preset Editor Sheet

struct PresetEditorSheet: View {
    let preset: DownloadPreset
    let onSave: (DownloadPreset) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var formatType: DownloadPreset.PresetFormatType
    @State private var resolution: Int
    @State private var includeSubtitles: Bool

    init(preset: DownloadPreset, onSave: @escaping (DownloadPreset) -> Void, onCancel: @escaping () -> Void) {
        self.preset = preset
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: preset.name)
        _formatType = State(initialValue: preset.formatType)
        _resolution = State(initialValue: preset.resolution)
        _includeSubtitles = State(initialValue: preset.includeSubtitles)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(preset.name.isEmpty ? "새 프리셋" : "프리셋 편집")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("취소") { onCancel() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            VStack(spacing: 0) {
                formRow(title: "이름") {
                    TextField("프리셋 이름", text: $name)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 180)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }

                Divider().padding(.leading, 8)

                formRow(title: "포맷") {
                    Picker("", selection: $formatType) {
                        ForEach(DownloadPreset.PresetFormatType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .font(.callout)
                }

                Divider().padding(.leading, 8)

                formRow(title: "해상도") {
                    Picker("", selection: $resolution) {
                        Text("4K (2160p)").tag(2160)
                        Text("2K (1440p)").tag(1440)
                        Text("1080p").tag(1080)
                        Text("720p").tag(720)
                        Text("480p").tag(480)
                        Text("360p").tag(360)
                    }
                    .pickerStyle(.menu)
                    .font(.callout)
                    .frame(width: 120)
                    .disabled(formatType == .audio)
                    .opacity(formatType == .audio ? 0.4 : 1)
                }

                Divider().padding(.leading, 8)

                formRow(title: "자막 포함") {
                    Toggle("", isOn: $includeSubtitles)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            HStack {
                Spacer()
                Button("취소") { onCancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)

                Button("저장") {
                    let preset = DownloadPreset(
                        id: preset.id,
                        name: name.trimmingCharacters(in: .whitespaces),
                        formatType: formatType,
                        resolution: formatType == .audio ? 0 : resolution,
                        includeSubtitles: includeSubtitles,
                        sponsorBlock: preset.sponsorBlock,
                        embedMetadata: preset.embedMetadata
                    )
                    onSave(preset)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360)
    }

    private func formRow<Control: View>(title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            control()
        }
        .padding(.vertical, 10)
    }
}
