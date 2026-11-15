import Foundation

/// Reads which host a browser wanted from the first bytes of a connection, without completing TLS.
public enum RequestSniffer {
    public static func host(from data: Data) -> String? {
        serverName(fromClientHello: data) ?? httpHost(fromRequest: data)
    }

    public static func serverName(fromClientHello data: Data) -> String? {
        let b = [UInt8](data)
        var i = 0
        func need(_ n: Int) -> Bool { i + n <= b.count }
        func u8() -> Int? { guard need(1) else { return nil }; defer { i += 1 }; return Int(b[i]) }
        func u16() -> Int? { guard need(2) else { return nil }; defer { i += 2 }; return Int(b[i]) << 8 | Int(b[i + 1]) }
        func skip(_ n: Int) -> Bool { guard need(n) else { return false }; i += n; return true }

        guard u8() == 0x16, skip(2), u16() != nil else { return nil }     // record header
        guard u8() == 0x01, skip(3) else { return nil }                    // handshake: ClientHello
        guard skip(2 + 32) else { return nil }                             // version + random
        guard let sid = u8(), skip(sid) else { return nil }
        guard let cs = u16(), skip(cs) else { return nil }
        guard let comp = u8(), skip(comp) else { return nil }
        guard let extLen = u16(), need(extLen) else { return nil }
        let extEnd = i + extLen
        while i + 4 <= extEnd {
            guard let type = u16(), let len = u16(), i + len <= extEnd else { return nil }
            if type == 0x0000 {
                guard u16() != nil else { return nil }                     // server_name_list length
                while i + 3 <= extEnd {
                    guard let nameType = u8(), let nameLen = u16(), need(nameLen) else { return nil }
                    if nameType == 0 {
                        let name = String(decoding: b[i..<(i + nameLen)], as: UTF8.self)
                        return clean(name)
                    }
                    i += nameLen
                }
                return nil
            }
            i += len
        }
        return nil
    }

    public static func httpHost(fromRequest data: Data) -> String? {
        guard let text = String(data: data.prefix(16384), encoding: .utf8),
              text.range(of: "^[A-Z]+ \\S+ HTTP/1\\.[01]\r\n", options: .regularExpression) != nil else { return nil }
        for line in text.components(separatedBy: "\r\n").dropFirst() {
            if line.isEmpty { break }
            if line.lowercased().hasPrefix("host:") {
                return clean(String(line.dropFirst(5)))
            }
        }
        return nil
    }

    private static func clean(_ raw: String) -> String? {
        var h = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let colon = h.lastIndex(of: ":"), !h.hasPrefix("[") { h = String(h[..<colon]) }
        return h.isEmpty ? nil : h
    }
}
