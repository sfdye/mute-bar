import AppKit
import Carbon.HIToolbox

enum HotKeyCenter {
    static let signature: OSType = 0x4D555445 // 'MUTE'
    private static var ref: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    static var action: () -> Void = {}

    static func register(keyCode: UInt32) {
        unregister()
        let id = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(keyCode, 0, id, GetEventDispatcherTarget(), 0, &ref)

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hk
            )
            if err == noErr && hk.signature == HotKeyCenter.signature {
                HotKeyCenter.action()
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    static func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
