import Foundation
import Testing
@testable import DetoxDaemonKit

@Test func neverSignalsLaunchdOrItself() {
    let procs = [RunningProcess(pid: 1, executablePath: "/x/A.app/Contents/MacOS/launchd"),
                 RunningProcess(pid: getpid(), executablePath: "/x/A.app/Contents/MacOS/me"),
                 RunningProcess(pid: 500, executablePath: "/x/A.app/Contents/MacOS/A")]
    #expect(ProcessTerminator.matches(procs, bundlePaths: ["/x/A.app"]).map(\.0.pid) == [500])
}

@Test func nonUTF8HostsIsNeverOverwritten() throws {
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("hosts-\(UUID().uuidString)")
    let original = Data("# caf".utf8) + Data([0xE9]) + Data("\n127.0.0.1\tlocalhost\n".utf8)   // Latin-1 é
    try original.write(to: URL(fileURLWithPath: path))
    let hosts = HostsFile(path: path, runner: RecordingCommandRunner(), flushesDNS: false)
    #expect(throws: (any Error).self) { try hosts.apply(domains: ["x.com"]) }
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == original)
}

@Test func missingHostsFileIsCreated() throws {
    let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("hosts-\(UUID().uuidString)")
    #expect(try HostsFile(path: path, runner: RecordingCommandRunner(), flushesDNS: false).apply(domains: ["x.com"]))
}

@Test func enforcerResetFlushesStaleAnchor() {
    let r = RecordingCommandRunner()
    let e = Enforcer(hosts: HostsFile(path: "/dev/null", runner: r, flushesDNS: false), packetFilter: PacketFilter(runner: r),
                     chromePolicy: ChromePolicy(plistPath: NSTemporaryDirectory() + "/c-\(UUID()).plist"),
                     terminator: ProcessTerminator(listing: LibprocProcessListing()) { _, _ in 0 }, resolveApp: { _ in nil })
    e.resetFirewall()
    #expect(r.invocations.map { [$0.0] + $0.1 } == [["/sbin/pfctl", "-a", "com.apple/detox", "-F", "all"]])
}
