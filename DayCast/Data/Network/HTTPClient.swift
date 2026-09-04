import Foundation

/// Transport. Returns raw bytes and throws `AppError` — never `URLError`, never an HTTP
/// status code.
///
/// This is the seam the repositories are tested against. Because it sits *below* decoding,
/// a repository test stubs bytes and then exercises the real URL construction, the real
/// JSON decoding and the real DTO→entity mapping. Putting the seam any higher would leave
/// all three untested.
protocol HTTPClient: Sendable {
    func data(from endpoint: Endpoint) async throws -> Data
}
