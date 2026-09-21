# bubbles_sheet — agent working rules

Discovered from this repository on 2026-09-21. Everything here is observed, not assumed:
if a rule below is not backed by a file in this repo, it does not belong here.

## What this repo is

A **published Dart/Flutter widget package** (`bubbles_sheet`, version `0.4.0` in
`pubspec.yaml`): pill-shouldered, iOS-26-style modal bottom sheets built on
`package:smooth_sheets`. Plus a demo app under `example/`.

- Library source: `lib/bubbles_sheet.dart` (the public export barrel) and `lib/src/`:
  `bubbles_sheet.dart` (`showBubblesSheet`, the detents, the surface),
  `bubbles_paged_sheet.dart` (the paged-flow chrome), `bubbles_sheet_theme.dart`
  (`BubblesSheetThemeData` and friends), `bubbles_sheet_actions.dart`
  (`BubblesSheetCta`/`BubblesSheetAction`), `device_corner_radius.dart`
  (`BubblesDeviceCornerRadius`).
- The barrel **also re-exports `package:smooth_sheets/smooth_sheets.dart` wholesale**, so
  consumers get `SheetController`, `ModalSheetRoute` and friends from one import. Dropping
  that re-export breaks downstream imports that have nothing to do with this package's own
  types.
- Dependencies: `smooth_sheets ^1.0.2`, `screen_corner_radius ^3.0.0`. The latter is a
  platform-channel plugin, but **this repo contains no `android/`, `ios/` or other native
  directory of its own** — nothing here is built for a device.
- Demo app: `example/` — its own pubspec (`publish_to: "none"`), depends on the package by
  `path: ../`, includes `../analysis_options.yaml`. No `android/`/`ios/` either. Its
  pubspec carries a standing comment that it is **deliberately not a workspace member**,
  because it ships inside the published archive and `resolution: workspace` there breaks
  `pub get` for anyone who downloads it. Do not "tidy" that into a workspace.
- Lints: `analysis_options.yaml` includes
  `package:very_good_analysis/analysis_options.10.2.0.yaml` with a documented override
  block (`public_member_api_docs: false`, `lines_longer_than_80_chars: false`,
  `cascade_invocations: false`, and others — each has a comment saying why).
- SDK constraints (`pubspec.yaml`): Dart `^3.11.1`, Flutter `>=3.44.0`. The Flutter floor
  is not arbitrary — `pubspec.yaml` records that 3.44 is where
  `FlutterView.displayCornerRadii` lands, which is what resolves the flush-corner radius
  on Android 12+ without the host supplying one. Lowering it silently breaks that path.
- `pubspec.yaml` also declares four `screenshots:` entries pointing into `doc/screenshots/`.
  Those PNGs are tracked and are validated by `flutter pub publish --dry-run`.

**The package is published to pub.dev.** `lib/`'s public surface, `pubspec.yaml`'s
version/metadata, `doc/screenshots/` and `LICENSE` are therefore a release path, not
ordinary source — see `.claude/docs/routing.yaml`.

## Commands (the real ones)

There is **no CI workflow, no Makefile, and no script runner** in this repo. These are the
actual toolchain commands, confirmed to run here (Flutter 3.44.3 stable at bootstrap):

| Purpose | Command |
|---|---|
| Static analysis | `flutter analyze` |
| Format check | `dart format --output=none --set-exit-if-changed .` |
| Format (write) | `dart format .` |
| Tests | `flutter test` |
| Demo app analysis | `flutter analyze` from `example/` |
| Release dry-run | `flutter pub publish --dry-run` |
| Dependencies | `flutter pub get` |

Run them through `tool/harness/verify <tier>` rather than one at a time — that is what the
completion gate reads.

## Test layout

`test/` holds **seven flutter_test widget-test files, 42 tests, all passing at bootstrap**.
They are named by the behaviour they pin, not one-per-source-file:

| File | Pins |
|---|---|
| `bubbles_sheet_test.dart` | the chrome, the CTA/close builders, pop values, the dark palette |
| `bubbles_sheet_theme_test.dart` | `BubblesSheetThemeData` resolution, `copyWith`, `lerp` |
| `close_button_test.dart` | one close-button size across both headers |
| `device_corner_radius_test.dart` | the two radius sources and the async repaint |
| `fit_detent_test.dart` | `fit` snapping back to the natural content height |
| `keyboard_lift_test.dart` | content staying above the keyboard |
| `paged_sheet_test.dart` | paged-flow teardown |

There are **no golden tests** — nothing calls `matchesGoldenFile`, so there is no golden
directory to update and no platform pinning to worry about. New tests follow the same
by-behaviour naming.

`BubblesDeviceCornerRadius` holds **static mutable state** (a `ValueNotifier` plus an
in-flight future) and is reset with `tearDown(BubblesDeviceCornerRadius.resetForTesting)`.
Any new test that touches a sheet's corner radius must do the same, or it leaks into the
next test.

## Architecture conventions

Observable, and deliberately short — this is a widget package, not a layered app:

- `lib/bubbles_sheet.dart` exports the public API. Anything not exported there is
  internal; adding or removing an export is a public-API change.
- `lib/src/` holds the implementation. Private types there are `_`-prefixed
  (`_BubblesSheetSurface`, `_FitDetent`, `_FlushOffset`) and are genuinely private.
- `BubblesSheetThemeData` is a `ThemeExtension`: every colour, measurement, icon, haptic
  and chrome builder lives on it, and sheets pick it up with no wiring at the call site.
  New chrome knobs belong there, not as new `showBubblesSheet` parameters.
- A `ThemeExtension` has to stay internally consistent: a field added to
  `BubblesSheetThemeData` (or to `BubblesSheetPalette`/`BubblesSheetMetrics`/
  `BubblesSheetHaptics`) must be handled in `copyWith` **and** `lerp` in the same change.
- `example/` must never be imported by `lib/`. The dependency runs one way only.

No state-management, DI, routing or persistence conventions exist in this repo — do not
introduce one as a side effect of another change.

## Rules for agents

- Never edit `example/` to make a `lib/` change look like it works; fix `lib/`.
- A change to `lib/bubbles_sheet.dart`'s exports, to any exported widget's or
  `showBubblesSheet`'s signature, to `BubblesSheetThemeData`'s public fields, or to
  `pubspec.yaml`'s `version` is a **release-path** change: full tier, and `CHANGELOG.md`
  gets an entry in the same change. This repo's CHANGELOG entries are prose explaining
  *why*, not one-line bullets — match that.
- Do not lower the `flutter:` constraint in `pubspec.yaml` without reading the comment
  above it first.
- `pubspec.lock` (root and `example/`) is gitignored here and is not part of any change set.
- `doc/screenshots/*.png` are release assets referenced from `pubspec.yaml`; do not
  regenerate or rename them unless asked.

## Known baseline (2026-09-21, at harness bootstrap)

`dart format --output=none --set-exit-if-changed .` **fails** on 13 of this repo's 14 Dart
files — pre-existing state, deliberately left untouched by the bootstrap. `flutter analyze`
is clean and `flutter test` is 42/42 green. See `docs/agents/verification.md` for what that
means for a `fast` run.
