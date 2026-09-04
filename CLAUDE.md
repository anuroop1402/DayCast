# DayCast

Take-home exercise: a native iOS app that searches for a city and ranks the next 7 days
for **skiing, surfing, outdoor sightseeing, and indoor sightseeing** using Open-Meteo.
No backend.

Assessed on engineering judgment, not feature volume. All written reasoning lives in
`docs/` — see `docs/01-Solution-Planning.md` for scope and assumptions.

---

## Current state — update this at the end of every phase

**Phase 3 complete** (5 use-case implementations, concurrent two-endpoint merge,
marine-degradation policy, stub repositories, 103 tests green). **Phase 4 is next:
ViewModels + `ViewState` + SwiftUI screens.** `App/DependencyContainer.swift` does not
exist yet — it lands in Phase 4 alongside its first consumer.

| Phase | | |
|---|---|---|
| 0 | Foundations, test target, `docs/01-Solution-Planning.md` | ✅ |
| 1 | Domain: entities, `SuitabilityRule` × 4, `AppError`, protocols, architecture test | ✅ |
| 2 | Data: DTOs, `HTTPClient`, 3 repository impls, mappers | ✅ |
| 3 | Use-case implementations + orchestration (marine degradation) | ✅ |
| 4 | Presentation: ViewModels + `ViewState`, SwiftUI screens | ⏳ next |
| 5 | `docs/02`–`04`, full README, screenshots | — |

**Scoring model was reviewed and signed off at the Phase 1 checkpoint.** Three bugs were
found by printing a characterisation table, not by the tests. Do not change thresholds or
composition without re-running that table — see `docs/04-AI-Usage.md`.

**Composition principle, applied consistently:** a prerequisite is a *gate* (multiplies,
can veto), not a weighted factor. Skiing needs snow and running lifts; surfing needs
rideable swell and marine data; indoor sightseeing needs to be reachable. Outdoor
sightseeing is purely additive because it has no hard prerequisite.

---

## Architecture — non-negotiable

**Clean Architecture, applied consistently.**

```
Presentation  →  Domain  ←  Data
```

- `Domain` imports **`Foundation` only**. No SwiftUI, no UIKit, no URLSession, and no
  knowledge that `Data` or `Presentation` exist.
- **ViewModels call use cases. Never repositories.**
- Repository *protocols* live in `Domain/Repositories`; implementations in
  `Data/Repositories` (dependency inversion).
- Use cases are protocols with a `callAsFunction` requirement, so call sites read as verbs.
- Composition root is `App/DayCastApp.swift` + `App/DependencyContainer.swift`.
  Nothing else constructs concrete dependencies.

## Conventions

- **Swift 6** language mode, iOS 18.0+. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is on,
  so mark domain types `nonisolated` explicitly rather than inheriting main-actor isolation.
- **Scoring engine**: pure `nonisolated` functions. No I/O, and never read `Date()`
  internally — inject the reference date so tests are deterministic.
- **State**: `@Observable` + a generic `ViewState<T>` (`idle / loading / loaded / empty /
  failed`). Never `ObservableObject`. Never an `isLoading` + `error` + `data` triple.
- **Concurrency**: debounce and cancellation via `.task(id:)`. No Combine.
- **Tests**: Swift Testing — `import Testing`, `@Test`, `#expect`. Not XCTest.
- **Zero third-party dependencies.**
- Scoring weights and thresholds are **named constants**. No magic numbers.
- Both targets use `PBXFileSystemSynchronizedRootGroup`: files dropped in `DayCast/` or
  `DayCastTests/` join their target automatically. **Do not edit `project.pbxproj` to add
  source files.**

## Data-layer facts, verified against captured responses

Fixtures in `DayCastTests/Fixtures/` are **real Open-Meteo responses**, not hand-written.
Hand-written JSON agrees with the DTO by construction and tests nothing.

- **No `keyDecodingStrategy`.** `.convertFromSnakeCase` maps `temperature_2m_max` to
  `temperature2MMax` — capital `M`. Because the columns must be optional, a mismatch decodes
  as `nil` instead of throwing, and the whole week silently disappears. Every DTO spells its
  `CodingKeys` out.
- **Inland marine is `HTTP 200` with all-null values**, not an error. The mapper omits those
  days; an empty dictionary is a valid answer.
- **A geocoding search with no matches omits the `results` key entirely** — it is not `[]`.
- **Day labels parse at UTC midnight.** Forecast and Marine can snap to different grid
  points and report different `utc_offset_seconds`, so any other anchor breaks the merge's
  dictionary key. Presentation must format these with a UTC calendar.
- **`RecentSearchesRepository.replace(with:)`, not `save(_ city:)`.** De-duplication and the
  ten-item cap are business rules and belong in the use case; storage stays dumb.

## Domain rules that are easy to get wrong

- **Marine data is coastal-only.** A failed or empty Marine API response degrades
  *surfing alone* to "no coastal data". It must **never** fail the whole screen — an
  inland city still gets valid ski and sightseeing scores. Degradation is **per-day** —
  it falls out of the dictionary lookup in the merge, so don't reintroduce a city-wide flag.
- **Cancellation is the one marine error that is not swallowed.** `GetActivityForecast`
  rethrows `AppError.cancelled` and `CancellationError`. `.task(id:)` cancels on every
  keystroke, and swallowing that would render a coastal city as "no coastal data" from a
  superseded request.
- **Indoor sightseeing is not "always good."** It scores high when outdoor conditions are
  poor, then drops again when weather is travel-hostile (storm, heavy snow, gale).
- Ski and surf scores are **weather-only** — they do not know whether a mountain or beach
  is actually nearby. This limitation is surfaced in the UI, not just in the docs.
- Every score carries **human-readable reasons generated in the domain**, not assembled
  in the view.

## Considered and rejected — do not add

- A `DataSource` layer between repository and `HTTPClient` (`HTTPClient` *is* the data source)
- Presentation models that mirror domain entities 1:1
- Offline caching, Core Location, °C/°F toggle, a second weather provider, snapshot tests

Rationale is recorded in `docs/`. If one of these starts to look necessary, update the doc
rather than silently adding it.

## Documentation

`docs/` is the single home for planning, architecture decisions, assumptions, trade-offs,
and AI usage. Do not scatter rationale across code comments; the README stays short and
links into `docs/`.

**`docs/04-AI-Usage.md` is a running log — append to it at the end of every phase**, while
the details are fresh. Record specific moments: where AI output was wrong and how it was
caught, where the user overruled a recommendation and why. Generic bullets written at the
end ("used AI for brainstorming and code review") are worthless; dated, checkable
specifics are the whole point.

## Verify before calling a phase done

```bash
xcodebuild test -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Confirm the **exit code is 0** and `** TEST SUCCEEDED **` appears. The absence of visible
failures is not a pass — that mistake actually happened in Phase 0.

## Working style

Work proceeds in phases. Each phase ends on a green build and passing tests, then **the
user commits** — do not run `git commit`, `git push`, or create branches.
