import AppKit

/// Global shortcut: hold both Option keys and press R.
///
/// Carbon hotkeys and the usual shortcut libraries can't tell left Option
/// from right Option, so this watches raw key events instead. Global key
/// monitoring only delivers events once the app has been granted
/// Accessibility access (System Settings → Privacy & Security → Accessibility);
/// the system prompt for it is triggered on first launch.
final class HotkeyManager {

    /// Device-dependent modifier bits from IOKit's hidsystem
    /// (NX_DEVICELALTKEYMASK / NX_DEVICERALTKEYMASK) — the only way to
    /// distinguish the two Option keys in an NSEvent.
    private static let leftOptionBit: UInt = 0x20
    private static let rightOptionBit: UInt = 0x40
    private static let rKeyCode: UInt16 = 15  // kVK_ANSI_R

    private var monitors: [Any] = []

    init(onTrigger: @escaping @MainActor () -> Void) {
        promptForAccessibilityIfNeeded()

        // Global monitor fires when another app has focus; the local one
        // covers the case where this app is frontmost.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            guard Self.isChord(event) else { return }
            Task { @MainActor in onTrigger() }
        }) {
            monitors.append(monitor)
        }

        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard Self.isChord(event) else { return event }
            Task { @MainActor in onTrigger() }
            return nil
        }) {
            monitors.append(monitor)
        }
    }

    private static func isChord(_ event: NSEvent) -> Bool {
        let raw = event.modifierFlags.rawValue
        return event.keyCode == rKeyCode
            && raw & leftOptionBit != 0
            && raw & rightOptionBit != 0
            && event.modifierFlags.intersection([.command, .control, .shift]).isEmpty
    }

    private func promptForAccessibilityIfNeeded() {
        // Literal key for kAXTrustedCheckOptionPrompt — the extern CFStringRef
        // is a `var` to Swift and gets rejected under strict concurrency.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
