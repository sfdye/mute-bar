import AppKit
import Carbon.HIToolbox
import ServiceManagement

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

    private var hotkey: Hotkey {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "hotkeyCode") != nil else { return .default }
            return Hotkey(
                keyCode: UInt32(defaults.integer(forKey: "hotkeyCode")),
                modifiers: UInt32(defaults.integer(forKey: "hotkeyMods"))
            )
        }
        set {
            UserDefaults.standard.set(Int(newValue.keyCode), forKey: "hotkeyCode")
            UserDefaults.standard.set(Int(newValue.modifiers), forKey: "hotkeyMods")
        }
    }

    private var recorder: RecorderPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.image = statusImage()
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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SocketServer.shared.stop()
        return .terminateNow
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
        if !HotKeyCenter.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers) {
            NSLog("MuteBar: hotkey registration failed for \(hotkey.label)")
        }
    }

    @objc private func changeHotkey() {
        HotKeyCenter.unregister() // don't trigger the old shortcut while recording
        NSApp.activate(ignoringOtherApps: true)
        let panel = RecorderPanel(currentLabel: hotkey.label)
        panel.onDone = { [weak self, weak panel] result in
            guard let self else { return }
            if let result {
                if HotKeyCenter.register(keyCode: result.keyCode, modifiers: result.modifiers) {
                    self.hotkey = result
                } else {
                    // registration failed (system conflict) — keep the old shortcut
                    let alert = NSAlert()
                    alert.messageText = "\"\(result.label)\" is not available"
                    alert.informativeText = "It conflicts with an existing system shortcut. Please pick another."
                    alert.runModal()
                    self.applyHotkey()
                }
            } else {
                self.applyHotkey()
            }
            self.rebuildMenu()
            self.recorder = nil
        }
        recorder = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
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
        statusItem.button?.image = statusImage()
        rebuildMenu()
    }

    /// Template monochrome icon: blends with the menubar and adapts to
    /// light/dark mode automatically. Sized relative to the system status
    /// bar thickness (not a fixed point size) so it stays correct on both
    /// standard and tall/notched menu bars; the cell clamps it if needed.
    private func statusImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(
            pointSize: NSStatusBar.system.thickness * 0.66, weight: .medium
        )
        let image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
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

        let shortcutLine = NSMenuItem(
            title: "Mute shortcut: \(hotkey.label)", action: nil, keyEquivalent: ""
        )
        shortcutLine.isEnabled = false
        menu.addItem(shortcutLine)
        menu.addItem(NSMenuItem(
            title: "Change Shortcut…", action: #selector(changeHotkey), keyEquivalent: ""
        ))

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
