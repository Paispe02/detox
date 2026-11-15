import Foundation

public enum AppSettings {
    private static let videoKey = "videoFolder"
    private static let onboardedKey = "onboarded"

    public static var defaultVideoFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Detox")
    }

    /// The folder of motivational videos; created if missing.
    public static var videoFolder: URL {
        get {
            let url = UserDefaults.standard.url(forKey: videoKey) ?? defaultVideoFolder
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        set { UserDefaults.standard.set(newValue, forKey: videoKey) }
    }

    public static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }
}
