import CommonCrypto
import Foundation
import Security

extension PasswordHash {
    public static let defaultIterations = 600_000

    public static func make(password: String, iterations: Int = defaultIterations) -> PasswordHash {
        let salt = randomBytes(16)
        return PasswordHash(salt: salt, iterations: iterations,
                            hash: derive(password: password, salt: salt, iterations: iterations))
    }

    public func verify(_ password: String) -> Bool {
        constantTimeEqual(Self.derive(password: password, salt: salt, iterations: iterations), hash)
    }

    /// PBKDF2-HMAC-SHA256, 32-byte output.
    public static func derive(password: String, salt: Data, iterations: Int) -> Data {
        let pw = Array(password.utf8).map { Int8(bitPattern: $0) }
        var out = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { s in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pw, pw.count,
                                 s.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                                 &out, out.count)
        }
        precondition(status == kCCSuccess, "PBKDF2 failed")
        return Data(out)
    }
}

func randomBytes(_ count: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    precondition(SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess)
    return Data(bytes)
}

func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
}
