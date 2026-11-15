import DetoxCore
import DetoxDaemonKit
import DetoxIPC
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let args = CommandLine.arguments

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

/// Runs an async request synchronously (used by the one-shot commands).
func ask(_ request: Request, socket: String) -> Response? {
    let sem = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Response?
    Task {
        result = try? await DetoxClient(socketPath: socket).send(request)
        sem.signal()
    }
    sem.wait()
    return result
}

if args.contains("--can-uninstall") {
    guard case .status(let s)? = ask(.status, socket: DaemonPaths.production.socketPath) else {
        fail("No se pudo hablar con el servicio de Detox.")
    }
    let busy = s.blocks.filter { [.running, .active, .paused].contains($0.phase) }
    if let last = busy.map(\.commitmentEnd).max() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM, HH:mm"
        fail("Hay bloqueos en marcha; no se puede desinstalar hasta el \(f.string(from: last)).")
    }
    exit(0)
}

if args.contains("--cleanup") {
    Daemon(paths: .production, dryRun: false).cleanupSystem()
    exit(0)
}

let paths: DaemonPaths
let dryRun: Bool
if let i = args.firstIndex(of: "--root"), i + 1 < args.count {
    let root = URL(fileURLWithPath: args[i + 1])
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    paths = .testing(root: root)
    dryRun = true
} else {
    guard getuid() == 0 else { fail("detoxd debe ejecutarse como root (o con --root <dir> para pruebas).") }
    paths = .production
    dryRun = false
}

signal(SIGPIPE, SIG_IGN)
let daemon = Daemon(paths: paths, dryRun: dryRun)
do {
    try daemon.start()
} catch {
    fail("detoxd: no se pudo arrancar: \(error)")
}
print("detoxd en marcha (\(dryRun ? "modo pruebas" : "producción")), socket \(paths.socketPath)")
dispatchMain()
