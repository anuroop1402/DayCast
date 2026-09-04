import Testing
import Foundation
@testable import DayCast

struct EndpointTests {

    private func query(_ endpoint: Endpoint) throws -> [String: String] {
        let url = try #require(endpoint.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }

    @Test("Each API has its own host")
    func hostsAreDistinct() {
        #expect(Endpoint.geocoding(query: "Oslo").host == "geocoding-api.open-meteo.com")
        #expect(Endpoint.forecast(latitude: 0, longitude: 0, days: 7).host == "api.open-meteo.com")
        #expect(Endpoint.marine(latitude: 0, longitude: 0, days: 7).host == "marine-api.open-meteo.com")
    }

    @Test("Queries with spaces and accents are percent-encoded")
    func queriesAreEncoded() throws {
        let url = try #require(Endpoint.geocoding(query: "San José del Cabo").url)
        #expect(url.absoluteString.contains("San%20Jos"))
        #expect(!url.absoluteString.contains(" "))
    }

    @Test("Coordinates are fixed to four decimal places")
    func coordinatePrecision() throws {
        // ~11 m — finer than the forecast grid, and stable enough that identical requests
        // produce identical URLs.
        let items = try query(Endpoint.forecast(latitude: 59.912734567, longitude: 10.746091, days: 7))
        #expect(items["latitude"] == "59.9127")
        #expect(items["longitude"] == "10.7461")
    }

    @Test("Negative coordinates survive formatting")
    func negativeCoordinates() throws {
        let items = try query(Endpoint.marine(latitude: -33.8688, longitude: -151.2093, days: 7))
        #expect(items["latitude"] == "-33.8688")
        #expect(items["longitude"] == "-151.2093")
    }

    @Test("The forecast request asks for every variable the mapper reads")
    func forecastRequestsAllVariables() throws {
        let items = try query(Endpoint.forecast(latitude: 0, longitude: 0, days: 7))
        let requested = Set((items["daily"] ?? "").split(separator: ",").map(String.init))

        // If a variable is dropped from the request, the mapper silently substitutes a
        // default and every score shifts. Pinning the list keeps request and DTO in step.
        #expect(requested.contains("snowfall_sum"))
        #expect(requested.contains("wind_gusts_10m_max"))
        #expect(requested.contains("sunshine_duration"))
        #expect(requested.contains("daylight_duration"))
        #expect(requested.contains("apparent_temperature_max"))
        #expect(requested == Set(Endpoint.forecastDailyVariables))
    }

    @Test("Marine requests swell height and period, not just wave height")
    func marineRequestsSwell() throws {
        let items = try query(Endpoint.marine(latitude: 0, longitude: 0, days: 7))
        let requested = Set((items["daily"] ?? "").split(separator: ",").map(String.init))

        // Wave height alone cannot separate groundswell from local wind chop, which is the
        // distinction SurfingRule is built on.
        #expect(requested.contains("swell_wave_height_max"))
        #expect(requested.contains("swell_wave_period_max"))
    }

    @Test("timezone=auto is always sent so day labels are local to the location")
    func timezoneIsAuto() throws {
        #expect(try query(Endpoint.forecast(latitude: 0, longitude: 0, days: 7))["timezone"] == "auto")
        #expect(try query(Endpoint.marine(latitude: 0, longitude: 0, days: 7))["timezone"] == "auto")
    }

    @Test("The forecast window is requested explicitly")
    func forecastDays() throws {
        #expect(try query(Endpoint.forecast(latitude: 0, longitude: 0, days: 7))["forecast_days"] == "7")
    }
}
