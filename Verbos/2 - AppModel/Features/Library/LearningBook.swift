import Foundation

struct LearningBook: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let englishTitle: String
    let author: String
    let license: String
    let verbFocus: VerbFocus?
    let sentences: [BookSentence]
    let continuation: [BookSentence]?
    let ending: [BookSentence]?
    var fullText: [BookSentence] { sentences + (continuation ?? []) + (ending ?? []) }

    struct VerbFocus: Codable, Sendable {
        let infinitive: String
        let tense: String
    }
}

struct BookSentence: Codable, Identifiable, Sendable {
    let id: String
    let spanish: String
    let english: String
}

struct LearningVerb: Codable, Identifiable, Sendable {
    let id: String
    let english: String
    let third: String
    let past: String
    let tail: String
    let englishTail: String
    let forms: [String: [String]]
}

enum LearningMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case present, preterite, imperfect, future, mixed
    var id: Self { self }
    var title: String {
        switch self {
        case .present: "Present"
        case .preterite: "Finished past"
        case .imperfect: "Used to"
        case .future: "Future"
        case .mixed: "Past & future"
        }
    }
    var detail: String {
        switch self {
        case .present: "What happens now or regularly."
        case .preterite: "A completed past event: I was, I wanted."
        case .imperfect: "Past habits or background: I used to be."
        case .future: "What will happen: I will be."
        case .mixed: "Recognise finished past, past habits and future forms."
        }
    }
    var tenses: [LearningMode] {
        self == .mixed ? [.preterite, .imperfect, .future] : [self]
    }
}

enum LearningContentError: LocalizedError {
    case missingContent, invalidCatalogue, unavailableBook, unavailableTranslation
    var errorDescription: String? {
        switch self {
        case .missingContent: "The learning content could not be opened. Please try again."
        case .invalidCatalogue: "The downloaded catalogue could not be verified. Your existing books have been kept."
        case .unavailableBook: "This verb does not yet have a supported Cuentiva book."
        case .unavailableTranslation: "This verb does not have enough distinct translations for a question."
        }
    }
}
