import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_calendar_preview.dart';
import 'package:hosspi_hms/features/settings/data/settings_staff_self_repository.dart';
import 'package:hosspi_hms/features/settings/domain/settings_staff_self_models.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Rosters tab (`/settings?tab=rosters`) — staff self-service shift calendar.
///
/// See [SettingsRostersAtomPermissions] for the inventory → matrix map.
class SettingsRostersSection extends ConsumerStatefulWidget {
  const SettingsRostersSection({super.key});

  @override
  ConsumerState<SettingsRostersSection> createState() =>
      _SettingsRostersSectionState();
}

class _SettingsRostersSectionState
    extends ConsumerState<SettingsRostersSection> {
  SettingsRosterPeriodPreset _preset = SettingsRosterPeriodPreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = true;
  AppFailure? _failure;
  List<SettingsStaffShift> _shifts = const <SettingsStaffShift>[];
  List<HrRosterDayPreview> _days = const <HrRosterDayPreview>[];

  (DateTime, DateTime) get _range => settingsRosterPeriodRange(
    _preset,
    customStart: _customStart,
    customEnd: _customEnd,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final (DateTime from, DateTime to) = _range;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final Result<List<SettingsStaffShift>> result = await ref
        .read(settingsStaffSelfRepositoryProvider)
        .listMyShifts(from: from, to: to);
    if (!mounted) {
      return;
    }
    result.when(
      success: (List<SettingsStaffShift> items) {
        setState(() {
          _shifts = items;
          _days = settingsStaffShiftsToDayPreviews(items, from: from, to: to);
          _loading = false;
          _failure = null;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _shifts = const <SettingsStaffShift>[];
          _days = const <HrRosterDayPreview>[];
          _loading = false;
          _failure = failure;
        });
      },
    );
  }

  void _selectPreset(SettingsRosterPeriodPreset preset) {
    if (_preset == preset && preset != SettingsRosterPeriodPreset.custom) {
      return;
    }
    setState(() => _preset = preset);
    if (preset == SettingsRosterPeriodPreset.custom) {
      unawaited(_pickCustomRange());
      return;
    }
    unawaited(_load());
  }

  Future<void> _pickCustomRange() async {
    final AppLocalizations l10n = context.l10n;
    DateTime? start = _customStart ?? _range.$1;
    DateTime? end = _customEnd ?? _range.$2;

    final bool? applied = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(l10n.settingsRosterPeriodCustom),
              icon: const Icon(Icons.date_range_outlined),
              content: AppFormSection(
                children: <Widget>[
                  AppDateField(
                    value: start,
                    labelText: l10n.hrStartDateLabel,
                    isRequired: true,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    currentDate: DateTime.now(),
                    pickerButtonLabel: l10n.hrPickDateAction,
                    invalidDateMessage: l10n.appDateInvalidMessage,
                    onChanged: (DateTime? value) {
                      setDialogState(() => start = value);
                    },
                  ),
                  AppDateField(
                    value: end,
                    labelText: l10n.hrEndDateLabel,
                    isRequired: true,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    currentDate: DateTime.now(),
                    pickerButtonLabel: l10n.hrPickDateAction,
                    invalidDateMessage: l10n.appDateInvalidMessage,
                    onChanged: (DateTime? value) {
                      setDialogState(() => end = value);
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                AppButton.close(
                  label: l10n.commonCancelActionLabel,
                  onPressed: () => Navigator.of(dialogContext).maybePop(false),
                ),
                AppButton.primary(
                  label: l10n.appDateRangeApplyAction,
                  onPressed: start == null || end == null
                      ? null
                      : () => Navigator.of(dialogContext).maybePop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true || !mounted || start == null || end == null) {
      if (mounted &&
          _customStart == null &&
          _preset == SettingsRosterPeriodPreset.custom) {
        setState(() => _preset = SettingsRosterPeriodPreset.thisMonth);
        unawaited(_load());
      }
      return;
    }

    setState(() {
      _preset = SettingsRosterPeriodPreset.custom;
      _customStart = start;
      _customEnd = end;
    });
    unawaited(_load());
  }

  Future<void> _showPeriodDetails(HrRosterPeriodDetails details) async {
    await showHrRosterPeriodDetailsDialog(context, details: details);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final (DateTime from, DateTime to) = _range;
    final String periodLabel = _periodHeader(l10n, locale, from, to);

    return AppAccessGate(
      requirement: SettingsRostersAtomPermissions.tab,
      child: AppCollapsibleSection(
        title: l10n.settingsRostersSectionTitle,
        description: l10n.settingsRostersSectionBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              periodLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppFontWeight.emphasis,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.sm,
              runSpacing: theme.spacing.sm,
              children: <Widget>[
                for (final SettingsRosterPeriodPreset preset
                    in SettingsRosterPeriodPreset.values)
                  FilterChip(
                    label: Text(_presetLabel(l10n, preset)),
                    selected: _preset == preset,
                    onSelected: (_) => _selectPreset(preset),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            _buildBody(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return AppStateView(
        variant: AppStateViewVariant.loading,
        title: l10n.settingsRostersLoadingTitle,
        body: l10n.settingsRostersLoadingBody,
      );
    }

    final AppFailure? failure = _failure;
    if (failure != null) {
      if (failure.category == AppFailureCategory.notFound) {
        return AppStateView(
          title: l10n.settingsStaffProfileMissingTitle,
          body: l10n.settingsStaffProfileMissingBody,
          icon: Icons.badge_outlined,
        );
      }
      return AppFailureStateView(
        failure: failure,
        title: l10n.settingsRostersUnavailableTitle,
        onRetry: () => unawaited(_load()),
      );
    }

    if (_shifts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppStateView(
            title: l10n.settingsRostersEmptyTitle,
            body: l10n.settingsRostersEmptyBody,
            icon: Icons.event_available_outlined,
          ),
          if (_days.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.md),
            HrRosterCalendarPreview(
              days: _days,
              onShowDetails: (HrRosterPeriodDetails details) {
                unawaited(_showPeriodDetails(details));
              },
            ),
          ],
        ],
      );
    }

    return HrRosterCalendarPreview(
      days: _days,
      onShowDetails: (HrRosterPeriodDetails details) {
        unawaited(_showPeriodDetails(details));
      },
    );
  }

  String _periodHeader(
    AppLocalizations l10n,
    Locale locale,
    DateTime from,
    DateTime to,
  ) {
    final String fromLabel = AppFormatters.mediumDate(from, locale);
    final String toLabel = AppFormatters.mediumDate(to, locale);
    final String range = fromLabel == toLabel ? fromLabel : '$fromLabel – $toLabel';
    return l10n.settingsRostersPeriodHeader(range);
  }

  String _presetLabel(AppLocalizations l10n, SettingsRosterPeriodPreset preset) {
    return switch (preset) {
      SettingsRosterPeriodPreset.today => l10n.settingsRosterPeriodToday,
      SettingsRosterPeriodPreset.tomorrow => l10n.settingsRosterPeriodTomorrow,
      SettingsRosterPeriodPreset.thisWeek => l10n.settingsRosterPeriodThisWeek,
      SettingsRosterPeriodPreset.thisMonth => l10n.settingsRosterPeriodThisMonth,
      SettingsRosterPeriodPreset.lastMonth => l10n.settingsRosterPeriodLastMonth,
      SettingsRosterPeriodPreset.nextMonth => l10n.settingsRosterPeriodNextMonth,
      SettingsRosterPeriodPreset.nextThreeMonths =>
        l10n.settingsRosterPeriodNextThreeMonths,
      SettingsRosterPeriodPreset.custom => l10n.settingsRosterPeriodCustom,
    };
  }
}
