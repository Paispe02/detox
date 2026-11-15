import DetoxCore
import Foundation

public struct AppHit: Equatable, Sendable {
    public var bundlePath: String
    public var bundleID: String
    public var blockIDs: Set<UUID>
}

/// Applies an EnforcementPlan to the system: hosts, pf, Chrome policy, running apps.
public final class Enforcer {
    private let hosts: HostsFile
    private let packetFilter: PacketFilter
    private let chromePolicy: ChromePolicy
    private let terminator: ProcessTerminator
    private let resolveApp: (String) -> String?

    public init(hosts: HostsFile, packetFilter: PacketFilter, chromePolicy: ChromePolicy,
                terminator: ProcessTerminator, resolveApp: @escaping (String) -> String?) {
        self.hosts = hosts
        self.packetFilter = packetFilter
        self.chromePolicy = chromePolicy
        self.terminator = terminator
        self.resolveApp = resolveApp
    }

    /// Bundle path → which app and which blocks.
    func appTargets(_ plan: EnforcementPlan) -> [String: (bundleID: String, blockIDs: Set<UUID>)] {
        var out: [String: (bundleID: String, blockIDs: Set<UUID>)] = [:]
        for (bid, ids) in plan.appBundleIDs {
            if let path = resolveApp(bid) { out[path] = (bid, (out[path]?.blockIDs ?? []).union(ids)) }
        }
        for (path, ids) in plan.appPaths {
            out[path] = (out[path]?.bundleID ?? "", (out[path]?.blockIDs ?? []).union(ids))
        }
        return out
    }

    /// Each step is independent: one failing (e.g. pf) must not stop the others.
    public func apply(plan: EnforcementPlan, anyBlockRunning: Bool, tick: Int) -> [AppHit] {
        log { try hosts.apply(domains: Array(plan.blockedDomains.keys)) }
        log { try packetFilter.apply(enabled: !plan.isEmpty) }
        if tick % 15 == 0 { log { try packetFilter.verify() } }
        log { try chromePolicy.apply(enabled: anyBlockRunning) }
        let targets = appTargets(plan)
        return terminator.terminate(bundlePaths: Array(targets.keys)).compactMap { t in
            targets[t.bundlePath].map { AppHit(bundlePath: t.bundlePath, bundleID: $0.bundleID, blockIDs: $0.blockIDs) }
        }
    }

    /// Removes everything Detox put on the system.
    public func cleanup() {
        log { try hosts.apply(domains: []) }
        log { try packetFilter.apply(enabled: false) }
        log { try chromePolicy.apply(enabled: false) }
    }

    private func log(_ body: () throws -> Void) {
        do { try body() } catch { FileHandle.standardError.write(Data("detoxd: \(error)\n".utf8)) }
    }
}
