import 'package:flutter/material.dart';

/// A resolved visual property plus where it came from.
class PropValue {
  const PropValue({required this.value, required this.source});

  final String value;

  /// `'theme.<path>'` if [value] matches a design token, else `'literal'`.
  final String source;

  Map<String, Object?> toJson() => <String, Object?>{'value': value, 'source': source};
}

/// Best-effort resolved props for [element]'s widget, with theme provenance.
///
/// Covers the common cases only (PLAN.md §3.4): a handful of widget types
/// for `backgroundColor`/`borderRadius`, and `Text`/`RichText` for
/// `textStyle`. Naive equality against [ThemeData] — first match wins, no
/// attempt to disambiguate roles that share a value.
Map<String, PropValue> resolvedPropsOf(Element element) {
  final Widget widget = element.widget;
  final ThemeData theme = Theme.of(element);
  final Map<String, PropValue> props = <String, PropValue>{};

  Color? color;
  BorderRadius? borderRadius;
  TextStyle? textStyle;

  switch (widget) {
    case Container(decoration: final decoration, color: final containerColor):
      if (decoration is BoxDecoration) {
        color = decoration.color;
        if (decoration.borderRadius case final BorderRadius radius) borderRadius = radius;
      } else {
        color = containerColor;
      }
    case DecoratedBox(decoration: final decoration):
      if (decoration is BoxDecoration) {
        color = decoration.color;
        if (decoration.borderRadius case final BorderRadius radius) borderRadius = radius;
      }
    case Card(color: final cardColor, shape: final shape):
      color = cardColor;
      if (shape is RoundedRectangleBorder) {
        if (shape.borderRadius case final BorderRadius radius) borderRadius = radius;
      }
    case ButtonStyleButton(style: final style):
      color = style?.backgroundColor?.resolve(const <WidgetState>{});
      final ShapeBorder? shape = style?.shape?.resolve(const <WidgetState>{});
      if (shape is RoundedRectangleBorder) {
        if (shape.borderRadius case final BorderRadius radius) borderRadius = radius;
      }
    case Text(style: final style):
      textStyle = style;
    case RichText(text: final text):
      textStyle = text.style;
    default:
      break;
  }

  if (color != null) {
    props['backgroundColor'] = PropValue(value: _hex(color), source: _colorSource(color, theme));
  }
  if (borderRadius != null) {
    props['borderRadius'] = PropValue(value: _radius(borderRadius), source: 'literal');
  }
  if (textStyle != null) {
    props['textStyle'] = PropValue(value: _textStyle(textStyle), source: _textStyleSource(textStyle, theme));
  }

  return props;
}

String _hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _radius(BorderRadius radius) {
  final double tl = radius.topLeft.x;
  final bool uniform =
      radius.topLeft == radius.topRight && radius.topLeft == radius.bottomLeft && radius.topLeft == radius.bottomRight;
  return uniform ? tl.toStringAsFixed(tl.truncateToDouble() == tl ? 0 : 1) : radius.toString();
}

String _textStyle(TextStyle style) {
  final String size = style.fontSize?.toStringAsFixed(0) ?? '?';
  final int weight = style.fontWeight?.value ?? FontWeight.normal.value;
  return '$size/$weight';
}

String _colorSource(Color color, ThemeData theme) {
  final ColorScheme scheme = theme.colorScheme;
  final Map<String, Color> roles = <String, Color>{
    'primary': scheme.primary,
    'onPrimary': scheme.onPrimary,
    'primaryContainer': scheme.primaryContainer,
    'onPrimaryContainer': scheme.onPrimaryContainer,
    'secondary': scheme.secondary,
    'onSecondary': scheme.onSecondary,
    'secondaryContainer': scheme.secondaryContainer,
    'onSecondaryContainer': scheme.onSecondaryContainer,
    'tertiary': scheme.tertiary,
    'onTertiary': scheme.onTertiary,
    'error': scheme.error,
    'onError': scheme.onError,
    'surface': scheme.surface,
    'onSurface': scheme.onSurface,
    'surfaceContainerHighest': scheme.surfaceContainerHighest,
    'outline': scheme.outline,
    'outlineVariant': scheme.outlineVariant,
    'inversePrimary': scheme.inversePrimary,
  };
  for (final MapEntry<String, Color> entry in roles.entries) {
    if (entry.value.toARGB32() == color.toARGB32()) return 'theme.colorScheme.${entry.key}';
  }
  if (theme.dividerColor.toARGB32() == color.toARGB32()) return 'theme.dividerColor';
  if (theme.scaffoldBackgroundColor.toARGB32() == color.toARGB32()) return 'theme.scaffoldBackgroundColor';
  return 'literal';
}

String _textStyleSource(TextStyle style, ThemeData theme) {
  final Map<String, TextStyle?> styles = <String, TextStyle?>{
    'displayLarge': theme.textTheme.displayLarge,
    'displayMedium': theme.textTheme.displayMedium,
    'displaySmall': theme.textTheme.displaySmall,
    'headlineLarge': theme.textTheme.headlineLarge,
    'headlineMedium': theme.textTheme.headlineMedium,
    'headlineSmall': theme.textTheme.headlineSmall,
    'titleLarge': theme.textTheme.titleLarge,
    'titleMedium': theme.textTheme.titleMedium,
    'titleSmall': theme.textTheme.titleSmall,
    'bodyLarge': theme.textTheme.bodyLarge,
    'bodyMedium': theme.textTheme.bodyMedium,
    'bodySmall': theme.textTheme.bodySmall,
    'labelLarge': theme.textTheme.labelLarge,
    'labelMedium': theme.textTheme.labelMedium,
    'labelSmall': theme.textTheme.labelSmall,
  };
  for (final MapEntry<String, TextStyle?> entry in styles.entries) {
    final TextStyle? candidate = entry.value;
    if (candidate == null) continue;
    if (candidate.fontSize == style.fontSize &&
        (candidate.fontWeight ?? FontWeight.normal) == (style.fontWeight ?? FontWeight.normal)) {
      return 'theme.textTheme.${entry.key}';
    }
  }
  return 'literal';
}
