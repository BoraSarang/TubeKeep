import Foundation
import AppKit
import ComposableArchitecture

@Reducer
struct LibraryReducer {
    @ObservableState
    struct State: Equatable {
        var items: [LibraryItem] = []
        var searchText = ""
        var selectedChannel: String? = nil
        var sortOrder: LibrarySortOrder = .dateDesc
        var filterMode: LibraryFilterMode = .all
        var viewMode: LibraryViewMode = .grid
        var isLoading = false

        init() {
            let saved = UserDefaults.standard.string(forKey: Constants.libraryViewModeKey) ?? "grid"
            viewMode = LibraryViewMode(rawValue: saved) ?? .grid
        }

        var filteredItems: [LibraryItem] {
            var result = items

            if filterMode == .recent {
                let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                result = result.filter { $0.downloadDate >= cutoff }
            }

            if let channelId = selectedChannel {
                result = result.filter { $0.channelId == channelId }
            }

            if !searchText.isEmpty {
                result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            }

            switch sortOrder {
            case .dateDesc:
                result.sort { $0.downloadDate > $1.downloadDate }
            case .dateAsc:
                result.sort { $0.downloadDate < $1.downloadDate }
            case .titleAsc:
                result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            case .channelAsc:
                result.sort { $0.channelName.localizedCompare($1.channelName) == .orderedAscending }
            }

            return result
        }
    }

    enum Action: Equatable {
        case loadFromDisk
        case itemsLoaded([LibraryItem])
        case addItem(LibraryItem)
        case removeItem(String)
        case setSearchText(String)
        case setSelectedChannel(String?)
        case setSortOrder(LibrarySortOrder)
        case setFilterMode(LibraryFilterMode)
        case setViewMode(LibraryViewMode)
        case openFile(String)
        case revealInFinder(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadFromDisk:
                return .run { send in
                    let items = await LibraryCacheService.shared.loadItems()
                    await send(.itemsLoaded(items))
                }

            case .itemsLoaded(let items):
                state.items = items
                return .none

            case .addItem(let item):
                state.items.insert(item, at: 0)
                return .run { _ in
                    await LibraryCacheService.shared.addItem(item)
                }

            case .removeItem(let id):
                state.items.removeAll { $0.id == id }
                return .run { _ in
                    await LibraryCacheService.shared.removeItem(id: id)
                }

            case .setSearchText(let text):
                state.searchText = text
                return .none

            case .setSelectedChannel(let channelId):
                state.selectedChannel = channelId
                return .none

            case .setSortOrder(let order):
                state.sortOrder = order
                return .none

            case .setViewMode(let mode):
                state.viewMode = mode
                return .run { _ in
                    UserDefaults.standard.set(mode.rawValue, forKey: Constants.libraryViewModeKey)
                }

            case .setFilterMode(let mode):
                state.filterMode = mode
                return .none

            case .openFile(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let url = URL(fileURLWithPath: item.filePath)
                NSWorkspace.shared.open(url)
                return .none

            case .revealInFinder(let id):
                guard let item = state.items.first(where: { $0.id == id }) else { return .none }
                let url = URL(fileURLWithPath: item.filePath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return .none
            }
        }
    }
}
