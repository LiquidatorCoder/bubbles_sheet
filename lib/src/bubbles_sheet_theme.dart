import 'package:bubbles_sheet/src/bubbles_sheet_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The chrome colours for one brightness.
///
/// A sheet picks between [BubblesSheetThemeData.light] and
/// [BubblesSheetThemeData.dark] from its own `dark` flag, not from the ambient
/// [Theme] brightness — a sheet is often deliberately inverted against the
/// screen behind it.
@immutable
class BubblesSheetPalette {
  const BubblesSheetPalette({
    required this.surface,
    required this.title,
    required this.dragHandle,
    required this.closeButtonBackground,
    required this.closeButtonIcon,
    required this.action,
    required this.disabledAction,
    this.surfaceShadow = const <BoxShadow>[],
  });

  /// Fill behind the sheet, under the rounded corners.
  final Color surface;

  /// Colour applied to [BubblesSheetThemeData.titleStyle].
  final Color title;

  /// The 36×4 grab handle.
  final Color dragHandle;

  /// Fill of the circular leading close button.
  final Color closeButtonBackground;

  /// Glyph inside the leading close button.
  final Color closeButtonIcon;

  /// Label colour for an enabled header [BubblesSheetAction].
  final Color action;

  /// Label colour for a disabled header [BubblesSheetAction].
  final Color disabledAction;

  /// Cast under the floating sheet.
  final List<BoxShadow> surfaceShadow;

  /// Warm, cream-on-black defaults — the palette the package ships with.
  static const BubblesSheetPalette cream = BubblesSheetPalette(
    surface: Color(0xFFFAF9F5),
    title: Color(0xFF111111),
    dragHandle: Color(0xFFE6DFD8),
    closeButtonBackground: Color(0xFFEFE9DE),
    closeButtonIcon: Color(0xFF111111),
    action: Color(0xFFD97757),
    disabledAction: Color(0xFF7A7770),
    surfaceShadow: [
      BoxShadow(color: Color(0x14141413), offset: Offset(0, 4), blurRadius: 12, spreadRadius: -2),
      BoxShadow(color: Color(0x0A141413), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  /// The dark counterpart to [cream].
  static const BubblesSheetPalette charcoal = BubblesSheetPalette(
    surface: Color(0xFF181715),
    title: Color(0xFFFAF9F5),
    dragHandle: Color(0x24FFFFFF),
    closeButtonBackground: Color(0xFF252320),
    closeButtonIcon: Color(0xFFFAF9F5),
    action: Color(0xFFD97757),
    disabledAction: Color(0xFFA09D96),
    surfaceShadow: [
      BoxShadow(color: Color(0x14141413), offset: Offset(0, 4), blurRadius: 12, spreadRadius: -2),
      BoxShadow(color: Color(0x0A141413), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  BubblesSheetPalette copyWith({
    Color? surface,
    Color? title,
    Color? dragHandle,
    Color? closeButtonBackground,
    Color? closeButtonIcon,
    Color? action,
    Color? disabledAction,
    List<BoxShadow>? surfaceShadow,
  }) {
    return BubblesSheetPalette(
      surface: surface ?? this.surface,
      title: title ?? this.title,
      dragHandle: dragHandle ?? this.dragHandle,
      closeButtonBackground: closeButtonBackground ?? this.closeButtonBackground,
      closeButtonIcon: closeButtonIcon ?? this.closeButtonIcon,
      action: action ?? this.action,
      disabledAction: disabledAction ?? this.disabledAction,
      surfaceShadow: surfaceShadow ?? this.surfaceShadow,
    );
  }

  static BubblesSheetPalette lerp(BubblesSheetPalette a, BubblesSheetPalette b, double t) {
    return BubblesSheetPalette(
      surface: Color.lerp(a.surface, b.surface, t)!,
      title: Color.lerp(a.title, b.title, t)!,
      dragHandle: Color.lerp(a.dragHandle, b.dragHandle, t)!,
      closeButtonBackground: Color.lerp(a.closeButtonBackground, b.closeButtonBackground, t)!,
      closeButtonIcon: Color.lerp(a.closeButtonIcon, b.closeButtonIcon, t)!,
      action: Color.lerp(a.action, b.action, t)!,
      disabledAction: Color.lerp(a.disabledAction, b.disabledAction, t)!,
      surfaceShadow: BoxShadow.lerpList(a.surfaceShadow, b.surfaceShadow, t) ?? b.surfaceShadow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BubblesSheetPalette &&
        other.surface == surface &&
        other.title == title &&
        other.dragHandle == dragHandle &&
        other.closeButtonBackground == closeButtonBackground &&
        other.closeButtonIcon == closeButtonIcon &&
        other.action == action &&
        other.disabledAction == disabledAction &&
        listEquals(other.surfaceShadow, surfaceShadow);
  }

  @override
  int get hashCode => Object.hash(
    surface,
    title,
    dragHandle,
    closeButtonBackground,
    closeButtonIcon,
    action,
    disabledAction,
    Object.hashAll(surfaceShadow),
  );
}

/// The sheet's geometry — insets, radii, and the padding around each chrome
/// slot.
@immutable
class BubblesSheetMetrics {
  const BubblesSheetMetrics({
    this.inset = 16,
    this.topInset = 6,
    this.topRadius = 32,
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.ctaPadding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
    this.footerPadding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
    this.headerRowHeight = 44,
    this.headerSlotWidth = 44,
    this.closeButtonSize = 36,
    this.dragHandleSize = const Size(36, 4),
    this.deviceCornerRadius = 0,
  });

  /// How far the floating sheet sits in from the screen edges. Lerps to zero as
  /// the sheet approaches its largest detent.
  final double inset;

  /// Gap between the status bar and the top of the sheet at its largest detent.
  final double topInset;

  /// Radius of the sheet's top corners.
  final double topRadius;

  /// Padding around the header row (close button, title, trailing action).
  final EdgeInsets headerPadding;

  /// Padding around the sticky primary CTA.
  final EdgeInsets ctaPadding;

  /// Padding around the sticky footer.
  final EdgeInsets footerPadding;

  /// Height of the header row.
  final double headerRowHeight;

  /// Width reserved for the header's leading and trailing slots.
  ///
  /// Separate from [closeButtonSize] so the tap target and the space the title
  /// centres between can be tuned independently, and separate from
  /// [headerRowHeight] because a taller header is not a wider one.
  final double headerSlotWidth;

  /// Diameter of the circular close button.
  final double closeButtonSize;

  /// Size of the grab handle.
  final Size dragHandleSize;

  /// The device's own bottom screen-corner radius, in logical pixels.
  ///
  /// The sheet's bottom corners lerp up to this as it goes flush, so the curve
  /// continues into the bezel instead of cutting across it. Flutter can't read
  /// it, so the host app supplies it — e.g. from `package:screen_corner_radius`.
  /// Left at 0 the sheet simply squares off at the bottom edge.
  final double deviceCornerRadius;

  /// Total height of the header chrome: grab handle, its padding, and the
  /// header row.
  ///
  /// One formula, so a `PreferredSizeWidget` header reserves exactly what it
  /// goes on to paint.
  double get headerHeight => dragHandleSize.height + 10 + headerRowHeight + headerPadding.vertical;

  BubblesSheetMetrics copyWith({
    double? inset,
    double? topInset,
    double? topRadius,
    EdgeInsets? headerPadding,
    EdgeInsets? ctaPadding,
    EdgeInsets? footerPadding,
    double? headerRowHeight,
    double? headerSlotWidth,
    double? closeButtonSize,
    Size? dragHandleSize,
    double? deviceCornerRadius,
  }) {
    return BubblesSheetMetrics(
      inset: inset ?? this.inset,
      topInset: topInset ?? this.topInset,
      topRadius: topRadius ?? this.topRadius,
      headerPadding: headerPadding ?? this.headerPadding,
      ctaPadding: ctaPadding ?? this.ctaPadding,
      footerPadding: footerPadding ?? this.footerPadding,
      headerRowHeight: headerRowHeight ?? this.headerRowHeight,
      headerSlotWidth: headerSlotWidth ?? this.headerSlotWidth,
      closeButtonSize: closeButtonSize ?? this.closeButtonSize,
      dragHandleSize: dragHandleSize ?? this.dragHandleSize,
      deviceCornerRadius: deviceCornerRadius ?? this.deviceCornerRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BubblesSheetMetrics &&
        other.inset == inset &&
        other.topInset == topInset &&
        other.topRadius == topRadius &&
        other.headerPadding == headerPadding &&
        other.ctaPadding == ctaPadding &&
        other.footerPadding == footerPadding &&
        other.headerRowHeight == headerRowHeight &&
        other.headerSlotWidth == headerSlotWidth &&
        other.closeButtonSize == closeButtonSize &&
        other.dragHandleSize == dragHandleSize &&
        other.deviceCornerRadius == deviceCornerRadius;
  }

  @override
  int get hashCode => Object.hash(
    inset,
    topInset,
    topRadius,
    headerPadding,
    ctaPadding,
    footerPadding,
    headerRowHeight,
    headerSlotWidth,
    closeButtonSize,
    dragHandleSize,
    deviceCornerRadius,
  );
}

/// Hooks fired at the moments a sheet wants to feel physical.
///
/// All null by default — the package deliberately doesn't call
/// `HapticFeedback` itself, so an app can route these through whatever haptics
/// façade and user setting it already has.
@immutable
class BubblesSheetHaptics {
  const BubblesSheetHaptics({this.onPresent, this.onDismiss, this.onBack});

  /// A sheet is being pushed.
  final VoidCallback? onPresent;

  /// The close button or a back button was tapped.
  final VoidCallback? onDismiss;

  /// A paged sheet stepped back a page.
  final VoidCallback? onBack;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BubblesSheetHaptics &&
        other.onPresent == onPresent &&
        other.onDismiss == onDismiss &&
        other.onBack == onBack;
  }

  @override
  int get hashCode => Object.hash(onPresent, onDismiss, onBack);
}

/// Everything a `showBubblesSheet` sheet needs that isn't the sheet itself:
/// colours, geometry, type, icons, haptics, and how the primary CTA renders.
///
/// Register it on the app's theme so every sheet picks it up:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light().copyWith(
///     extensions: const [BubblesSheetThemeData(/* … */)],
///   ),
/// )
/// ```
///
/// Every field has a working default, so the package renders correctly with no
/// registration at all.
@immutable
class BubblesSheetThemeData extends ThemeExtension<BubblesSheetThemeData> {
  const BubblesSheetThemeData({
    this.light = BubblesSheetPalette.cream,
    this.dark = BubblesSheetPalette.charcoal,
    this.metrics = const BubblesSheetMetrics(),
    this.titleStyle = _defaultTitleStyle,
    this.actionStyle = _defaultActionStyle,
    this.closeIcon = Icons.close_rounded,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.ctaBuilder = buildDefaultCta,
    this.haptics = const BubblesSheetHaptics(),
  });

  /// Chrome colours for a sheet opened with `dark: false` (the default).
  final BubblesSheetPalette light;

  /// Chrome colours for a sheet opened with `dark: true`.
  final BubblesSheetPalette dark;

  final BubblesSheetMetrics metrics;

  /// Header title. Any colour on it is replaced by the palette's `title`.
  final TextStyle titleStyle;

  /// Trailing header action label. Any colour on it is replaced by the
  /// palette's `action` / `disabledAction`.
  final TextStyle actionStyle;

  /// Glyph in the leading close button.
  final IconData closeIcon;

  /// Glyph in a paged sheet's back button.
  final IconData backIcon;

  /// How the sticky primary CTA renders. Defaults to [buildDefaultCta], a pill
  /// button drawn from the ambient [ColorScheme].
  final BubblesSheetCtaWidgetBuilder ctaBuilder;

  final BubblesSheetHaptics haptics;

  /// The registered theme, or the package defaults when none is registered.
  static BubblesSheetThemeData of(BuildContext context) {
    return Theme.of(context).extension<BubblesSheetThemeData>() ?? const BubblesSheetThemeData();
  }

  /// The palette a sheet opened with [dark] should use.
  BubblesSheetPalette paletteFor({required bool dark}) => dark ? this.dark : light;

  @override
  BubblesSheetThemeData copyWith({
    BubblesSheetPalette? light,
    BubblesSheetPalette? dark,
    BubblesSheetMetrics? metrics,
    TextStyle? titleStyle,
    TextStyle? actionStyle,
    IconData? closeIcon,
    IconData? backIcon,
    BubblesSheetCtaWidgetBuilder? ctaBuilder,
    BubblesSheetHaptics? haptics,
  }) {
    return BubblesSheetThemeData(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      metrics: metrics ?? this.metrics,
      titleStyle: titleStyle ?? this.titleStyle,
      actionStyle: actionStyle ?? this.actionStyle,
      closeIcon: closeIcon ?? this.closeIcon,
      backIcon: backIcon ?? this.backIcon,
      ctaBuilder: ctaBuilder ?? this.ctaBuilder,
      haptics: haptics ?? this.haptics,
    );
  }

  @override
  BubblesSheetThemeData lerp(ThemeExtension<BubblesSheetThemeData>? other, double t) {
    if (other is! BubblesSheetThemeData) return this;
    // Icons, builders and callbacks can't be interpolated — they snap at the
    // midpoint, the same thing IconThemeData does.
    final snapped = t < 0.5 ? this : other;
    return BubblesSheetThemeData(
      light: BubblesSheetPalette.lerp(light, other.light, t),
      dark: BubblesSheetPalette.lerp(dark, other.dark, t),
      metrics: t < 0.5 ? metrics : other.metrics,
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t)!,
      actionStyle: TextStyle.lerp(actionStyle, other.actionStyle, t)!,
      closeIcon: snapped.closeIcon,
      backIcon: snapped.backIcon,
      ctaBuilder: snapped.ctaBuilder,
      haptics: snapped.haptics,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BubblesSheetThemeData &&
        other.light == light &&
        other.dark == dark &&
        other.metrics == metrics &&
        other.titleStyle == titleStyle &&
        other.actionStyle == actionStyle &&
        other.closeIcon == closeIcon &&
        other.backIcon == backIcon &&
        other.ctaBuilder == ctaBuilder &&
        other.haptics == haptics;
  }

  @override
  int get hashCode =>
      Object.hash(light, dark, metrics, titleStyle, actionStyle, closeIcon, backIcon, ctaBuilder, haptics);
}

const TextStyle _defaultTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.2,
  height: 1.15,
);

const TextStyle _defaultActionStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2);

/// The package's stock primary CTA: a full-width pill drawn from the ambient
/// [ColorScheme], so it inherits an app's brand colour without any wiring.
///
/// Replace it via `BubblesSheetThemeData.ctaBuilder` to use your own button.
Widget buildDefaultCta(BuildContext context, BubblesSheetCta cta) {
  return _DefaultCtaButton(cta: cta);
}

class _DefaultCtaButton extends StatefulWidget {
  const _DefaultCtaButton({required this.cta});

  final BubblesSheetCta cta;

  @override
  State<_DefaultCtaButton> createState() => _DefaultCtaButtonState();
}

class _DefaultCtaButtonState extends State<_DefaultCtaButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.cta.enabled && widget.cta.onTap != null;
    final background = enabled
        ? (_down ? Color.lerp(scheme.primary, Colors.black, 0.12)! : scheme.primary)
        : scheme.onSurface.withValues(alpha: 0.12);
    final foreground = enabled ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.cta.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled ? widget.cta.onTap : null,
        child: AnimatedScale(
          scale: enabled && _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 56,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.cta.icon != null) ...[
                  Icon(widget.cta.icon, size: 17, color: foreground),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.cta.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
