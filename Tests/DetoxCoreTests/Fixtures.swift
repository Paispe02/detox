import Foundation
@testable import DetoxCore

let madridTZ = TimeZone(identifier: "Europe/Madrid")!

func madrid(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = madridTZ
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

extension PasswordHash {
    static let dummy = PasswordHash(salt: Data(repeating: 1, count: 16), iterations: 1, hash: Data(repeating: 2, count: 32))
}

extension Block {
    static func fixture(
        name: String = "Noches limpias",
        targets: BlockTargets = BlockTargets(services: [.youtube]),
        window: DailyWindow = DailyWindow(start: LocalTime(22, 30), end: LocalTime(6, 0)),
        weekdays: Set<Weekday> = Set(Weekday.allCases),
        startDate: LocalDate = LocalDate(2026, 12, 1),
        endDate: LocalDate = LocalDate(2026, 12, 31),
        timeZoneID: String = "Europe/Madrid",
        lock: Lock = .noExit,
        pauseMinutes: Int = 15
    ) -> Block {
        Block(id: UUID(), name: name, targets: targets, window: window, weekdays: weekdays,
              startDate: startDate, endDate: endDate, timeZoneID: timeZoneID, lock: lock,
              pauseMinutes: pauseMinutes, pausedUntil: nil, cancelledAt: nil)
    }
}
