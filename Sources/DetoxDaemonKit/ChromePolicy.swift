import Foundation

/// Machine-level Chrome policy that turns off Chrome's own DNS-over-HTTPS resolver.
public final class ChromePolicy {
    private let plistPath: String
    private let key = "DnsOverHttpsMode"

    public init(plistPath: String = "/Library/Managed Preferences/com.google.Chrome.plist") {
        self.plistPath = plistPath
    }

    public func apply(enabled: Bool) throws {
        var dict = (NSDictionary(contentsOfFile: plistPath) as? [String: Any]) ?? [:]
        if enabled {
            guard dict[key] as? String != "off" else { return }
            dict[key] = "off"
        } else {
            guard dict[key] != nil else { return }
            dict[key] = nil
            if dict.isEmpty {
                try? FileManager.default.removeItem(atPath: plistPath)
                return
            }
        }
        let url = URL(fileURLWithPath: plistPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: url, options: .atomic)
        chmod(plistPath, 0o644)
    }
}
