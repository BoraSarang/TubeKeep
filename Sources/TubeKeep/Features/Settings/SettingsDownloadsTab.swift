import SwiftUI
import ComposableArchitecture

struct SettingsDownloadsTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "동시 다운로드", description: "동시에 처리할 다운로드 개수") {
                Stepper(
                    "\(store.concurrentDownloads)개",
                    value: Binding(
                        get: { store.concurrentDownloads },
                        set: { store.send(.setConcurrentDownloads($0)) }
                    ),
                    in: Constants.minConcurrentDownloads...Constants.maxConcurrentDownloads
                )
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "속도 제한", description: "0 = 무제한") {
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
                    .font(.callout)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    Text("MB/s")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
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

            SettingsRow(title: "자동 재시도", description: "실패 시 자동 재시도 횟수") {
                Stepper(
                    "\(store.maxRetries)회",
                    value: Binding(
                        get: { store.maxRetries },
                        set: { store.send(.setMaxRetries($0)) }
                    ),
                    in: 0...10
                )
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "업로드 확인 개수") {
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
                    .font(.callout)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("개")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
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

            SettingsRow(title: "순번 실패 시 생략", description: "실패해도 다음 항목 계속 진행") {
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

            SettingsComponents.divider()

            SettingsRow(title: "기본 해상도", description: "다운로드 기본 해상도") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.defaultResolution },
                        set: { store.send(.setDefaultResolution($0)) }
                    )
                ) {
                    Text("4K").tag(2160)
                    Text("2K").tag(1440)
                    Text("1080p").tag(1080)
                    Text("720p").tag(720)
                    Text("480p").tag(480)
                    Text("360p").tag(360)
                    Text("240p").tag(240)
                    Text("144p").tag(144)
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()

            SettingsRow(title: "SponsorBlock", description: "다운로드 시 스폰서/인트로/아웃트로 자동 제거") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.sponsorBlock },
                        set: { _ in store.send(.toggleSponsorBlock) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "메타데이터 임베딩", description: "파일에 제목/채널/섬네일 정보를 자동으로 포함") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.embedMetadata },
                        set: { _ in store.send(.toggleEmbedMetadata) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsComponents.divider()

            SettingsRow(title: "자막 언어", description: "자막 다운로드 언어 (override)") {
                Picker(
                    "",
                    selection: Binding(
                        get: { store.subtitleLanguageOverride },
                        set: { store.send(.setSubtitleLanguageOverride($0)) }
                    )
                ) {
                    Text("자동 (시스템 언어)").tag("")
                    Text("한국어").tag("ko")
                    Text("영어").tag("en")
                    Text("일본어").tag("ja")
                }
                .pickerStyle(.menu)
                .font(.callout)
                .fixedSize()
            }

            SettingsComponents.divider()
        }
    }
}