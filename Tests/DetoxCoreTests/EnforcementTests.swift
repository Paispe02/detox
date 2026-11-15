import Foundation
import Testing
@testable import DetoxCore

@Test func strictestWins() {
    let a = Block.fixture(targets: BlockTargets(services: [.youtube]))
    var b = Block.fixture(targets: BlockTargets(services: [.youtube, .whatsapp]))
    b.pausedUntil = madrid(2026, 12, 2, 23, 30)
    let plan = makeEnforcementPlan(blocks: [a, b], now: madrid(2026, 12, 2, 23, 0), isTrustedTime: true)
    #expect(plan.blockedDomains["www.youtube.com"] == [a.id])
    #expect(plan.blockedDomains["web.whatsapp.com"] == nil)
    #expect(plan.appBundleIDs["net.whatsapp.WhatsApp"] == nil)
    #expect(plan.activeBlockIDs == [a.id])
}

@Test func customDomainsExpandAndArePrimary() {
    let b = Block.fixture(targets: BlockTargets(domains: ["reddit.com"]))
    let plan = makeEnforcementPlan(blocks: [b], now: madrid(2026, 12, 2, 23, 0), isTrustedTime: true)
    #expect(plan.blockedDomains.keys.contains("www.reddit.com"))
    #expect(plan.primaryDomains.isSuperset(of: ["reddit.com", "www.reddit.com"]))
}

@Test func appsAndServiceAppsAreBlocked() {
    let app = AppTarget(bundleID: "com.valvesoftware.steam", name: "Steam", path: "/Applications/Steam.app")
    let b = Block.fixture(targets: BlockTargets(services: [.whatsapp], apps: [app]))
    let plan = makeEnforcementPlan(blocks: [b], now: madrid(2026, 12, 2, 23, 0), isTrustedTime: true)
    #expect(plan.appBundleIDs["net.whatsapp.WhatsApp"] == [b.id])
    #expect(plan.appBundleIDs["com.valvesoftware.steam"] == [b.id])
    #expect(plan.appPaths["/Applications/Steam.app"] == [b.id])
}

@Test func emptyOutsideWindow() {
    #expect(makeEnforcementPlan(blocks: [Block.fixture()], now: madrid(2026, 12, 2, 12, 0), isTrustedTime: true).isEmpty)
}
