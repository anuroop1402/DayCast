import Foundation

/// One decoder configuration, shared by every repository.
nonisolated enum OpenMeteoJSON {

    /// **No `keyDecodingStrategy`. Every DTO spells its JSON keys out.**
    ///
    /// `.convertFromSnakeCase` was here first and it silently broke the forecast. It
    /// capitalises each underscore-separated component, so `temperature_2m_max` becomes
    /// `temperature2MMax` — capital `M` — and the obvious `temperature2mMax` never matched.
    /// Because the DTO's columns are optional (they have to be; Open-Meteo nulls variables
    /// it cannot produce), nothing threw: every temperature decoded as `nil`, the mapper
    /// dropped all seven days, and the repository reported `AppError.noResults` on a
    /// perfectly good response. Every Open-Meteo variable that matters here carries a
    /// number — `2m`, `10m` — so this was not an edge case.
    ///
    /// Explicit `CodingKeys` cost a few lines and can be diffed against the API docs.
    /// A key strategy cannot.
    static let decoder = JSONDecoder()

    /// Decodes, translating any failure into `AppError.decoding`.
    ///
    /// A decoding failure is our bug, not the user's problem, so it is deliberately opaque
    /// at this boundary — `AppError.decoding` is not retryable and the UI says "something
    /// went wrong" rather than surfacing a key path.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AppError.decoding
        }
    }
}
