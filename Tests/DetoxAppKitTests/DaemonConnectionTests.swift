import DetoxCore
import DetoxIPC
import Foundation
import Testing
@testable import DetoxAppKit

private struct Down: Error {}

private final class DeadClient: DaemonClienting {
    func send(_ request: Request) async throws -> Response { throw Down() }
    func events() -> AsyncThrowingStream<DaemonEvent, Error> { AsyncThrowingStream { $0.finish(throwing: Down()) } }
}

private final class StatusClient: DaemonClienting {
    let snapshot = StatusSnapshot(now: .now, isTrustedTime: true, blocks: [], friends: [], blockedDomainsNow: ["x.com"], rateLimitedUntil: nil)
    func send(_ request: Request) async throws -> Response {
        if case .status = request { return .status(snapshot) }
        return .failure(.wrongCredential)
    }
    func events() -> AsyncThrowingStream<DaemonEvent, Error> { AsyncThrowingStream { _ in } }
}

@MainActor @Test func unreachableDaemonFlipsFlag() async {
    let c = DaemonConnection(client: DeadClient())
    let r = await c.perform(.status)
    #expect(!c.isDaemonReachable)
    guard case .failure(.daemonUnavailable) = r else { Issue.record("\(r)"); return }
}

@MainActor @Test func refreshStoresSnapshot() async {
    let c = DaemonConnection(client: StatusClient())
    await c.refresh()
    #expect(c.isDaemonReachable && c.snapshot?.blockedDomainsNow == ["x.com"])
}

@MainActor @Test func failureResponseBecomesResultFailure() async {
    let c = DaemonConnection(client: StatusClient())
    let r = await c.perform(.deleteFriend(id: UUID()))
    guard case .failure(.wrongCredential) = r else { Issue.record("\(r)"); return }
    #expect(c.isDaemonReachable)
}
