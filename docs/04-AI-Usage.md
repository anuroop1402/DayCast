# 04 — AI Usage

> A **running log**, appended as work happens — not reconstructed at the end. Entries are
> dated and tied to specific commits so they can be checked against the history.

**Tool:** Claude (Claude Code) in the terminal, with a committed `CLAUDE.md` constraining
architecture rules and rejected alternatives.

## How I'm using it

I use AI the way I'd use a fast, well-read pair: to argue architecture, draft boilerplate,
and pressure-test edge cases. It does not get to make decisions, and its output is not
trusted because it looks confident.

Three rules I've held to:

1. **Nothing is committed on the basis that it looks right.** Builds and tests are run, and
   the *exit code* is checked — see 2026-09-04 entry below, where that caught a false pass.
2. **Documentation gets verified like code.** AI-written docs make claims. Claims about
   things that don't exist are bugs (see the CI-script entry).
3. **Architecture decisions are mine.** Where I disagreed, I overruled it and recorded why.

Constraints are pinned in `CLAUDE.md` rather than repeated per prompt, so drift across a
long session is structural rather than something I have to police by memory.

---

## Log

### 2026-09-03 — Architecture: I overruled the recommendation

**Proposed:** MVVM with an isolated domain layer, adding a use case *only* where real
orchestration existed (one: fetch forecast + marine, merge, score). The argument was that
`SearchCitiesUseCase { repo.search(query) }` is a passthrough that adds a file and no value.

**My decision: full Clean, use cases uniformly.** The proposal optimises for the smallest
possible file count, but "does this operation have *enough* orchestration to deserve a use
case?" is a judgement call that differs by reader. A uniform rule is defensible; a
case-by-case one invites "why does this have a use case and that doesn't?" in every code
review. Consistency of a pattern is worth more than the handful of files it saves.

Two sub-decisions I did accept, and they're recorded as *considered and rejected* in
`CLAUDE.md` so they read as decisions rather than gaps:
- No `DataSource` layer between repository and `HTTPClient` — `HTTPClient` *is* the remote
  data source; the extra layer would be a pure passthrough (it's an Android-sample
  convention, not a Clean requirement)
- No presentation models mirroring domain entities 1:1

### 2026-09-03 — "Presenter vs ViewModel" — pushed back on the vocabulary

I asked whether Clean still uses a ViewModel. The useful part of the answer was that
Clean's *ViewModel* is a passive struct emitted by a Presenter, which is not what MVVM
means by the word. Conclusion I acted on: the `@Observable` object occupies the
**Presenter** slot, and Clean's Presenter + passive-ViewModel pair collapses into one
object because SwiftUI's declarative binding already *is* the output boundary that pattern
was invented to hand-roll. Documented in `02-Architecture-Decisions.md` rather than left
implicit, since the naming looks like plain MVVM at a glance.

### 2026-09-04 — Verification caught a false pass ⚠️

The first `xcodebuild test` run printed no failures and was reported as passing. It wasn't
evidence — the command was piped through `tail`, and the captured exit code came back
empty, so nothing had actually been checked.

Re-ran with `set -o pipefail`, grepping explicitly for `** TEST SUCCEEDED **` and asserting
`EXIT: 0`. It did pass — but it passed *unverified* the first time, which is the failure
mode the brief calls out by name.

The rule is now written into `CLAUDE.md`: *"Absence of visible failures is not a pass."*
Every phase closes on an explicit exit-code check.

### 2026-09-04 — AI-written documentation overclaimed

`docs/01-Solution-Planning.md` stated the Clean dependency rule was *"enforced by a script
in CI, not just a diagram."* No such script existed — I'd created an empty `Scripts/`
directory and the doc described the intent as though it were done.

Caught before commit. Rather than write the script to make the sentence true, I moved
enforcement into the test target as an **architecture test** (Phase 1) — it runs with ⌘U
alongside everything else and needs no separate CI wiring — then corrected §7, the
milestone table, and the definition-of-done checkbox to match.

Documentation that describes work that hasn't happened is a defect. Docs get reviewed
against reality, not just for prose.

### 2026-09-04 — Diagnosis over retry: `git rebase --root`

Rewriting commit authorship (wrong GitHub account) failed on an untracked
`xcschememanagement.plist`. Moved it aside; it failed again on
`contents.xcworkspacedata`. The instinct — and the first suggestion — was to clear the
next blocker and continue.

Stopped and worked out the actual mechanism: `rebase --root` bases the replay on an **empty
sentinel commit**, and with `squash-onto` set it keeps the working tree in place, so
*every* tracked file becomes untracked relative to that HEAD. It wasn't two bad files; it
was going to block on all of them, and `--abort` was stuck behind the same check.

Switched to plumbing — `git commit-tree` against the existing trees, then a single
`update-ref`. No checkout, no merge, nothing to conflict. Verified the result: 2 commits,
correct identity, original messages and timestamps preserved, tree byte-identical to the
pre-rewrite state.

Two blockers is a coincidence; a mechanism predicts the third.

### 2026-09-04 — Challenging the brief: Marine API

The brief names the Geocoding and Forecast APIs. Neither exposes wave data, so surfing
would have to be inferred from wind speed — a poor proxy, since wind produces local chop
while surfable waves come from distant swell.

Open-Meteo publishes a separate Marine API with `swell_wave_height_max` and
`swell_wave_period_max`. Decision: use it, and treat the extension as a design decision
rather than scope creep — because it forces a genuinely interesting problem. Marine data
exists only for coastal coordinates, so the app needs an explicit **partial-failure
policy**: a missing marine response degrades *surfing alone* to "no coastal data" while
skiing and sightseeing still score. A whole-screen error there would be wrong.

That policy is exactly the orchestration that justifies the use-case layer, so the
extension pays for itself architecturally. Recorded in `01-Solution-Planning.md` §5.

### 2026-09-04 — Phase 1: green tests hid a broken model

Wrote the domain and 14 tests for the scoring engine. All 14 passed. Then printed a
characterisation table of the actual scores across ten scenarios, and two of them were
obviously wrong:

| | before | after |
|---|---|---|
| 24 °C sunny day, skiing | **40** ("fair") | 0 |
| Blizzard, 90 km/h gusts, skiing | **85** ("excellent") | 0 |

The summer day earned 25% for "not raining" and 15% for "not windy" while having no snow.
The blizzard had perfect snow, but gusts were only 15% of the score, so the model could not
express "every lift is shut".

**My tests passed because they asserted the behaviours I thought to check** — drizzle vs.
blizzard for indoor, rain vs. warmth for skiing. It never occurred to me to ask what a
summer day scores for skiing, so nothing asked. Green tests prove the assertions you wrote,
not that the model is right. Printing the actual output found in seconds what the suite was
structurally incapable of finding.

Both bugs now have regression tests naming the old score in a comment.

### 2026-09-04 — One flaw, three times: recognising the pattern

The fix was not "add a wind rule". Root cause: **additive factors let the absence of
negatives substitute for the presence of a prerequisite.**

I had already solved this twice without noticing it was the same problem — marine data gates
surfing, travel feasibility gates indoor sightseeing — and then failed to apply it to snow.
Once named, a third instance was visible immediately: swell height was a 40%-weighted factor,
so a clean period and warm air dragged a dangerous 4.2 m day to 53/100 and a flat sea to
12/100.

Now consistent: **skiing needs snow, surfing needs waves, indoor sightseeing needs to be
reachable.** Outdoor sightseeing stays purely additive because it has no hard prerequisite —
just accumulating discomfort. The distinction is documented in `ScoreComposition`.

Worth recording because the AI-suggested fix for the first bug was local ("increase the wind
weight"). Generalising it into a modelling principle, and then re-auditing the rules I had
already written, was the part that mattered.

### 2026-09-04 — A score of 0 explained with good news

The blizzard scored 0 for skiing and led with *"[favourable] 28 cm fresh snow"*. Both facts
were true and the ordering made the output nonsense.

Gate reasons are now sorted so `.limiting` always leads: *"Gusts to 90 km/h — lifts likely
closed"*, then the snow. A veto has to dominate the explanation as well as the arithmetic —
otherwise the number and the words disagree.

### 2026-09-04 — The architecture test caught itself first ⚠️

`ArchitectureBoundaryTests` fails the build if anything under `Domain/` imports beyond
`Foundation` or references `URLSession`/`UserDefaults`.

Its first run failed — on doc comments in `AppError` and `Repositories` that *explain* why
the domain avoids those types. A naive text search counted the explanation of the rule as a
violation of it. Fixed by stripping comments before scanning; a guard that fires on its own
documentation trains you to ignore it.

Then verified it can actually fail: injected `import SwiftUI` into a domain entity,
confirmed the suite went red with `(module → "SwiftUI") == "Foundation"`, and reverted. A
guard nobody has seen fail is not evidence of anything.

**Phase 1 result:** 40 tests, 5 suites, green.

### 2026-09-04 — Phase 2: fixtures are captured, never hand-written

Every decoding test loads a response **actually captured from Open-Meteo**, saved under
`DayCastTests/Fixtures/`. This was a deliberate reaction to the Phase 1 lesson: a
hand-written fixture encodes what you assumed the API returns, so it agrees with your DTO
by construction and tests nothing. Two of my assumptions were already wrong in code before
I checked them against real responses:

| assumption | reality |
|---|---|
| An inland city fails the Marine request | Prague returns **`HTTP 200` with every value `null`** |
| No search matches returns `"results": []` | The `results` key is **omitted entirely** |

Both would have shipped as user-visible bugs of the worst kind — *plausible* ones. Mapping
Prague's nulls to `0` would have claimed we measured a flat sea and scored surfing as
genuinely bad rather than unknown; a non-optional `results` array would have thrown
`keyNotFound` on a perfectly successful request and turned "no cities found" into an error
banner. Neither is visible from the API docs. Both are obvious the moment you `curl` it.

### 2026-09-04 — `.convertFromSnakeCase` broke the forecast silently ⚠️

The best bug of the phase, and it needed no AI to create — it's the idiomatic Swift choice.

`JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` capitalises every
underscore-separated component. `temperature_2m_max` therefore converts to
**`temperature2MMax`** — capital `M` — and the DTO's obvious `temperature2mMax` never
matched. Nothing threw. The columns *have* to be optional, because Open-Meteo nulls
variables it cannot produce for a grid point, so all seven temperature columns simply
decoded as `nil`, the mapper dropped every day for want of a temperature, and the
repository reported `AppError.noResults` on a completely valid response.

Every Open-Meteo variable that matters here carries a number — `2m`, `10m`. This was not an
edge case; it was most of the payload.

Caught by the fixture tests, which is exactly the job they were written for — a hand-written
fixture would not have caught it either, but only because the whole class of bug is
invisible without a real response to compare against. Verified the mechanism in a
standalone script rather than guessing at the conversion, then fixed it by **deleting the
key strategy entirely** and spelling out `CodingKeys` on both columnar DTOs. Explicit keys
can be diffed line-by-line against the API's `daily=` parameter list; a key strategy cannot
be diffed against anything.

The regression test asserts on **values**, not on the day count: a wrong key fails as a
plausible-looking zero, and the softer columns fall back to `0` by design, so
`count == 7` alone would not have stayed red.

### 2026-09-04 — Two dates that look identical and aren't

Forecast and Marine are requested with `timezone=auto` and can snap to **different grid
points**, so the same calendar day can come back with a different `utc_offset_seconds` from
each endpoint — Biarritz resolved to `Europe/Paris` on the marine side. Parsing those
`"2026-09-04"` labels in the device's timezone produces two different `Date` values for the
same day, and the marine merge is a dictionary keyed on exactly that value: it would have
missed silently and every day would have degraded to "no coastal data".

Anchored every label to **UTC midnight** so the value is a stable key, which also stops the
displayed day sliding by one for a user in Sydney checking Oslo. The constraint leaks into
the presentation layer — those dates must be formatted with a UTC calendar — so it is
recorded on `ForecastDate` where the next person will hit it.

### 2026-09-04 — Overruled: `save(_ city:)` on the repository

The natural signature for the recent-searches repository is `save(_ city: City)`. I changed
it to `replace(with cities: [City])`.

De-duplication and the ten-item cap are **business rules**. `save(_ city:)` forces storage
to decide where the city goes in the list and what falls off the end — the repository would
be implementing policy, and a second implementation would have to reimplement it
identically. `replace(with:)` keeps storage dumb: `SaveRecentSearchUseCase` reads, applies
the rules, and writes back. The domain keeps the policy, which is the entire point of
having the protocol live in `Domain/`.

Same instinct as the Phase 1 gate-vs-factor call: the abstraction should be shaped by where
the *decision* belongs, not by what reads most naturally at one call site.

**Phase 2 result:** 82 tests, 13 suites, green, exit code 0.

### 2026-09-04 — Phase 3: the swallowed error I had to argue for

`GetActivityForecast` catches the Marine API's errors and returns an empty dictionary.
Swallowing an error is the kind of thing a reviewer should stop on, and AI review flagged
it as one — the suggestion was to surface a `marineUnavailable` flag on `ActivityForecast`
so the UI could distinguish "inland" from "Marine API is down".

I rejected it. The two cases produce the **same user-visible outcome**: we do not know the
sea state, so surfing reports `insufficientData` and says so. A flag the UI cannot act on
differently is a field that exists to be ignored. The distinction is a *logging* concern,
not a presentation one.

But the challenge did find a real bug next to it. Blanket `catch` also swallows
**cancellation** — and `.task(id:)` cancels the previous request on every keystroke. Land
succeeding while marine is cancelled would have rendered a coastal city as "no coastal
data", from a request nobody was waiting on. `AppError.cancelled` and `CancellationError`
are now rethrown explicitly, with the reason written where the `catch` is.

The pattern is becoming familiar: the AI's *conclusion* was wrong, the thing it was looking
at was worth looking at.

### 2026-09-04 — Per-day degradation was free, and I nearly wrote it twice

I had planned a decision for this phase: does a *partial* marine response degrade the whole
city or only the missing days? I asked for both designs and got a plausible one for
"whole city" — count the days, compare against the window, degrade everything if short.

It was unnecessary. The merge is `days.map { $0.withMarine(marine[$0.date]) }` — a
dictionary lookup that already yields `nil` for a missing key. Per-day degradation is what
the data structure does on its own; the "whole city" version would have been extra code to
make the answer *worse*. The test `degradationIsPerDay` pins it so a future refactor cannot
quietly reintroduce the choice.

Worth recording because the mistake was mine, not the model's: I asked for a comparison of
two designs before checking whether the question had an answer already.

### 2026-09-04 — A passing test that proved nothing

The first version of `shortQueryDoesNotHitTheNetwork` asserted only `cities.isEmpty`. That
passes whether or not the network is touched — an empty stub returns empty either way. It
now stubs the repository with `.failure(.offline)`, so the test fails loudly if the request
is ever made, and asserts `repository.queries.isEmpty`.

Third time this project that a green test has been the problem rather than the evidence
(Phase 0's false pass, Phase 1's characterisation table, now this). The habit that catches
it is asking *"what would have to break for this test to fail?"* — if the answer is
"nothing I changed", the test is decoration.

**Phase 3 result:** 103 tests passing, exit code 0.

### 2026-09-04 — Phase 4: a test that passed because of where I live ⚠️

`DayLabel.weekday` turns a forecast date into "Today" / "Tomorrow" / "Friday". I wrote it
reading `Calendar.current` to find the user's day, and wrote a test asserting that 23:00 on
day 0 still reads as "Today".

It failed — and the failure was the useful part. My machine is on IST (UTC+5:30), so
23:00 UTC is already 04:30 the *next* day locally, and the function correctly returned
"Thursday". The implementation was right; **the test was asserting my timezone**. Worse, the
inverse was also true: the two tests that did pass would have failed in New York. A suite
that green-lights or red-lights code based on where the developer is sitting is not a suite.

The fix was not to adjust the expected strings. `Calendar.current` is a hidden read of the
environment — the same defect as the scoring engine reading `Date()` internally, which
`CLAUDE.md` already forbids, and I did not recognise it as the same thing until the test
broke. The timezone is now an injected parameter, and the tests run the same assertions
through UTC, Asia/Kolkata and America/New_York. Asia/Kolkata is deliberate: a half-hour
offset breaks any accidental assumption that offsets are whole hours.

Fourth time on this project a green test has been the problem rather than the evidence.

### 2026-09-04 — The question the compiler asked that I hadn't

`nonisolated enum ViewState` compiled. `extension ViewState: Equatable where Value: Equatable {}`
compiled. The *test* did not:

> main actor-isolated conformance of 'ViewState<[Int]>' to 'Equatable' cannot be used in
> nonisolated context

`nonisolated` on a type does not carry to its extensions. With
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the unmarked extension picked up main-actor
isolation and took the `Equatable` conformance with it. The app target never noticed,
because every consumer was already on the main actor — only a `nonisolated` test found it.

Worth recording because `CLAUDE.md` already said "mark domain types `nonisolated`
explicitly" and I read that as being about *types*. It is about every declaration.

### 2026-09-04 — Where I stopped short: I could not drive the simulator

The phase's exit criterion is "runs on simulator, all states reachable". I got the app
built, installed, launched and screenshotted at its idle state — then could not tap the
search field, because `simctl` has no tap primitive and AppleScript keystrokes go nowhere
without focus. Two attempts, then I stopped rather than burning the phase on simulator
automation.

So: **launch and first render are verified; the search → forecast → breakdown flow is not.**
Recording it here rather than letting "Phase 4 complete" imply more than was checked. The
screenshots that Phase 5 owes are the natural place to close this properly.

### 2026-09-05 — The bug no test could have found

Running the app against Queenstown produced a card reading **"Best day for Ski:
Wednesday"** above a red **Unsuitable** badge. Every number behind it was right — I checked
against the live API: Wednesday genuinely had the week's most snowfall (3.01 cm), and the
town sits at 322 m while its ski fields are at 1200–1900 m, so a hopeless weather-only ski
score is the documented limitation working exactly as designed.

The defect was the *card contradicting itself*. Someone skimming the strip reads the day,
not the badge. `bestDay(for:)` returning the highest-scoring day is correct domain
behaviour; presenting that day as a recommendation when the answer is "don't" is a
presentation bug, and no unit test would ever have flagged it because every assertion it
could make was already passing.

Fixed by moving the rule into `ForecastViewModel` as `BestDaySummary` — in a private view
struct it would have stayed untestable, and this project deliberately has no snapshot
tests. `.unsuitable` now names no day; `.poor` still does, because "least bad" is useful
when a week is merely mediocre and stops being useful when the answer is *don't*.

It also caught a VoiceOver bug on the way: the card was about to read "Skiing, dash,
Unsuitable", which tells a screen-reader user nothing. It now reads "Skiing: no suitable
day in the next 7 days".

The lesson is about *my* process, not the model's: I called Phase 4 complete on 133 green
tests without having looked at the app against real data. The user looked, and found this
in one screenshot.

### 2026-09-05 — Two wrong answers from taking the first search result

Hunting for a city that would actually score for skiing, I scripted a geocoding sweep with
`count=1` and reported that La Paz was 26 m and 33.8 °C, and that Leh was at sea level.
Both were the wrong continent — La Paz, Mexico and a coastal Leh, not Bolivia and Ladakh.

The irony is that this is precisely the failure the app already prevents: search results
carry `admin1, country` so the user disambiguates, and `SaveRecentSearch` de-duplicates on
Open-Meteo's numeric `id` rather than on name for exactly this reason. My throwaway script
skipped the safeguard the real code has.

Confirmed live: searching **Farellones** returns the 173 m one in Aysén *first* and the
2458 m ski town second. The subtitle is what makes that survivable.

**Phase 4 result:** 136 tests passing, exit code 0. The first run came back exit code 65
with zero test failures — a simulator preflight flake that never launched the app. Exactly
the case the exit-code rule exists for, and the second time this session it has fired.

### 2026-09-05 — I predicted Excellent, the app said Fair, and the app was right ⚠️

To find a city where skiing would actually score, I wrote a throwaway script approximating
the scoring curves and predicted Valle Nevado would come back **Excellent**. I flagged it as
a prediction rather than a measurement, and said a materially different result was worth
investigating. The app returned **Fair**.

Recomputing with the real rule logic showed the app was correct — best day Friday, 47/100.
Two causes, both mine:

1. **The forecast had moved.** My data was ~13 hours old: 13.2 cm of snow on the 10th had
   become 4.4 cm, halving the snow gate from 0.88 to 0.50 and dragging the whole week down.
2. **My script approximated the curves.** I modelled the existing-base credit as a step
   function; the real rule ramps it linearly from −2 °C to +4 °C.

The useful part is that the discrepancy was *checkable*. Because the thresholds are named
constants and the composition is documented, reproducing the model outside the app took
twenty lines. Had the weights been magic numbers inside a `switch`, "is the app wrong?"
would have been unanswerable.

### 2026-09-05 — Two bugs a screenshot found and 136 tests could not

Looking at the breakdown screen for Valle Nevado:

```
Temperature          -8–-2 °C          ← three dashes in a row, unreadable
Snowfall              4.4 cm
...
⚠️ Thin cover — no fresh snow          ← four rows below "4.4 cm"
```

The first is a range joined with an en dash, colliding with two minus signs — and at a ski
resort both ends are negative for most of the season, so this is the normal case, not an
edge case. Fixed by using "to" for every range rather than switching separator by sign: one
format is harder to get wrong later than a conditional one.

The second is worse — the app contradicting itself. `SkiingRule` only calls snowfall
"notable" at ≥ 5 cm, so 4.4 cm fell through to a catch-all sentence written for days with
genuinely zero snow. The *score* was right; a 0.50 snow gate is exactly what capped it at
Fair. The sentence was false, sitting directly beneath the number that disproved it. Now
"Only 4.4 cm fresh snow", with a 0.5 cm floor below which a trace is still reported as none.

**Not one existing test broke.** They assert on `ScoreReason.factor` and `.sentiment`, never
on copy — a Phase 1 decision made for exactly this reason, which paid for itself here. Two
regression tests added.

That is the third bug this project found by looking at the running app rather than by
testing it, after the Phase 1 characterisation table and the Phase 4 best-day contradiction.
All three shared a shape: every individual number correct, and the combination lying.

### 2026-09-05 — Phase 5: writing down where the plan was wrong

`docs/03` was specified in `01` as the place the plan and the outcome get compared. The
temptation in writing it was to present the finished design as though it had been the
intention — the scoring model as a considered gate-based architecture, rather than as a bug
fix applied after a fully green test suite had shipped a 24 °C ski day at 40/100.

Section 2 is written the other way round: *the plan was wrong here, here and here.* It also
records the one place the shipped app deviates from a commitment in `01` — the day list
shows each day's top activity rather than all four — because a document that records only
the deviations flattering to its author is not a record.

**Phase 5 result:** 138 tests passing, exit code 0. `docs/02`, `docs/03`, a rewritten README,
and three screenshots captured from the running app.

---

*Log complete. Five phases, five commits, each on a green build.*
