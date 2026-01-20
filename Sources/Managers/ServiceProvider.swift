import AppKit

@MainActor
class ServiceProvider: NSObject {
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        print("[DEBUG] ServiceProvider initialized")
    }
    
    @objc func handleService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        print("[DEBUG] Service handling triggered")
        if let items = pboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let selectedText = items.first {
            print("[DEBUG] Service received text: \(selectedText)")
            self.appState.showAskDialog(with: selectedText)
        } else {
            print("[DEBUG] Service triggered but no text found in pasteboard")
        }
    }
}
