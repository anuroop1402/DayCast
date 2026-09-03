# DayCast

A native iOS app that lets you search for a city and see how suitable the next 7 days are
for **skiing**, **surfing**, **outdoor sightseeing**, and **indoor sightseeing** — scored
from Open-Meteo forecast data.

> 🚧 **In progress.** Built in phases, each ending on a green build and passing tests.
> The commit history is meant to be read as a narrative.

---

## How I'm approaching this

The interesting part of this problem isn't fetching weather — it's deciding what
"suitable" means, committing to assumptions, and structuring the app so that the scoring
model stays isolated and cheap to change.

- **[docs/01-Solution-Planning.md](docs/01-Solution-Planning.md)** — problem framing, the
  questions I'd have asked a PM and the assumptions I committed to instead, explicit scope
  cuts with reasons, and milestones. Written *before* any implementation.
- **[CLAUDE.md](CLAUDE.md)** — the architecture rules I'm holding myself to, including the
  alternatives I considered and deliberately rejected.

Further docs (architecture decisions, assumptions & trade-offs, AI usage) land as the
decisions behind them actually get made, rather than being written up front.

## Architecture

Clean Architecture, applied consistently. `Domain` imports nothing but `Foundation`;
ViewModels talk only to use cases.

```
Presentation  →  Domain  ←  Data
 SwiftUI          pure        Open-Meteo,
 @Observable      Swift       UserDefaults
```

## Stack

SwiftUI · Swift 6 language mode · Clean Architecture · Swift Testing · **zero third-party dependencies**

## Running it

```bash
git clone git@github.com:anuroop1402/DayCast.git
cd DayCast
open DayCast.xcodeproj
```

Then **⌘R** to run, **⌘U** to test. No package resolution, no API keys, no setup — the
shared scheme is committed so tests run on a fresh clone.

Requires Xcode 16+ and iOS 18.0+.

```bash
# or from the command line
xcodebuild test -project DayCast.xcodeproj -scheme DayCast \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Progress

| Phase | | |
|---|---|---|
| 0 | Foundations, test target, planning docs | ✅ |
| 1 | Domain: entities + suitability scoring engine | ⏳ |
| 2 | Data: Open-Meteo client, DTOs, repositories | — |
| 3 | Use cases + orchestration | — |
| 4 | Presentation: ViewModels + SwiftUI screens | — |
| 5 | Docs, README, screenshots | — |
