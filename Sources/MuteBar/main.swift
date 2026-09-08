import AppKit
import Carbon.HIToolbox
import ServiceManagement

struct HotkeyPreset {
    let label: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let presets: [HotkeyPreset] = [
        .init(label: "F6", keyCode: UInt32(kVK_F6), modifiers: 0),
        .init(label: "F7", keyCode: UInt32(kVK_F7), modifiers: 0),
        .init(label: "F8", keyCode: UInt32(kVK_F8), modifiers: 0),
        .init(label: "F5", keyCode: UInt32(kVK_F5), modifiers: 0),
        .init(label: "⌘⇧M", keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey)),
        .init(label: "⌃⌥M", keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(controlKey | optionKey)),
    ]
}

enum AppState {
    case noMeeting
    case live
    case muted

    var symbol: String {
        switch self {
        case .noMeeting: return "mic"
        case .live: return "mic.fill"
        case .muted: return "mic.slash.fill"
        }
    }

    var title: String {
        switch self {
        case .noMeeting: return "No active meeting"
        case .live: return "Mic on"
        case .muted: return "Muted"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var state: AppState = .noMeeting
    private var browserConnected = false
    // fd -> latest state per browser connection; any in-meeting browser wins
    private var connStates: [Int32: (inMeeting: Bool, muted: Bool)] = [:]

    private var hotkey: HotkeyPreset {
        get {
            let code = UserDefaults.standard.integer(forKey: "hotkeyCode")
            let mods = UserDefaults.standard.integer(forKey: "hotkeyMods")
            return HotkeyPreset.presets.first { Int($0.keyCode) == code && Int($0.modifiers) == mods }
                ?? HotkeyPreset.presets[0]
        }
        set {
            UserDefaults.standard.set(Int(newValue.keyCode), forKey: "hotkeyCode")
            UserDefaults.standard.set(Int(newValue.modifiers), forKey: "hotkeyMods")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)
        statusItem = item
        rebuildMenu()

        HotKeyCenter.action = { [weak self] in self?.toggleMute() }
        applyHotkey()

        SocketServer.shared.onMessage = { [weak self] fd, json in
            DispatchQueue.main.async {
                guard let self, let type = json["type"] as? String else { return }
                if type == "state" {
                    let inMeeting = json["inMeeting"] as? Bool ?? false
                    let muted = json["muted"] as? Bool ?? false
                    self.connStates[fd] = (inMeeting, muted)
                    self.recomputeState()
                }
            }
        }
        SocketServer.shared.onClientChange = { [weak self] count in
            DispatchQueue.main.async {
                guard let self else { return }
                self.browserConnected = count > 0
                // drop states from closed connections
                let live = Set(SocketServer.shared.clientFDs)
                self.connStates = self.connStates.filter { live.contains($0.key) }
                self.recomputeState()
                self.rebuildMenu()
            }
        }
        SocketServer.shared.start()
    }

    private func recomputeState() {
        let inMeeting = connStates.values.filter { $0.inMeeting }
        if let s = inMeeting.last {
            setState(s.muted ? .muted : .live)
        } else {
            setState(.noMeeting)
        }
    }

    // MARK: - Actions

    private func toggleMute() {
        SocketServer.shared.broadcast(["type": "toggle"])
    }

    private func applyHotkey() {
        HotKeyCenter.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
    }

    @objc private func selectHotkey(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? HotkeyPreset else { return }
        hotkey = preset
        applyHotkey()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MuteBar: login item toggle failed: \(error)")
        }
        rebuildMenu()
    }

    // MARK: - UI state

    private func setState(_ newState: AppState) {
        guard newState != state else { return }
        state = newState
        statusItem.button?.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)
        statusItem.button?.contentTintColor = (state == .muted) ? .systemRed : nil
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusLine = NSMenuItem(title: state.title, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let connLine = NSMenuItem(
            title: browserConnected ? "Browser: connected" : "Browser: not connected",
            action: nil, keyEquivalent: ""
        )
        connLine.isEnabled = false
        menu.addItem(connLine)

        menu.addItem(.separator())
        let toggle = NSMenuItem(title: "Toggle mute (\(hotkey.label))", action: #selector(toggleMuteMenu), keyEquivalent: "")
        menu.addItem(toggle)

        let shortcutMenu = NSMenu(title: "Mute shortcut")
        for preset in HotkeyPreset.presets {
            let item = NSMenuItem(
                title: preset.label, action: #selector(selectHotkey(_:)), keyEquivalent: ""
            )
            item.representedObject = preset
            item.state = (preset.keyCode == hotkey.keyCode && preset.modifiers == hotkey.modifiers) ? .on : .off
            shortcutMenu.addItem(item)
        }
        let shortcutItem = NSMenuItem(title: "Mute shortcut", action: nil, keyEquivalent: "")
        shortcutItem.submenu = shortcutMenu
        menu.addItem(shortcutItem)

        let loginItem = NSMenuItem(
            title: "Start at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: ""
        )
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MuteBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleMuteMenu() { toggleMute() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
