import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

enum AppSortDirection { ascending, descending }

@immutable
final class AppSortDescriptor {
  const AppSortDescriptor({
    required this.field,
    this.direction = AppSortDirection.ascending,
  });

  final String field;
  final AppSortDirection direction;

  AppSortDescriptor copyWith({String? field, AppSortDirection? direction}) {
    return AppSortDescriptor(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSortDescriptor &&
        other.field == field &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(field, direction);
}

@immutable
final class AppSortOption {
  const AppSortOption({
    required this.field,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final String field;
  final String label;
  final IconData? icon;
  final bool enabled;
}

class AppSortMenuButton extends StatelessWidget {
  const AppSortMenuButton({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.ascendingLabel,
    required this.descendingLabel,
    this.clearLabel,
    this.semanticLabel,
    this.tooltip,
    this.enabled = true,
    this.icon = Icons.sort_outlined,
    super.key,
  });

  final List<AppSortOption> options;
  final AppSortDescriptor? value;
  final ValueChanged<AppSortDescriptor?> onChanged;
  final String label;
  final String ascendingLabel;
  final String descendingLabel;
  final String? clearLabel;
  final String? semanticLabel;
  final String? tooltip;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final String buttonLabel = _selectedLabel();

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? buttonLabel,
      child: PopupMenuButton<Object>(
        enabled: enabled,
        tooltip: tooltip ?? semanticLabel ?? buttonLabel,
        initialValue: value,
        onSelected: _handleSelected,
        itemBuilder: _menuItems,
        child: _SortButtonContent(icon: icon, label: buttonLabel),
      ),
    );
  }

  List<PopupMenuEntry<Object>> _menuItems(BuildContext context) {
    final List<PopupMenuEntry<Object>> items = <PopupMenuEntry<Object>>[];

    for (final AppSortOption option in options) {
      items
        ..add(
          PopupMenuItem<Object>(
            value: AppSortDescriptor(field: option.field),
            enabled: option.enabled,
            child: _SortMenuItem(
              option: option,
              directionLabel: ascendingLabel,
              direction: AppSortDirection.ascending,
            ),
          ),
        )
        ..add(
          PopupMenuItem<Object>(
            value: AppSortDescriptor(
              field: option.field,
              direction: AppSortDirection.descending,
            ),
            enabled: option.enabled,
            child: _SortMenuItem(
              option: option,
              directionLabel: descendingLabel,
              direction: AppSortDirection.descending,
            ),
          ),
        );
    }

    final String? resetLabel = clearLabel;
    if (resetLabel != null && resetLabel.isNotEmpty) {
      if (items.isNotEmpty) {
        items.add(const PopupMenuDivider());
      }
      items.add(
        PopupMenuItem<Object>(
          value: _clearSortValue,
          enabled: value != null,
          child: Row(
            children: <Widget>[
              const Icon(Icons.close),
              const SizedBox(width: 12),
              Expanded(child: Text(resetLabel)),
            ],
          ),
        ),
      );
    }

    return items;
  }

  void _handleSelected(Object selectedValue) {
    if (identical(selectedValue, _clearSortValue)) {
      onChanged(null);
      return;
    }

    onChanged(selectedValue as AppSortDescriptor);
  }

  String _selectedLabel() {
    final AppSortDescriptor? descriptor = value;
    if (descriptor == null) {
      return label;
    }

    final AppSortOption? option = _optionForField(descriptor.field);
    final String fieldLabel = option?.label ?? descriptor.field;
    final String directionLabel =
        descriptor.direction == AppSortDirection.ascending
        ? ascendingLabel
        : descendingLabel;

    return '$fieldLabel, $directionLabel';
  }

  AppSortOption? _optionForField(String field) {
    for (final AppSortOption option in options) {
      if (option.field == field) {
        return option;
      }
    }
    return null;
  }
}

const Object _clearSortValue = Object();

class _SortButtonContent extends StatelessWidget {
  const _SortButtonContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: theme.appTokens.listIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: theme.spacing.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.xs),
            Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SortMenuItem extends StatelessWidget {
  const _SortMenuItem({
    required this.option,
    required this.directionLabel,
    required this.direction,
  });

  final AppSortOption option;
  final String directionLabel;
  final AppSortDirection direction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(option.icon ?? _directionIcon(direction)),
        const SizedBox(width: 12),
        Expanded(child: Text('${option.label} $directionLabel')),
      ],
    );
  }
}

IconData _directionIcon(AppSortDirection direction) {
  return switch (direction) {
    AppSortDirection.ascending => Icons.arrow_upward,
    AppSortDirection.descending => Icons.arrow_downward,
  };
}
