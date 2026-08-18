import SwiftUI
import ComposableArchitecture

struct SettingsStorageTab: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var showClearConfirm = false

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
                        .fill(AppColors.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.separator, lineWidth: 0.5)
                )
            }

            SettingsComponents.divider()

            SettingsComponents.sectionSubHeader()

            SettingsComponents.sectionHeader(
                title: "데이터 초기화",
                subtitle: "생성된 AI 파생 데이터를 삭제합니다"
            )

            SettingsComponents.divider()

            SettingsRow(title: "AI 파생 데이터 초기화", description: "요약·챕터·태그·마인드맵·자막큐·팟캐스트·질문답을 모두 삭제하고, 팟캐스트 파일도 제거합니다. 이후 자막부터 다시 생성됩니다") {
                Button("초기화") { showClearConfirm = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
            }

            SettingsComponents.divider()
        }
        .alert("AI 파생 데이터 초기화", isPresented: $showClearConfirm) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) { store.send(.clearDerivedAIData) }
        } message: {
            Text("요약·챕터·태그·마인드맵·자막큐·팟캐스트·질문답과 팟캐스트 파일이 삭제됩니다. 되돌릴 수 없습니다.")
        }
        .alert("초기화 완료", isPresented: Binding(
            get: { store.clearReport != nil },
            set: { if !$0 { store.send(.dismissClearReport) } }
        )) {
            Button("확인", role: .cancel) { store.send(.dismissClearReport) }
        } message: {
            Text(store.clearReport?.message ?? "")
        }
    }
}
