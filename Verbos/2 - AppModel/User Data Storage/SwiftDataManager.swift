import Foundation
import SwiftData

@Model
final class StoredSession {
    @Attribute(.unique) var id: UUID
    var payload: Data

    init(id: UUID, payload: Data) {
        self.id = id
        self.payload = payload
    }
}

@Model
final class StoredDoubloonWallet {
    @Attribute(.unique) var identifier: String
    var payload: Data

    init(identifier: String = "doubloon-wallet", payload: Data) {
        self.identifier = identifier
        self.payload = payload
    }
}

@ModelActor
actor SessionStore {
    func fetchSessions() throws -> [TodaySession] {
        try modelContext.fetch(FetchDescriptor<StoredSession>()).map {
            try JSONDecoder().decode(TodaySession.self, from: $0.payload)
        }
    }

    func save(_ session: TodaySession) throws {
        let identifier = session.id
        let descriptor = FetchDescriptor<StoredSession>(predicate: #Predicate { $0.id == identifier })
        let payload = try JSONEncoder().encode(session)
        do {
            if let record = try modelContext.fetch(descriptor).first {
                record.payload = payload
            } else {
                modelContext.insert(StoredSession(id: identifier, payload: payload))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func fetchDoubloonWallet() throws -> DoubloonWallet {
        let descriptor = FetchDescriptor<StoredDoubloonWallet>()
        guard let record = try modelContext.fetch(descriptor).first else { return DoubloonWallet() }
        return try JSONDecoder().decode(DoubloonWallet.self, from: record.payload)
    }

    func saveDoubloonWallet(_ wallet: DoubloonWallet) throws {
        let descriptor = FetchDescriptor<StoredDoubloonWallet>(predicate: #Predicate { $0.identifier == "doubloon-wallet" })
        let payload = try JSONEncoder().encode(wallet)
        do {
            if let record = try modelContext.fetch(descriptor).first {
                record.payload = payload
            } else {
                modelContext.insert(StoredDoubloonWallet(payload: payload))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

actor SwiftDataManager: SessionRepository, DoubloonRepository {
    private let storeURL: URL
    private var sessionStore: SessionStore?

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    private func store() throws -> SessionStore {
        if let sessionStore { return sessionStore }
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(for: StoredSession.self, StoredDoubloonWallet.self, configurations: configuration)
        let store = SessionStore(modelContainer: container)
        sessionStore = store
        return store
    }

    func fetchSessions() async throws -> [TodaySession] {
        try await store().fetchSessions()
    }

    func save(_ session: TodaySession) async throws {
        try await store().save(session)
    }

    func fetchDoubloonWallet() async throws -> DoubloonWallet {
        try await store().fetchDoubloonWallet()
    }

    func saveDoubloonWallet(_ wallet: DoubloonWallet) async throws {
        try await store().saveDoubloonWallet(wallet)
    }
}
