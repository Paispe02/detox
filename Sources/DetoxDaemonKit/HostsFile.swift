import Foundation

public enum HostsSection {
    public static let begin = "# BEGIN DETOX"
    public static let end = "# END DETOX"
    /// Apple's documented signal for a network to turn iCloud Private Relay off.
    public static let privateRelayDomains = ["mask.icloud.com", "mask-h2.icloud.com"]

    private static func isOurLine(_ line: Substring) -> Bool {
        line.hasPrefix("127.0.0.1\t") || line.hasPrefix("::1\t")
    }

    /// Returns `original` with exactly one DETOX section for `domains` (none when empty).
    /// Everything outside the section is preserved byte for byte.
    public static func render(original: String, domains: [String]) -> String {
        var kept: [Substring] = []
        let lines = original.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line == Substring(begin) {
                // Find matching END; if missing, drop only our own lines after BEGIN.
                if let endIdx = lines[(i + 1)...].firstIndex(of: Substring(end)) {
                    i = endIdx + 1
                } else {
                    i += 1
                    while i < lines.count && isOurLine(lines[i]) { i += 1 }
                }
                continue
            }
            kept.append(line)
            i += 1
        }
        var base = kept.joined(separator: "\n")
        let unique = Array(Set(domains)).sorted()
        guard !unique.isEmpty else { return base }
        if !base.isEmpty && !base.hasSuffix("\n") { base += "\n" }
        var section = begin + "\n"
        for d in unique + privateRelayDomains {
            section += "127.0.0.1\t\(d)\n::1\t\(d)\n"
        }
        return base + section + end + "\n"
    }
}

public final class HostsFile {
    private let path: String
    private let runner: CommandRunning
    private let flushesDNS: Bool

    public init(path: String, runner: CommandRunning, flushesDNS: Bool) {
        self.path = path
        self.runner = runner
        self.flushesDNS = flushesDNS
    }

    /// Writes the section if the file differs. Returns true when it changed.
    @discardableResult
    public func apply(domains: [String]) throws -> Bool {
        let current: String
        if FileManager.default.fileExists(atPath: path) {
            // Unreadable or non-UTF-8: refuse rather than replace the user's file.
            guard let s = String(data: try Data(contentsOf: URL(fileURLWithPath: path)), encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            current = s
        } else {
            current = ""
        }
        let rendered = HostsSection.render(original: current, domains: domains)
        guard rendered != current else { return false }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".hosts.detox.\(getpid())")
        try Data(rendered.utf8).write(to: tmp)
        chmod(tmp.path, 0o644)
        guard rename(tmp.path, url.path) == 0 else {
            unlink(tmp.path)
            throw CocoaError(.fileWriteUnknown)
        }
        if flushesDNS {
            try runner.run("/usr/bin/dscacheutil", ["-flushcache"])
            try runner.run("/usr/bin/killall", ["-HUP", "mDNSResponder"])
        }
        return true
    }
}
