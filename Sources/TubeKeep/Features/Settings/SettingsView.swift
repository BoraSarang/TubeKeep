import SwiftUI
import AppKit
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var editingPreset: DownloadPreset?

    var body: some View {
        HStack(spacing: 0) {
            tabSidebar

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    switch store.selectedTab {
                    case .downloads: SettingsDownloadsTab(store: store)
                    case .storage: SettingsStorageTab(store: store, editingPreset: $editingPreset)
                    case .notifications: SettingsNotificationsTab(store: store)
                    case .system: SettingsSystemTab(store: store)
                    case .ai: SettingsAITab(store: store)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorSheet(
                preset: preset,
                onSave: { saved in
                    if preset.name.isEmpty {
                        store.send(.addPreset(saved))
                    } else {
                        store.send(.updatePreset(saved))
                    }
                    editingPreset = nil
                },
                onCancel: {
                    editingPreset = nil
                }
            )
        }
    }

    // MARK: - Tab Sidebar

    private var tabSidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
        }
        .frame(width: 140)
        .padding(.vertical, 12)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let selected = store.selectedTab == tab
        return Button {
            store.send(.setSelectedTab(tab))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}