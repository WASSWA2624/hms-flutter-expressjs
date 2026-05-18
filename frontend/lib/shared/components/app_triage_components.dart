import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

@immutable
final class AppTriageOption {
  const AppTriageOption({
    required this.value,
    required this.label,
    this.tone,
    this.icon,
  });

  final String value;
  final String label;
  final AppWorkspaceStatusTone? tone;
  final IconData? icon;
}

@immutable
final class AppTriageRiskFlagOption {
  const AppTriageRiskFlagOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;
}

@immutable
final class AppVitalSummaryItem {
  const AppVitalSummaryItem({
    required this.label,
    required this.value,
    required this.status,
    this.recordedAtLabel,
  });

  final String label;
  final String value;
  final AppWorkspaceStatus status;
  final String? recordedAtLabel;
}

@immutable
final class AppClinicalAlertSummary {
  const AppClinicalAlertSummary({required this.status, this.description});

  final AppWorkspaceStatus status;
  final String? description;
}

class AppTriagePriorityBadge extends StatelessWidget {
  const AppTriagePriorityBadge({
    required this.value,
    this.label,
    this.emptyLabel = '',
    this.tone,
    this.icon,
    super.key,
  });

  final String? value;
  final String? label;
  final String emptyLabel;
  final AppWorkspaceStatusTone? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final String resolvedLabel =
        _firstNonEmpty(<String?>[label, _readableToken(value), emptyLabel]) ??
        '';
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: resolvedLabel,
        tone: tone ?? appTriageToneForValue(value),
        icon: icon ?? appTriageIconForValue(value),
      ),
    );
  }
}

class AppTriageUrgencyField extends StatelessWidget {
  const AppTriageUrgencyField({
    required this.options,
    required this.onChanged,
    this.value,
    this.labelText,
    this.semanticLabel,
    this.helperText,
    this.enabled = true,
    this.isRequired = false,
    super.key,
  });

  final String? value;
  final List<AppTriageOption> options;
  final String? labelText;
  final String? semanticLabel;
  final String? helperText;
  final bool enabled;
  final bool isRequired;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: value,
      labelText: labelText,
      semanticLabel: semanticLabel ?? labelText,
      helperText: helperText,
      enabled: enabled,
      isRequired: isRequired,
      onChanged: onChanged,
      options: _triageSelectOptions(context, options),
    );
  }
}

class AppTriageDecisionField extends StatelessWidget {
  const AppTriageDecisionField({
    required this.options,
    required this.onChanged,
    this.value,
    this.labelText,
    this.semanticLabel,
    this.helperText,
    this.enabled = true,
    this.isRequired = false,
    this.searchable = true,
    super.key,
  });

  final String? value;
  final List<AppTriageOption> options;
  final String? labelText;
  final String? semanticLabel;
  final String? helperText;
  final bool enabled;
  final bool isRequired;
  final bool searchable;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> choices = _triageSelectOptions(
      context,
      options,
    );
    if (!searchable) {
      return AppSelectField<String>(
        value: value,
        labelText: labelText,
        semanticLabel: semanticLabel ?? labelText,
        helperText: helperText,
        enabled: enabled,
        isRequired: isRequired,
        onChanged: onChanged,
        options: choices,
      );
    }

    return AppSelectField<String>.searchable(
      value: value,
      labelText: labelText,
      semanticLabel: semanticLabel ?? labelText,
      helperText: helperText,
      enabled: enabled,
      isRequired: isRequired,
      onChanged: onChanged,
      options: choices,
    );
  }
}

class AppTriageRiskFlagSelector extends StatelessWidget {
  const AppTriageRiskFlagSelector({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.maxColumns = 2,
    this.minItemWidth = 220,
    super.key,
  });

  final String title;
  final List<AppTriageRiskFlagOption> options;
  final Set<String> selected;
  final bool enabled;
  final int maxColumns;
  final double minItemWidth;
  final void Function(String value, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppSectionPanel(
      title: title,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        AppResponsiveWrap(
          maxColumns: maxColumns,
          minItemWidth: minItemWidth,
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            for (final AppTriageRiskFlagOption option in options)
              AppCheckboxField(
                title: option.label,
                value: selected.contains(option.value),
                enabled: enabled,
                secondary: option.icon == null ? null : Icon(option.icon),
                onChanged: (bool value) => onChanged(option.value, value),
              ),
          ],
        ),
      ],
    );
  }
}

class AppTriageSummaryPanel extends StatelessWidget {
  const AppTriageSummaryPanel({
    required this.items,
    this.title,
    this.description,
    this.statuses = const <AppWorkspaceStatus>[],
    this.notesLabel,
    this.notes,
    this.emptyValue = '',
    this.actions = const <Widget>[],
    this.tone = AppWorkspaceStatusTone.neutral,
    this.minItemWidth = 150,
    super.key,
  });

  final String? title;
  final String? description;
  final List<AppInfoTileData> items;
  final List<AppWorkspaceStatus> statuses;
  final String? notesLabel;
  final String? notes;
  final String emptyValue;
  final List<Widget> actions;
  final AppWorkspaceStatusTone tone;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? normalizedNotes = _nonEmpty(notes);

    return AppContentPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_hasHeader) ...<Widget>[
            _TriagePanelHeader(
              title: title,
              description: description,
              statuses: statuses,
              actions: actions,
            ),
            SizedBox(height: theme.spacing.md),
          ] else if (statuses.isNotEmpty || actions.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final AppWorkspaceStatus status in statuses)
                  AppWorkspaceStatusBadge(status: status),
                ...actions,
              ],
            ),
            SizedBox(height: theme.spacing.md),
          ],
          AppInfoTileGrid(
            items: items,
            minItemWidth: minItemWidth,
            spacing: theme.spacing.md,
            runSpacing: theme.spacing.sm,
            emptyValue: emptyValue,
            borderedTiles: false,
          ),
          if (normalizedNotes != null && notesLabel != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            AppSectionPanel(
              title: notesLabel,
              density: AppContentPanelDensity.compact,
              children: <Widget>[
                Text(normalizedNotes, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasHeader =>
      _nonEmpty(title) != null ||
      _nonEmpty(description) != null ||
      statuses.isNotEmpty ||
      actions.isNotEmpty;
}

class AppVitalsSummaryPanel extends StatelessWidget {
  const AppVitalsSummaryPanel({
    required this.title,
    required this.items,
    this.emptyLabel,
    this.status,
    this.alerts = const <AppClinicalAlertSummary>[],
    this.editLabel,
    this.onEdit,
    this.tone = AppWorkspaceStatusTone.neutral,
    super.key,
  });

  final String title;
  final List<AppVitalSummaryItem> items;
  final String? emptyLabel;
  final AppWorkspaceStatus? status;
  final List<AppClinicalAlertSummary> alerts;
  final String? editLabel;
  final VoidCallback? onEdit;
  final AppWorkspaceStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasContent = items.isNotEmpty || alerts.isNotEmpty;

    return AppContentPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    if (status != null)
                      AppWorkspaceStatusBadge(status: status!),
                  ],
                ),
              ),
              if (onEdit != null && editLabel != null)
                AppButton.tertiary(
                  label: editLabel!,
                  leadingIcon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          if (!hasContent)
            Text(
              emptyLabel ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...<Widget>[
            for (final AppVitalSummaryItem item in items)
              _VitalSummaryRow(item: item),
            if (alerts.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  for (final AppClinicalAlertSummary alert in alerts)
                    Tooltip(
                      message: alert.description ?? alert.status.label,
                      child: AppWorkspaceStatusBadge(status: alert.status),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TriagePanelHeader extends StatelessWidget {
  const _TriagePanelHeader({
    required this.title,
    required this.description,
    required this.statuses,
    required this.actions,
  });

  final String? title;
  final String? description;
  final List<AppWorkspaceStatus> statuses;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_nonEmpty(title) != null)
                Text(title!, style: theme.textTheme.titleSmall),
              if (_nonEmpty(description) != null) ...<Widget>[
                if (_nonEmpty(title) != null)
                  SizedBox(height: theme.spacing.xs),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (statuses.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final AppWorkspaceStatus status in statuses)
                      AppWorkspaceStatusBadge(status: status),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...<Widget>[
          SizedBox(width: theme.spacing.sm),
          Wrap(spacing: theme.spacing.xs, children: actions),
        ],
      ],
    );
  }
}

class _VitalSummaryRow extends StatelessWidget {
  const _VitalSummaryRow({required this.item});

  final AppVitalSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _joinDisplay(<String?>[item.label, item.value]),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_nonEmpty(item.recordedAtLabel) != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    item.recordedAtLabel!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppWorkspaceStatusBadge(status: item.status),
        ],
      ),
    );
  }
}

List<AppSelectOption<String>> _triageSelectOptions(
  BuildContext context,
  List<AppTriageOption> options,
) {
  final ThemeData theme = Theme.of(context);
  return <AppSelectOption<String>>[
    for (final AppTriageOption option in options)
      AppSelectOption<String>(
        value: option.value,
        label: option.label,
        leadingIcon: Icon(
          option.icon ?? appTriageIconForValue(option.value),
          color: _toneAccent(
            theme,
            option.tone ?? appTriageToneForValue(option.value),
          ),
        ),
      ),
  ];
}

AppWorkspaceStatusTone appTriageToneForValue(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'LEVEL_1' ||
    'IMMEDIATE' ||
    'EMERGENCY' ||
    'NOT_FIT_FOR_OPD' => AppWorkspaceStatusTone.error,
    'LEVEL_2' ||
    'URGENT' ||
    'HIGH' ||
    'PRIORITY_DOCTOR' => AppWorkspaceStatusTone.warning,
    'LEVEL_3' || 'ROUTINE' || 'NORMAL_DOCTOR' => AppWorkspaceStatusTone.info,
    'LEVEL_4' ||
    'LEVEL_5' ||
    'LESS_URGENT' ||
    'NON_URGENT' => AppWorkspaceStatusTone.success,
    'SERVICE_ONLY' || 'DIRECT_SERVICE' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData appTriageIconForValue(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'LEVEL_1' ||
    'IMMEDIATE' ||
    'EMERGENCY' ||
    'NOT_FIT_FOR_OPD' => Icons.emergency_outlined,
    'LEVEL_2' ||
    'URGENT' ||
    'HIGH' ||
    'PRIORITY_DOCTOR' => Icons.priority_high_outlined,
    'SERVICE_ONLY' || 'DIRECT_SERVICE' => Icons.room_service_outlined,
    'ROUTINE' || 'NORMAL_DOCTOR' || 'LEVEL_3' => Icons.schedule_outlined,
    _ => Icons.local_hospital_outlined,
  };
}

Color _toneAccent(ThemeData theme, AppWorkspaceStatusTone tone) {
  final AppStatusColors statusColors = theme.statusColors;
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String? normalized = _nonEmpty(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _readableToken(String? value) {
  final String? normalized = _nonEmpty(value);
  if (normalized == null) {
    return null;
  }
  return normalized
      .split(RegExp(r'[_\s-]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' - ');
}
