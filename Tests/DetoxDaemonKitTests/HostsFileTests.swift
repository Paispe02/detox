import Foundation
import Testing
@testable import DetoxDaemonKit

let macDefaultHosts = """
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1\tlocalhost
255.255.255.255\tbroadcasthost
::1             localhost

"""

@Test func addsSectionPreservingUserEntries() {
    let out = HostsSection.render(original: macDefaultHosts, domains: ["www.youtube.com"])
    #expect(out.hasPrefix(macDefaultHosts))
    #expect(out.contains("# BEGIN DETOX\n127.0.0.1\twww.youtube.com\n::1\twww.youtube.com\n"))
    #expect(out.hasSuffix("# END DETOX\n"))
}

@Test func replacesExistingSectionExactlyOnce() {
    let once = HostsSection.render(original: macDefaultHosts, domains: ["a.com"])
    let twice = HostsSection.render(original: once, domains: ["b.com"])
    #expect(twice.components(separatedBy: "# BEGIN DETOX").count == 2)
    #expect(twice.contains("\tb.com\n") && !twice.contains("\ta.com\n"))
}

@Test func removesSectionWhenNoDomains() {
    #expect(HostsSection.render(original: HostsSection.render(original: macDefaultHosts, domains: ["x.com"]), domains: [])
            == macDefaultHosts)
}

@Test func handlesMissingTrailingNewline() {
    let out = HostsSection.render(original: "127.0.0.1 localhost", domains: ["x.com"])
    #expect(out.hasPrefix("127.0.0.1 localhost\n# BEGIN DETOX\n"))
    #expect(HostsSection.render(original: "127.0.0.1 localhost", domains: []) == "127.0.0.1 localhost")
}

@Test func includesPrivateRelayWhenBlocking() {
    let out = HostsSection.render(original: macDefaultHosts, domains: ["x.com"])
    #expect(out.contains("127.0.0.1\tmask.icloud.com\n") && out.contains("::1\tmask-h2.icloud.com\n"))
    #expect(!HostsSection.render(original: macDefaultHosts, domains: []).contains("mask.icloud.com"))
}

@Test func sortsAndDeduplicates() {
    let out = HostsSection.render(original: "", domains: ["b.com", "a.com", "b.com"])
    #expect(out.components(separatedBy: "127.0.0.1\tb.com\n").count == 2)
    #expect(out.range(of: "\ta.com")!.lowerBound < out.range(of: "\tb.com")!.lowerBound)
}

@Test func danglingBeginWithoutEndIsRepaired() {
    let broken = macDefaultHosts + "# BEGIN DETOX\n127.0.0.1\tx.com\n::1\tx.com\n10.0.0.5\tnas.local\n"
    let out = HostsSection.render(original: broken, domains: [])
    #expect(out == macDefaultHosts + "10.0.0.5\tnas.local\n")
}

@Test func applyIsIdempotentAndFlushesOnlyOnChange() throws {
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("hosts-\(UUID().uuidString)")
    try macDefaultHosts.write(toFile: path, atomically: true, encoding: .utf8)
    let runner = RecordingCommandRunner()
    let hosts = HostsFile(path: path, runner: runner, flushesDNS: true)
    #expect(try hosts.apply(domains: ["www.youtube.com"]))
    #expect(runner.invocations.count == 2)
    #expect(runner.invocations[0].0 == "/usr/bin/dscacheutil")
    #expect(try !hosts.apply(domains: ["www.youtube.com"]))
    #expect(runner.invocations.count == 2)
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    #expect((attrs[.posixPermissions] as? Int) == 0o644)
    #expect(try String(contentsOfFile: path, encoding: .utf8).contains("www.youtube.com"))
}
