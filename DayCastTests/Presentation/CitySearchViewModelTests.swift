import Testing
import Foundation
@testable import DayCast

@MainActor
struct CitySearchViewModelTests {

    // Assembled per test so each one starts from a clean graph.
    private func make(
        search: StubSearchCitiesUseCase = .init(),
        get: StubGetRecentSearchesUseCase = .init(),
        save: StubSaveRecentSearchUseCase = .init(),
        clear: StubClearRecentSearchesUseCase = .init(),
        debounce: Duration = .zero
    ) -> CitySearchViewModel {
        CitySearchViewModel(
            searchCities: search,
            getRecentSearches: get,
            saveRecentSearch: save,
            clearRecentSearches: clear,
            debounce: debounce
        )
    }

    // MARK: - State transitions

    @Test("A search with matches loads them")
    func successfulSearchLoads() async {
        let search = StubSearchCitiesUseCase()
        search.result = .success([.fixture(id: 1), .fixture(id: 2)])
        let viewModel = make(search: search)

        viewModel.query = "Oslo"
        await viewModel.search()

        #expect(viewModel.results.value?.count == 2)
    }

    @Test("A search with no matches is empty, not an error and not a blank list")
    func noMatchesIsEmpty() async {
        let search = StubSearchCitiesUseCase()
        search.result = .success([])
        let viewModel = make(search: search)

        viewModel.query = "zzzqqq"
        await viewModel.search()

        #expect(viewModel.results == .empty)
    }

    @Test("A failure becomes a failed state carrying the error")
    func failureIsSurfaced() async {
        let search = StubSearchCitiesUseCase()
        search.result = .failure(AppError.offline)
        let viewModel = make(search: search)

        viewModel.query = "Oslo"
        await viewModel.search()

        #expect(viewModel.results == .failed(.offline))
        #expect(viewModel.results.error?.isRetryable == true)
    }

    @Test("A cancelled request never reaches the user as an error")
    func cancellationIsNotAnError() async {
        let search = StubSearchCitiesUseCase()
        search.result = .failure(AppError.cancelled)
        let viewModel = make(search: search)

        viewModel.query = "Oslo"
        await viewModel.search()

        // Superseded by a newer keystroke — its error belongs to nobody.
        #expect(viewModel.results.error == nil)
    }

    // MARK: - The length floor

    @Test("A query below the floor stays idle rather than reporting no results")
    func shortQueryStaysIdle() async {
        let search = StubSearchCitiesUseCase()
        search.result = .failure(AppError.offline)   // would surface if it were ever called
        let viewModel = make(search: search)

        viewModel.query = "O"
        await viewModel.search()

        // Not `.empty`: saying "No cities found" after one character is a lie about a
        // search that was never made.
        #expect(viewModel.results == .idle)
        #expect(search.queries.isEmpty)
        #expect(viewModel.isShowingRecents)
    }

    @Test("A searchable query stops showing recents")
    func longQueryHidesRecents() {
        let viewModel = make()
        viewModel.query = "Os"
        #expect(!viewModel.isShowingRecents)
    }

    // MARK: - Debounce

    @Test("A keystroke superseded during the debounce never reaches the network")
    func cancelledDebounceMakesNoRequest() async {
        let search = StubSearchCitiesUseCase()
        search.result = .success([.fixture()])
        let viewModel = make(search: search, debounce: .seconds(30))
        viewModel.query = "Oslo"

        let task = Task { await viewModel.search() }
        task.cancel()
        await task.value

        // This is the whole point of debouncing: the request is not made, and the screen
        // keeps whatever it had rather than flashing a spinner.
        #expect(search.queries.isEmpty)
        #expect(viewModel.results == .idle)
    }

    // MARK: - Recents

    @Test("Choosing a city records it and refreshes the list")
    func selectionSavesAndReloads() async {
        let save = StubSaveRecentSearchUseCase()
        let get = StubGetRecentSearchesUseCase()
        get.result = .success([.fixture(id: 7)])
        let viewModel = make(get: get, save: save)

        await viewModel.select(.fixture(id: 7))

        #expect(save.saved.map(\.id) == [7])
        #expect(viewModel.recents.map(\.id) == [7])
    }

    @Test("A failed save does not block the user from seeing the forecast")
    func failedSaveIsSwallowed() async {
        let save = StubSaveRecentSearchUseCase()
        save.error = AppError.unexpected
        let viewModel = make(save: save)

        await viewModel.select(.fixture())

        // No error state: the user asked for a forecast, not to write to disk.
        #expect(viewModel.results.error == nil)
    }

    @Test("Unreadable recent searches are an empty list, not an error state")
    func failedRecentsReadIsEmpty() async {
        let get = StubGetRecentSearchesUseCase()
        get.result = .failure(AppError.unexpected)
        let viewModel = make(get: get)

        await viewModel.loadRecents()

        #expect(viewModel.recents.isEmpty)
        #expect(viewModel.results.error == nil)
    }

    @Test("Clearing empties the list")
    func clearEmptiesRecents() async {
        let get = StubGetRecentSearchesUseCase()
        get.result = .success([.fixture()])
        let clear = StubClearRecentSearchesUseCase()
        let viewModel = make(get: get, clear: clear)
        await viewModel.loadRecents()

        await viewModel.clearRecents()

        #expect(viewModel.recents.isEmpty)
        #expect(clear.callCount == 1)
    }
}
