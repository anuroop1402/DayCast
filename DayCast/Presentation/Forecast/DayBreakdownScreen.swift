import SwiftUI

/// Why each activity scored what it did, for one day.
///
/// This screen is a definition-of-done item: *every score in the UI is explainable by
/// tapping into a breakdown*. The reasons are generated in the domain by the rule that
/// produced the score, so what is shown here is the actual basis of the number and not a
/// second explanation assembled in the view that could drift away from it.
struct DayBreakdownScreen: View {

    let day: DayForecast
    let city: City

    var body: some View {
        List {
            Section {
                ForEach(day.weather.summaryItems, id: \.label) { item in
                    LabeledContent(item.label, value: item.value)
                }
            } header: {
                Text("Conditions")
            }

            ForEach(day.scores) { score in
                Section {
                    HStack {
                        Label(score.activity.displayName, systemImage: score.activity.symbolName)
                            .font(.headline)
                        Spacer()
                        RatingBadge(rating: score.rating)
                    }

                    ForEach(score.reasons) { reason in
                        ReasonRow(reason: reason)
                    }

                    if let limitation = score.activity.limitation {
                        Text(limitation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(DayLabel.full(day.date))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReasonRow: View {

    let reason: ScoreReason

    var body: some View {
        Label {
            Text(reason.detail)
                .font(.subheadline)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sentimentDescription): \(reason.detail)")
    }

    private var symbol: String {
        switch reason.sentiment {
        case .favourable:   "checkmark.circle.fill"
        case .unfavourable: "minus.circle.fill"
        // A gate reads differently from a mere negative — it is what *decided* the score,
        // not one factor among several that pushed it down.
        case .limiting:     "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch reason.sentiment {
        case .favourable:   .green
        case .unfavourable: .orange
        case .limiting:     .red
        }
    }

    private var sentimentDescription: String {
        switch reason.sentiment {
        case .favourable:   "In favour"
        case .unfavourable: "Against"
        case .limiting:     "Limiting factor"
        }
    }
}

private extension DailyWeather {
    /// The measurements behind the scores, so a user can check the model's working.
    var summaryItems: [(label: String, value: String)] {
        var items: [(String, String)] = [
            // "to" rather than an en dash: at a ski resort both ends are routinely negative,
            // and "-8–-2 °C" is unreadable. One format for every case beats a conditional one.
            ("Temperature", "\(temperatureMinCelsius.roundedInt) to \(temperatureMaxCelsius.roundedInt) °C"),
            ("Feels like", "\(apparentTemperatureMaxCelsius.roundedInt) °C"),
            ("Wind", "\(windSpeedMaxKilometresPerHour.roundedInt) km/h, gusting \(windGustsMaxKilometresPerHour.roundedInt)"),
            ("Precipitation", "\(precipitationSumMillimetres.reasonValue) mm (\(precipitationProbabilityMaxPercent.roundedInt)% chance)"),
            ("Sunshine", "\((sunshineFraction * 100).roundedInt)% of daylight"),
            ("UV index", uvIndexMax.reasonValue)
        ]
        if snowfallSumCentimetres > 0 {
            items.insert(("Snowfall", "\(snowfallSumCentimetres.reasonValue) cm"), at: 4)
        }
        if let marine {
            items.append(("Swell", "\(marine.swellWaveHeightMax.reasonValue) m at \(marine.swellWavePeriodMax.reasonValue) s"))
        }
        return items
    }
}
