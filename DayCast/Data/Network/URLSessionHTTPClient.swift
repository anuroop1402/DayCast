import Foundation

/// `HTTPClient` over `URLSession`.
///
/// Its whole job is translation: everything `URLSession` and Open-Meteo can throw at us
/// becomes an `AppError`, so nothing above `Data` ever imports a transport type.
nonisolated struct URLSessionHTTPClient: HTTPClient {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from endpoint: Endpoint) async throws -> Data {
        guard let url = endpoint.url else { throw AppError.unexpected }

        do {
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse else { throw AppError.unexpected }
            guard (200...299).contains(http.statusCode) else {
                throw AppError.server(statusCode: http.statusCode)
            }
            return data

        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw Self.mapped(error)
        } catch is CancellationError {
            throw AppError.cancelled
        } catch {
            throw AppError.unexpected
        }
    }

    /// `URLError` → `AppError`.
    ///
    /// Cancellation is mapped explicitly and separately: a superseded search is a routine
    /// consequence of debouncing, and surfacing it as a failure would flash an error banner
    /// every time the user types another character.
    static func mapped(_ error: URLError) -> AppError {
        switch error.code {
        case .cancelled:
            .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cannotConnectToHost, .cannotFindHost:
            .offline
        case .timedOut:
            .timedOut
        default:
            .unexpected
        }
    }
}
