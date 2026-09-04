import Foundation
@testable import DayCast

/// Stubs transport, keyed by host, so a single stub can serve a repository that talks to
/// more than one Open-Meteo API.
///
/// `@unchecked Sendable`: mutated only from the single task each test runs.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {

    private var responses: [String: Result<Data, AppError>] = [:]
    private(set) var requested: [Endpoint] = []

    init() {}

    @discardableResult
    func stub(host: String, with result: Result<Data, AppError>) -> Self {
        responses[host] = result
        return self
    }

    @discardableResult
    func stub(host: String, fixture: String) throws -> Self {
        stub(host: host, with: .success(try Fixture.data(fixture)))
    }

    func data(from endpoint: Endpoint) async throws -> Data {
        requested.append(endpoint)
        guard let response = responses[endpoint.host] else {
            throw AppError.unexpected
        }
        return try response.get()
    }

    // Convenience accessors used by assertions.
    var geocodingHost: String { "geocoding-api.open-meteo.com" }
    var forecastHost: String { "api.open-meteo.com" }
    var marineHost: String { "marine-api.open-meteo.com" }
}
