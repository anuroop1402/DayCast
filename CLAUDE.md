# DayCast

Take-home exercise: a native iOS app that searches for a city and ranks the next 7 days
for **skiing, surfing, outdoor sightseeing, and indoor sightseeing** using Open-Meteo.
No backend.

Assessed on engineering judgment, not feature volume. All written reasoning lives in
`docs/` — see `docs/01-Solution-Planning.md` for scope and assumptions.

---

## Current state — update this at the end of every phase

**Phase 1 complete** (domain entities, scoring engine, 4 rules, protocols, 40 tests green).
**Phase 2 is next: Data layer — DTOs, HTTPClient, repository implementations.**

| Phase | | |
|---|---|---|
| 0 | Foundations, test target, `docs/01-Solution-Planning.md` | ✅ |
| 1 | Domain: entities, `SuitabilityRule` × 4, `AppError`, protocols, architecture test | ✅ |
| 2 | Data: DTOs, `HTTPClient`, 3 repository impls, mappers | ⏳ next |
| 3 | Use-case implementations + orchestration (marine degradation) | — |
| 4 | Presentation: ViewModels + `ViewState`, SwiftUI screens | — |
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

## Domain rules that are easy to get wrong

- **Marine data is coastal-only.** A failed or empty Marine API response degrades
  *surfing alone* to "no coastal data". It must **never** fail the whole screen — an
  inland city still gets valid ski and sightseeing scores.
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
