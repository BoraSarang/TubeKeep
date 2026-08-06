import SwiftUI
import ComposableArchitecture

struct SettingsStorageTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            SettingsComponents.sectionHeader(
                title: "저장 위치",
                subtitle: "다운로드 파일이 저장되는 폴더와 이름 규칙을 설정합니다"
            )

            SettingsComponents.divider()

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
        }
    }
}
