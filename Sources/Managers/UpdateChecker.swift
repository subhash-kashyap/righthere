import AppKit

/// Update check against GitHub releases — deliberately not Sparkle.
/// Sparkle needs signing keys, an appcast feed, and framework embedding
/// in the hand-rolled bundle; until distribution justifies that, "update"
/// means comparing the latest release tag and opening its page.
@MainActor
final class UpdateChecker: ObservableObject {

    /// GitHub repo the app checks against. Must match where releases
    /// are published (tags like "v1.1" or "1.1", zipped app attached).
    static let repo = "subhash-kashyap/righthere"

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: String)
        case failed
    }

    @Published var state: State = .idle

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func check() {
        state = .checking
        Task {
            do {
                guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
                    state = .failed
                    return
                }
                var request = URLRequest(url: url)
                request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)

                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let releaseURL = json["html_url"] as? String else {
                    state = .failed
                    return
                }

                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                state = latest.compare(Self.currentVersion, options: .numeric) == .orderedDescending
                    ? .updateAvailable(version: latest, url: releaseURL)
                    : .upToDate
            } catch {
                state = .failed
            }
        }
    }

    func openRelease() {
        if case .updateAvailable(_, let urlString) = state, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
