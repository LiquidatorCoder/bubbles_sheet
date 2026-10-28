import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

// The entrance/exit of every Bubbles sheet, modal or paged. A 360 ms expo-out:
// fast off the line, long soft landing.
@internal
const Duration kBubblesSheetTransitionDuration = Duration(milliseconds: 360);
@internal
const Curve kBubblesSheetTransitionCurve = Cubic(0.16, 1, 0.3, 1);

/// When a drag released below the lowest detent dismisses the sheet.
///
/// smooth_sheets' `_SheetDismissible` decides on release, and only for a drag
/// that pulled the sheet below its lowest detent (above it the sheet's own
/// physics consume the drag and the gesture handler reports "not handled", so a
/// flick that merely settles at a lower detent is never a dismissal):
///
///  * keyboard open: never dismiss;
///  * release velocity reported as 0: dismiss if the visible fraction is under
///    `dismissalOffset` (30% by default);
///  * moving down: dismiss only if `|v| / viewportHeight` exceeds
///    `minFlingVelocityRatio`, however far the sheet was dragged;
///  * moving up: never dismiss.
///
/// `SwipeDismissSensitivity` cannot combine distance with velocity, so the
/// ratio `r` has to sit between two releases that must behave differently:
///
///  * a slow, small peek (a 40pt pull let go at ~80pt/s) must snap back, as on
///    iOS. Flutter reports any release above `kMinFlingVelocity` (50pt/s) as a
///    real fling, so a ratio near that floor (about 32pt/s at 0.04 on an 800pt
///    viewport) dismisses this peek whatever its distance;
///  * a deliberate drag (about 0.5 screen-heights/s, roughly 580pt/s on 874pt)
///    must dismiss. The stock 2.0 (about 1750pt/s on an 874pt iPhone) made such
///    a drag, taken nearly off-screen, snap back.
///
/// 0.2 splits them: about 175pt/s on an 874pt phone and 160pt/s on an 800pt
/// viewport. A release reported as exactly 0 (slower than 50pt/s, or stopped
/// before lifting) still uses the distance rule.
@internal
const SwipeDismissSensitivity kBubblesSwipeDismissSensitivity = SwipeDismissSensitivity(minFlingVelocityRatio: 0.2);

/// A [ModalSheetRoute] that owns the [SheetController] its sheet is driven by,
/// and disposes it only once the sheet is gone.
///
/// The controller has to outlive the sheet subtree, and the route's future is
/// the wrong place to end its life: that future completes at *pop*, the start
/// of the exit transition, while the sheet is still mounted, still attached to
/// the controller and still relaying out (the keyboard collapsing as the route
/// leaves is enough). Disposed there, the controller sits under a live sheet,
/// and smooth_sheets' `SheetController.notifyListeners` — which defers a
/// notification raised during layout to a post-frame callback — then fires on a
/// dead controller ("A SheetController was used after being disposed."). The
/// sheet also loses its `controller.metrics` mid-exit, so a sheet parked at the
/// large detent would see its flush bottom corners jump back to the device
/// radius.
///
/// `Navigator` only calls [dispose] once the route's overlay entries have
/// unmounted: `_RouteEntry.dispose` waits for them, since an overlay entry is
/// the root of the route's subtree and unmounts last. So by then the sheet's
/// model has detached from the controller. A notification deferred earlier in that same
/// frame can still be pending, so the controller is disposed in a post-frame
/// callback registered from here: callbacks run in registration order, which
/// puts it behind any deferred notify.
@internal
class BubblesSheetRoute<T> extends ModalSheetRoute<T> {
  BubblesSheetRoute({
    required SheetController controller,
    required super.builder,
    required super.viewportBuilder,
    required super.barrierColor,
    required super.barrierDismissible,
    required super.swipeDismissible,
  }) : _sheetController = controller,
       super(
         swipeDismissSensitivity: kBubblesSwipeDismissSensitivity,
         transitionDuration: kBubblesSheetTransitionDuration,
         transitionCurve: kBubblesSheetTransitionCurve,
       );

  final SheetController _sheetController;

  @override
  void dispose() {
    super.dispose();
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _sheetController.dispose());
    // Disposal waits on a frame; make sure one is coming so the controller
    // never lingers on an otherwise idle app.
    binding.ensureVisualUpdate();
  }
}

/// Critically damped (ratio 1.0) and stiffer than smooth_sheets' default
/// (mass 0.5, stiffness 100, ratio 1.1 - overdamped, slow tail that "creeps"
/// into place). omega = 20 s^-1: ~0.4 s to settle 400 px to 1 px, no
/// overshoot of its own. The bounce at the ends still comes from the
/// overdrag in BouncingSheetPhysics.
@internal
final SpringDescription kBubblesSnapSpring = SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1);

@internal
class BubblesSnappyBouncingSheetPhysics extends BouncingSheetPhysics {
  const BubblesSnappyBouncingSheetPhysics({super.bounceExtent});

  @override
  SpringDescription get spring => kBubblesSnapSpring;
}
