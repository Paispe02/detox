import DetoxCore
import Foundation
import Testing
@testable import DetoxAppKit

@Test func headlineNamesTheFailureWhenServiceIsDown() {
    #expect(StatusSummary.headline(nil, reachable: false) == "Detox no está protegiendo tus noches")
    #expect(StatusSummary.headline(nil, reachable: true) == "Conectando…")
}

@Test func headlineWithoutBlocks() {
    let s = StatusSnapshot(now: .now, isTrustedTime: true, blocks: [], friends: [], blockedDomainsNow: [], rateLimitedUntil: nil)
    #expect(StatusSummary.headline(s, reachable: true) == "Sin bloqueos programados")
    #expect(StatusSummary.headline(s, reachable: false) == "Detox no está protegiendo tus noches")
}
