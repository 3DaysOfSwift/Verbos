import Foundation

// One storage seam enables isolated tests. Features remain concrete types.
protocol SessionRepository: Sendable {
    func fetchSessions() async throws -> [TodaySession]
    func save(_ session: TodaySession) async throws
}
