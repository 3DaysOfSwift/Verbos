import Foundation
import CryptoKit

struct LearningContent: Sendable {
    let books: [LearningBook]
    let verbs: [LearningVerb]
}

protocol LearningContentRepository: Sendable {
    func load() async throws -> LearningContent
    func refreshBooks() async throws -> [LearningBook]
}

// Same public release feed and pack validation used by Cuentiva.
// Verb forms come from its maintained catalogue.json, bundled unchanged.
actor CuentivaContentRepository: LearningContentRepository {
    private let bundle: Bundle
    private let cacheURL: URL
    private let networkingManager: NetworkingManager
    private var updateTask: Task<[LearningBook], Error>?

    init(bundle: Bundle = .main, cacheURL: URL, networkingManager: NetworkingManager) {
        self.bundle = bundle
        self.cacheURL = cacheURL
        self.networkingManager = networkingManager
    }

    func load() throws -> LearningContent {
        guard let booksURL = bundle.url(forResource: "books", withExtension: "json"),
              let verbsURL = bundle.url(forResource: "verbs", withExtension: "json") else {
            throw LearningContentError.missingContent
        }
        let bundled = try JSONDecoder().decode([LearningBook].self, from: Data(contentsOf: booksURL))
        let verbs = try JSONDecoder().decode([LearningVerb].self, from: Data(contentsOf: verbsURL))
        // A failed cache read is a recoverable content error, never erased user progress.
        let books: [LearningBook]
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            books = try JSONDecoder().decode([LearningBook].self, from: Data(contentsOf: cacheURL))
        } else {
            books = bundled
        }
        try validate(books: books, verbs: verbs)
        return LearningContent(books: books, verbs: verbs)
    }

    func refreshBooks() async throws -> [LearningBook] {
        if let updateTask { return try await updateTask.value }
        let task = Task { try await self.downloadBooks() }
        updateTask = task
        defer { updateTask = nil }
        return try await task.value
    }

    private func downloadBooks() async throws -> [LearningBook] {
        guard let endpoint = URL(string: "https://github.com/3DaysOfSwift/GlobalEnglish-SpanishLearningBooksCollection") else {
            throw LearningContentError.invalidCatalogue
        }
        let manifestData = try await networkingManager.fetch(
            endpoint.appending(path: "releases/latest/download/catalogue.json"), maximumBytes: 409_600)
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.schema == 2, !manifest.packs.isEmpty, manifest.packs.count <= 2000,
              Set(manifest.packs.map(\.id)).count == manifest.packs.count,
              manifest.packs.allSatisfy(\.isValid),
              manifest.packs.reduce(0, { $0 + $1.bytes }) <= 268_435_456 else {
            throw LearningContentError.invalidCatalogue
        }
        var books: [LearningBook] = []
        for descriptor in manifest.packs {
            let path = "releases/download/\(descriptor.release)/\(descriptor.id)-\(descriptor.checksum).json"
            let bytes = try await networkingManager.fetch(endpoint.appending(path: path), maximumBytes: descriptor.bytes)
            let checksum = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard bytes.count == descriptor.bytes, checksum == descriptor.checksum else {
                throw LearningContentError.invalidCatalogue
            }
            let pack = try JSONDecoder().decode(Pack.self, from: bytes)
            guard pack.schema == 2, pack.id == descriptor.id, pack.books.count == descriptor.books else {
                throw LearningContentError.invalidCatalogue
            }
            books.append(contentsOf: pack.books)
        }
        guard let verbsURL = bundle.url(forResource: "verbs", withExtension: "json") else {
            throw LearningContentError.missingContent
        }
        let verbs = try JSONDecoder().decode([LearningVerb].self, from: Data(contentsOf: verbsURL))
        try validate(books: books, verbs: verbs)
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(books).write(to: cacheURL, options: .atomic)
        return books
    }

    private func validate(books: [LearningBook], verbs: [LearningVerb]) throws {
        guard !books.isEmpty, Set(books.map(\.id)).count == books.count,
              Set(verbs.map(\.id)).count == verbs.count,
              books.allSatisfy({ !$0.title.isEmpty && !$0.fullText.isEmpty &&
                  $0.fullText.allSatisfy { !$0.spanish.isEmpty && !$0.english.isEmpty } }),
              books.contains(where: { $0.verbFocus?.infinitive == "ser" }) else {
            throw LearningContentError.invalidCatalogue
        }
        for verb in verbs where ["ser", "estar", "querer"].contains(verb.id) {
            _ = try ConjugationQuestions.make(verb: verb, mode: .mixed)
        }
    }

    private struct Manifest: Decodable { let schema: Int; let packs: [Descriptor] }
    private struct Pack: Decodable { let schema: Int; let id: String; let books: [LearningBook] }
    private struct Descriptor: Decodable {
        let id: String
        let release: String
        let checksum: String
        let bytes: Int
        let books: Int
        var isValid: Bool {
            func safe(_ text: String) -> Bool {
                !text.isEmpty && text.count <= 100 &&
                text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            }
            return safe(id) && safe(release) && checksum.count == 64 &&
                checksum.allSatisfy { "0123456789abcdef".contains($0) } &&
                bytes > 0 && bytes <= 409_600 && books > 0 && books <= 13
        }
    }
}
