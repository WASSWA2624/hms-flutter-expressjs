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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Wrap(
        spacing: 4,
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
      ),
    );
  }
}

class _AppTabChip extends StatefulWidget {
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
  State<_AppTabChip> createState() => _AppTabChipState();
}

class _AppTabChipState extends State<_AppTabChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = widget.isSelected
        ? widget.colorScheme.primaryContainer.withValues(alpha: 0.7)
        : _isHovered
            ? widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : Colors.transparent;
    final Color foregroundColor = widget.isSelected
        ? widget.colorScheme.onPrimaryContainer
        : widget.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              bottom: BorderSide(
                color: widget.isSelected
                    ? widget.colorScheme.primary
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.theme.spacing.md,
                  vertical: widget.theme.spacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(widget.icon, size: 18, color: foregroundColor),
                    SizedBox(width: widget.theme.spacing.xs),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: widget.isSelected
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
      ),
    );
  }
}
