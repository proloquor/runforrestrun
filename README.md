# Run Forrest Run 🏃

An iOS training app that reads your **live heart rate**, tests your **HR zones**, and
coaches you through two structured sessions with **audible + spoken alerts** when you
drift out of the target zone:

1. **HR Zone Test** — a guided ramp test that *measures* your true max HR and
   recalibrates every zone (far more accurate than the age estimate).
2. **Norwegian 4×4** — the classic VO₂max session: 4 × 4 min hard @ 85–95 % HRmax
   with 3 min recoveries. You get an instant "ease off / push harder" cue the moment
   you leave the target band.
3. **Zone 2 Run** — a steady aerobic-base run held in Zone 2, with the same
   out-of-zone alerting logic.

Built in SwiftUI, iOS 17+.

---

## ⚠️ Read this about Oura and "real-time"

Oura's official integration is a **cloud API** (v2). The ring buffers readings and
syncs them to Oura's servers **through your phone periodically**, so "live" heart-rate
samples lag by **seconds to a couple of minutes**. Oura does **not** expose a public
real-time Bluetooth stream to third-party apps.

That lag is fine for a steady Zone 2 run, but it's too slow for sharp 4×4 intervals
where the target changes every few minutes and you need an *instant* cue. So the app
treats the heart-rate feed as a **pluggable source** (`HeartRateSource`):

| Source | Latency | Best for |
| --- | --- | --- |
| **Bluetooth HR strap** (any standard `0x180D` device — Polar, Garmin, Coros, Wahoo, Scosche…) | Instant | The 4×4 intervals & zone test |
| **Oura (cloud)** | Seconds–minutes | Zone 2, casual use, when you don't have a strap |
| **Demo signal** | — | Trying the app in the Simulator |

**Oura still powers the experience:** it's your account connection and the source of
your personalized resting heart rate (which drives the Karvonen/HRR zone math) and
your workout history/readiness. You pick the live source in **Connect**. The app is
honest about the trade-off right in the UI.

---

## Getting started

### Requirements
- Xcode 16 or newer (the project uses file-system-synchronized groups)
- iOS 17+ device or Simulator
- (Optional) An Oura account + a Bluetooth heart-rate strap

### Open & run
```bash
open RunForrestRun.xcodeproj
```
Pick the **RunForrestRun** scheme and run.

- **On the Simulator** the app auto-selects the **Demo signal** so every feature is
  usable without hardware — you'll see the HR sweep across zones and hear the alerts.
- **On a device** it defaults to scanning for a **Bluetooth HR strap**. Pair one by
  just wearing it and starting a workout, or switch the source in **Connect**.

### If the project won't open
The committed `RunForrestRun.xcodeproj` is hand-authored. If your Xcode version
disagrees with it, regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```bash
brew install xcodegen
xcodegen generate
open RunForrestRun.xcodeproj
```

### Connecting Oura
1. Go to <https://cloud.ouraring.com/personal-access-tokens> and create a
   **Personal Access Token** (PAT).
2. In the app, tap the **Connect** button (top-right on the Train tab) → paste the
   token → **Connect Oura**.

The token is stored in the iOS **Keychain** and is only ever sent to `api.ouraring.com`.
On connect, the app pulls your latest resting HR and age to personalize your zones.

> A PAT is used instead of full OAuth because this is a personal, single-user app: no
> backend, no redirect URI, no client secret. The `OuraClient` interface is written so
> OAuth 2.0 can be layered in later without touching the rest of the app.

---

## How the coaching works

- **Zones** use **Heart Rate Reserve (Karvonen)**: `target = rest + %·(max − rest)`,
  personalized from your Oura resting HR and your measured/estimated max HR.
- The **4×4 work bouts** are prescribed as **85–95 % of HRmax** (with 60–70 %
  recoveries), matching the protocol; **Zone 2** targets ~60–70 % HRR.
- During *enforced* phases the `WorkoutEngine` compares live HR to the target band
  every second. After a short **grace period** (so brief blips don't nag you) it fires:
  - a **spoken cue** ("Ease off, heart rate too high" / "Pick it up"),
  - a **tone** (higher pitch = too high, lower = too low), synthesized in code,
  - a **haptic** buzz,
  - and a **"back in the zone"** confirmation when you recover.
- Audio is configured to **duck** (not stop) your music/podcast, and the app requests
  `audio` + `bluetooth-central` background modes so cues keep working with the screen
  off mid-run.

---

## Project structure

```
RunForrestRun/
├── App/            App entry, composition root (AppModel), root tab view
├── Models/         UserProfile, HeartRateZone, HeartRateTarget, WorkoutTemplate/Session
├── Services/
│   ├── HeartRate/  HeartRateSource protocol + BLE / Oura / Simulated + HeartRateMonitor
│   ├── Oura/       OuraClient (API v2), Codable models
│   ├── Audio/      AudioCoach (speech + code-synthesized tones + haptics)
│   ├── Zones/      ZoneCalculator (Karvonen)
│   └── Persistence/ ProfileStore, HistoryStore, Keychain
├── Workouts/       WorkoutLibrary (the 3 protocols) + WorkoutEngine (the clock/alerts)
└── Features/       Home, Connect, ZoneTest, Workout (pre-start/active/summary), Profile, History
```

The whole heart-rate stack is behind one protocol, so adding a new source (e.g.
Apple Watch via HealthKit, or a future Oura real-time SDK) is a single new file.

---

## Roadmap / nice-to-haves
- Apple Watch companion + HealthKit workout session as a true real-time source
- Save completed sessions back to Apple Health
- Configurable Zone 2 / 4×4 durations and rep counts in the UI
- Live HR chart on the summary screen
- OAuth 2.0 flow for multi-user distribution

---

*Not affiliated with Ōura Health Oy. "Oura" is a trademark of its owner; this app uses
the public Oura API v2.*
