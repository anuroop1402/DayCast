import SwiftUI

/// The week for one city.
///
/// Two questions, two sections. The summary strip answers *"when should I ski?"* — the best
/// day for each activity. The list answers *"what should I do on Thursday?"* — the pick of
/// the day, with the full breakdown one tap away.
struct ForecastScreen: View {

    @State var viewModel: ForecastViewModel

    var body: some View {
        content
            .navigationTitle(viewModel.city.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: DayForecast.self) { day in
                DayBreakdownScreen(day: day, city: viewModel.city)
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading forecast").controlSize(.large)
        case .loaded:
            loaded
        case .empty:
            ContentUnavailableView(
                "No forecast",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("The forecast service returned no days for \(viewModel.city.name).")
            )
        case .failed(let error):
            StatePlaceholder(error: error) {
                Task { await viewModel.load() }
            }
        }
    }

    private var loaded: some View {
        List {
            Section("Best day for") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.bestDays) { summary in
                            BestDayCard(summary: summary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
            }

            Section("Next \(viewModel.days.count) days") {
                ForEach(viewModel.days) { day in
                    NavigationLink(value: day) {
                        DayRow(day: day)
                    }
                }
            }

            // The honest caveats, on screen rather than only in the README.
            Section {
                if viewModel.isMissingMarineData {
                    Label(
                        "No coastal wave data for this location, so surfing cannot be scored.",
                        systemImage: "water.waves.slash"
                    )
                }
                Label(
                    "Scores come from weather alone. DayCast does not know whether a ski area or a surfable beach is actually nearby.",
                    systemImage: "info.circle"
                )
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

/// One activity's pick of the week.
private struct BestDayCard: View {

    let summary: BestDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(summary.activity.shortName, systemImage: summary.activity.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(dayText)
                .font(.headline)
            RatingBadge(rating: summary.rating)
        }
        .padding(12)
        .frame(minWidth: 120, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var dayText: String {
        guard let day = summary.day else { return "—" }
        return DayLabel.weekday(day.date)
    }

    /// Spelled out rather than read as "dash": a card with no day needs to say *why* it has
    /// none, and "Skiing, dash, Unsuitable" tells a VoiceOver user nothing.
    private var accessibilityDescription: String {
        let name = summary.activity.displayName
        guard let day = summary.day else {
            return summary.rating == .unknown
                ? "\(name): no data"
                : "\(name): no suitable day in the next 7 days"
        }
        return "Best day for \(name): \(DayLabel.weekday(day.date)), \(summary.rating.displayName)"
    }
}

/// One day, led by whatever it is best for.
private struct DayRow: View {

    let day: DayForecast

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayLabel.weekday(day.date))
                    .font(.body.weight(.medium))
                Text(DayLabel.shortDate(day.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if let top = day.rankedScores.first, top.value != nil {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(top.activity.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RatingBadge(rating: top.rating)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
