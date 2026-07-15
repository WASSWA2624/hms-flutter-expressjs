import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

@immutable
final class AppTabItem {
  const AppTabItem({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

class AppTabStrip extends StatelessWidget {
  const AppTabStrip({
    required this.tabs,
    required this.selectedId,
    required this.onTabTapped,
    super.key,
  });

  final List<AppTabItem> tabs;
  final String? selectedId;
  final ValueChanged<String> onTabTapped;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 2,
      children: <Widget>[
        for (final AppTabItem tab in tabs)
          _AppTabChip(
            icon: tab.icon,
            label: tab.label,
            isSelected: selectedId == tab.id,
            onTap: () => onTabTapped(tab.id),
            colorScheme: colorScheme,
            theme: theme,
          ),
      ],
    );
  }
}

class _AppTabChip extends StatelessWidget {
  const _AppTabChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isSelected
        ? colorScheme.primaryContainer
        : Colors.transparent;
    final Color foregroundColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 18, color: foregroundColor),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
