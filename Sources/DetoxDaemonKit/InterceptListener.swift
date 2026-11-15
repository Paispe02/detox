import Darwin
import Foundation

public struct ListenEndpoint: Hashable, Sendable {
    public var address: String
    public var port: UInt16

    public init(address: String, port: UInt16) {
        self.address = address
        self.port = port
    }

    public static let production = [
        ListenEndpoint(address: "127.0.0.1", port: 80), ListenEndpoint(address: "127.0.0.1", port: 443),
        ListenEndpoint(address: "::1", port: 80), ListenEndpoint(address: "::1", port: 443),
    ]
}

/// Accepts the connections that /etc/hosts redirects to loopback, sniffs the host, and closes them.
public final class InterceptListener {
    private let endpoints: [ListenEndpoint]
    private let deliverQueue: DispatchQueue
    private let onHost: (String) -> Void
    private let workQueue = DispatchQueue(label: "com.detox.listener", attributes: .concurrent)
    private var sources: [DispatchSourceRead] = []
    public private(set) var boundEndpoints: [ListenEndpoint] = []

    public init(endpoints: [ListenEndpoint], deliverOn queue: DispatchQueue, onHost: @escaping (String) -> Void) {
        self.endpoints = endpoints
        self.deliverQueue = queue
        self.onHost = onHost
    }

    /// Returns the endpoints that could not be bound (e.g. port already in use).
    public func start() -> [ListenEndpoint] {
        var failed: [ListenEndpoint] = []
        for ep in endpoints {
            guard let (fd, port) = bindSocket(ep) else { failed.append(ep); continue }
            boundEndpoints.append(ListenEndpoint(address: ep.address, port: port))
            let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: workQueue)
            src.setEventHandler { [weak self] in
                let c = accept(fd, nil, nil)
                guard c >= 0, let self else { return }
                self.workQueue.async { self.handle(c) }
            }
            src.setCancelHandler { close(fd) }
            sources.append(src)
            src.resume()
        }
        return failed
    }

    public func stop() {
        sources.forEach { $0.cancel() }
        sources = []
    }

    private func handle(_ fd: Int32) {
        defer { close(fd) }
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while data.count < 16384 {
            let n = read(fd, &chunk, chunk.count)
            if n <= 0 { break }
            data.append(contentsOf: chunk[0..<n])
            if let host = RequestSniffer.host(from: data) {
                deliverQueue.async { self.onHost(host) }
                return
            }
        }
    }

    private func bindSocket(_ ep: ListenEndpoint) -> (Int32, UInt16)? {
        let v6 = ep.address.contains(":")
        let fd = socket(v6 ? AF_INET6 : AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        var ok: Int32
        if v6 {
            setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &one, socklen_t(MemoryLayout<Int32>.size))
            var a = sockaddr_in6()
            a.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
            a.sin6_family = sa_family_t(AF_INET6)
            a.sin6_port = ep.port.bigEndian
            inet_pton(AF_INET6, ep.address, &a.sin6_addr)
            ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) } }
        } else {
            var a = sockaddr_in()
            a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            a.sin_family = sa_family_t(AF_INET)
            a.sin_port = ep.port.bigEndian
            a.sin_addr.s_addr = inet_addr(ep.address)
            ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        }
        guard ok == 0, listen(fd, 64) == 0 else { close(fd); return nil }
        var storage = sockaddr_storage()
        var len = socklen_t(MemoryLayout<sockaddr_storage>.size)
        _ = withUnsafeMutablePointer(to: &storage) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
        let port: UInt16 = withUnsafePointer(to: &storage) { p in
            v6 ? p.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { UInt16(bigEndian: $0.pointee.sin6_port) }
               : p.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt16(bigEndian: $0.pointee.sin_port) }
        }
        return (fd, port)
    }
}
