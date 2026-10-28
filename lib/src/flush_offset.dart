import 'package:flutter/foundation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

// The sheet floats on its inset everywhere except right at the top of the large
// detent — there it lerps the inset to 0 and the bottom corners up to the
// device's screen radius so the curve continues smoothly into the bezel.
const double kBubblesFlushBegin = 0.6;
const double kBubblesFlushEnd = 0.9;

/// Flush threshold proportional to the viewport, shifted up by the bottom
/// viewport inset (the software keyboard). When the keyboard lifts the sheet,
/// this keeps the lift from spuriously engaging the edge-flush — the sheet
/// holds its floating inset and rounded corners while a field is focused, and
/// only kisses the device edges when the user actually drags it toward large.
///
/// Internal: shared by the modal and paged sheets, not exported from the
/// package barrel.
@internal
class BubblesFlushOffset implements SheetOffset {
  const BubblesFlushOffset(this.fraction);

  final double fraction;

  @override
  double resolve(ViewportLayout metrics) => metrics.viewportSize.height * fraction + metrics.viewportPadding.bottom;
}
