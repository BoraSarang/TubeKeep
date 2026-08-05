import SwiftUI
import ComposableArchitecture

struct SettingsStorageTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @Binding var editingPreset: DownloadPreset?

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "저장 폴더", description: "다운로드 파일 저장 폴더") {
                Button(store.storageDirectory) {
                    store.send(.selectStorageDirectory)
                }
                .buttonStyle(.plain)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 200, alignment: .trailing)
            }

            SettingsComponents.divider()

            SettingsRow(title: "파일명 템플릿", description: "지원: {channel} {index} {title} {date} {resolution} {id}") {
                TextField(
                    "{channel} - {index} - {title}",
                    text: Binding(
                        get: { store.filenameTemplate },
                        set: { store.send(.setFilenameTemplate($0)) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 200)
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

            SettingsComponents.divider()

            SettingsRow(title: "Smart Mode", description: "URL 입력 시 활성 프리셋으로 바로 다운로드 큐에 추가") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.smartMode },
                        set: { _ in store.send(.toggleSmartMode) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "활성 프리셋", description: "Smart Mode에서 사용할 다운로드 프리셋") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.activePresetId },
                        set: { store.send(.setActivePreset($0)) }
                    )
                ) {
                    Text("사용 안 함").tag(nil as UUID?)
                    ForEach(store.presets) { preset in
                        Text(preset.name).tag(preset.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
                .disabled(!store.smartMode)
                .opacity(store.smartMode ? 1 : 0.4)
            }

            if !store.presets.isEmpty {
                SettingsComponents.divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(store.presets.enumerated()), id: \.offset) { _, preset in
                        HStack {
                            Text(preset.name)
                                .font(.callout)
                            Spacer()
                            Text("\(preset.formatType.rawValue) · \(preset.resolution > 0 ? "\(preset.resolution)p" : "오디오")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("편집") {
                                editingPreset = preset
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            Button("삭제") {
                                store.send(.deletePreset(preset.id))
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.leading, 20)
            }

            SettingsComponents.divider()

            Button("프리셋 추가") {
                editingPreset = DownloadPreset(id: UUID(), name: "", formatType: .video, resolution: 1080, includeSubtitles: false, sponsorBlock: false, embedMetadata: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.top, 6)
            .padding(.leading, 20)
        }
    }
}