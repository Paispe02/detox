import Combine
import DetoxCore
import DetoxIPC
import Foundation

/// The app's only link to detoxd: polls status, relays events, performs requests.
@MainActor
public final class DaemonConnection: ObservableObject {
    @Published public private(set) var snapshot: StatusSnapshot?
    @Published public private(set) var isDaemonReachable = true

    private let client: DaemonClienting
    private var pollTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<DaemonEvent>.Continuation] = [:]

    public init(client: DaemonClienting) {
        self.client = client
    }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        eventTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    for try await event in self.client.events() {
                        self.continuations.values.forEach { $0.yield(event) }
                        if case .stateChanged = event { await self.refresh() }
                    }
                } catch {}
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    /// A fresh stream of daemon events for one consumer.
    public var events: AsyncStream<DaemonEvent> {
        let id = UUID()
        return AsyncStream { cont in
            continuations[id] = cont
            cont.onTermination = { [weak self] _ in Task { @MainActor in self?.continuations[id] = nil } }
        }
    }

    public func refresh() async {
        if case .success(.status(let s)) = await perform(.status) { snapshot = s }
    }

    @discardableResult
    public func perform(_ request: Request) async -> Result<Response, CommandError> {
        do {
            let r = try await client.send(request)
            isDaemonReachable = true
            if case .failure(let e) = r { return .failure(e) }
            return .success(r)
        } catch {
            isDaemonReachable = false
            return .failure(.daemonUnavailable)
        }
    }
}
