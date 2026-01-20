import SwiftUI
import KeyboardShortcuts

struct HistoryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    let timestamp: Date
    let question: String
    let answer: String
    let context: String
}

@main
struct RightHereApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            Text("right here")
                .font(.headline)
            
            Divider()
            
            Button("ask right here") {
                appState.showAskDialog()
            }
            .keyboardShortcut("a", modifiers: [.control, .option])
            
            Divider()
            
            if !appState.history.isEmpty {
                Menu("History") {
                    ForEach(appState.history.prefix(10)) { item in
                        Button(action: {
                            appState.showHistoryDetail(item)
                        }) {
                            Text(item.question)
                                .lineLimit(1)
                        }
                    }
                    
                    if appState.history.count > 10 {
                        Divider()
                        Button("View All History...") {
                            appState.showHistoryList()
                        }
                    }
                }
                
                Divider()
            }
            
            Button("Settings...") {
                appState.showSettings()
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text("r h")
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("history_json") private var historyJSON: String = "[]"
    
    @Published var selectedText: String = ""
    @Published var history: [HistoryItem] = []
    
    private var serviceProvider: ServiceProvider?
    private var askWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
    
    init() {
        loadHistory()
        setupHotkeys()
        setupServices()
    }
    
    private func loadHistory() {
        if let data = historyJSON.data(using: .utf8) {
            do {
                self.history = try JSONDecoder().decode([HistoryItem].self, from: data)
            } catch {
                print("[DEBUG] Failed to load history: \(error)")
                self.history = []
            }
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(self.history)
            if let jsonString = String(data: data, encoding: .utf8) {
                self.historyJSON = jsonString
            }
        } catch {
            print("[DEBUG] Failed to save history: \(error)")
        }
    }
    
    func addToHistory(question: String, answer: String, context: String) {
        let newItem = HistoryItem(timestamp: Date(), question: question, answer: answer, context: context)
        self.history.insert(newItem, at: 0)
        saveHistory()
    }
    
    func setupHotkeys() {
        KeyboardShortcuts.onKeyDown(for: .askRightHere) { [weak self] in
            Task { @MainActor in
                self?.showAskDialog()
            }
        }
    }
    
    func setupServices() {
        self.serviceProvider = ServiceProvider(appState: self)
        NSApp.servicesProvider = self.serviceProvider
        NSUpdateDynamicServices()
    }
    
    func showAskDialog(with initialText: String = "") {
        self.selectedText = initialText
        
        // Notify AskView to clear previous response/loader
        NotificationCenter.default.post(name: NSNotification.Name("ResetAskView"), object: nil)
        
        if askWindow == nil {
            let view = AskView(appState: self)
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
                styleMask: [.borderless, .titled, .fullSizeContentView], 
                backing: .buffered,
                defer: false
            )
            
            window.identifier = NSUserInterfaceItemIdentifier("ask-dialog")
            window.contentViewController = hostingController
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating
            window.center()
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            
            self.askWindow = window
        }
        
        askWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAskDialog() {
        askWindow?.orderOut(nil)
    }
    
    func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(appState: self)
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "right here Settings"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showHistoryList() {
        // Implementation for showing a separate window with all history
        showHistoryDetail(nil)
    }
    
    func showHistoryDetail(_ item: HistoryItem?) {
        if historyWindow == nil {
            let view = HistoryView(appState: self, selectedItem: item)
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "right here History"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            self.historyWindow = window
        } else {
            // Update the view if window is already open
            (historyWindow?.contentViewController as? NSHostingController<HistoryView>)?.rootView = HistoryView(appState: self, selectedItem: item)
        }
        
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension KeyboardShortcuts.Name {
    static let askRightHere = Self("askRightHere", default: .init(.a, modifiers: [.control, .option]))
}
