import DetoxCore
import Foundation
import Testing
@testable import DetoxIPC

private func socketPath() -> String {
    let p = (NSTemporaryDirectory() as NSString).appendingPathComponent("dx-\(UUID().uuidString.prefix(8)).sock")
    precondition(p.utf8.count < 104)
    return p
}

private func startServer(_ handler: @escaping (Request) -> Response) throws -> (IPCServer, String) {
    let path = socketPath()
    let server = IPCServer(socketPath: path, queue: DispatchQueue(label: "test.ipc"), handler: handler)
    try server.start()
    return (server, path)
}

@Test func pingRoundTrip() async throws {
    let (server, path) = try startServer { req in
        if case .ping = req { return .pong }
        return .ok
    }
    defer { server.stop() }
    let r = try await DetoxClient(socketPath: path).send(.ping)
    guard case .pong = r else { Issue.record("got \(r)"); return }
}

@Test func statusRoundTripPreservesDates() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000.25)
    let snap = StatusSnapshot(now: now, isTrustedTime: true, blocks: [], friends: [],
                              blockedDomainsNow: ["www.youtube.com"], rateLimitedUntil: nil)
    let (server, path) = try startServer { _ in .status(snap) }
    defer { server.stop() }
    let r = try await DetoxClient(socketPath: path).send(.status)
    guard case .status(let got) = r else { Issue.record("got \(r)"); return }
    #expect(got == snap)
}

@Test func failureRoundTrip() async throws {
    let (server, path) = try startServer { _ in .failure(.tightening([.removesTargets])) }
    defer { server.stop() }
    let r = try await DetoxClient(socketPath: path).send(.status)
    guard case .failure(let e) = r else { Issue.record("got \(r)"); return }
    #expect(e == .tightening([.removesTargets]))
}

@Test func subscriberReceivesBroadcast() async throws {
    let (server, path) = try startServer { _ in .ok }
    defer { server.stop() }
    let stream = DetoxClient(socketPath: path).events()
    try await Task.sleep(nanoseconds: 300_000_000)
    server.broadcast(.stateChanged)
    let received = try await withThrowingTaskGroup(of: DaemonEvent?.self) { group in
        group.addTask {
            for try await e in stream { return e }
            return nil
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return nil
        }
        let first = try await group.next()!
        group.cancelAll()
        return first
    }
    #expect(received == .stateChanged)
}

@Test func clientFailsWhenNoServer() async {
    await #expect(throws: (any Error).self) { _ = try await DetoxClient(socketPath: socketPath()).send(.ping) }
}

@Test func lineBufferSplitsAndKeepsRemainder() throws {
    var b = LineBuffer()
    #expect(try b.append(Data("a\nb".utf8)) == [Data("a".utf8)])
    #expect(try b.append(Data("\n".utf8)) == [Data("b".utf8)])
}

@Test func oversizedLineIsRejected() {
    var b = LineBuffer()
    #expect(throws: (any Error).self) { try b.append(Data(repeating: 65, count: LineBuffer.maxLineBytes + 1)) }
}

@Test func everyRequestCaseRoundTrips() throws {
    let draft = BlockDraft(name: "x", targets: BlockTargets(services: [.youtube]),
                           window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)), weekdays: [.monday],
                           startDate: LocalDate(2026, 12, 1), endDate: LocalDate(2026, 12, 31),
                           timeZoneID: "Europe/Madrid", lock: .password("1234"), pauseMinutes: 15)
    let id = UUID()
    let all: [Request] = [.ping, .status, .createBlock(draft), .updateBlock(id: id, draft: draft), .deleteBlock(id: id),
                          .unlock(blockID: id, credential: .friendCode("123456"), action: .cancel),
                          .registerFriend(name: "Ana"), .confirmFriend(id: id, code: "1"), .deleteFriend(id: id), .subscribe]
    for r in all {
        let line = try IPCCoding.encodeLine(r)
        #expect(line.last == UInt8(ascii: "\n"))
        let back: Request = try IPCCoding.decode(line.dropLast())
        #expect(try IPCCoding.encodeLine(back) == line)
    }
}
