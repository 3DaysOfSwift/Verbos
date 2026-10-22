import Foundation

actor NetworkingManager {
    private let session: URLSession

    init() {
        // The repository owns the verified offline snapshot; avoid a second disk cache.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func fetch(_ url: URL, maximumBytes: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.scheme == "https", response.expectedContentLength <= maximumBytes else {
            throw URLError(.badServerResponse)
        }
        var data = Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < maximumBytes else { throw LearningContentError.invalidCatalogue }
            data.append(byte)
        }
        return data
    }
}
