internal import Combine
import SwiftUI

@MainActor
class UpdateManager: ObservableObject {
    @Published var latestVersion: String = ""
    @Published var isUpdateAvailable: Bool = false

    @AppStorage("lastGitHubCheck") private var lastCheck: Date = .distantPast
    @AppStorage("cachedGitHubVersion") private var cachedVersion: String = ""
    @AppStorage("lastAppVersion") private var lastAppVersion: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        resetIfAppUpdated()
    }

    private func resetIfAppUpdated() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        if lastAppVersion != currentVersion {
            lastCheck = .distantPast
            isUpdateAvailable = false
            lastAppVersion = currentVersion
        }
    }

    func checkForUpdateIfNeeded() {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        guard lastCheck < oneDayAgo else {
            latestVersion = cachedVersion
            updateCheckAgainstBundle()
            return
        }

        fetchLatestGitHubVersion()
    }

    private func fetchLatestGitHubVersion() {
        guard let url = URL(string: "https://api.github.com/repos/Foraum-GmbH/kimai-clock/releases/latest") else { return }

        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GitHubRelease.self, decoder: JSONDecoder())
            .map { $0.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v")) }
            .replaceError(with: "error")
            .receive(on: RunLoop.main)
            .sink { [weak self] version in
                guard let self = self else { return }
                self.latestVersion = version
                self.cachedVersion = version
                self.lastCheck = Date()
                self.updateCheckAgainstBundle()
            }
            .store(in: &cancellables)
    }

    private func updateCheckAgainstBundle() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        isUpdateAvailable = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}

struct GitHubRelease: Codable {
    let tag_name: String
}
