import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            Button {
                store.send(.toggleExpanded)
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                    Text("설정")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: store.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if store.isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, -16)

                    // MARK: 다운로드
                    sectionHeader("다운로드")

                    settingRow(label: "동시 다운로드") {
                        Stepper(
                            "\(store.concurrentDownloads)개",
                            value: Binding(
                                get: { store.concurrentDownloads },
                                set: { store.send(.setConcurrentDownloads($0)) }
                            ),
                            in: Constants.minConcurrentDownloads...Constants.maxConcurrentDownloads
                        )
                        .font(.caption)
                    }

                    settingRow(label: "속도 제한") {
                        HStack(spacing: 4) {
                            TextField(
                                "0",
                                value: Binding(
                                    get: { store.limitRate },
                                    set: { store.send(.setLimitRate($0)) }
                                ),
                                format: .number
                            )
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 36)
                            .multilineTextAlignment(.trailing)
                            Text("MB/s")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }

                    settingRow(label: "자동 재시도") {
                        Stepper(
                            "\(store.maxRetries)회",
                            value: Binding(
                                get: { store.maxRetries },
                                set: { store.send(.setMaxRetries($0)) }
                            ),
                            in: 0...10
                        )
                        .font(.caption)
                    }

                    settingRow(label: "업로드 확인 개수") {
                        HStack(spacing: 4) {
                            TextField(
                                "500",
                                value: Binding(
                                    get: { store.maxUploadCheck },
                                    set: { store.send(.setMaxUploadCheck($0)) }
                                ),
                                format: .number
                            )
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                            Text("개")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }

                    settingRow(label: "순번 실패 시 생략") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.skipIndexOnFailure },
                                set: { _ in store.send(.toggleSkipIndexOnFailure) }
                            )
                        )
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingRow(label: "기본 해상도") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { store.defaultResolution },
                                set: { store.send(.setDefaultResolution($0)) }
                            )
                        ) {
                            Text("144p").tag(144)
                            Text("240p").tag(240)
                            Text("360p").tag(360)
                            Text("480p").tag(480)
                            Text("720p").tag(720)
                            Text("1080p").tag(1080)
                            Text("2K").tag(1440)
                            Text("4K").tag(2160)
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                    }

                    // MARK: 출력
                    sectionHeader("출력")

                    settingRow(label: "출력 폴더") {
                        Button(store.outputDirectory) {
                            store.send(.selectOutputDirectory)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.head)
                    }

                    settingRow(label: "파일명 템플릿") {
                        TextField(
                            "{channel} - {index} - {title}",
                            text: Binding(
                                get: { store.filenameTemplate },
                                set: { store.send(.setFilenameTemplate($0)) }
                            )
                        )
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
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

                    Text("지원: {channel} {index} {title} {date} {resolution} {id}")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.bottom, 4)

                    // MARK: 기타
                    sectionHeader("기타")

                    settingRow(label: "알림음") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.playSoundOnComplete },
                                set: { _ in store.send(.togglePlaySound) }
                            )
                        )
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    settingRow(label: "시작 시 실행") {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.launchAtLogin },
                                set: { _ in store.send(.toggleLaunchAtLogin) }
                            )
                        )
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func settingRow(label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            control()
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.leading, 8)
    }
}
