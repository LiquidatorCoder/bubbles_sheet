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
