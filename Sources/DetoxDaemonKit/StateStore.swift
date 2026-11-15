import DetoxCore
import Foundation

public final class StateStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Missing file → empty state. Corrupt file → moved aside, empty state.
    public func load() throws -> DetoxState {
        guard let data = try? Data(contentsOf: url) else { return DetoxState() }
        do {
            return try JSONDecoder().decode(DetoxState.self, from: data)
        } catch {
            let aside = url.deletingLastPathComponent()
                .appendingPathComponent("state.json.corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: aside)
            return DetoxState()
        }
    }

    public func save(_ state: DetoxState) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        chmod(dir.path, 0o700)
        let tmp = dir.appendingPathComponent(".state.json.tmp")
        try JSONEncoder().encode(state).write(to: tmp)
        chmod(tmp.path, 0o600)
        guard rename(tmp.path, url.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
