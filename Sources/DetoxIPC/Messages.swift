import DetoxCore
import Foundation

public enum Request: Codable, Sendable, Equatable {
    case ping
    case status
    case createBlock(BlockDraft)
    case updateBlock(id: UUID, draft: BlockDraft)
    case deleteBlock(id: UUID)
    case unlock(blockID: UUID, credential: UnlockCredential, action: UnlockAction)
    case registerFriend(name: String)
    case confirmFriend(id: UUID, code: String)
    case deleteFriend(id: UUID)
    case subscribe
}

public struct FriendProvisioning: Codable, Sendable, Equatable {
    public var friendID: UUID
    public var name: String
    public var uri: String

    public init(friendID: UUID, name: String, uri: String) {
        self.friendID = friendID
        self.name = name
        self.uri = uri
    }
}

public enum Response: Codable, Sendable {
    case pong
    case status(StatusSnapshot)
    case block(BlockView)
    case friendProvisioning(FriendProvisioning)
    case ok
    case failure(CommandError)
}

public struct AttemptEvent: Codable, Equatable, Sendable {
    public enum Target: Codable, Equatable, Sendable {
        case domain(String)
        case app(bundleID: String, name: String)
    }

    public var target: Target
    public var blockIDs: [UUID]
    public var blockNames: [String]
    public var isPrimaryDomain: Bool
    public var at: Date

    public init(target: Target, blockIDs: [UUID], blockNames: [String], isPrimaryDomain: Bool, at: Date) {
        self.target = target
        self.blockIDs = blockIDs
        self.blockNames = blockNames
        self.isPrimaryDomain = isPrimaryDomain
        self.at = at
    }
}

public enum DaemonEvent: Codable, Equatable, Sendable {
    case attempt(AttemptEvent)
    case windowStarted(blockIDs: [UUID], domains: [String])
    case pauseEnded(blockID: UUID, domains: [String])
    case stateChanged
}
