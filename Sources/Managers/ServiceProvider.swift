import AppKit

/// Receives selected text from the macOS Services menu ("ask right here"
/// in any app's right-click menu) and opens the ask dialog with it.
@MainActor
class ServiceProvider: NSObject {
    var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    @objc func handleService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let items = pboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
              let selectedText = items.first else { return }
        appState.showAskDialog(with: selectedText)
    }
}
