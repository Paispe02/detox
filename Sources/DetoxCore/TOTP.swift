import CryptoKit
import Foundation

public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    /// RFC 4648, uppercase, no padding.
    public static func encode(_ data: Data) -> String {
        var out = ""
        var buffer = 0
        var bits = 0
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { out.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return out
    }
}

public enum TOTP {
    public static let period: TimeInterval = 30

    public static func counter(at date: Date) -> UInt64 {
        UInt64(floor(date.timeIntervalSince1970 / period))
    }

    /// RFC 6238 with HMAC-SHA1, 6 digits.
    public static func code(secret: Data, counter: UInt64) -> String {
        var big = counter.bigEndian
        let msg = Data(bytes: &big, count: 8)
        let mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: msg, using: SymmetricKey(data: secret)))
        let offset = Int(mac[19] & 0x0f)
        let value = (UInt32(mac[offset] & 0x7f) << 24) | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8) | UInt32(mac[offset + 3])
        return String(format: "%06u", value % 1_000_000)
    }
}

public struct FriendKey: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var secret: Data
    public var isConfirmed: Bool
    public var lastUsedCounter: UInt64?
    public var createdAt: Date

    public static func generate(name: String, now: Date) -> FriendKey {
        FriendKey(id: UUID(), name: name, secret: randomBytes(20), isConfirmed: false,
                  lastUsedCounter: nil, createdAt: now)
    }

    public var provisioningURI: String {
        var allowed = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
        allowed.insert(charactersIn: "-._~")
        let label = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? "amigo"
        return "otpauth://totp/Detox:\(label)?secret=\(Base32.encode(secret))&issuer=Detox&algorithm=SHA1&digits=6&period=30"
    }

    /// Accepts the code for the current, previous or next 30 s step, once.
    public mutating func consume(code: String, at date: Date) -> Bool {
        let clean = code.filter { !$0.isWhitespace }
        guard clean.count == 6 else { return false }
        let c = TOTP.counter(at: date)
        for candidate in [c &- 1, c, c &+ 1] {
            if let last = lastUsedCounter, candidate <= last { continue }
            if constantTimeEqual(Data(TOTP.code(secret: secret, counter: candidate).utf8), Data(clean.utf8)) {
                lastUsedCounter = candidate
                return true
            }
        }
        return false
    }
}
