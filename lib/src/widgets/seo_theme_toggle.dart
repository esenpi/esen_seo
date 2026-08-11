import 'package:flutter/material.dart';

import '../components/seo_components.dart';
import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';

/// A controlled light/dark switch with a matching DOM-first presentation.
///
/// Flutter invokes [onChanged] with the next resolved brightness. The web
/// document receives only inert component data; the package-owned runtime
/// creates and controls the button when the route opts into
/// `SeoDomFirstFeature.themeToggle`.
///
/// A DOM-first document supports exactly one toggle. Multiple markers remain
/// inert so the runtime never guesses which control owns the page preference.
class SeoThemeToggle extends StatelessWidget {
  const SeoThemeToggle({
    super.key,
    required this.isDark,
    required this.onChanged,
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.lightSemanticLabel = 'Use light theme',
    this.darkSemanticLabel = 'Use dark theme',
    this.compactOnSmallScreens = false,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;
  final String lightLabel;
  final String darkLabel;
  final String lightSemanticLabel;
  final String darkSemanticLabel;

  /// Shows only the symbol at widths up to
  /// [seoThemeToggleCompactBreakpoint].
  ///
  /// The semantic label and tooltip remain available in compact mode. The
  /// corresponding DOM-first marker opts into the same responsive behavior.
  final bool compactOnSmallScreens;

  List<SeoNode> toSeoNodes() => buildSeoThemeToggleNodes(
        lightLabel: lightLabel,
        darkLabel: darkLabel,
        lightSemanticLabel: lightSemanticLabel,
        darkSemanticLabel: darkSemanticLabel,
        compactOnSmallScreens: compactOnSmallScreens,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = isDark ? lightLabel : darkLabel;
    final semanticLabel = isDark ? lightSemanticLabel : darkSemanticLabel;
    final symbol = isDark ? '\u2600' : '\u263e';
    final showLabel = !compactOnSmallScreens ||
        MediaQuery.sizeOf(context).width > seoThemeToggleCompactBreakpoint;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(showLabel ? 92 : 48, showLabel ? 40 : 48),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: showLabel ? 12 : 7, vertical: 7),
      ),
      foregroundColor: WidgetStatePropertyAll(colors.onSurface),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? colors.surfaceContainer
            : colors.surfaceContainerLow,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: colors.outlineVariant),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1,
            ),
      ),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: showLabel
            ? OutlinedButton.icon(
                onPressed: () => onChanged(!isDark),
                style: style,
                icon: Text(symbol),
                label: Text(label),
              )
            : OutlinedButton(
                onPressed: () => onChanged(!isDark),
                style: style,
                child: Text(symbol),
              ),
      ),
    ).seoNodes(toSeoNodes());
  }
}
