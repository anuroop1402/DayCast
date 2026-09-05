# 03 — Assumptions and Trade-offs

> [`01-Solution-Planning.md`](01-Solution-Planning.md) was written before implementation and
> deliberately not revised. This document is where the plan and the outcome are compared, so
> the gap stays visible instead of being edited away.
>
> Five parts: what the scoring model assumes, **where the plan turned out to be wrong**, the
> known limitations, how each definition-of-done criterion was verified, and what I would do
> next.

---

## 1. What "suitable" means — the assumptions the model rests on

There is no correct ski score. Every number in this app is the output of a model I invented,
and the model is only defensible if its assumptions are stated. These are the load-bearing
ones.

### The user I am scoring for

| Assumption | Consequence if wrong |
|---|---|
| A **competent recreational** surfer, not a beginner and not an expert. | The ideal swell band (1.0–2.5 m) is wrong for both ends. A beginner wants 0.3–0.8 m; an expert is fine at 4 m. |
| A **recreational** skier on marked runs, not a ski tourer. | Lift operability is modelled as a hard gate. A tourer does not care whether lifts run. |
| Someone who will actually **go outside** if conditions are good. | Indoor sightseeing is scored as *relative attractiveness*, so it rises when outdoor conditions fall. For a user who only ever visits museums, that inversion is noise. |
| Sightseeing means **walking around a city**, roughly 2–4 hours. | Temperature and precipitation dominate; a 20-minute dash between galleries would weight them far less. |

Every one of these is a question I would have asked a PM. They are recorded as assumptions
in `01` §3 because guessing and saying so is more useful than guessing silently.

### The thresholds, and where they came from

Thresholds are named constants, chosen from ordinary domain knowledge rather than data — I
have no labelled dataset of "good ski days". They are reviewable precisely because they are
named: disagreeing with `swellIdealFromMetres = 1.0` is a one-line conversation.

| Constant | Value | Reasoning |
|---|---|---|
| `excellentFreshSnowCm` | 15 cm | A 15 cm dump is a genuinely good powder day. |
| `baseHoldsAtOrBelowCelsius` | −2 °C | Cold enough that an existing base survives without new snow. |
| `maxCreditForExistingBase` | 0.5 | We can see air temperature, not snow depth. Half credit for an **unobserved** base is a deliberate cap on a guess. |
| `liftsRunAtOrBelowGustsKph` | 60 | Below this, wind is unpleasant; above it, lifts start closing. |
| `rainRuinsDayMillimetres` | 5 mm | Rain destroys a snow base far faster than warmth alone. |
| `swellIdealFromMetres` … `To` | 1.0–2.5 m | Rideable and fun for the assumed surfer. |
| `swellPeriodExcellentSeconds` | 12 s | Long-period groundswell is clean and powerful; short-period sea is wind slop. |

**The most important structural assumption:** a prerequisite is a *gate*, not a weighted
factor. That one is not a guess — it is a bug fix, and §2 explains why.

### Deliberate honesty over deliberate precision

- **Scores are shown as five bands, never as raw numbers.** A model built on the assumptions
  above does not earn "73% suitable". Bands communicate the confidence the model actually
  has. The 0–100 value exists internally so days can be ranked.
- **`insufficientData` is a distinct outcome, not a score of 0.** Telling a user Prague has
  bad surf is a lie; telling them we could not tell is true.
- **Ski and surf are weather-only.** Nothing in Open-Meteo says whether a mountain or a
  rideable beach is at these coordinates. This is stated **in the app**, not just here —
  see the caveat below the day list.

---

## 2. Where the plan was wrong

### 2.1 The scoring model was structurally broken, and the tests all passed

`01` §6 specified one composition rule for every activity:

```
score = Σ (weightᵢ × factorᵢ)    where Σ weightᵢ = 1.0
```

That is what Phase 1 built, with full unit-test coverage, all green. Then I printed a
characterisation table of real scores for real days and found three bugs at once:

| Day | Activity | Scored | Should be |
|---|---|---|---|
| 24 °C, sunny, no snow | Skiing | **40 / 100** | 0 |
| Blizzard, 90 km/h gusts | Skiing | **85 / 100** | near 0 |
| 4.2 m swell, clean period | Surfing | **53 / 100** | near 0 — dangerous |

The warm day collected 25% for "not raining" and 15% for "not windy" while having no snow at
all. The blizzard could not express "every lift is shut", because gusts were only 15% of the
total.

**One flaw, three times: additive factors let the absence of negatives substitute for the
presence of a prerequisite.** Snow is not something you trade against wind — without it
there is no skiing at any temperature.

The fix was AD-7: prerequisites became **gates** that multiply the whole score. Outdoor
sightseeing stayed purely additive because it genuinely has no hard prerequisite — the
asymmetry is the model, not an inconsistency.

**What this cost, and the lesson.** Every unit test passed before and after. They asserted
that each factor curve behaved correctly, which was true and irrelevant — the defect was in
how the factors *combined*, and no test was looking there. Printing a table of real outputs
found in ten minutes what the suite could not.

> **Do not change thresholds or composition without re-running that characterisation table.**

### 2.2 The day list shows one activity, not four

`01` §3 committed to: *"Primary view is day-by-day (all 4 activities per day)."*

The shipped forecast screen shows each day led by its **top-ranked** activity, with all four
and their reasons one tap away in the breakdown.

Four ratings per row across seven rows is 28 badges on one screen — unreadable at default
Dynamic Type and worse at accessibility sizes. The screen answers the two real questions
separately instead: the summary strip answers *"when should I ski?"*, the list answers
*"what should I do on Thursday?"*. Nothing was lost; the "all four" view moved one level
down, where there is room for the reasons too.

### 2.3 Two hidden environment reads that made tests lie

Neither was planned for, and both are the same defect.

`CLAUDE.md` already forbade the scoring engine from reading `Date()` internally. I then
wrote `DayLabel` reading `Calendar.current` — and its tests passed on my machine (UTC+05:30)
and would have failed in New York. A test that asserts the developer's timezone is not a
test. The timezone is now an injected parameter, and assertions run through UTC,
Asia/Kolkata and America/New_York.

The general rule, now in `CLAUDE.md`: **never read `Date()` or `Calendar.current` inside a
rule or a formatter.** Inject them.

### 2.4 Marine partial failure needed no decision at all

I had planned to decide whether a *partial* marine response should degrade the whole city or
only the missing days, and asked for both designs. The question had already answered itself:
the merge is a dictionary lookup, which yields `nil` for a missing key. Per-day degradation
is what the data structure does unaided; the city-wide version would have been extra code
producing a worse answer.

Recorded because the mistake was mine — I compared two designs before checking whether the
question was live.

### 2.5 What the plan got right

For balance, since the above is all corrections: the marine-degradation policy, the
UTC-midnight date anchoring, capturing real fixtures rather than hand-writing JSON, and the
architecture-boundary test were all specified in `01` before implementation and all survived
contact unchanged. The inland-city risk in `01` §9 was mitigated exactly as planned — probe
it, capture the real response — and the captured response turned out to be `HTTP 200` with
all-null values rather than the error I had expected.

---

## 3. Known limitations

Things the app genuinely does not do well. Listed because a take-home that claims no
weaknesses is not being read carefully.

| Limitation | Why it stands |
|---|---|
| **Ski scores are useless for most ski towns.** Queenstown scores Unsuitable because the town sits at 322 m while its ski fields are at 1200–1900 m. Valle Nevado scores well because the resort *is* the searchable place. | Elevation-corrected forecasting needs resort data Open-Meteo does not expose. The UI states the limitation rather than hiding it. |
| **Surf scores do not know about beaches.** A coastal city with no surfable break still gets a swell-based score. | Same reason. `insufficientData` covers *no marine data*, not *no beach*. |
| **No offline capability.** Airplane mode gives an error state with retry, not stale data. | Forecasts go stale fast; a cache layer's main output is cache-invalidation bugs. Cut in `01` §4. |
| **Recent searches are lost if `City`'s shape changes.** | AD-12 — a bounded failure the app already handles as an empty state. |
| **"Today" can disagree with the city's today** for a few hours a day. | `01` §3 — the phone's calendar wins. |
| **The 7-day window is fixed.** | The brief specifies it. `GetActivityForecast.forecastDays` is one constant. |

---

## 4. Definition of done — verified

[`01-Solution-Planning.md`](01-Solution-Planning.md) §10 committed to six criteria. All six
were checked against the running app or the real repository rather than assumed.

| Criterion | Verified | How |
|---|---|---|
| Fresh clone builds and `xcodebuild test` passes with no manual setup | ✅ | Cloned from the remote into an empty directory and ran the README's exact command: exit code 0, 138 tests. No package resolution, no scheme selection, no keys. |
| `Domain` has zero imports outside `Foundation` | ✅ | `ArchitectureBoundaryTests` reads the source files on every ⌘U. |
| Every score in the UI is explainable by tapping into a breakdown | ✅ | Screenshot 3 — conditions the score can be audited against, plus the reason the domain generated. |
| Inland city degrades surfing only, not the screen | ✅ | Queenstown and Valle Nevado, live. Marine returns `HTTP 200` with all-null values; surfing reads "No data" while skiing and both sightseeing scores stand. |
| Airplane mode shows a real error state with retry, not a spinner forever | ✅ | Wi-Fi off mid-search → "No connection" with a working **Try again**; Wi-Fi on → retry recovered and returned results. |
| README: what, how to run, assumptions, screenshots | ✅ | — |

![Offline state](screenshots/04-offline.png)

The offline path is the one worth showing rather than asserting. `ViewState.failed` carries
the `AppError` rather than a bare flag precisely so the view can ask `isRetryable` — the
button appears because `.offline` says retrying could work, and it would *not* appear for
`.decoding`, where retrying the identical request cannot help.

---

## 5. What I would do next

Roughly in order of value per hour, if this continued past the exercise.

1. **Elevation correction for skiing.** The single largest source of wrong answers, and
   *not* the one-parameter change it first appears to be. I probed the API rather than
   assume, and the result is worth writing down.

   Open-Meteo's Forecast API accepts an `elevation` parameter and genuinely downscales
   temperature — Queenstown at 1900 m instead of its true 322 m:

   | | 09-05 | 09-06 | 09-07 | 09-08 | 09-09 | 09-10 | 09-11 |
   |---|---|---|---|---|---|---|---|
   | 322 m (auto) | 9.2 | 9.0 | 9.8 | 13.0 | 10.7 | 4.8 | 7.2 |
   | 1900 m | −1.1 | −1.3 | −0.5 | 2.7 | 0.4 | −5.5 | −3.1 |

   That is a ~0.58 °C/100 m lapse rate, and it would fix the *base-credit* half of the snow
   gate on its own.

   **But precipitation is not re-derived.** `precipitation_sum`, `rain_sum` and
   `snowfall_sum` come back byte-identical at 322 m and 1900 m. So 5 September reports
   −1.1 °C *and* 3.4 mm of rain — at a temperature where it is plainly falling as snow.

   That combination is worse than the current honest limitation: the temperature gate would
   open while fresh snowfall stayed near zero, and `rainFactor` would keep applying its 0.35
   penalty for rain that is not happening on the mountain. **Confidently wrong beats
   honestly limited only if you do the rest of the work.**

   So the real task is reclassifying precipitation phase in the mapper — take
   `precipitation_sum` (which is elevation-independent, so safe to reuse), split rain from
   snow against the downscaled temperature, and convert millimetres of water to centimetres
   of snow at roughly 10:1. That is a meteorological model with assumptions of its own, and
   it would need documenting here alongside the existing thresholds.

   A second open question: **where the target elevation comes from.** Open-Meteo will not
   say that Queenstown has a ski field 1600 m above it. A user-facing control ("score skiing
   at +1000 m") needs no new data source and makes the guess visible rather than burying it,
   which is the choice most consistent with the rest of this project. A terrain lookup for
   the highest point within ~15 km is the correct answer and costs a second provider.

   Architecturally the change is contained: `SkiingRule` needs no edit at all, because it
   consumes `DailyWeather` and would simply receive corrected values. The cost is that
   skiing and sightseeing then want *different* elevations, making this a third concurrent
   request — which `GetActivityForecast` is already shaped for.
2. **A characterisation-table test.** The manual table found three bugs no unit test could.
   Committing its output as an approved snapshot would make composition changes visible in a
   diff instead of relying on someone remembering to re-run it. This is the highest-value
   test not yet written.
3. **Tune the model against real days.** Every threshold is reasoned rather than measured.
   Even a few dozen hand-labelled days would turn opinions into evidence.
4. **UI tests for the three screens.** Snapshot tests were rejected and I stand by that, but
   the best-day contradiction (`AD-14`) showed the cost. A small number of flow-level UI tests
   would catch what unit tests structurally cannot.
5. **Localisation.** All copy is English and hard-coded. The structure is ready — display
   strings are already isolated in `Presentation/Formatting`.

**What I would still not add**, and the reasoning is in `01` §4: offline caching, Core
Location, a °C/°F toggle, a second weather provider, or a `DataSource` layer. Each was
considered and rejected on cost-versus-signal, not overlooked.
