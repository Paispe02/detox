import DetoxCore
import Foundation
import Testing
@testable import DetoxAppKit

private let now = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15

private func runningView(lock: LockSummary = .password, services: Set<ServiceID> = [.youtube, .instagram]) -> BlockView {
    BlockView(id: UUID(), name: "Noches", targets: BlockTargets(services: services, domains: ["reddit.com"]),
              window: DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)), weekdays: Set(Weekday.allCases),
              startDate: LocalDate(2027, 1, 1), endDate: LocalDate(2027, 1, 31), timeZoneID: "Europe/Madrid",
              lock: lock, pauseMinutes: 15, phase: .running, pausedUntil: nil, activeWindowEnd: nil,
              nextWindowStart: nil, commitmentEnd: now, progressCurrent: 14, progressTotal: 31)
}

private let ana = FriendView(id: UUID(), name: "Ana", isConfirmed: true, blockNames: [])

@MainActor @Test func newBlockDefaultsMatchSpec() {
    let m = EditorModel(existing: nil, friends: [], now: now)
    #expect(m.draft.window == DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)))
    #expect(m.draft.weekdays.count == 7 && m.draft.pauseMinutes == 15)
    #expect(m.lockChoice == .password && !m.isRunning)
    #expect(m.draft.timeZoneID == TimeZone.current.identifier)
}

@MainActor @Test func runningBlockCannotRemoveService() {
    let m = EditorModel(existing: runningView(), friends: [], now: now)
    #expect(m.isRunning)
    #expect(!m.canRemove(service: .youtube))
    #expect(m.canRemove(service: .tiktok))   // not in the block: adding is always allowed
    #expect(!m.canRemove(domain: "reddit.com"))
}

@MainActor @Test func runningBlockMinimumEndDateIsCurrentEnd() {
    #expect(EditorModel(existing: runningView(), friends: [], now: now).minimumEndDate == LocalDate(2027, 1, 31))
}

@MainActor @Test func runningBlockLockChoicesOnlyStricter() {
    let fromPassword = EditorModel(existing: runningView(lock: .password), friends: [ana], now: now)
    #expect(fromPassword.allowedLockKinds == [.password, .friend(ana.id), .noExit])
    let fromFriend = EditorModel(existing: runningView(lock: .friend(id: ana.id, name: "Ana")), friends: [ana], now: now)
    #expect(fromFriend.allowedLockKinds == [.friend(ana.id), .noExit])
    let fromNoExit = EditorModel(existing: runningView(lock: .noExit), friends: [ana], now: now)
    #expect(fromNoExit.allowedLockKinds == [.noExit])
}

@MainActor @Test func newBlockOffersOnlyConfirmedFriends() {
    let pending = FriendView(id: UUID(), name: "Luis", isConfirmed: false, blockNames: [])
    let m = EditorModel(existing: nil, friends: [ana, pending], now: now)
    #expect(m.allowedLockKinds == [.password, .friend(ana.id), .noExit])
}

@MainActor @Test func noExitRequiresCommitmentPhrase() {
    let m = EditorModel(existing: nil, friends: [], now: now)
    m.draft.targets.services = [.youtube]
    m.lockChoice = .noExit
    m.commitmentPhrase = "me compro"
    #expect(!m.canSubmit)
    m.commitmentPhrase = "Me comprometo "
    #expect(m.canSubmit)
}

@MainActor @Test func passwordNeedsFourCharsOnNewBlock() {
    let m = EditorModel(existing: nil, friends: [], now: now)
    m.draft.targets.services = [.youtube]
    m.password = "12"
    #expect(!m.canSubmit && m.validationMessage != nil)
    m.password = "1234"
    #expect(m.canSubmit)
}

@MainActor @Test func customDomainErrorMessage() {
    let m = EditorModel(existing: nil, friends: [], now: now)
    m.customDomainInput = "no es un dominio"
    #expect(m.addCustomDomain() == "Escribe un dominio como instagram.com")
    m.customDomainInput = "https://www.Twitch.tv/directory"
    #expect(m.addCustomDomain() == nil)
    #expect(m.draft.targets.domains == ["www.twitch.tv"] && m.customDomainInput.isEmpty)
}

@MainActor @Test func pauseRangeShrinksWhenRunning() {
    #expect(EditorModel(existing: nil, friends: [], now: now).pauseRange == 5...60)
    #expect(EditorModel(existing: runningView(), friends: [], now: now).pauseRange == 5...15)
}

@MainActor @Test func runningPasswordBlockSendsUnchangedLock() {
    let m = EditorModel(existing: runningView(), friends: [], now: now)
    #expect(m.makeDraft().lock == .unchanged)
    m.lockChoice = .noExit
    #expect(m.makeDraft().lock == .noExit)
}
