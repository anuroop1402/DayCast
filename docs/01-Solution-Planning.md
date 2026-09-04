# 01 — Solution Planning

> Written **before** implementation began, at the end of Phase 0. Deliberately not
> revised afterwards — later phases record what actually changed in
> `03-Assumptions-and-Tradeoffs.md`, so the gap between plan and outcome stays visible.

**Date:** 2026-09-04
**Platform:** iOS (Swift 6, SwiftUI, iOS 18.0+)

---

## 1. Problem understanding

Let a user search for a city, then answer one question for the next 7 days:

> *"How good is each of these four days for skiing / surfing / outdoor sightseeing /
> indoor sightseeing?"*

The brief is explicit that the interesting part is **not** fetching weather. It is:

1. **Defining suitability.** There is no "correct" ski score. I have to invent a defensible
   model, state its assumptions, and make it inspectable.
2. **Structuring the app** so the scoring model is isolated, testable, and cheap to change
   when someone disagrees with it — because they will.
3. **Communicating reasoning**, including where I chose an assumption instead of asking.

So the deliverable is really *a scoring model with an app around it*, not a weather app
with a score bolted on.

## 2. Requirements

**Explicit (from the brief)**
- Search for a city or town
- Rank next 7 days for 4 activities
- Open-Meteo Geocoding API + Forecast API
- Native iOS, no backend

**Inferred (my calls, not stated in the brief)**
- Scores must be **explainable** — a number with no "why" is not useful and is not
  defensible in review. Every score carries human-readable reasons.
- Loading / empty / error states are part of "the application", not polish.
- The 4 activities are fixed, but adding a 5th must not require touching the UI.
- No login, no backend, no sync.

## 3. Questions I would have asked a PM — and what I assumed instead

| Question | Assumption committed to | Why |
|---|---|---|
| What does "indoor sightseeing" suitability even mean? Museums are open in the rain. | Score = *relative attractiveness of going indoors*: high when outdoor conditions are poor, **but reduced again when weather is travel-hostile** (storm, heavy snow, gale). | A flat "always 90" is useless to a user. Modelling it as "bad outdoors → good indoors, unless you can't safely get there" makes it a real signal. Biggest judgement call in the project. |
| Rank days per activity, or activities per day? | **Both.** Primary view is day-by-day (all 4 activities per day); the best day per activity is surfaced at the top. | "Rank how suitable the next 7 days will be for each activity" reads as per-activity ranking, but users plan by day. Cheap to do both from the same scored data. |
| Ski score for a city with no mountains? Surf score for Prague? | Score the **weather at the city's coordinates**, not terrain. Surfing degrades explicitly to "no coastal data" when the Marine API returns nothing. | Terrain/resort data is out of scope and not in Open-Meteo. Being honest about *no data* beats inventing a plausible-looking number. |
| Units — °C/km/h or °F/mph? | Metric, fixed. | Open-Meteo's defaults. A unit toggle is presentation-only and adds no architectural signal. |
| How precise must scores be? | 0–100, shown as 5 named bands (Excellent → Unsuitable). | False precision ("73.2% suitable") oversells a model built on assumptions. Bands communicate confidence honestly. |
| Whose "today" is Today — the user's, or the city's? | **The user's own calendar day.** | Open-Meteo returns the *city's* local days, so for a few hours each day the two disagree — a user in Mumbai at 04:30 looking at Oslo is already on the next date. The phone's day wins because it matches the calendar the user is holding; the cost is that in that window the row labelled "Today" is the city's tomorrow. Surfaced in `DayLabel`, where the timezone is an injected parameter rather than a hidden read of `Calendar.current`. |

## 4. Scope

**In**
- ✅ City search (Geocoding API), debounced, with recent searches (UserDefaults)
- ✅ 7-day forecast (Forecast API)
- ✅ **Marine API** for real wave data — deliberate extension, see below
- ✅ Suitability engine: 4 activities, weighted factors, explainable reasons
- ✅ Loading / empty / error / retry states
- ✅ Unit tests: scoring engine, DTO decoding against captured real responses, use-case
  orchestration, ViewModel state transitions
- ✅ Dynamic Type + VoiceOver labels

**Out — and why**
| Not building | Reason |
|---|---|
| Offline caching / persistence of forecasts | Forecasts go stale fast; a cache layer is real work whose main output is cache-invalidation bugs. Not what's being assessed. |
| Core Location ("use my location") | Adds permissions plumbing and a privacy dialog; demonstrates no new architectural thinking beyond the search path already built. |
| User accounts, saved locations, notifications | No backend, and outside the brief. |
| Multiple weather providers behind one interface | The repository protocol already makes this possible. *Building* a second provider proves nothing the abstraction doesn't already show. |
| Unit toggle (°C/°F), theming, localisation | Presentation-only surface area. |
| UI snapshot tests | High maintenance cost, low signal for a 3-screen app; effort better spent on domain tests. |

The brief says feature volume is not the goal, so this list is intentionally aggressive.

## 5. The Marine API decision

The brief names the Geocoding and Forecast APIs. Neither exposes wave data, so surfing
would have to be guessed from wind speed — which is a poor proxy: wind creates local chop,
whereas surfable waves come from distant **swell**.

Open-Meteo publishes a separate **Marine API** with `swell_wave_height_max` and
`swell_wave_period_max`. I'm using it, and treating the extension as a design decision
rather than scope creep, because it forces a genuinely interesting problem:

> Marine data only exists for coastal coordinates. For Prague it returns nothing.

That means the app needs an explicit **partial-failure policy**: a failed or empty marine
response must degrade *surfing only* to "no coastal data", while skiing and sightseeing
still score normally. A whole-screen error there would be wrong.

That policy is exactly the kind of orchestration that justifies a use-case layer, so this
extension pays for itself architecturally.

## 6. Suitability model — first pass

Each activity scores as a **weighted sum of normalised factors**, each factor a
piecewise-linear curve over an "ideal band":

```
score(activity, day) = Σ (weightᵢ × factorScoreᵢ(day))    → 0...100
                       where Σ weightᵢ = 1.0
```

| Activity | Primary factors (first pass — expect revision in Phase 1) |
|---|---|
| **Skiing** | fresh snowfall; temperature at/below freezing (so snow holds); *rain* heavily penalised; high wind gusts penalised (lifts close) |
| **Surfing** | swell height (ideal band ~1–3 m — too small is flat, too big is dangerous); swell period (longer = cleaner); wind speed (strong wind = chop); water/air temp as minor comfort |
| **Outdoor sightseeing** | precipitation (dominant); temperature comfort band ~15–25 °C; wind; sunshine duration; extreme UV penalised |
| **Indoor sightseeing** | inverse of outdoor comfort, then penalised again by travel-hostile extremes (storm, heavy snow, gale) |

Each factor returns a score **and a reason string**, so the UI can explain *"Poor — heavy
rain, strong winds"* rather than just showing 22/100. Reasons are generated by the domain,
not assembled in the view.

Design constraints for the engine:
- Pure functions, `nonisolated`, zero I/O, no `Date()` read internally (time is injected)
- One rule type per activity behind a common protocol → a 5th activity is a new file, not
  an edit to a switch statement
- Weights and thresholds as named constants, not magic numbers, so they are reviewable

Ski and surf scores are **weather-only**; they do not know whether a mountain or a beach is
actually nearby. This is stated in the app UI, not just in the docs.

## 7. Architecture (summary — full rationale in `02-Architecture-Decisions.md`)

**Clean Architecture**, applied consistently:

```
Presentation  →  Domain  ←  Data
   (SwiftUI       (pure)      (Open-Meteo,
    @Observable                UserDefaults)
    ViewModels)
```

- `Domain` imports nothing but `Foundation`. Enforced by an **architecture test** in the
  test target (Phase 1) that scans domain sources for forbidden imports — an executable
  rule, not just a diagram.
- ViewModels talk **only** to use cases, never to repositories.
- Repository protocols live in `Domain`; implementations live in `Data` (dependency inversion).
- State: `@Observable` + a generic `ViewState` enum (`idle / loading / loaded / empty / failed`)
  so illegal states are unrepresentable.
- Zero third-party dependencies.

## 8. Milestones

| Phase | Deliverable | Done when |
|---|---|---|
| **0** | Test target, Swift 6, iOS 18 target, folder skeleton, shared scheme, this document | ✅ build + tests green |
| **1** | Domain: entities, scoring engine + 4 rules, use-case & repository protocols, `AppError`, architecture-boundary test | scoring fully unit-tested with **no networking in existence yet** |
| **2** | Data: DTOs, `HTTPClient`, 3 repository impls, mappers | decoding tested against **real captured JSON**, including an inland city with no marine data |
| **3** | Use-case implementations + orchestration | marine-degradation path tested |
| **4** | Presentation: ViewModels + tests, then SwiftUI screens | runs on simulator, all states reachable |
| **5** | Docs 02–04, README, screenshots | clean checkout builds and tests green |

Each phase ends on a green build and a commit, so the history reads as a narrative rather
than one large drop.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Scoring model is subjective and could look arbitrary | Named constants, documented reasoning per factor, exhaustive boundary tests, reasons surfaced in-app |
| Marine API behaviour for inland cities is undocumented | Probe it in Phase 2 and **capture the real response as a fixture** rather than assuming |
| Swift 6 strict concurrency friction | Enabled in Phase 0 while the codebase is empty — incremental cost instead of a big-bang migration at the end |
| Over-engineering Clean for a small app | Documented as deliberate in `02`, including the two places I stopped short (no DataSource passthrough layer, no duplicate presentation models) |

## 10. Definition of done

- [ ] Fresh clone builds and `xcodebuild test` passes with no manual setup
- [ ] `Domain` has zero imports outside `Foundation` (verified by an automated architecture test)
- [ ] Every score in the UI is explainable by tapping into a breakdown
- [ ] Inland city (no marine data) degrades surfing only, not the screen
- [ ] Airplane mode shows a real error state with retry, not a spinner forever
- [ ] README: what, how to run, assumptions, screenshots
