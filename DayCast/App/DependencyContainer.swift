import Foundation

/// The composition root. **The only place concrete types are constructed.**
///
/// Everything above it depends on protocols, which is what makes the dependency inversion
/// real rather than decorative: no ViewModel names `URLSessionHTTPClient` or
/// `UserDefaultsRecentSearchesRepository`, so the whole graph can be replaced here — for a
/// test, a preview, or a second weather provider — without touching a screen.
///
/// The `make…` methods return ViewModels rather than exposing the use cases, so a screen
/// cannot accidentally reach past its ViewModel and call a use case directly.
@MainActor
final class DependencyContainer {

    private let httpClient: any HTTPClient
    private let citySearchRepository: any CitySearchRepository
    private let forecastRepository: any ForecastRepository
    private let recentSearchesRepository: any RecentSearchesRepository

    /// Repositories are injectable so previews and tests can build a container over stubs
    /// instead of the network.
    init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        citySearchRepository: (any CitySearchRepository)? = nil,
        forecastRepository: (any ForecastRepository)? = nil,
        recentSearchesRepository: any RecentSearchesRepository = UserDefaultsRecentSearchesRepository()
    ) {
        self.httpClient = httpClient
        self.citySearchRepository = citySearchRepository
            ?? OpenMeteoCitySearchRepository(client: httpClient)
        self.forecastRepository = forecastRepository
            ?? OpenMeteoForecastRepository(client: httpClient)
        self.recentSearchesRepository = recentSearchesRepository
    }

    // MARK: - ViewModels

    func makeCitySearchViewModel() -> CitySearchViewModel {
        CitySearchViewModel(
            searchCities: SearchCities(repository: citySearchRepository),
            getRecentSearches: GetRecentSearches(repository: recentSearchesRepository),
            saveRecentSearch: SaveRecentSearch(repository: recentSearchesRepository),
            clearRecentSearches: ClearRecentSearches(repository: recentSearchesRepository)
        )
    }

    func makeForecastViewModel(city: City) -> ForecastViewModel {
        ForecastViewModel(
            city: city,
            getActivityForecast: GetActivityForecast(repository: forecastRepository)
        )
    }
}
