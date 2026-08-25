import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

/// The display's bottom screen-corner radius, in logical pixels.
///
/// Two sources, cheapest first:
///
///  * `FlutterView.displayCornerRadii` — synchronous, free, and populated by
///    `dart:ui` only on Android API 31+. Reported in *physical* pixels, so it is
///    divided by the view's `devicePixelRatio` here.
///  * `package:screen_corner_radius` — a platform channel that also covers iOS,
///    where Apple exposes no public API for this. It already reports *logical*
///    pixels on both platforms, so its values are used as-is.
///
/// The channel call is asynchronous while a sheet needs a radius during
/// `build`, so the first read starts the lookup and returns 0. [listenable]
/// fires when the answer lands, which is what lets a sheet opened in that
/// window repaint with the real curve rather than staying square.
abstract final class BubblesDeviceCornerRadius {
  static final ValueNotifier<double?> _resolved = ValueNotifier<double?>(null);
  static Future<void>? _inFlight;

  /// Notifies once the asynchronous lookup completes.
  ///
  /// Sheet surfaces listen to this so they repaint when the radius arrives.
  static ValueListenable<double?> get listenable => _resolved;

  /// The resolved radius, or null while the lookup is still outstanding.
  @visibleForTesting
  static double? get value => _resolved.value;

  /// Overrides the resolved value. For tests only.
  @visibleForTesting
  static void setValueForTesting(double? radius) {
    _inFlight = Future<void>.value();
    _resolved.value = radius;
  }

  /// Forgets the resolved value and lets the next read look it up again.
  @visibleForTesting
  static void resetForTesting() {
    _inFlight = null;
    _resolved.value = null;
  }

  /// The radius to draw with, resolving from whichever source can answer.
  static double resolve(BuildContext context) {
    final view = View.maybeOf(context);
    final native = view?.displayCornerRadii;
    if (view != null && native != null) {
      final ratio = view.devicePixelRatio;
      // dart:ui reports these in physical pixels; a 3x device would otherwise
      // get a radius three times too large.
      if (ratio > 0) return math.max(native.bottomLeft, native.bottomRight) / ratio;
    }
    ensureResolved();
    return _resolved.value ?? 0;
  }

  /// Starts the platform-channel lookup if it hasn't run yet.
  ///
  /// Called for you on the first [resolve]. Call it during startup if you would
  /// rather the answer be ready before the first sheet opens — it is safe to
  /// call more than once, and only ever does the work once.
  static void ensureResolved() {
    _inFlight ??= _read();
  }

  static Future<void> _read() async {
    try {
      final radii = await ScreenCornerRadius.get();
      if (radii != null) {
        _resolved.value = math.max(radii.bottomLeft, radii.bottomRight);
      }
    } on Object {
      // A platform with no implementation, or an OS that renamed the property
      // this is read from. Staying at null squares the corners off, which is
      // the honest fallback — never a reason to take a sheet down.
    }
  }
}
