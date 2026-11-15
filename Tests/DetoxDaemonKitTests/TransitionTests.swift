import DetoxCore
import Foundation
import Testing
@testable import DetoxDaemonKit

private let id = UUID()
private var plan: EnforcementPlan {
    var p = EnforcementPlan()
    p.blockedDomains = ["www.youtube.com": [id], "youtube.com": [id]]
    return p
}

@Test func scheduledToActiveIsWindowStarted() {
    #expect(transitionEvents(previous: [id: .scheduled], current: [id: .active], plan: plan)
            == [.windowStarted(blockIDs: [id], domains: ["www.youtube.com", "youtube.com"])])
}

@Test func runningToActiveIsWindowStarted() {
    #expect(transitionEvents(previous: [id: .running], current: [id: .active], plan: plan).count == 1)
}

@Test func unknownToActiveIsWindowStarted() {
    #expect(transitionEvents(previous: [:], current: [id: .active], plan: plan).count == 1)
}

@Test func pausedToActiveIsPauseEnded() {
    #expect(transitionEvents(previous: [id: .paused], current: [id: .active], plan: plan)
            == [.pauseEnded(blockID: id, domains: ["www.youtube.com", "youtube.com"])])
}

@Test func activeToActiveEmitsNothing() {
    #expect(transitionEvents(previous: [id: .active], current: [id: .active], plan: plan).isEmpty)
}
