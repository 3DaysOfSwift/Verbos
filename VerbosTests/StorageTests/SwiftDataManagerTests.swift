import Foundation
import Testing
@testable import Verbos

@MainActor struct SwiftDataManagerTests {
    @Test func sessionDeckAndProgressSurviveReopening() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VerbosTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "nested/Sessions.store")
        let env = try TestEnvironment()
        try await env.start()
        try await env.answerCorrectly()
        let session = try #require(env.today.currentSession)
        let manager = SwiftDataManager(storeURL: storeURL)
        try await manager.save(session)
        let reopened = SwiftDataManager(storeURL: storeURL)
        let sessions = try await reopened.fetchSessions()
        #expect(sessions == [session])
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
    }
}
