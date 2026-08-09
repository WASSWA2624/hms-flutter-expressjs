import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';

/// Named shortcut that resolves to a concrete [DateTimeRange].
@immutable
final class AppDateRangePreset {
  const AppDateRangePreset({
    required this.id,
    required this.label,
    required this.buildRange,
  });

  final String id;
  final String label;
  final DateTimeRange Function() buildRange;
}

/// HMS-themed date-range picker with presets and typed start/end fields.
Future<DateTimeRange?> showAppDateRangeDialog({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
  List<AppDateRangePreset> extraPresets = const <AppDateRangePreset>[],
  String? title,
  String? body,
}) {
  return showAppDialog<DateTimeRange>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _AppDateRangeDialog(
        firstDate: _dateOnly(firstDate),
        lastDate: _dateOnly(lastDate),
        initialRange: initialRange == null
            ? null
            : DateTimeRange(
                start: _dateOnly(initialRange.start),
                end: _dateOnly(initialRange.end),
              ),
        extraPresets: extraPresets,
        title: title,
        body: body,
      );
    },
  );
}

class _AppDateRangeDialog extends StatefulWidget {
  const _AppDateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.extraPresets,
    this.initialRange,
    this.title,
    this.body,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;
  final List<AppDateRangePreset> extraPresets;
  final String? title;
  final String? body;

  @override
  State<_AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

class _AppDateRangeDialogState extends State<_AppDateRangeDialog> {
  late DateTime? _start;
  late DateTime? _end;
  String? _activePresetId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTimeRange? initial = widget.initialRange;
    _start = initial?.start;
    _end = initial?.end;
  }

  List<AppDateRangePreset> _builtInPresets(AppLocalizations l10n) {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    return <AppDateRangePreset>[
      AppDateRangePreset(
        id: 'today',
        label: l10n.appDateRangePresetToday,
        buildRange: () => DateTimeRange(start: today, end: today),
      ),
      AppDateRangePreset(
        id: 'this_week',
        label: l10n.appDateRangePresetThisWeek,
        buildRange: () => DateTimeRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 6)),
        ),
      ),
      AppDateRangePreset(
        id: 'this_month',
        label: l10n.appDateRangePresetThisMonth,
        buildRange: () => DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(today.year, today.month + 1, 0),
        ),
      ),
      AppDateRangePreset(
        id: 'last_7',
        label: l10n.appDateRangePresetLast7Days,
        buildRange: () => DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      ),
      AppDateRangePreset(
        id: 'last_30',
        label: l10n.appDateRangePresetLast30Days,
        buildRange: () => DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        ),
      ),
      ...widget.extraPresets,
    ];
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(widget.firstDate)) {
      return widget.firstDate;
    }
    if (value.isAfter(widget.lastDate)) {
      return widget.lastDate;
    }
    return value;
  }

  void _applyPreset(AppDateRangePreset preset) {
    final DateTimeRange raw = preset.buildRange();
    final DateTime start = _clamp(_dateOnly(raw.start));
    final DateTime end = _clamp(_dateOnly(raw.end));
    setState(() {
      _activePresetId = preset.id;
      _start = start.isAfter(end) ? end : start;
      _end = end.isBefore(start) ? start : end;
      _error = null;
    });
  }

  void _useStartMonth() {
    final DateTime? start = _start;
    if (start == null) {
      return;
    }
    setState(() {
      _activePresetId = null;
      _start = _clamp(DateTime(start.year, start.month));
      _end = _clamp(DateTime(start.year, start.month + 1, 0));
      _error = null;
    });
  }

  void _shiftMonth(int delta) {
    final DateTime anchor = _start ?? _dateOnly(DateTime.now());
    final DateTime monthStart = DateTime(anchor.year, anchor.month + delta);
    setState(() {
      _activePresetId = null;
      _start = _clamp(monthStart);
      _end = _clamp(DateTime(monthStart.year, monthStart.month + 1, 0));
      _error = null;
    });
  }

  void _shiftYear(int delta) {
    final DateTime anchor = _start ?? _dateOnly(DateTime.now());
    final DateTime monthStart = DateTime(anchor.year + delta, anchor.month);
    setState(() {
      _activePresetId = null;
      _start = _clamp(monthStart);
      _end = _clamp(DateTime(monthStart.year, monthStart.month + 1, 0));
      _error = null;
    });
  }

  void _submit(AppLocalizations l10n) {
    final DateTime? start = _start;
    final DateTime? end = _end;
    if (start == null || end == null) {
      setState(() => _error = l10n.appDateRangeRequiredMessage);
      return;
    }
    if (start.isAfter(end)) {
      setState(() => _error = l10n.appDateRangeInvalidMessage);
      return;
    }
    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);
    final bool showActionLabels =
        AppBreakpoints.of(context).showsToolbarActionLabels;
    final List<AppDateRangePreset> presets = _builtInPresets(l10n);
    final String? summary = (_start != null && _end != null)
        ? '${materials.formatMediumDate(_start!)} – ${materials.formatMediumDate(_end!)}'
        : null;
    final String monthCaption = materials.formatMonthYear(
      _start ?? _dateOnly(DateTime.now()),
    );

    return AppActionLabelScope(
      showLabels: showActionLabels,
      forceIconOnly: !showActionLabels,
      child: AppDialog(
        title: Text(widget.title ?? l10n.appDateRangeDialogTitle),
        icon: const Icon(Icons.date_range_outlined),
        scrollable: true,
        maxWidth: 640,
        stackActionsWhenCompact: false,
        denseActions: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppMutedText(widget.body ?? l10n.appDateRangeDialogBody),
            SizedBox(height: theme.spacing.md),
            _sectionLabel(theme, l10n.appDateRangeSelectedLabel),
            SizedBox(height: theme.spacing.xs),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.md,
                  vertical: theme.spacing.md + 2,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_available_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child: Text(
                        summary ?? '—',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: AppFontWeight.emphasis,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: theme.spacing.lg),
            _sectionLabel(theme, l10n.appDateRangePresetsLabel),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final AppDateRangePreset preset in presets)
                  FilterChip(
                    label: Text(preset.label),
                    selected: _activePresetId == preset.id,
                    onSelected: (_) => _applyPreset(preset),
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: _activePresetId == preset.id
                          ? theme.colorScheme.onPrimary
                          : null,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _activePresetId == preset.id
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.lg),
            _sectionLabel(theme, l10n.appDateRangeCustomLabel),
            SizedBox(height: theme.spacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.xs,
                  vertical: theme.spacing.xs,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.appDateRangePreviousYearTooltip,
                      onPressed: () => _shiftYear(-1),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                    ),
                    IconButton(
                      tooltip: materials.previousPageTooltip,
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Text(
                            monthCaption,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: _start == null ? null : _useStartMonth,
                            child: Text(l10n.appDateRangeUseMonthAction),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: materials.nextPageTooltip,
                      onPressed: () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: l10n.appDateRangeNextYearTooltip,
                      onPressed: () => _shiftYear(1),
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: theme.spacing.md),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppDateField(
                  value: _start,
                  labelText: l10n.appDateRangeStartLabel,
                  pickerButtonLabel: l10n.appDateRangePickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  enableSpeechToText: false,
                  onChanged: (DateTime? value) {
                    setState(() {
                      _activePresetId = null;
                      _start = value == null ? null : _clamp(_dateOnly(value));
                      _error = null;
                    });
                  },
                ),
                AppDateField(
                  value: _end,
                  labelText: l10n.appDateRangeEndLabel,
                  pickerButtonLabel: l10n.appDateRangePickDateAction,
                  invalidDateMessage: l10n.appDateInvalidMessage,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  enableSpeechToText: false,
                  onChanged: (DateTime? value) {
                    setState(() {
                      _activePresetId = null;
                      _end = value == null ? null : _clamp(_dateOnly(value));
                      _error = null;
                    });
                  },
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.primary(
            label: l10n.appDateRangeApplyAction,
            leadingIcon: Icons.check,
            dense: true,
            onPressed: () => _submit(l10n),
          ),
          AppButton.close(
            label: l10n.commonCloseActionLabel,
            tooltip: l10n.commonCloseActionLabel,
            dense: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  final DateTime local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}
