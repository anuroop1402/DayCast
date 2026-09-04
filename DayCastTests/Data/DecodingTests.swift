import Testing
import Foundation
@testable import DayCast

/// Decoding is tested against **responses actually captured from Open-Meteo**, not
/// hand-written JSON. Hand-written fixtures encode what you *assumed* the API returns, and
/// both of the traps below were assumptions I had already written into the code before
/// checking.
struct GeocodingDecodingTests {

    @Test("A real search response decodes into cities")
    func decodesOslo() throws {
        let response = try OpenMeteoJSON.decode(
            GeocodingResponseDTO.self, from: Fixture.data("geocoding-oslo.json")
        )
        let cities = (response.results ?? []).map(CityMapper.map)

        #expect(cities.count == 5)

        let oslo = try #require(cities.first)
        #expect(oslo.id == 3143244)
        #expect(oslo.name == "Oslo")
        #expect(oslo.country == "Norway")
        #expect(oslo.admin1 == "Oslo")
        #expect(oslo.timezone == "Europe/Oslo")
        #expect(abs(oslo.latitude - 59.91273) < 0.0001)
    }

    @Test("A search with no matches omits the results key entirely")
    func noMatchesIsNotAnError() throws {
        // Open-Meteo returns {"generationtime_ms": 0.8} — no "results" key at all.
        // A non-optional array here would throw keyNotFound on a successful request and
        // turn "no cities found" into an error banner.
        let response = try OpenMeteoJSON.decode(
            GeocodingResponseDTO.self, from: Fixture.data("geocoding-no-results.json")
        )
        #expect(response.results == nil)
        #expect((response.results ?? []).isEmpty)
    }

    @Test("Same-named cities are distinguished by region")
    func duplicateNamesCarryRegion() throws {
        let response = try OpenMeteoJSON.decode(
            GeocodingResponseDTO.self, from: Fixture.data("geocoding-oslo.json")
        )
        let cities = (response.results ?? []).map(CityMapper.map)
        let names = Set(cities.map(\.name))

        #expect(names.count < cities.count, "fixture should contain repeated names")
        #expect(Set(cities.map(\.id)).count == cities.count, "ids must be unique")
    }
}

struct ForecastDecodingTests {

    private func forecast() throws -> [DailyWeather] {
        ForecastMapper.map(
            try OpenMeteoJSON.decode(
                ForecastResponseDTO.self, from: Fixture.data("forecast-oslo.json")
            )
        )
    }

    @Test("Columnar response is transposed into seven days")
    func decodesSevenDays() throws {
        #expect(try forecast().count == 7)
    }

    @Test("Values survive the transpose intact")
    func firstDayMatchesTheFixture() throws {
        let first = try #require(try forecast().first)

        #expect(first.temperatureMaxCelsius == 16.4)
        #expect(first.temperatureMinCelsius == 12.5)
        #expect(first.apparentTemperatureMaxCelsius == 16.2)
        #expect(first.precipitationSumMillimetres == 5.2)
        #expect(first.rainSumMillimetres == 5.2)
        #expect(first.snowfallSumCentimetres == 0)
        #expect(first.precipitationProbabilityMaxPercent == 86)
    }

    @Test("Keys containing a number decode — the trap that broke this once")
    func numericKeysDecode() throws {
        // `temperature_2m_max`, `wind_speed_10m_max`. Under `.convertFromSnakeCase` these
        // convert to `temperature2MMax` / `windSpeed10MMax` — capital M — so the DTO's
        // properties never matched, every column decoded as nil, and the mapper dropped
        // all seven days. Nothing threw, because the columns must stay optional.
        //
        // Asserting on non-zero values rather than on the count is deliberate: a wrong key
        // fails as a plausible-looking zero, and the wind columns fall back to 0.
        let days = try forecast()

        #expect(days.count == 7, "a mismatched key silently empties the whole week")
        #expect(days.allSatisfy { $0.temperatureMaxCelsius > $0.temperatureMinCelsius })
        #expect(days.contains { $0.windSpeedMaxKilometresPerHour > 0 })
        #expect(days.contains { $0.windGustsMaxKilometresPerHour > 0 })
        #expect(days.allSatisfy { $0.daylightDurationSeconds > 0 })
    }

    @Test("Dates are anchored to UTC midnight so they can key the marine merge")
    func datesAreUTCMidnight() throws {
        let first = try #require(try forecast().first)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let parts = calendar.dateComponents([.hour, .minute, .second], from: first.date)
        #expect(parts.hour == 0 && parts.minute == 0 && parts.second == 0)
    }

    @Test("Land forecasts carry no marine data — that merge happens later")
    func landForecastHasNoMarine() throws {
        #expect(try forecast().allSatisfy { $0.marine == nil })
    }
}

struct MarineDecodingTests {

    @Test("A coastal location yields real swell data")
    func coastalDecodes() throws {
        let marine = MarineMapper.map(
            try OpenMeteoJSON.decode(
                MarineResponseDTO.self, from: Fixture.data("marine-biarritz-coastal.json")
            )
        )
        #expect(marine.count == 7)

        let first = try #require(marine.sorted { $0.key < $1.key }.first?.value)
        #expect(first.swellWaveHeightMax == 0.58)
        #expect(first.swellWavePeriodMax == 6.95)
        #expect(first.waveHeightMax == 0.64)
    }

    @Test("An inland location returns HTTP 200 with all-null values")
    func inlandYieldsNothing() throws {
        // The assumption going in was that inland coordinates would fail the request.
        // They do not — Prague returns 200 with every value null. Mapping those to 0 would
        // claim we measured a flat sea and score surfing as genuinely bad.
        let marine = MarineMapper.map(
            try OpenMeteoJSON.decode(
                MarineResponseDTO.self, from: Fixture.data("marine-prague-inland.json")
            )
        )
        #expect(marine.isEmpty)
    }

    @Test("Null marine days are omitted, never defaulted to zero")
    func nullsAreOmittedNotZeroed() throws {
        let marine = MarineMapper.map(
            try OpenMeteoJSON.decode(
                MarineResponseDTO.self, from: Fixture.data("marine-prague-inland.json")
            )
        )
        #expect(!marine.values.contains { $0.swellWaveHeightMax == 0 })
    }

    @Test("An error body decodes for logging")
    func errorBodyDecodes() throws {
        let error = try OpenMeteoJSON.decode(
            OpenMeteoErrorDTO.self, from: Fixture.data("error-invalid-latitude.json")
        )
        #expect(error.error)
        #expect(error.reason.contains("Latitude"))
    }
}
