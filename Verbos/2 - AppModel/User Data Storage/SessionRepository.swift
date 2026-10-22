import Foundation

// One storage seam enables isolated tests. Features remain concrete types.
protocol SessionRepository: Sendable {
    func fetchSessions() async throws -> [TodaySession]
    func save(_ session: TodaySession) async throws
}

// This storage seam preserves one app-owned store while enabling isolated wallet tests.
protocol DoubloonRepository: Sendable {
    func fetchDoubloonWallet() async throws -> DoubloonWallet
    func saveDoubloonWallet(_ wallet: DoubloonWallet) async throws
}
