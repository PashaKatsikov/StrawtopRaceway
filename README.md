# Strawtop Raceway

A cartoon spinning-top racing game for iOS, built with Flutter. Launch your top
down hand-drawn tracks across three worlds — the Kitchen, the School Desk and
the Playground — dodging obstacles, grabbing coins and chasing a three-star
finish on every level.

## Features

- Physics-flavoured top racing with boost, shield and magnet power-ups
- Three worlds of hand-drawn levels, unlocked by earning stars
- Garage with collectable tops, each upgradable across speed, stability and power
- Shop, daily challenges, achievements and a local leaderboard
- Player profile with race, win, star and coin statistics
- Works fully offline: all progress is stored on the device

## Running the project

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run --release
```

The game is landscape-only in play and targets iOS. Push notifications,
attribution and the tracking prompt only behave correctly on a real device, so
use hardware rather than the Simulator for a full pass.

## Layout

- `lib/screens/`, `lib/game/`, `lib/widgets/`, `lib/theme/` — menus, race loop and UI kit
- `lib/data/` — save state, catalog, audio and image loading
- `lib/marshal/` — launch pipeline: connectivity, install intake, notifications
- `tool/` — asset and value generators used at build time
