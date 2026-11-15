import Darwin
import Foundation

/// Line-delimited JSON over a Unix stream socket. All handler calls run on `queue`.
public final class IPCServer {
    private final class Connection {
        let fd: Int32
        var buffer = LineBuffer()
        var source: DispatchSourceRead?
        var isSubscriber = false
        init(fd: Int32) { self.fd = fd }
    }

    private let socketPath: String
    private let permissions: mode_t
    private let queue: DispatchQueue
    private let handler: (Request) -> Response
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: Connection] = [:]

    public init(socketPath: String, permissions: mode_t = 0o666, queue: DispatchQueue,
                handler: @escaping (Request) -> Response) {
        self.socketPath = socketPath
        self.permissions = permissions
        self.queue = queue
        self.handler = handler
    }

    public func start() throws {
        unlink(socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketError(call: "socket", code: errno) }
        var addr = unixAddress(socketPath)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0 else { let e = errno; close(fd); throw SocketError(call: "bind", code: e) }
        chmod(socketPath, permissions)
        guard listen(fd, 16) == 0 else { let e = errno; close(fd); throw SocketError(call: "listen", code: e) }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        listenFD = fd
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in self?.acceptPending() }
        src.setCancelHandler { close(fd) }
        acceptSource = src
        src.resume()
    }

    public func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            for c in connections.values { c.source?.cancel() }
            connections.removeAll()
        }
        unlink(socketPath)
    }

    public func broadcast(_ event: DaemonEvent) {
        guard let line = try? IPCCoding.encodeLine(event) else { return }
        let send = { [self] in
            for c in connections.values where c.isSubscriber {
                if !writeAll(c.fd, line) { drop(c) }
            }
        }
        if DispatchQueue.getSpecific(key: queueKey) == ObjectIdentifier(self) { send() } else { queue.async(execute: send) }
    }

    private lazy var queueKey: DispatchSpecificKey<ObjectIdentifier> = {
        let k = DispatchSpecificKey<ObjectIdentifier>()
        queue.setSpecific(key: k, value: ObjectIdentifier(self))
        return k
    }()

    private func acceptPending() {
        _ = queueKey
        while true {
            let cfd = accept(listenFD, nil, nil)
            if cfd < 0 { return }
            noSigPipe(cfd)
            _ = fcntl(cfd, F_SETFL, O_NONBLOCK)
            let c = Connection(fd: cfd)
            let src = DispatchSource.makeReadSource(fileDescriptor: cfd, queue: queue)
            src.setEventHandler { [weak self, weak c] in
                guard let self, let c else { return }
                self.read(c)
            }
            src.setCancelHandler { close(cfd) }
            c.source = src
            connections[cfd] = c
            src.resume()
        }
    }

    private func read(_ c: Connection) {
        var chunk = [UInt8](repeating: 0, count: 65536)
        let n = Darwin.read(c.fd, &chunk, chunk.count)
        if n <= 0 {
            if n < 0 && (errno == EAGAIN || errno == EINTR) { return }
            drop(c)
            return
        }
        do {
            for line in try c.buffer.append(Data(chunk[0..<n])) {
                let response: Response
                if let req = try? IPCCoding.decode(line) as Request {
                    if case .subscribe = req { c.isSubscriber = true }
                    response = handler(req)
                } else {
                    response = .failure(.invalid("petición"))
                }
                if let out = try? IPCCoding.encodeLine(response), !writeAll(c.fd, out) {
                    drop(c)
                    return
                }
            }
        } catch {
            drop(c)
        }
    }

    private func drop(_ c: Connection) {
        c.source?.cancel()
        connections[c.fd] = nil
    }
}
