# 02 — Architecture Decisions

> The reasoning behind the structure. Each entry records what was decided, what was
> rejected, and what the decision **costs** — a decision with no cost is usually one that
> was never really made.
>
> Companion documents: [`01-Solution-Planning.md`](01-Solution-Planning.md) (written before
> implementation), [`03-Assumptions-and-Tradeoffs.md`](03-Assumptions-and-Tradeoffs.md)
> (where the plan and the outcome diverged), [`04-AI-Usage.md`](04-AI-Usage.md).

---

## The shape

```
Presentation  ───────►  Domain  ◄───────  Data
  SwiftUI views          pure Swift        Open-Meteo
  @Observable VMs        Foundation only   UserDefaults
  ViewState<T>           no frameworks
```

Both outer layers depend inward. `Domain` depends on nothing but `Foundation` and does not
know the other two exist.

| Layer | Files | Contains |
|---|---|---|
| `Domain` | 23 | Entities, 4 scoring rules, use cases, repository *protocols*, `AppError` |
| `Data` | 15 | DTOs, `HTTPClient`, repository *implementations*, mappers |
| `Presentation` | 10 | `ViewState`, 2 ViewModels, 3 screens, formatting |
| `App` | 2 | Composition root |

---

## AD-1 — Clean Architecture, and the test that makes it real

**Decision.** Three layers with the dependency rule pointing inward, enforced by
`ArchitectureBoundaryTests` — a test that reads the actual source files in `DayCast/Domain`
and fails the build if any of them imports SwiftUI, UIKit, URLSession or UserDefaults.

**Why a test rather than a diagram.** A diagram is a promise; a test is a guarantee. The
rule that matters here — *the scoring model must stay portable and framework-free* — is
exactly the rule that erodes first under time pressure, and it erodes invisibly. One
`import SwiftUI` added to a domain file to reach for `Color` would never be caught in
review of a 30-file diff.

It has already earned its place twice. It caught its own false positive on the first run:
doc comments in `AppError` and `Repositories` *explain* that the domain avoids `URLSession`,
and a naive text search counted the explanation as a violation. A guard that fires on the
documentation of the rule it enforces is worse than no guard, because it teaches you to
ignore it. It now strips comments before scanning.

**Cost.** Real ceremony for a four-screen app: 5 use-case protocols whose implementations
are three lines each. Accepted deliberately, and the places where the ceremony was *not*
paid are AD-4 and AD-8.

---

## AD-2 — Repository protocols in `Domain`, implementations in `Data`

**Decision.** `CitySearchRepository`, `ForecastRepository` and `RecentSearchesRepository`
are declared in `Domain/Repositories`; `OpenMeteoCitySearchRepository`,
`OpenMeteoForecastRepository` and `UserDefaultsRecentSearchesRepository` live in `Data`.

**Why.** This inversion is the whole mechanism. Without it, `Domain` would have to import
`Data` to call it, and the dependency arrow would point outward — at which point the
scoring model is coupled to `URLSession` and the architecture test is unsatisfiable.

**Why three protocols, not one `WeatherRepository`.** Geocoding, forecasts and recent
searches are three aggregates with three different failure modes: a search returning nothing
is normal, a forecast returning nothing is an error, and unreadable local storage is
neither. A use case should not depend on methods it never calls.

**Cost.** More files. Worth it the first time a use case needed only one of the three.

---

## AD-3 — Use cases as protocols with `callAsFunction`, including the thin ones

**Decision.** Five use-case protocols, each with a `callAsFunction` requirement, so call
sites read as verbs: `try await searchCities(query: "Oslo")`.

**Why uniformly, even where it is thin.** `GetRecentSearches` forwards a single call and
adds nothing. The alternative — a per-operation judgement about whether an operation has
*enough* orchestration to deserve a use case — produces a codebase where the rule is
"whatever the author felt like that day". A uniform rule is easier to defend, easier to
review, and means a ViewModel's dependency list is a complete description of what it can do.

Two of the five are not thin at all, and they are where the layer pays for itself:

- `GetActivityForecast` fetches two endpoints concurrently, merges them, and owns the
  partial-failure policy (AD-6).
- `SaveRecentSearch` holds de-duplication and the ten-item cap (AD-5).

**Cost.** Three files that a reviewer could reasonably call bureaucracy.

---

## AD-4 — No `DataSource` layer between repository and `HTTPClient`

**Decision.** Rejected. `HTTPClient` **is** the data source.

**Why.** The canonical Clean layering inserts a `RemoteDataSource` that a repository calls,
which then calls a networking client. Here that class would contain one method that forwards
to `HTTPClient` and returns its result unchanged. A layer whose every method is a
pass-through does not decouple anything — it just adds a file to open when tracing a bug.

The seam that layer is supposed to provide already exists: `HTTPClient` is a protocol, and
`StubHTTPClient` substitutes for it. Repository tests exercise the real URL construction,
the real decoding and the real mapping, stubbing only transport.

**Cost.** If a second transport (a local cache, say) were ever added, it would go behind
`HTTPClient` rather than beside a data source. That is a smaller change than the one avoided.

---

## AD-5 — `replace(with:)` on the storage protocol, not `save(_ city:)`

**Decision.** `RecentSearchesRepository` exposes `replace(with cities: [City])`.
De-duplication and the ten-item cap live in `SaveRecentSearch`.

**Why.** `save(_ city:)` is the more natural signature at the call site, which is exactly
why it is the trap. It forces storage to decide *where* the city goes in the list and *what
falls off the end* — both of which are business rules. A second implementation would have to
reimplement them identically, and neither would be testable without a persistence layer.

`replace(with:)` keeps storage dumb: the use case reads, applies the rules, writes back.

**The general principle, which recurs below:** shape an abstraction by where the *decision*
belongs, not by what reads most naturally at one call site.

**Cost.** Two round-trips to storage per save instead of one. Irrelevant at ten items in
`UserDefaults`.

---

## AD-6 — The partial-failure policy lives in the use case

**Decision.** `ForecastRepository` exposes land and sea as two methods.
`GetActivityForecast` fetches both concurrently and decides what a missing sea response
*means*.

- The land forecast is the only non-optional source — without it there is no day to score
  for any activity, so its failure propagates and the screen shows an error.
- A marine failure, or an inland `HTTP 200` full of nulls, leaves `marine == nil`.
  `SurfingRule` reports `insufficientData`; skiing and both kinds of sightseeing are
  untouched. **A marine failure must never fail the screen.**

**Why here and not elsewhere.** The repository would have to invent a policy it has no
business inventing. The ViewModel would have to understand both endpoints to apply one. The
use case is the only place that already knows about both and is still in the domain.

**Degradation is per-day, not per-city,** and that took no code: the merge is
`days.map { $0.withMarine(marine[$0.date]) }`, and a dictionary lookup already yields `nil`
for a missing key. Making it city-wide would have required *adding* a line whose only effect
is to discard marine data we successfully fetched. Pinned by a test, because the behaviour is
emergent rather than stated and a refactor could silently flip it.

**One error is not swallowed: cancellation.** `.task(id:)` cancels on every keystroke, and
treating that as "no sea data" would render a coastal city as inland from a superseded
request.

---

## AD-7 — Gates multiply, factors add

**Decision.** A prerequisite is a **gate** that multiplies the whole score (and can veto it
at zero), not a weighted factor that trades off against others.

| Activity | Gate(s) | Additive factors |
|---|---|---|
| Skiing | snow availability, lift operability | temperature, rain, wind comfort |
| Surfing | marine data present, rideable swell height | swell period, wind, comfort |
| Outdoor sightseeing | *none* | precipitation, temperature, wind, sunshine, UV |
| Indoor sightseeing | travel conditions | inverse outdoor comfort |

**Why.** [`01-Solution-Planning.md`](01-Solution-Planning.md) §6 specified a pure weighted
sum for every activity. Phase 1 printed a characterisation table of real scores and found
three bugs that the passing unit tests had not:

- A 24 °C sunny day scored **40/100 for skiing** — it collected 25% for "not raining" and
  15% for "not windy" while having no snow at all.
- A blizzard scored **85/100 for skiing**, because 90 km/h gusts were only 15% of the total
  and could not express "every lift is shut".
- A dangerous 4.2 m swell scored **53/100 for surfing**, dragged back up by a clean period
  and a warm afternoon.

One flaw, three times: **additive factors let the absence of negatives substitute for the
presence of a prerequisite.** Snow is not something you trade against wind — without it
there is no skiing at any temperature.

Outdoor sightseeing stays purely additive because it genuinely has no hard prerequisite.
The asymmetry is the point, not an inconsistency.

**Cost.** A multiplicative model is harder to reason about than a weighted sum, and gates
make scores drop sharply near a threshold. Mitigated by piecewise-linear curves rather than
step functions, and by every gate emitting a `limiting` reason so the user can see what
capped the score.

**Do not change thresholds or composition without re-running that characterisation table.**
The unit tests did not catch these and would not catch their return.

---

## AD-8 — No presentation models mirroring domain entities

**Decision.** Rejected. ViewModels hold `ActivityForecast` directly and expose computed
*views* of it.

**Why.** The textbook move is a `DayForecastViewData` per entity. Here every field would map
1:1, and the mapper would be the largest file in the layer while adding no behaviour — the
same pass-through smell as AD-4. Display strings live in `Presentation` as extensions
(`Activity.displayName`, `SuitabilityRating.tint`), so the domain still carries no
user-facing copy.

**The one exception, and why it is not a violation.** `BestDaySummary` exists because it
answers a question the domain does not ask: *what should this card say?* A week where every
day is `.unsuitable` still has a highest-scoring day, but naming it makes the card
contradict its own badge. That rule is presentation policy, and putting it in the ViewModel
is what makes it testable — in a private view struct it would not be.

---

## AD-9 — `ViewState<T>` instead of `isLoading` + `error` + `data`

**Decision.** One generic enum: `idle / loading / loaded(T) / empty / failed(AppError)`.

**Why.** The three-property triple can express states that do not exist — loading *and*
failed, data *and* an error — and then every view has to decide which wins, usually
differently. Here the impossible states are unrepresentable and each view is a `switch` with
no `default`.

Two details that carry weight:

- **`empty` is distinct from `loaded([])`.** "We searched and found nothing" and "we have
  results" want different copy. A `ViewState(collection)` initialiser maps a finished request
  onto the right one so no call site can forget the check and render a blank list.
- **`failed` carries the `AppError`**, so the view asks `isRetryable` and offers a retry
  button only when the identical request could plausibly succeed. A button that cannot work
  is worse than no button.

---

## AD-10 — `.task(id:)` for debounce and cancellation; no Combine

**Decision.** Structured concurrency throughout. The search screen carries
`.task(id: viewModel.query)`, and the ViewModel's `search()` sleeps before it does anything
expensive.

**Why.** Changing the query cancels the previous task and starts a new one — so the debounce
and the cancellation are the same mechanism, and the ViewModel needs no token, no
`cancellable` bag and no `debounce` operator. A superseded keystroke throws out of the sleep
and returns *before* touching the network, leaving the previous results on screen rather
than flashing a spinner.

**Cost.** The cancellation path has to be handled explicitly in three places
(`AppError.cancelled`, `CancellationError`, and the sleep), and forgetting one surfaces a
superseded request's error to the user. Each is covered by a test.

---

## AD-11 — Forecast days are parsed at UTC midnight

**Decision.** Open-Meteo's `"2026-09-05"` day labels parse at UTC midnight, everywhere.

**Why.** The API is asked for `timezone=auto`, so those strings are already *local calendar
days* at the requested coordinates. Forecast and Marine snap to different grid points and can
report different `utc_offset_seconds` — so parsing in any other frame gives the same label
two different `Date` values, and the merge's dictionary lookup misses silently. Every day
would degrade to "no coastal data" with nothing to show for it.

**The constraint leaks into `Presentation`,** which must format these with a UTC calendar or
the displayed day slides by one. That leak is documented on `ForecastDate` where the next
person will hit it, and `DayLabel` takes the timezone as a parameter rather than reading
`Calendar.current` — a hidden environment read made its tests assert the developer's
machine.

---

## AD-12 — `Codable` on the `City` entity, no persistence DTO

**Decision.** `City` conforms to `Codable` in the domain and is stored directly.

**Why.** `Codable` is `Foundation`, so the architecture test is satisfied and the domain
stays framework-free. A separate persistence DTO plus a mapper would be two more files for
no behavioural benefit at this size.

**Cost, stated plainly.** Changing `City`'s shape invalidates stored data. Acceptable
because the failure mode is bounded: `UserDefaultsRecentSearchesRepository` treats
undecodable storage as an empty list, so the worst case is a user losing ten search
shortcuts — a state the app already handles. If this held anything a user could not
regenerate in a second, the DTO would be worth it.

---

## AD-13 — `DependencyContainer` is the only place concrete types are constructed

**Decision.** One `@MainActor` container, built once in `DayCastApp`, vending ViewModels.

**Why vend ViewModels rather than expose use cases.** A screen that could reach the
container's use cases could call one directly and bypass its ViewModel. Exposing only
`makeCitySearchViewModel()` and `makeForecastViewModel(city:)` makes that impossible by
construction rather than by convention.

Repositories are injectable, so a preview or a test can build the whole graph over stubs
without touching the network.

---

## AD-14 — Swift Testing, and no snapshot tests

**Decision.** `import Testing` throughout, 138 tests. No UI snapshot tests.

**Why no snapshots.** High maintenance cost, low signal for a three-screen app: they fail on
every deliberate design change and pass through most real regressions. The effort went into
the scoring model and orchestration instead, which is where the risk actually is.

**What that costs, honestly.** It is why the "Best day for Ski: Wednesday / Unsuitable"
contradiction survived 133 passing tests — no assertion could have caught it, because every
number behind it was correct. It was found by looking at the running app. The mitigation is
process, now written into `CLAUDE.md`: *look at the app against real data before calling a
phase done.*

**Fixtures are captured, never hand-written.** `DayCastTests/Fixtures/` holds real
Open-Meteo responses. Hand-written JSON agrees with the DTO by construction and therefore
tests nothing — it would not have caught `.convertFromSnakeCase` mapping
`temperature_2m_max` to `temperature2MMax`, which decoded the entire week as `nil` without
throwing.

---

## AD-15 — Zero third-party dependencies

**Decision.** No Alamofire, no SnapshotTesting, no DI framework.

**Why.** Everything needed is in the platform: `URLSession`, `Codable`, `@Observable`,
Swift Testing, structured concurrency. Adding a package here would mean a reviewer has to
evaluate my dependency taste rather than my code, and it would obscure how little machinery
the problem actually needs. The DI "framework" is one class with two methods (AD-13).
