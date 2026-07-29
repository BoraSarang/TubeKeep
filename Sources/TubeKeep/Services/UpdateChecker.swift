import Foundation

struct AppcastEntry: Decodable {
    let latestVersion: String
    let minimumVersion: String?
    let downloadURL: String
    let releaseNotes: String?
    let pubDate: String?
}

enum UpdateChecker {
    private static let skipKey = "skipVersion"
    private static let lastCheckKey = "lastUpdateCheck"

    static func checkForUpdate() async -> AppcastEntry? {
        let defaults = UserDefaults.standard

        // Rate limit: max once per hour
        let lastCheck = defaults.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(lastCheck) < 3600 { return nil }

        defaults.set(Date(), forKey: lastCheckKey)

        guard let url = URL(string: Constants.appcastURL) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let entry = try JSONDecoder().decode(AppcastEntry.self, from: data)

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            let skippedVersion = defaults.string(forKey: skipKey)

            guard entry.latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending else { return nil }
            guard entry.latestVersion != skippedVersion else { return nil }

            return entry
        } catch {
            return nil
        }
    }

    static func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: skipKey)
    }

    static func resetSkip() {
        UserDefaults.standard.removeObject(forKey: skipKey)
    }
}
