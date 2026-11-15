import DetoxCore
import DetoxIPC
import Foundation

/// Events the app needs when blocks become active: close open tabs of the newly blocked domains.
public func transitionEvents(previous: [UUID: BlockPhase], current: [UUID: BlockPhase], plan: EnforcementPlan) -> [DaemonEvent] {
    var started: [UUID] = []
    var events: [DaemonEvent] = []
    for (id, phase) in current.sorted(by: { $0.key.uuidString < $1.key.uuidString }) where phase == .active {
        switch previous[id] {
        case .active: continue
        case .paused: events.append(.pauseEnded(blockID: id, domains: plan.domains(of: id)))
        default: started.append(id)
        }
    }
    if !started.isEmpty {
        let domains = Set(started.flatMap { plan.domains(of: $0) }).sorted()
        events.insert(.windowStarted(blockIDs: started, domains: domains), at: 0)
    }
    return events
}
