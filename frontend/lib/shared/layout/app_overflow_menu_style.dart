import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Shared chrome for "More actions" overflow menus.
///
/// Used by the workspace toolbar and by `AppDialog` footers so both surfaces
/// present one menu treatment instead of diverging per container.

/// Surface style for a root overflow menu.
MenuStyle appOverflowMenuStyle(ThemeData theme) {
  final ColorScheme colorScheme = theme.colorScheme;

  return MenuStyle(
    minimumSize: WidgetStateProperty.all(const Size(240, 0)),
    maximumSize: WidgetStateProperty.all(const Size(320, double.infinity)),
    backgroundColor: WidgetStateProperty.all(colorScheme.surface),
    surfaceTintColor: WidgetStateProperty.all(colorScheme.surfaceTint),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        side: theme.borders.side(),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
    ),
    padding: WidgetStateProperty.all(
      EdgeInsets.symmetric(vertical: theme.spacing.xs),
    ),
  );
}

/// Surface style for a nested submenu (end-aligned against its parent item).
MenuStyle appOverflowSubmenuStyle(ThemeData theme) {
  final MenuStyle base = appOverflowMenuStyle(theme);

  return MenuStyle(
    minimumSize: base.minimumSize,
    maximumSize: base.maximumSize,
    backgroundColor: base.backgroundColor,
    surfaceTintColor: base.surfaceTintColor,
    shape: base.shape,
    padding: base.padding,
    alignment: AlignmentDirectional.centerEnd,
  );
}

/// Row style for a single overflow menu entry.
ButtonStyle appOverflowMenuItemStyle(ThemeData theme, {bool selected = false}) {
  final ColorScheme colorScheme = theme.colorScheme;

  return ButtonStyle(
    padding: WidgetStateProperty.all(
      EdgeInsets.symmetric(horizontal: theme.spacing.sm),
    ),
    minimumSize: WidgetStateProperty.all(const Size(0, 48)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (selected) {
        return colorScheme.secondaryContainer;
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.surfaceContainerHighest;
      }
      return null;
    }),
    side: WidgetStateProperty.resolveWith<BorderSide?>((
      Set<WidgetState> states,
    ) {
      if (!states.contains(WidgetState.focused)) {
        return null;
      }
      return theme.borders.side(
        color: colorScheme.primary.withValues(alpha: 0.72),
        weight: AppBorderWeight.medium,
      );
    }),
  );
}
