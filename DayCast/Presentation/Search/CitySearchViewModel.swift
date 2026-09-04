import Foundation

/// Drives the search screen.
///
/// Talks to use cases only — it has never heard of `URLSession`, `UserDefaults` or a
/// repository. Swapping storage or the geocoding provider changes nothing in this file.
@Observable
final class CitySearchViewModel {

    /// Long enough that a fast typist makes one request instead of eight, short enough that
    /// a deliberate typist does not notice waiting. Injectable so tests do not sleep.
    static let defaultDebounce = Duration.milliseconds(300)

    /// Bound to the search field. Views drive `search()` from `.task(id: query)`, so
    /// changing this cancels the in-flight request before starting the next.
    var query: String = ""

    private(set) var results: ViewState<[City]> = .idle
    private(set) var recents: [City] = []

    private let searchCities: any SearchCitiesUseCase
    private let getRecentSearches: any GetRecentSearchesUseCase
    private let saveRecentSearch: any SaveRecentSearchUseCase
    private let clearRecentSearches: any ClearRecentSearchesUseCase
    private let debounce: Duration

    init(
        searchCities: any SearchCitiesUseCase,
        getRecentSearches: any GetRecentSearchesUseCase,
        saveRecentSearch: any SaveRecentSearchUseCase,
        clearRecentSearches: any ClearRecentSearchesUseCase,
        debounce: Duration = CitySearchViewModel.defaultDebounce
    ) {
        self.searchCities = searchCities
        self.getRecentSearches = getRecentSearches
        self.saveRecentSearch = saveRecentSearch
        self.clearRecentSearches = clearRecentSearches
        self.debounce = debounce
    }

    /// True while the query is too short to search. The screen shows recents here, which is
    /// why this is not `results == .idle` — that would also be true mid-cancellation.
    var isShowingRecents: Bool {
        !CitySearchPolicy.isSearchable(query)
    }

    // MARK: - Actions

    func loadRecents() async {
        // A failed read of ten search shortcuts does not deserve an error state; the
        // repository already treats unreadable storage as empty.
        recents = (try? await getRecentSearches()) ?? []
    }

    /// Debounces, then searches. Driven by `.task(id: query)`, so SwiftUI cancels the
    /// previous call on every keystroke and this method never has to track its own token.
    func search() async {
        guard CitySearchPolicy.isSearchable(query) else {
            // Not an empty *result* — nothing has been asked yet. Showing "No cities found"
            // after one character would be a lie about a search we never made.
            results = .idle
            return
        }

        // Cancellation lands here as a thrown error, which is the whole debounce: a
        // superseded keystroke returns before touching the network and, critically, leaves
        // `results` alone so the screen keeps the last good list instead of flashing.
        do { try await Task.sleep(for: debounce) } catch { return }

        results = .loading
        do {
            results = ViewState(try await searchCities(query: query))
        } catch let error as AppError {
            // A cancelled request has been replaced by a newer one. Its error belongs to
            // nobody and must never reach the screen.
            guard error != .cancelled else { return }
            results = .failed(error)
        } catch is CancellationError {
            return
        } catch {
            results = .failed(.unexpected)
        }
    }

    /// Records a chosen city. Failing to save a shortcut must not block navigation, so this
    /// deliberately swallows — the user asked to see a forecast, not to write to disk.
    func select(_ city: City) async {
        try? await saveRecentSearch(city: city)
        await loadRecents()
    }

    func clearRecents() async {
        try? await clearRecentSearches()
        recents = []
    }
}
