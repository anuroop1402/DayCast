import Foundation

nonisolated struct OpenMeteoCitySearchRepository: CitySearchRepository {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func searchCities(matching query: String) async throws -> [City] {
        let data = try await client.data(from: .geocoding(query: query))
        let response = try OpenMeteoJSON.decode(GeocodingResponseDTO.self, from: data)

        // A missing `results` key means no matches, not a failure. Returning an empty array
        // lets the caller show an empty state instead of an error.
        return (response.results ?? []).map(CityMapper.map)
    }
}
