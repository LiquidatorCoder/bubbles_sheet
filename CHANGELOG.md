## Unreleased

- Added `showBubblesPagedSheet`, the paged counterpart to `showBubblesSheet`.
  Paged flows used to be assembled by hand from `ModalSheetRoute`, the paged
  viewport and surface, and a `SheetController` the caller had to dispose — and
  the obvious place to dispose it, the route future's `whenComplete`, is the
  same premature dispose that crashed modal sheets closed with the keyboard up.
  The new function owns the controller on its route and shares the modal
  sheets' spring, swipe-dismiss, transition, barrier and present haptic. The
  building blocks stay exported for custom compositions.
- Fixed the paged header's close button dismissing the wrong route when the
  sheet was pushed on a nested navigator. It popped the root navigator's top
  route; it now pops the navigator that hosts the sheet, and honours `PopScope`
  through `maybePop` the way the modal header already did.
- Fixed the primary CTA and the footer disappearing behind the software
  keyboard. The sheet already lifts itself above the keyboard, but the bottom
  bar was also told to hide by the keyboard's height, so it was pushed under it
  a second time — on an iPhone the whole 84pt CTA slot sat behind the keys and a
  tap on it closed the sheet through the barrier instead.
- Fixed paged sheets squaring off to the device edges when the keyboard lifts
  them. The modal sheet already discounted the keyboard when deciding how close
  it was to its large detent; the paged viewport and surface did not, so a
  focused field on a tall page could make the sheet lose its inset and its
  rounded bottom corners while it was still floating.
- Fixed "A SheetController was used after being disposed." when a sheet was
  closed with the keyboard up. The controller was disposed as soon as the route
  popped — the *start* of the exit animation — while the sheet was still on
  screen and still relaying out as the keyboard went down. The route now owns
  the controller and releases it only once the sheet has left the tree. The same
  early disposal made a sheet parked at the large detent round its flush bottom
  corners back off mid-exit; that is gone too.

  If you build a paged flow yourself, the same rule applies to your own
  `SheetController`: dispose it when the route is disposed, not in the route
  future's `whenComplete`.
- Fixed a disabled primary CTA being all but invisible on a `dark: true` sheet.
  Its greyed-out pill and label were tinted from the app's colour scheme, not
  from the sheet's palette, so a dark sheet in a light app drew a black-on-black
  button (about 1:1 contrast) — and a light sheet in a dark app had the same
  problem the other way round. The CTA and footer now read `onSurface` from the
  palette of the sheet they sit on; the enabled pill is unchanged.
- Sheets now snap to a detent with a critically damped spring instead of
  smooth_sheets' default, which is overdamped and creeps the last few points
  into place. Dropped from large back to fit on an iPhone simulator, the time
  from release to rest falls from about 680ms to about 370ms; drags that end
  with a flick were already carried home by the finger's velocity and are
  unchanged. The bounce at the ends of travel is the same.
- The drag handle is now usable with a screen reader. It used to announce
  "Drag to dismiss" on every sheet — including ones opened with
  `swipeDismissible: false`, which can't be dragged away — and offered no action,
  so VoiceOver and TalkBack users had no way to grow a sheet the way a sighted
  user drags its handle. It is now a "Sheet grabber" button whose increase and
  decrease actions step between the sheet's detents, with a dismiss action only
  when swipe-to-dismiss is actually enabled.
- **Look change:** a sheet resting at the medium detent — or at any height below
  its content — now floats like a sheet at the fit detent does: inset from the
  bottom edge, with bottom corners concentric with the display. It used to keep
  its side insets but run straight off the bottom of the screen, because the
  sheet is never laid out shorter than its content. Only the visible part is
  painted and hit-tested now, so nothing hidden under the inset is tappable;
  dragged below its lowest detent the sheet still slides away whole. The
  `02-detents.png` screenshot shows the old look.
- Fixed swipe-to-dismiss springing back when you let go while still moving.
  Dragged below its lowest detent, a sheet only dismissed if released dead still
  past a threshold, or flung faster than two screen-heights a second — a
  steady drag nearly off the bottom of an iPhone and released mid-motion
  snapped back up, because anything between "still" and "flung" fell through
  both rules. A deliberate downward release — from a fifth of a screen-height a
  second — now dismisses, while a slow peek still settles back and a still
  release keeps the distance rule. Flicks that merely carry the sheet to a
  lower detent are unaffected.
- Fixed floating sheets losing their bottom curve on displays with square
  corners (iPhone SE, most of web and desktop) and wherever the display radius
  can't be resolved. The floating bottom radius was the display's radius minus
  the inset, which is nothing on a square screen, so the sheet floated with
  rounded top corners over a square bottom. It now never drops below the top
  radius; curved displays are unchanged, and a flush sheet on a square screen is
  still square.
- The sheet surface repaints as the sheet moves instead of rebuilding its
  widgets on every frame of a drag.

## 0.4.0

- Added `BubblesSheetThemeData.closeBuilder`, the counterpart to `ctaBuilder`.
  The header's close control was the one piece of sheet chrome an app could not
  draw itself: it could be recoloured, resized and given a different glyph, but
  it was always the package's circle. An app with its own button component ended
  up with a single control in the sheet that no design system drew.

  The builder is handed a `BubblesSheetClose` carrying the glyph, the dismissal
  callback, *this* sheet's palette — a sheet picks its chrome from its own `dark`
  flag, so a builder cannot work that out from context — and `closeButtonSize`.
  Dismissal stays the package's, so a replaced control cannot forget to close.

  Both headers honour it. The default, `buildDefaultClose`, is the same circle
  as before, so this is additive: no existing sheet changes.

## 0.3.1

- Fixed the close button rendering at different sizes in the two headers. The
  modal sheet drew it at 44pt and the paged sheet at 36pt, which showed up as an
  obvious jump when opening one sheet after the other.

  `NavigationToolbar` — which the modal header uses so it can offer a trailing
  action — gives its leading slot a *tight* height, and a tight parent
  constraint beats `Container`'s own `width`/`height`. The circle is now
  centered inside the slot, so `closeButtonSize` decides its size in both
  headers. The tap target stays a full 44pt.
- Screenshots retaken, since they showed the oversized button.

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
