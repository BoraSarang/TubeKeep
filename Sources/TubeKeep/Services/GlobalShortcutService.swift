import Carbon
import AppKit

enum GlobalShortcutAction: String, CaseIterable, Identifiable {
    case openDownloader = "영상 다운로더"
    case openBatchDownloader = "일괄 다운로더"
    case openChannelDownloader = "채널 다운로더"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .openDownloader: return "arrow.down.circle"
        case .openBatchDownloader: return "rectangle.stack"
        case .openChannelDownloader: return "tv"
        }
    }

    var notification: Notification.Name {
        switch self {
        case .openDownloader: return Constants.openDownloaderWindowNotification
        case .openBatchDownloader: return Constants.openBatchWindowNotification
        case .openChannelDownloader: return Constants.openChannelWindowNotification
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .openDownloader: return 1
        case .openBatchDownloader: return 2
        case .openChannelDownloader: return 3
        }
    }
}

struct HotKeyBinding: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    var isEnabled: Bool = true

    var display: String {
        let mods = GlobalShortcutService.modifierString(modifiers)
        let key = GlobalShortcutService.stringFromKeyCode(keyCode) ?? "?"
        return mods + key
    }
}

@MainActor
final class GlobalShortcutService {
    static let shared = GlobalShortcutService()

    static let didChangeNotification = Notification.Name("GlobalShortcutsDidChange")

    private let storageKey = "globalShortcuts"
    private var hotKeyRefs: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private var eventHandlerInstalled = false
    private var actionMap: [UInt32: GlobalShortcutAction] = [:]

    func start() {
        installEventHandler()
        let bindings = loadBindings()
        for action in GlobalShortcutAction.allCases {
            if let binding = bindings[action] {
                register(action: action, binding: binding)
            }
        }
    }

    func loadBindings() -> [GlobalShortcutAction: HotKeyBinding] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([String: HotKeyBinding].self, from: data)
        else { return [:] }
        var result: [GlobalShortcutAction: HotKeyBinding] = [:]
        for (key, value) in dict {
            if let action = GlobalShortcutAction(rawValue: key) {
                result[action] = value
            }
        }
        return result
    }

    func binding(for action: GlobalShortcutAction) -> HotKeyBinding? {
        loadBindings()[action]
    }

    func menuKeyEquivalent(for binding: HotKeyBinding) -> (key: String, modifiers: NSEvent.ModifierFlags) {
        let key = GlobalShortcutService.stringFromKeyCode(binding.keyCode)?.lowercased() ?? ""
        var flags: NSEvent.ModifierFlags = []
        if binding.modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if binding.modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if binding.modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if binding.modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return (key, flags)
    }

    func saveBinding(_ action: GlobalShortcutAction, _ binding: HotKeyBinding) {
        var dict: [String: HotKeyBinding] = [:]
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let d = try? JSONDecoder().decode([String: HotKeyBinding].self, from: data) {
            dict = d
        }
        dict[action.rawValue] = binding
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        register(action: action, binding: binding)
        NotificationCenter.default.post(name: GlobalShortcutService.didChangeNotification, object: nil)
    }

    func clearBinding(_ action: GlobalShortcutAction) {
        unregister(action: action)
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var dict = try? JSONDecoder().decode([String: HotKeyBinding].self, from: data)
        else { return }
        dict.removeValue(forKey: action.rawValue)
        if let newData = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(newData, forKey: storageKey)
        }
        NotificationCenter.default.post(name: GlobalShortcutService.didChangeNotification, object: nil)
    }

    // MARK: - Carbon HotKey

    private func installEventHandler() {
        guard !eventHandlerInstalled else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let action = GlobalShortcutService.shared.actionMap[hotKeyID.id]
            if let action {
                NotificationCenter.default.post(name: action.notification, object: nil)
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, &handlerRef)
        eventHandlerInstalled = true
    }

    private func register(action: GlobalShortcutAction, binding: HotKeyBinding) {
        unregister(action: action)
        guard binding.isEnabled, binding.keyCode > 0 else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x5455_4B50), id: action.hotKeyID)
        actionMap[action.hotKeyID] = action
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs[action] = ref
        }
    }

    private func unregister(action: GlobalShortcutAction) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
    }

    // MARK: - Key conversion helpers

    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    nonisolated static func modifierString(_ modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    nonisolated static func stringFromKeyCode(_ keyCode: UInt32) -> String? {
        guard keyCode <= 127,
              let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        guard let bytePtr = CFDataGetBytePtr(dataRef) else { return nil }
        let layout = unsafeBitCast(bytePtr, to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return nil }
        let result = String(utf16CodeUnits: chars, count: length).uppercased()
        return result.isEmpty ? "\(keyCode)" : result
    }
}
