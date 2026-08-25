# bubbles_sheet

Pill-shouldered, iOS-26-style modal bottom sheets for Flutter, built on
[`smooth_sheets`](https://pub.dev/packages/smooth_sheets).

Every sheet gets the same chrome — a grab handle, a leading close button, a
centered title, an optional trailing text action, and a primary CTA that stays
pinned to the bottom while the body scrolls. The sheet floats on an inset above
a dimmed barrier, and as you drag it to its largest detent the inset lerps away
and the bottom corners grow into the device's own screen radius, so the curve
continues into the bezel instead of cutting across it.

## Usage

```dart
final picked = await showBubblesSheet<String>(
  context,
  title: 'Sort by',
  builder: (context) => const SortOptions(),
);
```

Detents default to `[fit, large]` — content-sized to start, draggable to nearly
full screen. Pass your own to change that:

```dart
showBubblesSheet<void>(
  context,
  title: 'Pick a token',
  detents: const [BubblesSheetDetent.medium, BubblesSheetDetent.large],
  builder: (context) => const TokenList(),
);
```

### A sticky CTA that depends on the body's state

The CTA renders in the chrome, outside the body, so state both of them read
belongs above the sheet. Hand it a `Listenable` and only the CTA rebuilds:

```dart
final pending = ValueNotifier<int>(current);
await showBubblesSheet<int>(
  context,
  title: 'Max slippage',
  primaryCtaListenable: pending,
  primaryCtaBuilder: (context) => BubblesSheetCta(
    title: 'Set ${pending.value}bps',
    enabled: pending.value != current,
    onTap: () => Navigator.of(context).pop(pending.value),
  ),
  builder: (_) => SlippagePicker(onChanged: (v) => pending.value = v),
).whenComplete(pending.dispose);
```

### A trailing header action

The slot opposite the close button, for a secondary action that doesn't commit
the sheet:

```dart
trailingAction: BubblesSheetAction(
  label: 'Clear',
  onTap: () => draft.value = Filters.none,
),
```

## Theming

Every colour, measurement, icon, haptic and the CTA widget itself come from
`BubblesSheetThemeData`, registered as a `ThemeExtension`. It has working
defaults for everything, so the package renders correctly with no wiring at all
— register it only to override:

```dart
MaterialApp(
  theme: ThemeData.light().copyWith(
    extensions: [
      BubblesSheetThemeData(
        light: BubblesSheetPalette.cream.copyWith(action: myBrandCoral),
        titleStyle: myTitleStyle,
        closeIcon: PhosphorIconsBold.x,
        ctaBuilder: (context, cta) => MyPillButton(label: cta.title, onTap: cta.onTap),
        haptics: BubblesSheetHaptics(
          onPresent: HapticFeedback.lightImpact,
          onDismiss: HapticFeedback.selectionClick,
        ),
      ),
    ],
  ),
)
```

Two things are worth calling out:

**Haptics are hooks, not calls.** The package never invokes `HapticFeedback`
itself, so it can't fire a buzz an app's own "haptics off" setting has disabled.
Wire `BubblesSheetHaptics` to whatever façade you already have.

**`deviceCornerRadius` has to be supplied.** Flutter can't read the physical
screen radius, so the flush-corner effect is off until you pass it — e.g. from
[`screen_corner_radius`](https://pub.dev/packages/screen_corner_radius):

```dart
metrics: BubblesSheetMetrics(deviceCornerRadius: myResolvedRadius),
```

Left at `0` the sheet simply squares off against the bottom edge.

## Paged sheets

Multi-page flows use `smooth_sheets`' own `PagedSheet` with this package's
chrome — `BubblesPagedSheetHeader` (which grows a back button on inner pages),
`BubblesPagedSheetViewport`, and `BubblesPagedSheetSurface`. `smooth_sheets` is
re-exported from `package:bubbles_sheet/bubbles_sheet.dart`, so those flows need
one import rather than two.

## Notes

`dark: true` selects `BubblesSheetThemeData.dark` explicitly — it does not read
the ambient `Theme` brightness. A sheet is often deliberately inverted against
the screen behind it, so the choice stays at the call site.
