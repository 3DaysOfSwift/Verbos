import Foundation

struct WordQuestion: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let spanish: String
    let person: String
    let verbID: String
    let tense: LearningMode
    let answer: String
    let choices: [String]
    var wrongAnswers: Set<String> = []
    var isRevealed = false
    var isAnswered = false
    var isResolved: Bool { isRevealed || isAnswered }

    func freshCopy() -> Self {
        Self(id: UUID(), spanish: spanish, person: person, verbID: verbID, tense: tense,
             answer: answer, choices: choices.shuffled())
    }
}

struct TodaySession: Codable, Equatable, Identifiable, Sendable {
    static let target = 20
    let id: UUID
    let day: Date
    let isExtraPractice: Bool
    var mode: LearningMode
    var verbID: String
    var bookTitle: String
    // A durable deck keeps resumed sessions independent of network/content changes.
    var deck: [WordQuestion]
    var question: WordQuestion
    var questionNumber = 1
    var correctCount = 0
    var completedAt: Date?
    var isComplete: Bool { completedAt != nil }
    var canChangeFocus: Bool { questionNumber == 1 && !isComplete }
}

enum TodayError: LocalizedError {
    case unavailableSession, staleQuestion, focusLocked, unresolvedQuestion
    var errorDescription: String? {
        switch self {
        case .unavailableSession: "This session is no longer available. Refresh to see today's practice."
        case .staleQuestion: "The question has changed. Please answer the question now on screen."
        case .focusLocked: "Your verb and learning mode are fixed after the first question."
        case .unresolvedQuestion: "Find or reveal the correct answer before continuing."
        }
    }
}
