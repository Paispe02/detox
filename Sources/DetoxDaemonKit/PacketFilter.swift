import Foundation

/// Public DNS-over-HTTPS/TLS resolvers, blocked on 443/853 during active windows so browsers
/// cannot resolve blocked domains around /etc/hosts.
public enum DoHResolvers {
    public static let addresses = [
        "1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001",
        "8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844",
        "9.9.9.9", "149.112.112.112", "2620:fe::fe", "2620:fe::9",
        "94.140.14.14", "94.140.15.15", "208.67.222.222", "208.67.220.220",
        "45.90.28.0", "45.90.30.0",
    ]
}

/// Rules live in the anchor `com.apple/detox`, which the stock /etc/pf.conf already includes
/// via `anchor "com.apple/*"`, so pf.conf is never modified.
public final class PacketFilter {
    private let runner: CommandRunning
    private let anchor: String
    private let pfctl = "/sbin/pfctl"
    public private(set) var token: String?
    private var loaded = false

    public init(runner: CommandRunning, anchor: String = "com.apple/detox") {
        self.runner = runner
        self.anchor = anchor
    }

    public static func rules(addresses: [String]) -> String {
        """
        table <detox_doh> const { \(addresses.joined(separator: ", ")) }
        block drop out quick proto { tcp udp } from any to <detox_doh> port { 443 853 }

        """
    }

    private func load() throws {
        try runner.run(pfctl, ["-a", anchor, "-f", "-"], stdin: Self.rules(addresses: DoHResolvers.addresses))
        loaded = true
    }

    public func apply(enabled: Bool) throws {
        if enabled {
            if token == nil {
                let r = try runner.run(pfctl, ["-E"])
                token = (r.stderr + r.stdout).split(separator: "\n")
                    .first { $0.hasPrefix("Token") }?
                    .split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                if token == nil { token = "" }   // pf already on without a token; remember we asked
            }
            if !loaded { try load() }
        } else if loaded || token != nil {
            try runner.run(pfctl, ["-a", anchor, "-F", "all"])
            if let t = token, !t.isEmpty { try runner.run(pfctl, ["-X", t]) }
            token = nil
            loaded = false
        }
    }

    /// Flushes the anchor regardless of what this instance remembers (used by --cleanup after the daemon stops).
    public func flush() throws {
        try runner.run(pfctl, ["-a", anchor, "-F", "all"])
        loaded = false
    }

    /// Reloads our rules if someone flushed the anchor.
    public func verify() throws {
        guard loaded else { return }
        let r = try runner.run(pfctl, ["-a", anchor, "-sr"])
        if !r.stdout.contains("block drop out quick") { try load() }
    }
}
