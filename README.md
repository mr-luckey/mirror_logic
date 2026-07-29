# Mirror Logic

Optical puzzle game — rotate mirrors, redirect a live laser, light the crystal.

## Alpha scope

- Real-time reflection physics (custom raycast)
- Chapters 1–2 (50 levels)
- Neon premium UI (BLoC-only state, no `setState` app logic)
- Local save: stars, coins, hints, settings
- Portrait Android & iOS

## Run

```bash
flutter pub get
dart run tool/generate_levels.dart
flutter test tool/fix_levels_test.dart
flutter run
```

## Architecture

`presentation` (BLoC) → `domain` (beam math) → `data` / `infrastructure`
