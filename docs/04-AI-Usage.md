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

---

*Appended per phase. Next: Phase 2 — Open-Meteo client, DTOs, repository implementations.*
