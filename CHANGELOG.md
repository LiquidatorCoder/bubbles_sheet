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
