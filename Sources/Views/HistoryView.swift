import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State var selectedItem: HistoryItem?
    
    var body: some View {
        HSplitView {
            // Sidebar: List of items
            List(appState.history, selection: $selectedItem) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.question)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(item.timestamp, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .tag(item)
                .padding(.vertical, 4)
            }
            .frame(minWidth: 150, maxWidth: 250)
            
            // Detail View
            if let item = selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Question")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(item.question)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        if !item.context.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Context")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text(item.context)
                                    .font(.system(size: 12))
                                    .padding(8)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(6)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Answer")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(item.answer)
                                .font(.system(size: 14, design: .serif))
                                .lineSpacing(6)
                        }
                        
                        Spacer()
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.textBackgroundColor))
            } else {
                ContentUnavailableView("Select a question to see details", systemImage: "clock.arrow.circlepath")
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
