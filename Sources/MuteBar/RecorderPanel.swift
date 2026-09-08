import AppKit
import Carbon.HIToolbox

/// Small panel that captures the next key combination as the global hotkey.
/// Esc or the Cancel button aborts without changing anything.
final class RecorderPanel: NSPanel {
    var onDone: ((Hotkey?) -> Void)?

    private var monitor: Any?
    private var finished = false
    private let hint = NSTextField(labelWithString: "")

    init(currentLabel: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 148),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Change Shortcut"
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        delegate = self

        let prompt = NSTextField(wrappingLabelWithString: "Press a key combination for the mute shortcut.")
        prompt.alignment = .center
        prompt.font = .systemFont(ofSize: 13, weight: .medium)

        hint.alignment = .center
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.stringValue = "Current: \(currentLabel)  ·  letters need ⌘/⌥/⌃  ·  Esc to cancel"

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.bezelStyle = .rounded

        let stack = NSStackView(views: [prompt, hint, cancel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView!.centerYAnchor),
        ])

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    override var canBecomeKey: Bool { true }

    @objc private func cancel(_ sender: Any?) {
        finish(nil)
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            finish(nil)
            return nil
        }
        let keyCode = UInt32(event.keyCode)
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let candidate = Hotkey(keyCode: keyCode, modifiers: modifiers)
        if candidate.isValid {
            finish(candidate)
        } else {
            hint.stringValue = "Add ⌘, ⌥ or ⌃ (or use an F-key) — that combo would swallow normal typing"
        }
        return nil
    }

    private func finish(_ result: Hotkey?) {
        guard !finished else { return }
        finished = true
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        let callback = onDone
        onDone = nil
        orderOut(nil)
        callback?(result)
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}

extension RecorderPanel: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finish(nil)
        return false
    }
}
