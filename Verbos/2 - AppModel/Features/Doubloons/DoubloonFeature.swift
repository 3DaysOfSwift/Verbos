import Foundation
import Observation

struct DoubloonWallet: Codable, Equatable, Sendable {
    var balance = 0
    var rewardedDays: Set<Date> = []
    var rewardedSessionMilestones: [UUID: Int] = [:]
    var unlockedBookDay: Date?
    var unlockedBookID: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case balance, rewardedDays, rewardedSessionMilestones, unlockedBookDay, unlockedBookID
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        balance = try values.decode(Int.self, forKey: .balance)
        rewardedDays = try values.decode(Set<Date>.self, forKey: .rewardedDays)
        rewardedSessionMilestones = try values.decodeIfPresent([UUID: Int].self, forKey: .rewardedSessionMilestones) ?? [:]
        unlockedBookDay = try values.decodeIfPresent(Date.self, forKey: .unlockedBookDay)
        unlockedBookID = try values.decodeIfPresent(String.self, forKey: .unlockedBookID)
    }
}

enum DoubloonError: LocalizedError {
    case insufficientBalance

    var errorDescription: String? {
        switch self {
        case .insufficientBalance: "Score ten correct answers to earn a doubloon."
        }
    }
}

// This feature owns earned doubloons and the one daily book they unlock.
@MainActor @Observable
final class DoubloonFeature {
    private(set) var wallet = DoubloonWallet()
    private(set) var hasLoaded = false
    private let repository: any DoubloonRepository
    private let calendar: Calendar
    private let now: () -> Date
    @ObservationIgnored private var operationTask: Task<Void, Error>?
    @ObservationIgnored private var operationID: UUID?

    init(repository: any DoubloonRepository, calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    var balance: Int { wallet.balance }

    func earnedDoubloons(for sessionID: UUID) -> Int {
        wallet.rewardedSessionMilestones[sessionID, default: 0]
    }

    func unlockedBookID(for day: Date) -> String? {
        guard let unlockedBookDay = wallet.unlockedBookDay,
              calendar.isDate(unlockedBookDay, inSameDayAs: day) else { return nil }
        return wallet.unlockedBookID
    }

    func load() async throws {
        try await perform(.load)
    }

    func awardProgress(for session: TodaySession) async throws {
        try await perform(.award(session))
    }

    func unlockDailyBook(id: String, on day: Date) async throws {
        try await perform(.unlock(bookID: id, day: calendar.startOfDay(for: day)))
    }

    private enum Command {
        case load
        case award(TodaySession)
        case unlock(bookID: String, day: Date)
    }

    private func perform(_ command: Command) async throws {
        let predecessor = operationTask
        let identifier = UUID()
        let task = Task { @MainActor in
            _ = try? await predecessor?.value
            try Task.checkCancellation()
            try await execute(command)
        }
        operationTask = task
        operationID = identifier
        defer {
            if operationID == identifier {
                operationTask = nil
                operationID = nil
            }
        }
        try await task.value
    }

    private func execute(_ command: Command) async throws {
        if !hasLoaded {
            wallet = try await repository.fetchDoubloonWallet()
            hasLoaded = true
        }
        switch command {
        case .load:
            return
        case let .award(session):
            let milestones = min(TodaySession.target, max(0, session.correctCount)) / 10
            guard milestones > 0 else { return }
            var proposedWallet = wallet
            let day = calendar.startOfDay(for: session.day)
            // A legacy daily-completion coin already paid for one of this session's milestones.
            if !session.isExtraPractice, session.isComplete,
               proposedWallet.rewardedSessionMilestones[session.id] == nil,
               proposedWallet.rewardedDays.contains(day) {
                proposedWallet.rewardedSessionMilestones[session.id] = 1
                proposedWallet.rewardedDays.remove(day)
            }
            let previouslyAwarded = proposedWallet.rewardedSessionMilestones[session.id, default: 0]
            proposedWallet.balance += max(0, milestones - previouslyAwarded)
            proposedWallet.rewardedSessionMilestones[session.id] = max(milestones, previouslyAwarded)
            guard proposedWallet != wallet else { return }
            try await repository.saveDoubloonWallet(proposedWallet)
            wallet = proposedWallet
        case let .unlock(bookID, day):
            if unlockedBookID(for: day) != nil { return }
            guard wallet.balance > 0 else { throw DoubloonError.insufficientBalance }
            var proposedWallet = wallet
            proposedWallet.balance -= 1
            proposedWallet.unlockedBookDay = day
            proposedWallet.unlockedBookID = bookID
            try await repository.saveDoubloonWallet(proposedWallet)
            wallet = proposedWallet
        }
    }
}
