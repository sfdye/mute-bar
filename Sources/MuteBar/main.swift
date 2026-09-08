import AppKit
import Carbon.HIToolbox

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: state.title)
        statusItem = item
        rebuildMenu()

        HotKeyCenter.action = { [weak self] in self?.toggleMute() }
        HotKeyCenter.register(keyCode: UInt32(kVK_F6))

        SocketServer.shared.onMessage = { [weak self] _, json in
            DispatchQueue.main.async {
                guard let type = json["type"] as? String else { return }
                if type == "state" {
                    let inMeeting = json["inMeeting"] as? Bool ?? false
                    let muted = json["muted"] as? Bool ?? false
                    self?.setState(inMeeting ? (muted ? .muted : .live) : .noMeeting)
                }
            }
        }
        SocketServer.shared.onClientChange = { [weak self] count in
            DispatchQueue.main.async {
                self?.browserConnected = count > 0
                self?.rebuildMenu()
            }
        }
        SocketServer.shared.start()
    }

    private func toggleMute() {
        SocketServer.shared.broadcast(["type": "toggle"])
    }

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
        menu.addItem(NSMenuItem(title: "Toggle mute (F6)", action: #selector(toggleMuteMenu), keyEquivalent: ""))
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
