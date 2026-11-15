import Foundation
import Testing
@testable import DetoxDaemonKit

@Test func rulesTextIsExact() {
    #expect(PacketFilter.rules(addresses: ["1.1.1.1", "2620:fe::9"]) == """
    table <detox_doh> const { 1.1.1.1, 2620:fe::9 }
    block drop out quick proto { tcp udp } from any to <detox_doh> port { 443 853 }

    """)
}

@Test func resolverListMatchesPlan() {
    #expect(DoHResolvers.addresses.count == 18)
    #expect(DoHResolvers.addresses.contains("1.1.1.1") && DoHResolvers.addresses.contains("45.90.30.0"))
}

@Test func enableParsesTokenAndLoadsRules() throws {
    let r = RecordingCommandRunner()
    r.scripted["/sbin/pfctl -E"] = CommandResult(stderr: "pf enabled\nToken : 13814183543617470847\n")
    let pf = PacketFilter(runner: r)
    try pf.apply(enabled: true)
    #expect(r.invocations.map { [$0.0] + $0.1 } == [["/sbin/pfctl", "-E"], ["/sbin/pfctl", "-a", "com.apple/detox", "-f", "-"]])
    #expect(r.invocations[1].2?.contains("detox_doh") == true)
    #expect(pf.token == "13814183543617470847")
    try pf.apply(enabled: true)   // already enabled: nothing new
    #expect(r.invocations.count == 2)
}

@Test func disableFlushesAndReleasesToken() throws {
    let r = RecordingCommandRunner()
    r.scripted["/sbin/pfctl -E"] = CommandResult(stderr: "Token : 42\n")
    let pf = PacketFilter(runner: r)
    try pf.apply(enabled: true)
    try pf.apply(enabled: false)
    #expect(r.invocations.suffix(2).map { [$0.0] + $0.1 }
            == [["/sbin/pfctl", "-a", "com.apple/detox", "-F", "all"], ["/sbin/pfctl", "-X", "42"]])
    #expect(pf.token == nil)
}

@Test func verifyReloadsWhenRulesMissing() throws {
    let r = RecordingCommandRunner()
    let pf = PacketFilter(runner: r)
    try pf.apply(enabled: true)
    let before = r.invocations.count
    try pf.verify()   // scripted -sr output is empty → reload
    #expect(r.invocations.count == before + 2)
    #expect(r.invocations.last!.1 == ["-a", "com.apple/detox", "-f", "-"])
    r.scripted["/sbin/pfctl -a com.apple/detox -sr"] = CommandResult(stdout: "block drop out quick proto tcp ...")
    try pf.verify()
    #expect(r.invocations.count == before + 3)
}

@Test func chromePolicyMergesAndRemovesOnlyOurKey() throws {
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("chrome-\(UUID().uuidString).plist")
    try PropertyListSerialization.data(fromPropertyList: ["HomepageLocation": "https://example.com"], format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: path))
    let policy = ChromePolicy(plistPath: path)
    try policy.apply(enabled: true)
    var dict = NSDictionary(contentsOfFile: path) as! [String: Any]
    #expect(dict["DnsOverHttpsMode"] as? String == "off" && dict["HomepageLocation"] != nil)
    try policy.apply(enabled: false)
    dict = NSDictionary(contentsOfFile: path) as! [String: Any]
    #expect(dict["DnsOverHttpsMode"] == nil && dict["HomepageLocation"] != nil)
}

@Test func chromePolicyDeletesFileWhenEmpty() throws {
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("chrome-\(UUID().uuidString).plist")
    let policy = ChromePolicy(plistPath: path)
    try policy.apply(enabled: true)
    #expect(FileManager.default.fileExists(atPath: path))
    try policy.apply(enabled: false)
    #expect(!FileManager.default.fileExists(atPath: path))
}
