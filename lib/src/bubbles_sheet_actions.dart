import 'package:flutter/material.dart';

/// The sticky primary action pinned to the bottom of a sheet.
///
/// It stays put while the body scrolls, so the committing tap is always where
/// the thumb already is.
@immutable
class BubblesSheetCta {
  const BubblesSheetCta({required this.title, required this.onTap, this.icon, this.enabled = true});

  final String title;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
}

/// Builds the sticky primary action for a sheet, letting a host app render its
/// own button rather than the package's default pill.
typedef BubblesSheetCtaBuilder = BubblesSheetCta? Function(BuildContext context);

/// Renders a [BubblesSheetCta] as a widget. Set on
/// `BubblesSheetThemeData.ctaBuilder`.
typedef BubblesSheetCtaWidgetBuilder = Widget Function(BuildContext context, BubblesSheetCta cta);

/// A text action in the header's trailing slot — the counterpart to the leading
/// close button.
///
/// Use it for a secondary action that doesn't commit the sheet ("Clear",
/// "Edit", "Skip"); the committing action belongs in the [BubblesSheetCta].
@immutable
class BubblesSheetAction {
  const BubblesSheetAction({required this.label, required this.onTap, this.enabled = true});

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
}
