# How I Worked

This is the entry point for the process behind the app: how the work was sequenced, how AI
output was verified, and where my own reasoning turned out to be wrong. The other documents
describe the result; this one describes getting there.

**If you have ten minutes, read in this order:**

1. This file.
2. [`04-AI-Usage.md`](04-AI-Usage.md) — the running log. Where AI was wrong, how it was
   caught, where I overruled it. Written as the work happened, not assembled at the end.
3. `git log` — one feature commit per phase, each on a green build, plus the `docs:` and
   `fix:` commits between them. The messages carry the reasoning; several are longer than
   the diff.
4. [`03-Assumptions-and-Tradeoffs.md`](03-Assumptions-and-Tradeoffs.md) §2 — where the plan
   turned out to be wrong.

---

## 1. The shape of the work

Five phases, in order, each ending on a green build and a commit:

| Phase | | Commit |
|---|---|---|
| 0 | Project foundations, test target, planning doc | `2563773` |
| 1 | Domain: entities, 4 scoring rules, protocols, architecture test | `6c2018e` |
| 2 | Data: DTOs, HTTP client, 3 repositories, mappers | `ee27c4d` |
| 3 | Use cases, concurrent forecast merge, marine degradation policy | `be1a769` |
| 4 | Presentation: `ViewState`, ViewModels, SwiftUI screens | `7194e08` |
| 5 | Architecture decisions, assumptions, README, screenshots | `6d62846` |

Domain first, on purpose. The scoring engine is the only part of this problem that isn't
already solved by the platform, so it got built first, in isolation, with no network and no
UI to hide behind.

Work continued after phase 5, once the app had been read and used rather than only tested.
Those commits are the interesting ones — see §5.

## 2. Planning, and what I did with it

[`01-Solution-Planning.md`](01-Solution-Planning.md) was written before any implementation
and is **deliberately never revised**. It contains the questions I would have asked a product
owner and what I assumed instead, in a table.

Leaving it unrevised is the point. If I edit the plan after the fact, it stops being evidence
of how I thought and becomes a description of what happened. Where the plan turned out to be
wrong, the correction lives in `docs/03` §2, with the original still readable.

One consequence I did not enjoy: `docs/01` records an assumption about timezone handling that
I later had to reverse. It is still there, wrong, with the reversal documented separately.
That felt worse to leave in than to fix, which is roughly how I knew it was the right call.

## 3. AI usage, and verification

AI was used throughout — for drafting, for review, and as something to argue with. The brief
says poor verification is the problem, not the usage, so here is exactly how verification
worked.

**The rule I held to: nothing counts as checked until it has been run against something real.**

Three mechanisms did the actual work:

**A characterisation table.** For the scoring engine, I printed scores across a wide range of
synthetic weather and read the table as a human. This found three bugs that the entire test
suite was green through. The worst: a 24 °C sunny day scored **40/100 for skiing**, because it
collected credit for "not raining" and "not windy" while having no snow at all. That is what
led to the gate-versus-factor distinction the whole model now rests on.

**Real captured API responses as fixtures.** Hand-written JSON agrees with your own DTO by
construction and tests nothing. Using real responses is how I found that an inland city
returns `HTTP 200` with every marine value `null` rather than an error, and that a geocoding
search with no matches omits the `results` key entirely instead of returning `[]`.

**Opening the app and looking at it.** Five real defects in this project were found this way.
Zero were found by the test suite. Details in §4, because that ratio is the most useful thing
I learned here.

**Where AI output was wrong, and how it was caught** — the fullest example, from
[`04-AI-Usage.md`](04-AI-Usage.md):

A draft of `docs/03` described elevation correction for ski scoring as essentially passing an
`elevation` parameter to the API. It was plausible, it matched the documentation, and it was
wrong in the part that matters. Before leaving it in a submission I queried the API at 322 m
and 1900 m for the same coordinates. Temperature downscales properly, about 0.58 °C per 100 m.
But `precipitation_sum`, `rain_sum` and `snowfall_sum` come back **identical at both
elevations**. So the "obvious" fix would report −1.1 °C alongside 3.4 mm of *rain* on a day
where that precipitation is plainly snow — the temperature gate opens, fresh snowfall stays
at zero, and the rain penalty still applies. Confidently wrong, where the app is currently
honestly limited.

One API call bought that answer. The section now carries the measured numbers and names the
two real problems instead.

## 4. The five bugs, and what they have in common

Every one of these was found by looking at the running app. None was found by a test.

| | What was wrong |
|---|---|
| 1 | A 24 °C sunny day scored 40/100 for skiing — weighted sum with no gate |
| 2 | A temperature range of −8 to −2 rendered as `-8--2`, joined with an en dash |
| 3 | 4.4 cm of snowfall printed "no fresh snow" — the sentence threshold and the score threshold disagreed |
| 4 | A "best day" card read *Wednesday* above a badge reading *Unsuitable* |
| 5 | Search rows ignored taps on the city name; only the empty space right of it worked |

**They share a shape.** In every case each individual value was correct and the *combination*
was wrong. A unit test asserts a value. None of these is a value.

That is not an argument for more tests. It is the reason `docs/01` §4 rejects snapshot tests
(brittle, and they would have caught #2 only by accident) and the reason the honest next step
is one UI test per screen on the primary tap path — which would have caught #5 directly.

The habit that actually worked was cheaper: **look at the app against real data before calling
anything done.** It is written into `CLAUDE.md` for that reason.

## 5. What happened after phase 5

Phase 5 was the planned end. Everything after it came from reading the documents back and
using the app, and I have left those commits in rather than squashing, because they are the
best evidence of how I work.

**`c346bbf` — verified all six definition-of-done criteria.** `docs/01` committed to six and
left them as an unticked checklist. Four were already covered. The two that were not needed
doing rather than asserting: a fresh clone from the remote building and passing on the
README's exact command, and the offline state recovering on retry with the network restored.
A checklist nobody ticks is not evidence.

**`99d2cdd` — the elevation section, corrected with measured behaviour.** §3 above. The
version I nearly submitted was plausible and wrong.

**`38945e2` — a transposed day count in `docs/01`.** The problem statement read "each of these
four days" one line below "the next 7 days". `docs/01` is marked as never revised, but that
policy exists to stop reasoning being rewritten to match outcomes, not to preserve a typo that
contradicts the line above it.

**`5a5eec7` — two bugs, both found by someone using the app and asking why.**

The first: "Today" meant the *device's* calendar day. `docs/01` recorded that as a considered
decision **and stated its cost** — but the cost it stated was only the mild half. It covered a
user *ahead* of the city, who sees a "Today" row that is really the city's tomorrow, with the
visible date giving it away. It missed the worse direction: a user in India at 22:00 IST
opening Shanghai sees China's **current** conditions headed "Tomorrow". That is not an
off-by-one label; it calls the present the future, with nothing on screen to contradict it.

The justification was weakest exactly where it broke. "It matches the calendar the user is
holding" is an argument for an app about your own life. This is a forecast about somewhere
else, and the days being ranked are that city's days. Reversed to the city's calendar, and
added a caption under the city name — *"It's 6:08 AM on Monday, 7 September in Queenstown"* —
so the app states which calendar it is using instead of leaving it to be inferred.

**The transferable lesson: an assumption you wrote down and only half-analysed is more
dangerous than one you never wrote down, because it looks settled.**

The second was bug #5 above. A `simultaneousGesture` on a `NavigationLink` sits on the link's
*content*, so taps on the label were consumed by the gesture and the link never activated,
while the rest of the cell still navigated. The recents list used the same `NavigationLink`
and the same row view *without* that gesture, which is why only one of the two lists was
broken — the structural difference was the whole bug. The gesture existed only to record the
recent search, which is a side effect racing a navigation and the wrong mechanism regardless
of hit-testing. It moved to the navigation destination, so "recent" now means a city that was
**viewed** rather than one that was tapped at.

A detail I liked: the old code left evidence. The recents list contained a city whose forecast
had never been opened. The save ran; the navigation didn't.

**`ff7349f` — this document, and four stale test counts.** The repo led with polished
architecture docs and left the process to be reconstructed from `git log`. Also corrected the
test count in four files, which still said 138 after the fixes above, and re-ran the fresh
clone check so the claim in `docs/03` §4 is accurate as written rather than inherited.

## 6. What I would do next, in order

1. **Elevation-aware ski scoring**, including precipitation-phase reclassification. Ski
   scoring is currently wrong for the towns people will actually search — Queenstown sits at
   322 m, its ski fields are at 1200–1900 m. This is the biggest real defect in the product.
2. **One UI test per screen** on the primary tap path. Five defects found by looking, zero by
   the suite. That ratio is itself the finding.
3. A local time line on the day-breakdown screen too, for consistency with the forecast screen.

## 7. Things I am not happy with

- Ski scoring is wrong for its main use case, and the honest fix is not small (§3).
- The scoring thresholds are informed guesses. They are named constants so they can be argued
  with, and I validated how they *combine*, but I did not validate the numbers themselves and
  cannot.
- Test coverage stops precisely where all five real defects lived.
- Reason strings are generated in the domain. Defensible — it keeps the explanation and the
  score from drifting apart, and bug #3 is what happens when they do — but it is user-facing
  copy in a layer that claims not to know about UI.

---

## Where everything else lives

| | |
|---|---|
| [`01-Solution-Planning.md`](01-Solution-Planning.md) | Written before implementation, never revised. Questions I'd have asked, assumptions, scope cuts. |
| [`02-Architecture-Decisions.md`](02-Architecture-Decisions.md) | 15 decisions, each with what was rejected and what it costs — including four places the textbook layering was deliberately not followed. |
| [`03-Assumptions-and-Tradeoffs.md`](03-Assumptions-and-Tradeoffs.md) | Where the plan was wrong, known limitations, how each definition-of-done criterion was verified. |
| [`04-AI-Usage.md`](04-AI-Usage.md) | The running log. Dated entries, specific failures, specific catches. |
| [`../CLAUDE.md`](../CLAUDE.md) | The standing rules I worked under, including what was considered and rejected. Also the file that kept the AI on-policy across sessions. |
