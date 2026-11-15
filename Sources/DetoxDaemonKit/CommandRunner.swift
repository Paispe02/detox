import Foundation

public struct CommandResult: Sendable {
    public var status: Int32
    public var stdout: String
    public var stderr: String

    public init(status: Int32 = 0, stdout: String = "", stderr: String = "") {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunning: AnyObject {
    @discardableResult
    func run(_ executable: String, _ arguments: [String], stdin: String?) throws -> CommandResult
}

extension CommandRunning {
    @discardableResult
    public func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        try run(executable, arguments, stdin: nil)
    }
}

public final class ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], stdin: String?) throws -> CommandResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        let input = Pipe()
        p.standardInput = input
        try p.run()
        if let stdin { input.fileHandleForWriting.write(Data(stdin.utf8)) }
        try input.fileHandleForWriting.close()
        let o = out.fileHandleForReading.readDataToEndOfFile()
        let e = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return CommandResult(status: p.terminationStatus,
                             stdout: String(decoding: o, as: UTF8.self),
                             stderr: String(decoding: e, as: UTF8.self))
    }
}

/// Records invocations instead of running them. Used by tests and by `detoxd --root` (dry run).
public final class RecordingCommandRunner: CommandRunning {
    public var invocations: [(String, [String], String?)] = []
    /// Canned results keyed by "executable arg1 arg2...".
    public var scripted: [String: CommandResult] = [:]

    public init() {}

    public func run(_ executable: String, _ arguments: [String], stdin: String?) throws -> CommandResult {
        invocations.append((executable, arguments, stdin))
        return scripted(([executable] + arguments).joined(separator: " "))
    }

    private func scripted(_ key: String) -> CommandResult { scripted[key] ?? CommandResult() }
}
