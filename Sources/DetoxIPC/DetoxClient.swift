import Darwin
import Foundation

public protocol DaemonClienting: Sendable {
    func send(_ request: Request) async throws -> Response
    func events() -> AsyncThrowingStream<DaemonEvent, Error>
}

public struct ConnectionClosed: Error {}

public final class DetoxClient: DaemonClienting {
    public let socketPath: String
    private let timeout: TimeInterval

    public init(socketPath: String = "/var/run/detox.sock", timeout: TimeInterval = 5) {
        self.socketPath = socketPath
        self.timeout = timeout
    }

    private func connect(readTimeout: TimeInterval?) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketError(call: "socket", code: errno) }
        noSigPipe(fd)
        if let t = readTimeout {
            var tv = timeval(tv_sec: Int(t), tv_usec: Int32((t - floor(t)) * 1_000_000))
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        }
        var addr = unixAddress(socketPath)
        let r = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard r == 0 else { let e = errno; close(fd); throw SocketError(call: "connect", code: e) }
        return fd
    }

    /// Reads lines from fd until `onLine` returns false or the socket closes.
    private static func readLines(_ fd: Int32, _ onLine: (Data) throws -> Bool) throws {
        var buffer = LineBuffer()
        var chunk = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = Darwin.read(fd, &chunk, chunk.count)
            if n < 0 { throw SocketError(call: "read", code: errno) }
            if n == 0 { throw ConnectionClosed() }
            for line in try buffer.append(Data(chunk[0..<n])) where try !onLine(line) { return }
        }
    }

    public func send(_ request: Request) async throws -> Response {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async { [self] in
                do {
                    let fd = try connect(readTimeout: timeout)
                    defer { close(fd) }
                    guard writeAll(fd, try IPCCoding.encodeLine(request)) else { throw ConnectionClosed() }
                    var response: Response?
                    try Self.readLines(fd) { line in
                        response = try IPCCoding.decode(line)
                        return false
                    }
                    cont.resume(returning: response!)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Subscribes and yields daemon events until the connection drops (then the stream throws).
    public func events() -> AsyncThrowingStream<DaemonEvent, Error> {
        AsyncThrowingStream { continuation in
            let fdBox = FDBox()
            continuation.onTermination = { _ in fdBox.close() }
            DispatchQueue.global().async { [self] in
                do {
                    let fd = try connect(readTimeout: nil)
                    fdBox.set(fd)
                    guard writeAll(fd, try IPCCoding.encodeLine(Request.subscribe)) else { throw ConnectionClosed() }
                    var acknowledged = false
                    try Self.readLines(fd) { line in
                        if !acknowledged { acknowledged = true; return true }   // the .ok reply
                        continuation.yield(try IPCCoding.decode(line))
                        return true
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

private final class FDBox: @unchecked Sendable {
    private let lock = NSLock()
    private var fd: Int32 = -1
    private var closed = false

    func set(_ fd: Int32) {
        lock.lock(); defer { lock.unlock() }
        if closed { Darwin.close(fd) } else { self.fd = fd }
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        closed = true
        if fd >= 0 { Darwin.shutdown(fd, SHUT_RDWR); Darwin.close(fd); fd = -1 }
    }
}
