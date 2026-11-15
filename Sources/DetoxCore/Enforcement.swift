import Foundation

public struct EnforcementPlan: Equatable, Sendable {
    public var blockedDomains: [String: Set<UUID>] = [:]
    public var primaryDomains: Set<String> = []
    public var appBundleIDs: [String: Set<UUID>] = [:]
    public var appPaths: [String: Set<UUID>] = [:]
    public var activeBlockIDs: Set<UUID> = []

    public init() {}

    public var isEmpty: Bool { blockedDomains.isEmpty && appBundleIDs.isEmpty && appPaths.isEmpty }

    /// Domains blocked because of one specific block.
    public func domains(of blockID: UUID) -> [String] {
        blockedDomains.filter { $0.value.contains(blockID) }.map(\.key).sorted()
    }
}

/// What must be blocked right now: union of every block that is active (not paused).
public func makeEnforcementPlan(blocks: [Block], now: Date, isTrustedTime: Bool) -> EnforcementPlan {
    var plan = EnforcementPlan()
    for b in blocks where b.phase(at: now, isTrustedTime: isTrustedTime) == .active {
        plan.activeBlockIDs.insert(b.id)
        func add(_ d: String, primary: Bool) {
            plan.blockedDomains[d, default: []].insert(b.id)
            if primary { plan.primaryDomains.insert(d) }
        }
        for s in b.targets.services {
            let def = ServiceCatalog.definition(s)
            def.primaryDomains.forEach { add($0, primary: true) }
            def.secondaryDomains.forEach { add($0, primary: false) }
            def.appBundleIDs.forEach { plan.appBundleIDs[$0, default: []].insert(b.id) }
        }
        for d in b.targets.domains {
            DomainExpansion.variants(of: d).forEach { add($0, primary: true) }
        }
        for a in b.targets.apps {
            plan.appBundleIDs[a.bundleID, default: []].insert(b.id)
            plan.appPaths[a.path, default: []].insert(b.id)
        }
    }
    return plan
}
