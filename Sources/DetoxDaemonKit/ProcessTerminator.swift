import Darwin
import Foundation

public struct RunningProcess: Equatable, Sendable {
    public var pid: pid_t
    public var executablePath: String

    public init(pid: pid_t, executablePath: String) {
        self.pid = pid
        self.executablePath = executablePath
    }
}

public protocol ProcessListing {
    func list() -> [RunningProcess]
}

public final class LibprocProcessListing: ProcessListing {
    public init() {}

    public func list() -> [RunningProcess] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var out: [RunningProcess] = []
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        for pid in pids.prefix(Int(max(n, 0))) where pid > 0 {
            if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 {
                out.append(RunningProcess(pid: pid, executablePath: String(cString: buf)))
            }
        }
        return out
    }
}

public enum AppResolver {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: String] = [:]
    nonisolated(unsafe) private static var cacheTime = Date.distantPast

    public static func bundlePath(forBundleID id: String,
                                  searchDirectories: [String] = ["/Applications", "/System/Applications"]) -> String? {
        lock.lock(); defer { lock.unlock() }
        if Date().timeIntervalSince(cacheTime) > 300 {
            cache = scan(searchDirectories)
            cacheTime = Date()
        }
        return cache[id]
    }

    private static func scan(_ dirs: [String]) -> [String: String] {
        var result: [String: String] = [:]
        let fm = FileManager.default
        func visit(_ dir: String, depth: Int) {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for item in items {
                let path = (dir as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    if let info = NSDictionary(contentsOfFile: path + "/Contents/Info.plist"),
                       let bid = info["CFBundleIdentifier"] as? String, result[bid] == nil {
                        result[bid] = path
                    }
                } else if depth < 2 {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue { visit(path, depth: depth + 1) }
                }
            }
        }
        dirs.forEach { visit($0, depth: 1) }
        return result
    }
}

public struct TerminatedApp: Equatable, Sendable {
    public var bundlePath: String
    public var pid: pid_t
}

/// SIGTERM on first sighting, SIGKILL if still alive next time. Returns only newly seen processes.
public final class ProcessTerminator {
    private let listing: ProcessListing
    private let signal: (pid_t, Int32) -> Int32
    private var seen: Set<pid_t> = []

    public init(listing: ProcessListing, signal: @escaping (pid_t, Int32) -> Int32 = { Darwin.kill($0, $1) }) {
        self.listing = listing
        self.signal = signal
    }

    public static func matches(_ processes: [RunningProcess], bundlePaths: [String]) -> [(RunningProcess, String)] {
        processes.compactMap { p in
            bundlePaths.first { p.executablePath.hasPrefix($0 + "/") }.map { (p, $0) }
        }
    }

    public func terminate(bundlePaths: [String]) -> [TerminatedApp] {
        guard !bundlePaths.isEmpty else { seen = []; return [] }
        let hits = Self.matches(listing.list(), bundlePaths: bundlePaths)
        var fresh: [TerminatedApp] = []
        var nowSeen: Set<pid_t> = []
        for (p, bundle) in hits {
            nowSeen.insert(p.pid)
            if seen.contains(p.pid) {
                _ = signal(p.pid, SIGKILL)
            } else {
                _ = signal(p.pid, SIGTERM)
                fresh.append(TerminatedApp(bundlePath: bundle, pid: p.pid))
            }
        }
        seen = nowSeen
        return fresh
    }
}
