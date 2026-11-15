import Darwin
import Foundation

public enum IPCCoding {
    /// JSON followed by "\n". Both ends use these coders, so dates round-trip exactly.
    public static func encodeLine<T: Encodable>(_ value: T) throws -> Data {
        var d = try JSONEncoder().encode(value)
        d.append(UInt8(ascii: "\n"))
        return d
    }

    public static func decode<T: Decodable>(_ line: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: line)
    }
}

public struct LineTooLong: Error {}

public struct LineBuffer {
    public static let maxLineBytes = 1_048_576
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) throws -> [Data] {
        pending.append(data)
        var lines: [Data] = []
        while let nl = pending.firstIndex(of: UInt8(ascii: "\n")) {
            lines.append(Data(pending[pending.startIndex..<nl]))
            pending = Data(pending[(nl + 1)...])
        }
        if pending.count > Self.maxLineBytes { throw LineTooLong() }
        return lines
    }
}

// MARK: - POSIX helpers

struct SocketError: Error, CustomStringConvertible {
    let call: String
    let code: Int32
    var description: String { "\(call): \(String(cString: strerror(code)))" }
}

func unixAddress(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        for (i, b) in bytes.prefix(buf.count - 1).enumerated() { buf[i] = b }
    }
    return addr
}

func noSigPipe(_ fd: Int32) {
    var one: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
}

func writeAll(_ fd: Int32, _ data: Data) -> Bool {
    data.withUnsafeBytes { raw -> Bool in
        var offset = 0
        while offset < raw.count {
            let n = Darwin.write(fd, raw.baseAddress! + offset, raw.count - offset)
            if n <= 0 { return false }
            offset += n
        }
        return true
    }
}
