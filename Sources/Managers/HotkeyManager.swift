import AppKit
import Carbon.HIToolbox

/// Global shortcut: hold both Option keys and press R — with no
/// Accessibility permission required.
///
/// Carbon's RegisterEventHotKey can't tell left Option from right Option,
/// and a global keyDown monitor (which can) needs Accessibility access.
/// The workaround: modifier changes (flagsChanged) are observable without
/// any permission, so this watches the two Option keys and only while BOTH
/// are held registers a Carbon hotkey for ⌥R. Release either Option and the
/// hotkey is gone — ⌥R keeps typing "®" everywhere, and the app never sees
/// the keystroke stream.
@MainActor
final class HotkeyManager {

    /// Device-dependent modifier bits from IOKit's hidsystem
    /// (NX_DEVICELALTKEYMASK / NX_DEVICERALTKEYMASK) — the only way to
    /// distinguish the two Option keys in an NSEvent.
    private static let leftOptionBit: UInt = 0x20
    private static let rightOptionBit: UInt = 0x40

    private let onTrigger: () -> Void
    private var monitors: [Any] = []
    private var hotKeyRefR: EventHotKeyRef?
    private var hotKeyRefO: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(onTrigger: @escaping @MainActor () -> Void) {
        self.onTrigger = onTrigger
        installCarbonHandler()

        // The global monitor sees other apps' modifier changes; the local
        // one covers the case where this app is frontmost.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { event in
            MainActor.assumeIsolated { Self.shared?.optionStateChanged(event) }
        }) {
            monitors.append(monitor)
        }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            MainActor.assumeIsolated { Self.shared?.optionStateChanged(event) }
            return event
        }) {
            monitors.append(monitor)
        }

        Self.shared = self
    }

    // The app keeps a single manager for its whole lifetime; a static
    // reference lets the @Sendable monitor closures reach it without
    // capturing non-Sendable state.
    private static weak var shared: HotkeyManager?

    private func optionStateChanged(_ event: NSEvent) {
        let raw = event.modifierFlags.rawValue
        let bothOptionsHeld = raw & Self.leftOptionBit != 0 && raw & Self.rightOptionBit != 0
        bothOptionsHeld ? registerHotkey() : unregisterHotkey()
    }

    /// Active only while both Option keys are down.
    private func registerHotkey() {
        if hotKeyRefR == nil {
            let id = EventHotKeyID(signature: OSType(0x5248_4552), id: 1)  // 'RHER'
            RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(optionKey), id,
                                GetApplicationEventTarget(), 0, &hotKeyRefR)
        }
        if hotKeyRefO == nil {
            let id = EventHotKeyID(signature: OSType(0x5248_4552), id: 2)  // 'RHER'
            RegisterEventHotKey(UInt32(kVK_ANSI_O), UInt32(optionKey), id,
                                GetApplicationEventTarget(), 0, &hotKeyRefO)
        }
    }

    private func unregisterHotkey() {
        if let ref = hotKeyRefR {
            UnregisterEventHotKey(ref)
            hotKeyRefR = nil
        }
        if let ref = hotKeyRefO {
            UnregisterEventHotKey(ref)
            hotKeyRefO = nil
        }
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers app-target events on the main run loop.
            MainActor.assumeIsolated { manager.onTrigger() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)
    }
}
