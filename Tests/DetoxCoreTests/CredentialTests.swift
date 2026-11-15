import Foundation
import Testing
@testable import DetoxCore

@Test func pbkdf2KnownVector() {
    #expect(PasswordHash.derive(password: "password", salt: Data("salt".utf8), iterations: 1).hexString
            == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
}

@Test func passwordVerify() {
    let h = PasswordHash.make(password: "luna-llena", iterations: 1_000)
    #expect(h.verify("luna-llena"))
    #expect(!h.verify("luna-llen"))
    #expect(h.salt.count == 16 && h.hash.count == 32)
    #expect(h.salt != PasswordHash.make(password: "luna-llena", iterations: 1_000).salt)
}

@Test func defaultIterationsMatchSpec() {
    #expect(PasswordHash.defaultIterations == 600_000)
}

@Test func base32() {
    #expect(Base32.encode(Data("foobar".utf8)) == "MZXW6YTBOI")
    #expect(Base32.encode(Data()) == "")
}

@Test(arguments: [(59.0, "287082"), (1111111109, "081804"), (1111111111, "050471"),
                  (1234567890, "005924"), (2000000000, "279037"), (20000000000, "353130")])
func totpRFC6238(t: Double, expected: String) {
    let secret = Data("12345678901234567890".utf8)
    #expect(TOTP.code(secret: secret, counter: TOTP.counter(at: Date(timeIntervalSince1970: t))) == expected)
}

private let t59 = Date(timeIntervalSince1970: 59)
private func rfcFriend() -> FriendKey {
    var f = FriendKey.generate(name: "Ana", now: t59)
    f.secret = Data("12345678901234567890".utf8)
    f.isConfirmed = true
    return f
}

@Test func acceptsCurrentCode() { var f = rfcFriend(); let r = f.consume(code: "287082", at: t59); #expect(r) }
@Test func acceptsPreviousStep() { var f = rfcFriend(); let r = f.consume(code: "287082", at: t59 + 30); #expect(r) }
@Test func rejectsTwoStepsOld() { var f = rfcFriend(); let r = f.consume(code: "287082", at: t59 + 60); #expect(!r) }
@Test func rejectsReuse() {
    var f = rfcFriend()
    let r = f.consume(code: "287082", at: t59); #expect(r)
    let r2 = f.consume(code: "287082", at: t59 + 5); #expect(!r2)
}
@Test func acceptsCodeWithSpaces() { var f = rfcFriend(); let r = f.consume(code: "287 082", at: t59); #expect(r) }
@Test func rejectsWrongCode() { var f = rfcFriend(); let r = f.consume(code: "123456", at: t59); #expect(!r) }

@Test func generatedFriendHas20ByteSecret() {
    let f = FriendKey.generate(name: "Ana", now: t59)
    #expect(f.secret.count == 20 && !f.isConfirmed && f.lastUsedCounter == nil)
}

@Test func provisioningURIEncodesName() {
    var f = rfcFriend()
    f.name = "Ana María"
    #expect(f.provisioningURI == "otpauth://totp/Detox:Ana%20Mar%C3%ADa?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Detox&algorithm=SHA1&digits=6&period=30")
}

@Test func limiterLocksOnFifthFailure() {
    var l = AttemptLimiter()
    let t = Date(timeIntervalSince1970: 0)
    for _ in 0..<4 { l.recordFailure(at: t) }
    #expect(!l.isLocked(at: t))
    l.recordFailure(at: t)
    #expect(l.isLocked(at: t.addingTimeInterval(599)))
    #expect(!l.isLocked(at: t.addingTimeInterval(600)))
}

@Test func limiterSuccessResets() {
    var l = AttemptLimiter()
    let t = Date(timeIntervalSince1970: 0)
    for _ in 0..<4 { l.recordFailure(at: t) }
    l.recordSuccess()
    for _ in 0..<4 { l.recordFailure(at: t) }
    #expect(!l.isLocked(at: t))
}
