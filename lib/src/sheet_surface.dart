import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// Where the sheet surface ends and how its corners are rounded, resolved from
/// the live [SheetController] metrics at paint time.
///
/// smooth_sheets lays the sheet's content out once, at the largest height it
/// can take, and never relays it out when the offset changes. At any offset
/// below the content height the sheet's render box is therefore taller than
/// the part of it that is on screen, and simply continues below the viewport
/// edge. Painting and clipping to the box would run the surface off the bottom
/// of the screen (and over the floating inset) at a partial detent. Instead the
/// surface is cut to its *visible* extent: from the box's top down to the
/// viewport bottom, with the same concentric bottom corners a fit sheet has.
///
/// Internal: shared by the modal and paged sheets, not exported from the
/// package barrel.
@internal
@immutable
class BubblesSurfaceGeometry {
  const BubblesSurfaceGeometry({
    required this.controller,
    required this.flushAnim,
    required this.topRadius,
    required this.deviceRadius,
    required this.inset,
    this.squareWhenParkedAtMax = false,
    this.squareWhenFlush = false,
  });

  final SheetController controller;

  /// 0 while the sheet floats, 1 once it is flush with the device edges.
  final Animation<double> flushAnim;
  final double topRadius;
  final double deviceRadius;
  final double inset;

  /// Square the bottom corners while the sheet is parked at its highest detent.
  /// Only valid when that detent is flush with the device edge (a `large`
  /// detent); a fit-only sheet is "at max" while still floating.
  final bool squareWhenParkedAtMax;

  /// Square the bottom corners once [flushAnim] has reached the flush end.
  final bool squareWhenFlush;

  double _bottomRadius() {
    final m = controller.metrics;
    final atMax = m != null && m.offset >= m.maxOffset - 0.5;
    if ((squareWhenParkedAtMax && atMax) || (squareWhenFlush && flushAnim.value >= 0.99)) {
      return 0;
    }
    return lerpDouble(deviceRadius - inset, deviceRadius, flushAnim.value)!.clamp(0.0, deviceRadius);
  }

  /// The visible height of a sheet box [boxHeight] tall.
  ///
  /// The offset is floored at the lowest detent, so a swipe-to-dismiss drag
  /// below it slides the surface down at its resting height instead of
  /// squashing it. With no metrics yet (before first layout) the whole box.
  double visibleHeight(double boxHeight) {
    final m = controller.metrics;
    if (m == null) return boxHeight;
    final offset = m.offset > m.minOffset ? m.offset : m.minOffset;
    return (offset - m.viewportPadding.bottom).clamp(0.0, boxHeight);
  }

  RRect resolve(Size size) {
    final bottom = Radius.circular(_bottomRadius());
    final top = Radius.circular(topRadius);
    return RRect.fromLTRBAndCorners(
      0,
      0,
      size.width,
      visibleHeight(size.height),
      topLeft: top,
      topRight: top,
      bottomLeft: bottom,
      bottomRight: bottom,
    );
  }

  bool differsFrom(BubblesSurfaceGeometry other) =>
      controller != other.controller ||
      flushAnim != other.flushAnim ||
      topRadius != other.topRadius ||
      deviceRadius != other.deviceRadius ||
      inset != other.inset ||
      squareWhenParkedAtMax != other.squareWhenParkedAtMax ||
      squareWhenFlush != other.squareWhenFlush;
}

/// One stable [Listenable] for a surface's painter and clipper, fed by the
/// sources it watches.
///
/// A [CustomPainter] re-adds itself to its `repaint` listenable every time a new
/// painter is installed, and `Listenable.merge` forwards that to every source.
/// A surface is rebuilt whenever the sheet re-lays out - including while the
/// route is tearing down, after the [SheetController] is disposed - so merging
/// the sources directly would touch a disposed controller. This relay
/// subscribes to the sources once and owns that subscription for the surface's
/// life.
@internal
class BubblesSurfaceRepaint extends ChangeNotifier {
  BubblesSurfaceRepaint(this._sources) {
    for (final source in _sources) {
      source.addListener(notifyListeners);
    }
  }

  final List<Listenable> _sources;

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

/// The sheet surface: fill and shadow painted, and the child clipped (and
/// hit-tested), to the geometry's visible rounded rect.
///
/// Repainting is driven by [repaint] — the sheet's offset, the flush animation —
/// not by rebuilding this widget, so a drag costs a paint and a reclip per
/// frame and no widget rebuild.
@internal
class BubblesSheetSurfaceBox extends StatelessWidget {
  const BubblesSheetSurfaceBox({
    required this.geometry,
    required this.repaint,
    required this.color,
    required this.shadows,
    required this.child,
    super.key,
  });

  final BubblesSurfaceGeometry geometry;
  final Listenable repaint;
  final Color color;
  final List<BoxShadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SurfacePainter(geometry: geometry, color: color, shadows: shadows, repaint: repaint),
      child: ClipRRect(
        clipper: _SurfaceClipper(geometry: geometry, reclip: repaint),
        child: child,
      ),
    );
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({required this.geometry, required this.color, required this.shadows, required Listenable repaint})
    : super(repaint: repaint);

  final BubblesSurfaceGeometry geometry;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = geometry.resolve(size);
    for (final shadow in shadows) {
      canvas.drawRRect(rrect.shift(shadow.offset).inflate(shadow.spreadRadius), shadow.toPaint());
    }
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      geometry.differsFrom(old.geometry) || color != old.color || !listEquals(shadows, old.shadows);
}

class _SurfaceClipper extends CustomClipper<RRect> {
  _SurfaceClipper({required this.geometry, required Listenable reclip}) : super(reclip: reclip);

  final BubblesSurfaceGeometry geometry;

  @override
  RRect getClip(Size size) => geometry.resolve(size);

  @override
  bool shouldReclip(_SurfaceClipper old) => geometry.differsFrom(old.geometry);
}
