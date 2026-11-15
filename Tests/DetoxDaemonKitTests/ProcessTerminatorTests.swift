import Foundation
import Testing
@testable import DetoxDaemonKit

private final class FakeListing: ProcessListing {
    var processes: [RunningProcess] = []
    func list() -> [RunningProcess] { processes }
}

@Test func matchesHelpersInsideBundle() {
    let procs = [RunningProcess(pid: 10, executablePath: "/Applications/WhatsApp.app/Contents/MacOS/WhatsApp"),
                 RunningProcess(pid: 11, executablePath: "/Applications/WhatsApp.app/Contents/Frameworks/x.app/Contents/MacOS/x"),
                 RunningProcess(pid: 12, executablePath: "/Applications/Safari.app/Contents/MacOS/Safari")]
    #expect(ProcessTerminator.matches(procs, bundlePaths: ["/Applications/WhatsApp.app"]).map(\.0.pid) == [10, 11])
}

@Test func doesNotMatchSimilarPrefix() {
    let procs = [RunningProcess(pid: 10, executablePath: "/Applications/WhatsApp.app2/Contents/MacOS/x")]
    #expect(ProcessTerminator.matches(procs, bundlePaths: ["/Applications/WhatsApp.app"]).isEmpty)
}

@Test func escalatesToSigkillOnSecondSighting() {
    let listing = FakeListing()
    listing.processes = [RunningProcess(pid: 10, executablePath: "/Applications/WhatsApp.app/Contents/MacOS/WhatsApp")]
    var sent: [(pid_t, Int32)] = []
    let t = ProcessTerminator(listing: listing) { pid, sig in sent.append((pid, sig)); return 0 }
    let first = t.terminate(bundlePaths: ["/Applications/WhatsApp.app"])
    #expect(first == [TerminatedApp(bundlePath: "/Applications/WhatsApp.app", pid: 10)])
    _ = t.terminate(bundlePaths: ["/Applications/WhatsApp.app"])
    #expect(sent.map(\.1) == [SIGTERM, SIGKILL])
    listing.processes = []
    #expect(t.terminate(bundlePaths: ["/Applications/WhatsApp.app"]).isEmpty)
}

@Test func secondSightingIsNotReportedAsNewAttempt() {
    let listing = FakeListing()
    listing.processes = [RunningProcess(pid: 10, executablePath: "/Applications/W.app/Contents/MacOS/W")]
    let t = ProcessTerminator(listing: listing) { _, _ in 0 }
    #expect(t.terminate(bundlePaths: ["/Applications/W.app"]).count == 1)
    #expect(t.terminate(bundlePaths: ["/Applications/W.app"]).isEmpty)
}

@Test func libprocListsThisProcess() {
    let me = LibprocProcessListing().list().first { $0.pid == getpid() }
    #expect(me != nil && !(me?.executablePath.isEmpty ?? true))
}

@Test func appResolverFindsSafari() {
    #expect(AppResolver.bundlePath(forBundleID: "com.apple.Safari") == "/Applications/Safari.app")
}
