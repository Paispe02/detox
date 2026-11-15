import Darwin
import Foundation
import Testing
@testable import DetoxDaemonKit

private func fixture() throws -> Data {
    let url = Bundle.module.url(forResource: "clienthello-instagram", withExtension: "bin", subdirectory: "Fixtures")!
    return try Data(contentsOf: url)
}

@Test func parsesSNIFromRealClientHello() throws {
    #expect(RequestSniffer.serverName(fromClientHello: try fixture()) == "www.instagram.com")
    #expect(RequestSniffer.host(from: try fixture()) == "www.instagram.com")
}

@Test func parsesHTTPHostHeader() {
    let req = Data("GET / HTTP/1.1\r\nHost: Instagram.com:80\r\nAccept: */*\r\n\r\n".utf8)
    #expect(RequestSniffer.httpHost(fromRequest: req) == "instagram.com")
    #expect(RequestSniffer.host(from: req) == "instagram.com")
}

@Test func truncatedClientHelloReturnsNil() throws {
    #expect(RequestSniffer.serverName(fromClientHello: try fixture().prefix(40)) == nil)
}

@Test func garbageReturnsNil() {
    #expect(RequestSniffer.host(from: Data([0x16, 0x03, 0x01, 0xff, 0xff, 0x01])) == nil)
    #expect(RequestSniffer.host(from: Data("hello".utf8)) == nil)
}

@Test func listenerDeliversHostForLoopbackConnection() async throws {
    let payload = try fixture()
    let got = Locked<String?>(nil)
    let listener = InterceptListener(endpoints: [ListenEndpoint(address: "127.0.0.1", port: 0)],
                                     deliverOn: DispatchQueue(label: "test.listener")) { got.set($0) }
    #expect(listener.start().isEmpty)
    defer { listener.stop() }
    let port = listener.boundEndpoints[0].port
    #expect(port != 0)

    let fd = socket(AF_INET, SOCK_STREAM, 0)
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    let r = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    #expect(r == 0)
    _ = payload.withUnsafeBytes { write(fd, $0.baseAddress, payload.count) }
    for _ in 0..<40 where got.get() == nil { try await Task.sleep(nanoseconds: 50_000_000) }
    close(fd)
    #expect(got.get() == "www.instagram.com")
}

final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ v: T) { value = v }
    func get() -> T { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ v: T) { lock.lock(); value = v; lock.unlock() }
}
