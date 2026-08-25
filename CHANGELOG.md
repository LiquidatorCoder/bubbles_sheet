## 0.3.0

- The flush bottom corners now resolve themselves on **iOS as well as Android**.
  The package depends on
  [`screen_corner_radius`](https://pub.dev/packages/screen_corner_radius) for the
  platforms `dart:ui` doesn't answer for, so there is nothing to wire up.
- **This makes bubbles_sheet a plugin package: Android and iOS only.** On web and
  desktop the radius resolves to `0` and the corners square off. If you need
  those platforms, pin `0.2.0` and pass `deviceCornerRadius` yourself.
- On iOS the radius comes from a private `UIScreen` property, since Apple
  publishes no API for it. Pass `deviceCornerRadius` explicitly if you would
  rather not ship that.
- The lookup is asynchronous. A sheet opened before it lands repaints once the
  radius arrives; `BubblesDeviceCornerRadius.ensureResolved()` lets you start it
  during app startup instead.

## 0.2.0

**Breaking:** requires Flutter 3.44, and `BubblesSheetMetrics.deviceCornerRadius`
is now `double?` rather than `double`.

- The flush bottom corners now resolve themselves on Android 12+, by reading
  `FlutterView.displayCornerRadii` (Flutter 3.44+) per-view at build time.
  `dart:ui` reports those radii in physical pixels; they are converted to
  logical pixels for you. Note that `dart:ui` populates them **only** on Android
  API 31+ — on iOS and elsewhere the value is `null`, and you should keep
  supplying `deviceCornerRadius` yourself.
- `deviceCornerRadius` becomes an override rather than the only source. Passing
  it still always wins, so existing code behaves exactly as before.
- The example now reads the real device radius instead of hardcoding one, which
  was giving it a visibly tighter curve than the bezel it was meant to match.
- Screenshots, in the README and in pub.dev's own gallery.

## 0.1.0

- Initial release, extracted from the Arch Wallet app.
- `showBubblesSheet` — modal sheet with `fit` / `medium` / `large` detents,
  iOS-style scroll-to-drag handoff, and corners that go flush with the device
  bezel at the largest detent.
- Header chrome: drag handle, leading close button, centered title, and a
  trailing text action.
- Sticky primary CTA (static, built, or driven by a `Listenable`) and sticky
  footer slots.
- `BubblesPagedSheet*` chrome for multi-page flows built on `PagedSheet`.
- `BubblesSheetThemeData` — a `ThemeExtension` carrying palettes, geometry,
  type, icons, haptic hooks, and the CTA builder.
