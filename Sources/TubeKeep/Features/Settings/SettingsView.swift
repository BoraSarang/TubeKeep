import SwiftUI
import AppKit
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var editingPreset: DownloadPreset?

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.setSelectedTab($0)) }
            )) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
            .navigationTitle("설정")
        } detail: {
            detailContent
        }
        .frame(minWidth: 760, minHeight: 480)
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

    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            switch store.selectedTab {
            case .downloads:
                SettingsDownloadsTab(store: store, editingPreset: $editingPreset)
            case .channels:
                SettingsChannelsTab(store: store)
            case .automation:
                SettingsAutomationTab(store: store)
            case .providers:
                SettingsProvidersTab(store: store)
            case .models:
                SettingsModelsTab(store: store)
            case .storage:
                SettingsStorageTab(store: store)
            case .notifications:
                SettingsNotificationsTab(store: store)
            case .shortcuts:
                SettingsShortcutsTab(store: store)
            case .general:
                SettingsSystemTab(store: store)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}