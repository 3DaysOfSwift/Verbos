import Foundation

// Cuentiva's six table slots. Explicit people remove ambiguity from bare verb forms.
enum ConjugationQuestions {
    private static let spanishPeople = ["yo", "tú", "él", "nosotros", "vosotros", "ellos"]
    private static let englishPeople = ["I", "You (singular)", "He", "We", "You (plural)", "They"]

    static func translation(verb: LearningVerb, tense: LearningMode, person: Int) throws -> String {
        guard (0..<6).contains(person) else { throw LearningContentError.unavailableTranslation }
        let verbText: String
        switch tense {
        case .present:
            verbText = ["ser", "estar"].contains(verb.id)
                ? ["am", "are", "is", "are", "are", "are"][person]
                : person == 2 ? verb.third : verb.english
        case .preterite:
            verbText = ["ser", "estar"].contains(verb.id)
                ? ["was", "were", "was", "were", "were", "were"][person] : verb.past
        case .imperfect: verbText = "used to " + verb.english
        case .future: verbText = "will " + verb.english
        case .mixed: throw LearningContentError.unavailableTranslation
        }
        return englishPeople[person] + " " + verbText
    }

    static func make(verb: LearningVerb, mode: LearningMode) throws -> [WordQuestion] {
        // Distractors change person or tense, never introduce synonyms of the correct option.
        var translations: Set<String> = []
        for tense in [LearningMode.present, .preterite, .imperfect, .future] {
            guard let forms = verb.forms[tense.rawValue], forms.count == 6,
                  forms.allSatisfy({ !$0.isEmpty }) else { throw LearningContentError.unavailableTranslation }
            for person in 0..<6 {
                translations.insert(try translation(verb: verb, tense: tense, person: person))
            }
        }
        guard translations.count >= 9 else { throw LearningContentError.unavailableTranslation }
        var questions: [WordQuestion] = []
        for tense in mode.tenses {
            guard let forms = verb.forms[tense.rawValue] else { throw LearningContentError.unavailableTranslation }
            for person in 0..<6 {
                let answer = try translation(verb: verb, tense: tense, person: person)
                let distractors = translations.filter { $0 != answer }.shuffled().prefix(8)
                questions.append(WordQuestion(id: UUID(), spanish: forms[person],
                    person: spanishPeople[person], verbID: verb.id, tense: tense,
                    answer: answer, choices: (Array(distractors) + [answer]).shuffled(),
                    example: example(verb: verb, answer: answer)))
            }
        }
        return questions.shuffled()
    }

    static func example(verb: LearningVerb, answer: String) -> VerbExample {
        let naturalAnswer = answer
            .replacingOccurrences(of: " (singular)", with: "")
            .replacingOccurrences(of: " (plural)", with: "")
        return VerbExample(spanishEnding: verb.tail + ".",
                           english: naturalAnswer + " " + verb.englishTail + ".")
    }
}
