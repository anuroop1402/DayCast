import SwiftUI

/// Search for a city, or pick one you looked at recently.
struct CitySearchScreen: View {

    private let container: DependencyContainer
    @State private var viewModel: CitySearchViewModel

    init(container: DependencyContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeCitySearchViewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("DayCast")
                .searchable(
                    text: $viewModel.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search for a city"
                )
                .navigationDestination(for: City.self) { city in
                    ForecastScreen(viewModel: container.makeForecastViewModel(city: city))
                }
                // Debounce and cancellation in one line: changing the query cancels the
                // previous run, and `search()` sleeps before it does anything expensive.
                // This is why the app needs no Combine and no manual debounce token.
                .task(id: viewModel.query) { await viewModel.search() }
                .task { await viewModel.loadRecents() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isShowingRecents {
            recents
        } else {
            switch viewModel.results {
            case .idle:
                recents
            case .loading:
                ProgressView().controlSize(.large)
            case .loaded(let cities):
                List(cities) { city in
                    NavigationLink(value: city) {
                        CityRow(city: city)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Task { await viewModel.select(city) }
                    })
                }
                .listStyle(.plain)
            case .empty:
                ContentUnavailableView.search(text: viewModel.query)
            case .failed(let error):
                StatePlaceholder(error: error) {
                    Task { await viewModel.search() }
                }
            }
        }
    }

    @ViewBuilder
    private var recents: some View {
        if viewModel.recents.isEmpty {
            ContentUnavailableView(
                "Find your week",
                systemImage: "magnifyingglass",
                description: Text("Search for a city to see the best days for skiing, surfing and sightseeing.")
            )
        } else {
            List {
                Section {
                    ForEach(viewModel.recents) { city in
                        NavigationLink(value: city) {
                            CityRow(city: city)
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        Button("Clear") {
                            Task { await viewModel.clearRecents() }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

/// A city and enough context to tell it from the four others with the same name.
struct CityRow: View {

    let city: City

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(city.name)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [city.admin1, city.country].compactMap { $0 }.joined(separator: ", ")
    }
}
