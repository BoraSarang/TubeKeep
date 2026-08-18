import SwiftUI
import AppKit
import ComposableArchitecture

struct SettingsView: View {
    @ObservedObject var store: StoreOf<SettingsReducer>
    @State private var editingPreset: DownloadPreset?

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.setSelectedTab($0)) }
        )) {
            tabView(.downloads) {
                SettingsDownloadsTab(store: store, editingPreset: $editingPreset)
            }
            tabView(.channels) {
                SettingsChannelsTab(store: store)
            }
            tabView(.automation) {
                SettingsAutomationTab(store: store)
            }
            tabView(.ai) {
                SettingsAITab(store: store)
            }
            tabView(.storage) {
                SettingsStorageTab(store: store)
            }
            tabView(.notifications) {
                SettingsNotificationsTab(store: store)
            }
            tabView(.shortcuts) {
                SettingsShortcutsTab(store: store)
            }
            tabView(.general) {
                SettingsSystemTab(store: store)
            }
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: 640, minHeight: 440)
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

    private func tabView<Content: View>(_ tab: SettingsTab, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .tabItem {
            Label(tab.rawValue, systemImage: tab.icon)
        }
        .tag(tab)
    }
}