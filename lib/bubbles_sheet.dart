/// Pill-shouldered, iOS-26-style modal bottom sheets, built on
/// `package:smooth_sheets`.
///
/// The entry point is `showBubblesSheet`; `BubblesSheetThemeData` holds every
/// colour, measurement, icon and haptic the chrome uses, and is registered as a
/// `ThemeExtension` so sheets pick it up with no wiring at the call site.
///
/// smooth_sheets is re-exported: paged flows built with `PagedSheet` need its
/// `SheetController`, `ModalSheetRoute` and friends, and re-exporting keeps
/// those on one import rather than two.
library;

export 'package:smooth_sheets/smooth_sheets.dart';

export 'src/bubbles_paged_sheet.dart';
export 'src/bubbles_sheet.dart';
export 'src/bubbles_sheet_actions.dart';
export 'src/bubbles_sheet_theme.dart';
export 'src/device_corner_radius.dart';
