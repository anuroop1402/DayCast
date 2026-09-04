import Testing
import Foundation
@testable import DayCast

/// Locks in the behaviour the rule doc-comments *claim*, so the claims cannot silently
/// become false. These are the assertions worth arguing about in review — each one encodes
/// a product decision, not an implementation detail.
struct ScoringCharacterisationTests {

    private let engine = SuitabilityScoring()

    private func score(_ day: DailyWeather, _ activity: Activity) -> SuitabilityScore {
        let match = engine.scores(for: day).first { $0.activity == activity }
        precondition(match != nil, "engine produced no score for \(activity)")
        return match!
    }

    // MARK: - Indoor sightseeing: the model's biggest judgement call

    @Test("Drizzle beats a blizzard for indoor sightseeing — travel feasibility gates it")
    func drizzleBeatsBlizzardIndoors() {
        let drizzle = score(.drizzle, .indoorSightseeing).value!
        let blizzard = score(.blizzard, .indoorSightseeing).value!

        #expect(drizzle > blizzard, "drizzle \(drizzle) should beat blizzard \(blizzard)")
    }

    @Test("A blizzard surfaces travel conditions as the leading, limiting reason")
    func blizzardExplainsTheGate() {
        let result = score(.blizzard, .indoorSightseeing)
        #expect(result.reasons.first?.factor == .travelConditions)
        #expect(result.reasons.first?.sentiment == .limiting)
    }

    @Test("A perfect day is never 'unsuitable' for indoor sightseeing — museums are open")
    func perfectDayIsNotUnsuitableIndoors() {
        let result = score(.perfectSummerDay, .indoorSightseeing)
        #expect(result.rating != .unsuitable)
        #expect(result.value! >= 20, "the baseline appeal floor should hold")
    }

    @Test("Good weather still makes outdoor sightseeing the better choice")
    func outdoorBeatsIndoorOnAGoodDay() {
        let outdoor = score(.perfectSummerDay, .outdoorSightseeing).value!
        let indoor = score(.perfectSummerDay, .indoorSightseeing).value!
        #expect(outdoor > indoor)
    }

    // MARK: - Skiing: rain is worse than mere warmth

    @Test("Rain on snow scores worse than a dry day at the same temperature")
    func rainIsWorseThanWarmth() {
        let dry = DailyWeather.fixture(
            temperatureMax: 2, apparentTemperatureMax: 0,
            precipitationSum: 0, rainSum: 0, snowfallSum: 0
        )
        let wet = DailyWeather.fixture(
            temperatureMax: 2, apparentTemperatureMax: 0,
            precipitationSum: 12, rainSum: 12, snowfallSum: 0
        )
        #expect(score(wet, .skiing).value! < score(dry, .skiing).value!)
    }

    @Test("A powder day scores well for skiing")
    func powderDayScoresWell() {
        let result = score(.powderDay, .skiing)
        #expect(result.value! >= SuitabilityRating.goodThreshold)
        #expect(result.reasons.contains { $0.factor == .freshSnow && $0.sentiment == .favourable })
    }

    // MARK: - Surfing: missing marine data is not a zero

    @Test("No marine data yields insufficientData, not a score of zero")
    func inlandCityCannotBeScoredForSurfing() {
        let result = score(.perfectSummerDay, .surfing)   // fixture has marine: nil
        #expect(result.outcome == .insufficientData)
        #expect(result.value == nil)
        #expect(result.rating == .unknown)
        #expect(result.reasons.first?.factor == .dataAvailability)
    }

    @Test("Missing marine data degrades surfing alone — other activities still score")
    func marineFailureDoesNotPoisonOtherActivities() {
        let scores = engine.scores(for: .perfectSummerDay)
        let scorable = scores.filter { $0.activity != .surfing }

        #expect(scorable.count == 3)
        #expect(scorable.allSatisfy { $0.value != nil })
    }

    @Test("Clean groundswell outscores a flat, blown-out day")
    func goodSurfBeatsFlatSea() {
        #expect(score(.goodSurfDay, .surfing).value! > score(.flatBlownOutDay, .surfing).value!)
    }

    // MARK: - Engine invariants

    @Test("Every activity gets exactly one score", arguments: [
        DailyWeather.perfectSummerDay, .drizzle, .blizzard, .powderDay, .goodSurfDay
    ])
    func everyActivityIsScoredOnce(day: DailyWeather) {
        let scores = engine.scores(for: day)
        #expect(scores.count == Activity.allCases.count)
        #expect(Set(scores.map(\.activity)) == Set(Activity.allCases))
    }

    @Test("Scores stay within 0...100", arguments: [
        DailyWeather.perfectSummerDay, .drizzle, .blizzard, .powderDay,
        .rainOnSnowDay, .goodSurfDay, .flatBlownOutDay
    ])
    func scoresAreInRange(day: DailyWeather) {
        for score in engine.scores(for: day) {
            if let value = score.value {
                #expect((0...100).contains(value), "\(score.activity) produced \(value)")
            }
        }
    }

    @Test("Scoring is deterministic")
    func scoringIsPure() {
        #expect(engine.scores(for: .drizzle) == engine.scores(for: .drizzle))
    }

    // MARK: - Regressions found by the characterisation table
    //
    // Both of these passed a full green test suite before the table was printed. They are
    // the reason gates exist in SkiingRule.

    @Test("A warm sunny day is unsuitable for skiing, not 'fair'")
    func summerDayCannotBeSkied() {
        let result = score(.perfectSummerDay, .skiing)

        // Previously 40/100: it collected credit for "not raining" and "not windy".
        #expect(result.value! <= 5, "got \(result.value!) on a 24 degree snowless day")
        #expect(result.rating == .unsuitable)
        #expect(result.reasons.first?.factor == .snowBase)
        #expect(result.reasons.first?.sentiment == .limiting)
    }

    @Test("A blizzard is not an excellent ski day — lifts do not run in 90 km/h gusts")
    func blizzardIsNotExcellentForSkiing() {
        let result = score(.blizzard, .skiing)

        // Previously 85/100: wind was only 15% of an additive score.
        #expect(result.rating != .excellent)
        #expect(result.value! < SuitabilityRating.goodThreshold)
        #expect(result.reasons.contains { $0.factor == .wind && $0.sentiment == .limiting })
    }

    @Test("Deep snow lowers indoor sightseeing without vetoing it outright")
    func heavySnowDoesNotZeroIndoorSightseeing() {
        let powder = score(.powderDay, .indoorSightseeing).value!

        // 22 cm is disruptive in a city but routine in a ski town, so it should drag the
        // score down rather than declare the museums unreachable.
        #expect(powder > 0)
        #expect(powder < score(.drizzle, .indoorSightseeing).value!)
    }

    @Test("Gates cannot be out-voted by favourable additive factors")
    func gatesDominateAdditiveFactors() {
        // Ideal ski temperature, bone dry, dead calm — but no snow.
        let idealButSnowless = DailyWeather.fixture(
            temperatureMax: -6, apparentTemperatureMax: -8,
            precipitationSum: 0, rainSum: 0, snowfallSum: 0,
            windSpeedMax: 3, windGustsMax: 6
        )
        // Cold enough for a base to survive, so not zero — but nowhere near a good day.
        #expect(score(idealButSnowless, .skiing).value! <= 50)
    }

    @Test("Dangerously large swell is unsuitable, not 'fair'")
    func hugeSwellIsUnsuitable() {
        let huge = DailyWeather.fixture(
            temperatureMax: 18, apparentTemperatureMax: 17,
            windSpeedMax: 25, windGustsMax: 40,
            marine: MarineConditions(
                swellWaveHeightMax: 4.2, swellWavePeriodMax: 14, waveHeightMax: 5.0
            )
        )
        // Previously 53/100: a clean 14 s period and warm air outvoted the wave size.
        let result = score(huge, .surfing)
        #expect(result.value! < SuitabilityRating.fairThreshold)
        #expect(result.reasons.first?.factor == .swellHeight)
        #expect(result.reasons.first?.sentiment == .limiting)
    }

    @Test("A flat sea scores zero for surfing regardless of how pleasant the day is")
    func flatSeaScoresZero() {
        // Previously 12/100, earned entirely by comfortable wind and air temperature.
        #expect(score(.flatBlownOutDay, .surfing).value! == 0)
    }

    @Test("The swell gate does not penalise a genuinely good surf day")
    func goodSurfIsUnaffectedByTheGate() {
        #expect(score(.goodSurfDay, .surfing).value! >= SuitabilityRating.excellentThreshold)
    }

    @Test("A veto never leads with a favourable reason")
    func vetoesLeadTheExplanation() {
        // A blizzard has 28 cm of fresh snow AND closed lifts. Explaining a score of 0
        // with "28 cm fresh snow" would be actively misleading.
        let result = score(.blizzard, .skiing)
        #expect(result.value! == 0)
        #expect(result.reasons.first?.sentiment == .limiting)
    }

    // MARK: - Characterisation table (prints the actual model output)

    @Test("Print the scenario matrix for review")
    func printScenarioMatrix() {
        let scenarios: [(String, DailyWeather)] = [
            ("Perfect summer day", .perfectSummerDay),
            ("Drizzle",            .drizzle),
            ("Blizzard",           .blizzard),
            ("Powder day",         .powderDay),
            ("Rain on snow",       .rainOnSnowDay),
            ("Good surf",          .goodSurfDay),
            ("Flat & blown out",   .flatBlownOutDay)
        ]

        print("\nSCENARIO             | SKI | SURF | OUTDOOR | INDOOR")
        print("---------------------|-----|------|---------|-------")
        for (name, day) in scenarios {
            let cells = Activity.allCases.map { activity -> String in
                let value = score(day, activity).value
                return value.map { String(format: "%3d", $0) } ?? " --"
            }
            let padded = name.padding(toLength: 20, withPad: " ", startingAt: 0)
            print("\(padded) | \(cells[0]) | \(cells[1])  |   \(cells[2])   |  \(cells[3])")
        }
        print("")
    }
}
