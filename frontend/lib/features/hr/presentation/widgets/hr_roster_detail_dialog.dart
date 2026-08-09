import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const Map<int, String> _kWeekdayCodes = <int, String>{
  DateTime.monday: 'MON',
  DateTime.tuesday: 'TUE',
  DateTime.wednesday: 'WED',
  DateTime.thursday: 'THU',
  DateTime.friday: 'FRI',
  DateTime.saturday: 'SAT',
  DateTime.sunday: 'SUN',
};

String _rosterStatusLabel(AppLocalizations l10n, String? status) {
  switch ((status ?? '').trim().toUpperCase()) {
    case 'PUBLISHED':
      return l10n.hrRosterStatusCompleted;
    case 'DRAFT':
      return l10n.hrRosterStatusDraft;
    default:
      return (status ?? '').trim().isEmpty
          ? l10n.profileUnknownValue
          : status!;
  }
}

Future<void> showHrRosterDetailDialog(
  BuildContext context,
  WidgetRef ref,
  HrWorkItem item,
) async {
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final String rosterId = item.rosterId ?? item.effectiveId;

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return FutureBuilder<Result<Map<String, Object?>>>(
        future: controller.getRoster(rosterId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<Map<String, Object?>>> snapshot,
            ) {
              final Result<Map<String, Object?>>? result = snapshot.data;
              final Map<String, Object?>? roster = result?.when(
                success: (Map<String, Object?> value) => value,
                failure: (_) => null,
              );
              final AppFailure? failure = result?.when(
                success: (_) => null,
                failure: (AppFailure value) => value,
              );

              return _HrRosterDetailShell(
                item: item,
                roster: roster,
                failure: failure,
                isLoading: snapshot.connectionState != ConnectionState.done,
              );
            },
      );
    },
  );
}

@immutable
final class _RosterStaffRow {
  const _RosterStaffRow({
    required this.staffProfileId,
    this.displayId,
    this.name,
    this.staffNumber,
    this.position,
    this.practitionerType,
    this.staffCategory,
    this.source,
  });

  factory _RosterStaffRow.fromJson(Map<String, Object?> json) {
    return _RosterStaffRow(
      staffProfileId: (json['staff_profile_id'] ?? '').toString(),
      displayId: json['display_id']?.toString(),
      name: json['name']?.toString(),
      staffNumber: json['staff_number']?.toString(),
      position: json['position']?.toString(),
      practitionerType: json['practitioner_type']?.toString(),
      staffCategory: json['staff_category']?.toString(),
      source: json['source']?.toString(),
    );
  }

  final String staffProfileId;
  final String? displayId;
  final String? name;
  final String? staffNumber;
  final String? position;
  final String? practitionerType;
  final String? staffCategory;
  final String? source;

  String get title =>
      (name ?? staffNumber ?? displayId ?? staffProfileId).trim();
}

class _HrRosterDetailShell extends ConsumerStatefulWidget {
  const _HrRosterDetailShell({
    required this.item,
    required this.roster,
    required this.failure,
    required this.isLoading,
  });

  final HrWorkItem item;
  final Map<String, Object?>? roster;
  final AppFailure? failure;
  final bool isLoading;

  @override
  ConsumerState<_HrRosterDetailShell> createState() =>
      _HrRosterDetailShellState();
}

class _HrRosterDetailShellState extends ConsumerState<_HrRosterDetailShell> {
  Map<String, Object?>? _roster;
  bool _busy = false;
  final Set<String> _selectedStaffIds = <String>{};
  final TextEditingController _staffSearchController = TextEditingController();
  String _staffSearchQuery = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _roster = widget.roster;
  }

  @override
  void didUpdateWidget(covariant _HrRosterDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roster != null) {
      _roster = widget.roster;
    }
  }

  @override
  void dispose() {
    _staffSearchController.dispose();
    super.dispose();
  }

  String get _rosterId =>
      widget.item.rosterId ??
      (_roster?['human_friendly_id'] ?? widget.item.effectiveId).toString();

  List<_RosterStaffRow> get _staffRows {
    final Object? raw = _roster?['staff'];
    if (raw is! List) {
      return const <_RosterStaffRow>[];
    }
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) =>
              _RosterStaffRow.fromJson(Map<String, Object?>.from(item)),
        )
        .where((row) => row.staffProfileId.isNotEmpty)
        .toList(growable: false);
  }

  List<_RosterStaffRow> get _visibleStaff {
    final String needle = _staffSearchQuery.trim().toLowerCase();
    return _staffRows.where((_RosterStaffRow row) {
      if (_categoryFilter != null &&
          (_rowCategory(row) != _categoryFilter)) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return <String?>[
        row.name,
        row.staffNumber,
        row.displayId,
        row.position,
        row.practitionerType,
        row.staffCategory,
        row.source,
      ].whereType<String>().any(
        (String value) => value.toLowerCase().contains(needle),
      );
    }).toList(growable: false);
  }

  String? _rowCategory(_RosterStaffRow row) {
    final String raw = (row.staffCategory ?? '').trim().toUpperCase();
    return raw.isEmpty ? null : raw;
  }

  String _informativeName(AppLocalizations l10n) {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final String rawName = (roster['name'] ?? widget.item.rosterName ?? '')
        .toString()
        .trim();
    final String period =
        (roster['period_label'] ?? widget.item.periodLabel ?? '').toString();
    final bool looksLikeDates =
        rawName.isEmpty ||
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(rawName) ||
        rawName == period;
    if (!looksLikeDates) {
      return rawName;
    }
    final String scope =
        (roster['department_name'] ??
                roster['facility_name'] ??
                '')
            .toString()
            .trim();
    final String status = _rosterStatusLabel(
      l10n,
      (roster['status'] ?? widget.item.status)?.toString(),
    );
    return <String?>[
      scope.isEmpty ? null : scope,
      period.isEmpty ? null : period,
      status,
    ].whereType<String>().join(' · ').ifEmpty(l10n.hrRosterDraftTitle);
  }

  Future<void> _reloadRoster() async {
    final Result<Map<String, Object?>> result = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .getRoster(_rosterId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (Map<String, Object?> value) {
        setState(() {
          _roster = value;
          _selectedStaffIds.removeWhere(
            (String id) =>
                !_staffRows.any((row) => row.staffProfileId == id),
          );
        });
      },
      failure: (AppFailure failure) => showHrMutationSnackBar(context, failure),
    );
  }

  Future<void> _showPeriodDetails(_RosterPeriodDetails details) async {
    final AppLocalizations l10n = context.l10n;
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _RosterPeriodDetailsDialog(details: details, l10n: l10n);
      },
    );
  }

  Future<void> _addStaff() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    String? staffProfileId;
    String? staffCategory = 'FULL_TIME';
    final bool? saved = await showAppWorkspaceMutationDialog(
      context: context,
      title: Text(l10n.hrRosterAddStaffAction),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      submitLabel: l10n.hrRosterAddStaffAction,
      cancelLabel: l10n.commonCancelActionLabel,
      submitIcon: Icons.person_add_alt_1_outlined,
      buildFields:
          (
            BuildContext context,
            GlobalKey<FormState> formKey,
            bool _, [
            AppFailure? failure,
          ]) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setLocal) {
                return AppFormSection(
                  children: <Widget>[
                    AppSelectField<String>.searchable(
                      value: staffProfileId,
                      labelText: l10n.hrRosterSelectStaffLabel,
                      isRequired: true,
                      options: hrSelectOptions(
                        state?.referenceData.staffProfiles ??
                            const <HrOption>[],
                      ),
                      validator: AppValidators.requiredValue(
                        l10n.hrFieldRequiredLabel(
                          l10n.hrRosterSelectStaffLabel,
                        ),
                      ),
                      onChanged: (String? value) =>
                          setLocal(() => staffProfileId = value),
                    ),
                    AppSelectField<String>(
                      value: staffCategory,
                      labelText: l10n.hrRosterStaffCategoryLabel,
                      options: _staffCategoryOptions(l10n),
                      onChanged: (String? value) {
                        if (value != null) {
                          setLocal(() => staffCategory = value);
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
      onSubmit: () async {
        if (staffProfileId == null || staffProfileId!.isEmpty) {
          return AppFailure.validation();
        }
        setState(() => _busy = true);
        final Result<Map<String, Object?>> result = await ref
            .read(hrWorkspaceControllerProvider.notifier)
            .attachRosterStaff(
              rosterId: _rosterId,
              staffProfileId: staffProfileId!,
              staffCategory: staffCategory,
            );
        setState(() => _busy = false);
        return result.when(
          success: (Map<String, Object?> value) {
            setState(() => _roster = value);
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    );
    if (saved == true && mounted) {
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _removeStaff(String staffProfileId) async {
    setState(() => _busy = true);
    final Result<Map<String, Object?>> result = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .detachRosterStaff(rosterId: _rosterId, staffProfileId: staffProfileId);
    setState(() => _busy = false);
    result.when(
      success: (Map<String, Object?> value) {
        setState(() {
          _roster = value;
          _selectedStaffIds.remove(staffProfileId);
        });
        showHrMutationSnackBar(context, null);
      },
      failure: (AppFailure failure) => showHrMutationSnackBar(context, failure),
    );
  }

  Future<void> _removeSelected() async {
    if (_selectedStaffIds.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    AppFailure? failure;
    for (final String id in _selectedStaffIds.toList(growable: false)) {
      final Result<Map<String, Object?>> result = await ref
          .read(hrWorkspaceControllerProvider.notifier)
          .detachRosterStaff(rosterId: _rosterId, staffProfileId: id);
      final AppFailure? next = result.when(
        success: (Map<String, Object?> value) {
          _roster = value;
          return null;
        },
        failure: (AppFailure value) => value,
      );
      if (next != null) {
        failure = next;
        break;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _selectedStaffIds.clear();
    });
    showHrMutationSnackBar(context, failure);
  }

  Future<void> _editRoster() async {
    final AppLocalizations l10n = context.l10n;
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final TextEditingController nameController = TextEditingController(
      text: (roster['name'] ?? '').toString(),
    );
    DateTime? periodStart = _parseDate(roster['period_start']) ?? widget.item.startAt;
    DateTime? periodEnd = _parseDate(roster['period_end']) ?? widget.item.endAt;
    String status = (roster['status'] ?? 'DRAFT').toString();
    bool isRecurring = roster['is_recurring'] == true;

    final bool? saved = await showAppWorkspaceMutationDialog(
      context: context,
      title: Text(l10n.hrRosterEditDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      submitLabel: l10n.commonEditActionLabel,
      cancelLabel: l10n.commonCancelActionLabel,
      submitIcon: Icons.save_outlined,
      maxWidth: 720,
      buildFields:
          (
            BuildContext context,
            GlobalKey<FormState> formKey,
            bool _, [
            AppFailure? failure,
          ]) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setLocal) {
                return AppFormSection(
                  children: <Widget>[
                    AppTextField(
                      controller: nameController,
                      labelText: l10n.hrRosterNameLabel,
                      helperText: l10n.hrRosterNameHelper,
                      isRequired: true,
                      validator: AppValidators.requiredText(
                        l10n.hrFieldRequiredLabel(l10n.hrRosterNameLabel),
                      ),
                    ),
                    AppDateField(
                      value: periodStart,
                      labelText: l10n.hrStartDateLabel,
                      isRequired: true,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      currentDate: DateTime.now(),
                      pickerButtonLabel: l10n.hrPickDateAction,
                      invalidDateMessage: l10n.appDateInvalidMessage,
                      onChanged: (DateTime? value) =>
                          setLocal(() => periodStart = value),
                    ),
                    AppDateField(
                      value: periodEnd,
                      labelText: l10n.hrEndDateLabel,
                      isRequired: true,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      currentDate: DateTime.now(),
                      pickerButtonLabel: l10n.hrPickDateAction,
                      invalidDateMessage: l10n.appDateInvalidMessage,
                      onChanged: (DateTime? value) =>
                          setLocal(() => periodEnd = value),
                    ),
                    AppSelectField<String>(
                      value: status,
                      labelText: l10n.hrStatusColumnLabel,
                      options: <AppSelectOption<String>>[
                        AppSelectOption<String>(
                          value: 'DRAFT',
                          label: l10n.hrRosterStatusDraft,
                        ),
                        AppSelectOption<String>(
                          value: 'PUBLISHED',
                          label: l10n.hrRosterStatusCompleted,
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setLocal(() => status = value);
                        }
                      },
                    ),
                    AppSwitchField(
                      value: isRecurring,
                      title: l10n.hrRosterRecurringLabel,
                      onChanged: (bool value) =>
                          setLocal(() => isRecurring = value),
                    ),
                  ],
                );
              },
            );
          },
      onSubmit: () async {
        if (periodStart == null ||
            periodEnd == null ||
            !periodEnd!.isAfter(periodStart!)) {
          return AppFailure.validation(
            detailMessage: l10n.hrFieldRequiredLabel(l10n.hrPeriodColumnLabel),
          );
        }
        final AppFailure? failure = await ref
            .read(hrWorkspaceControllerProvider.notifier)
            .updateRoster(_rosterId, <String, Object?>{
              'name': nameController.text.trim(),
              'period_start': periodStart!.toUtc().toIso8601String(),
              'period_end': periodEnd!.toUtc().toIso8601String(),
              'status': status,
              'is_recurring': isRecurring,
            });
        if (failure == null) {
          await _reloadRoster();
        }
        return failure;
      },
    );
    if (saved == true && mounted) {
      showHrMutationSnackBar(context, null);
    }
  }

  Future<void> _printRoster({bool staffOnly = false}) async {
    final AppLocalizations l10n = context.l10n;
    final Set<String> selected = staffOnly
        ? <String>{'staff'}
        : <String>{'overview', 'staff', 'schedule'};

    if (!staffOnly) {
      final Set<String>? chosen = await showAppDialog<Set<String>>(
        context: context,
        builder: (BuildContext context) {
          return _HrRosterPrintSectionsDialog(initialSelection: selected);
        },
      );
      if (chosen == null || chosen.isEmpty) {
        return;
      }
      selected
        ..clear()
        ..addAll(chosen);
    }

    final String html = _buildPrintHtml(l10n, selected);
    if (!mounted) {
      return;
    }
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: _informativeName(l10n),
      subtitle: _rosterId,
      bodyHtml: html,
      previewDialogTitle: l10n.hrRosterPrintDialogTitle,
    );
  }

  String _buildPrintHtml(AppLocalizations l10n, Set<String> sections) {
    final StringBuffer buffer = StringBuffer();
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    if (sections.contains('overview')) {
      buffer.writeln('<h2>${l10n.hrRosterOverviewSectionTitle}</h2><ul>');
      buffer.writeln(
        '<li><strong>${l10n.hrRosterNameLabel}:</strong> ${_informativeName(l10n)}</li>',
      );
      buffer.writeln(
        '<li><strong>${l10n.hrQueueItemColumnLabel}:</strong> $_rosterId</li>',
      );
      buffer.writeln(
        '<li><strong>${l10n.hrPeriodColumnLabel}:</strong> ${roster['period_label'] ?? widget.item.periodLabel ?? ''}</li>',
      );
      buffer.writeln(
        '<li><strong>${l10n.hrStatusColumnLabel}:</strong> ${_rosterStatusLabel(l10n, roster['status']?.toString())}</li>',
      );
      buffer.writeln('</ul>');
    }
    if (sections.contains('staff')) {
      buffer.writeln('<h2>${l10n.hrRosterAttachedStaffTitle}</h2><table border="1" cellpadding="4" cellspacing="0"><thead><tr>');
      buffer.writeln(
        '<th>${l10n.hrRosterNameLabel}</th><th>${l10n.hrStaffNumberLabel}</th><th>${l10n.hrPositionLabel}</th><th>${l10n.hrRosterStaffCategoryLabel}</th></tr></thead><tbody>',
      );
      for (final _RosterStaffRow row in _staffRows) {
        buffer.writeln(
          '<tr><td>${row.title}</td><td>${row.staffNumber ?? row.displayId ?? ''}</td><td>${row.position ?? ''}</td><td>${_staffCategoryLabel(l10n, row.staffCategory)}</td></tr>',
        );
      }
      buffer.writeln('</tbody></table>');
    }
    if (sections.contains('schedule')) {
      buffer.writeln('<h2>${l10n.hrRosterPreviewSectionTitle}</h2><ul>');
      for (final _RosterDayPreview day in _previewDays()) {
        buffer.writeln(
          '<li>${day.label}: ${day.statusLabel(l10n)}'
          '${day.isHoliday ? ' (${l10n.hrRosterPublicHolidayLabel})' : ''}'
          '${day.shifts.isEmpty ? '' : ' — ${day.shifts.map((_RosterShiftWindow shift) => shift.summary).join('; ')}'}</li>',
        );
      }
      buffer.writeln('</ul>');
    }
    return buffer.toString();
  }

  List<_RosterDayPreview> _previewDays() {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final DateTime? start = _parseDate(roster['period_start']) ?? widget.item.startAt;
    final DateTime? end = _parseDate(roster['period_end']) ?? widget.item.endAt;
    if (start == null || end == null) {
      return const <_RosterDayPreview>[];
    }
    final Map<String, Object?> constraints = _map(roster['constraints']);
    final Set<String> working = <String>{
      for (final Object? day in (constraints['working_days'] as List?) ??
          <Object?>['MON', 'TUE', 'WED', 'THU', 'FRI'])
        day.toString().toUpperCase(),
    };
    final Set<String> holidays = <String>{
      for (final Object? day
          in (constraints['public_holidays'] as List?) ?? const <Object?>[])
        day.toString(),
    };
    final bool respectHolidays = constraints['respect_public_holidays'] != false;
    final (int startHour, int startMinute) = _parseHourMinute(
      constraints['default_start_time']?.toString(),
      8,
      0,
    );
    final (int endHour, int endMinute) = _parseHourMinute(
      constraints['default_end_time']?.toString(),
      17,
      0,
    );
    final int dayStartMinutes = startHour * 60 + startMinute;
    final int dayEndMinutes = _dayEndMinutesSafe(
      dayStartMinutes,
      endHour * 60 + endMinute,
    );

    final Map<String, List<_RosterShiftWindow>> shiftsByDay =
        <String, List<_RosterShiftWindow>>{};
    for (final Object? shiftRaw
        in (roster['shifts'] as List?) ?? const <Object?>[]) {
      if (shiftRaw is! Map) {
        continue;
      }
      final Map<String, Object?> shift = Map<String, Object?>.from(shiftRaw);
      final DateTime? shiftStart = _parseDate(shift['start_time']);
      final DateTime? shiftEnd = _parseDate(shift['end_time']);
      if (shiftStart == null || shiftEnd == null) {
        continue;
      }
      final String key = _dateKey(shiftStart);
      final List<String> names = <String>[];
      for (final Object? assignmentRaw
          in (shift['assignments'] as List?) ?? const <Object?>[]) {
        if (assignmentRaw is! Map) {
          continue;
        }
        final Map<String, Object?> assignment = Map<String, Object?>.from(
          assignmentRaw,
        );
        final Map<String, Object?> profile = _map(assignment['staff_profile']);
        final Map<String, Object?> user = _map(profile['user']);
        final Map<String, Object?> userProfile = _map(user['profile']);
        final String name =
            <String?>[
                  userProfile['first_name']?.toString(),
                  userProfile['last_name']?.toString(),
                ]
                .whereType<String>()
                .where((String part) => part.trim().isNotEmpty)
                .join(' ')
                .ifEmpty(
                  profile['staff_number']?.toString() ??
                      profile['human_friendly_id']?.toString() ??
                      '',
                );
        if (name.isNotEmpty) {
          names.add(name);
        }
      }
      shiftsByDay
          .putIfAbsent(key, () => <_RosterShiftWindow>[])
          .add(
            _RosterShiftWindow(
              start: shiftStart,
              end: shiftEnd,
              staffNames: names,
              shiftType: shift['shift_type']?.toString(),
            ),
          );
    }

    final List<_RosterDayPreview> days = <_RosterDayPreview>[];
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final DateTime last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      final String key = _dateKey(cursor);
      final String code = _kWeekdayCodes[cursor.weekday] ?? 'MON';
      final bool holiday = holidays.contains(key);
      final bool treatedAsHoliday = respectHolidays && holiday;
      final bool workingDay = working.contains(code);
      final List<_RosterShiftWindow> dayShifts =
          List<_RosterShiftWindow>.from(
            shiftsByDay[key] ?? const <_RosterShiftWindow>[],
          )..sort(
            (_RosterShiftWindow a, _RosterShiftWindow b) =>
                a.start.compareTo(b.start),
          );
      days.add(
        _RosterDayPreview(
          date: cursor,
          label: key,
          isHoliday: holiday,
          isWorkingDay: workingDay && !treatedAsHoliday,
          dayStartMinutes: dayStartMinutes,
          dayEndMinutes: dayEndMinutes,
          shifts: dayShifts,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<_RosterStaffRow> visible = _visibleStaff;
    final bool allSelected =
        visible.isNotEmpty &&
        visible.every(
          (_RosterStaffRow row) =>
              _selectedStaffIds.contains(row.staffProfileId),
        );
    final bool noneSelected = visible.every(
      (_RosterStaffRow row) => !_selectedStaffIds.contains(row.staffProfileId),
    );

    return AppDialog(
      title: Text(l10n.hrRosterDetailDialogTitle),
      icon: const Icon(Icons.calendar_month_outlined),
      scrollable: true,
      maxWidth: 1100,
      content: widget.isLoading && _roster == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.failure != null && _roster == null)
                  Text(
                    widget.failure!.detailMessage ?? widget.failure!.messageKey,
                  )
                else ...<Widget>[
                  AppCollapsibleSection(
                    title: l10n.hrRosterOverviewSectionTitle,
                    titleIcon: Icons.info_outline,
                    child: AppInfoSheetGrid(
                      emptyValue: l10n.profileUnknownValue,
                      spacing: theme.spacing.lg,
                      runSpacing: theme.spacing.sm,
                      items: _overviewItems(l10n),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppCollapsibleSection(
                    title: l10n.hrRosterPreviewSectionTitle,
                    titleIcon: Icons.calendar_month_outlined,
                    child: _previewDays().isEmpty
                        ? Text(l10n.hrRosterNoSchedulePreviewLabel)
                        : _RosterCalendarPreview(
                            days: _previewDays(),
                            onShowDetails: _showPeriodDetails,
                          ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  AppCollapsibleSection(
                    title: l10n.hrRosterAttachedStaffTitle,
                    titleIcon: Icons.groups_outlined,
                    headerActions: <Widget>[
                      _RosterCountChip(
                        count: _staffRows.length,
                        labeledCount: l10n.hrRosterAssignedStaffCountChip(
                          _staffRows.length,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: Checkbox(
                          tristate: true,
                          value: allSelected
                              ? true
                              : noneSelected
                              ? false
                              : null,
                          onChanged: _busy || visible.isEmpty
                              ? null
                              : (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStaffIds.addAll(
                                        visible.map(
                                          (_RosterStaffRow row) =>
                                              row.staffProfileId,
                                        ),
                                      );
                                    } else {
                                      for (final _RosterStaffRow row
                                          in visible) {
                                        _selectedStaffIds.remove(
                                          row.staffProfileId,
                                        );
                                      }
                                    }
                                  });
                                },
                        ),
                      ),
                      AppAccessActionGate(
                        requirement: HrShiftsAtomPermissions.write,
                        builder: (BuildContext context, bool isAllowed) {
                          return AppButton.tertiary(
                            leadingIcon: Icons.person_remove_outlined,
                            label: l10n.hrRosterRemoveSelectedStaffAction,
                            tooltip: l10n.hrRosterRemoveSelectedStaffAction,
                            color: theme.colorScheme.error,
                            enabled:
                                isAllowed &&
                                !_busy &&
                                _selectedStaffIds.isNotEmpty,
                            onPressed:
                                !isAllowed ||
                                    _busy ||
                                    _selectedStaffIds.isEmpty
                                ? null
                                : _removeSelected,
                          );
                        },
                      ),
                      AppAccessActionGate(
                        requirement: HrShiftsAtomPermissions.write,
                        builder: (BuildContext context, bool isAllowed) {
                          return AppButton.secondary(
                            leadingIcon: Icons.person_add_alt_1_outlined,
                            label: l10n.hrRosterAddStaffAction,
                            tooltip: l10n.hrRosterAddStaffAction,
                            enabled: isAllowed && !_busy,
                            onPressed: !isAllowed || _busy ? null : _addStaff,
                          );
                        },
                      ),
                    ],
                    child: SizedBox(
                      height: 420,
                      child: AppListTable<_RosterStaffRow>(
                        page: AppPage<_RosterStaffRow>(
                          items: visible,
                          request: AppPageRequest(
                            pageSize: visible.isEmpty ? 20 : visible.length,
                          ),
                          totalItemCount: visible.length,
                        ),
                        enableExport: true,
                        columnVisibilityStorageKey: 'hr_roster_assigned_staff_v1',
                        columnVisibilityLabel:
                            l10n.commonTableSettingsActionLabel,
                        search: AppListTableSearch<_RosterStaffRow>(
                          controller: _staffSearchController,
                          semanticLabel: l10n.hrSearchLabel,
                          hintText: l10n.hrSearchHint,
                          clearLabel: l10n.hrClearFiltersAction,
                          matcher: (_RosterStaffRow row, String query) => true,
                          onSubmitted: (String value) =>
                              setState(() => _staffSearchQuery = value),
                          onClear: () => setState(() {
                            _staffSearchQuery = '';
                            _categoryFilter = null;
                          }),
                          showAdvancedFilterButton: true,
                          advancedFilterButtonLabel:
                              l10n.commonFiltersActionLabel,
                          advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
                          advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                          advancedFilterResetLabel: l10n.hrClearFiltersAction,
                          allFieldsLabel: l10n.opdAllFieldsFilterLabel,
                          filterGroups: <AppSearchBarFilterGroup>[
                            AppSearchBarFilterGroup(
                              key: 'category',
                              label: l10n.hrRosterStaffCategoryLabel,
                              allLabel: l10n.opdAllFieldsFilterLabel,
                              choices: <AppSearchBarFilterChoice>[
                                for (final AppSelectOption<String> option
                                    in _staffCategoryOptions(l10n))
                                  AppSearchBarFilterChoice(
                                    value: option.value,
                                    label: option.label,
                                  ),
                              ],
                            ),
                          ],
                          filterValue: AppSearchBarFilterValue(
                            options: <String, String>{
                              if (_categoryFilter != null)
                                'category': _categoryFilter!,
                            },
                          ),
                          onFilterChanged: (AppSearchBarFilterValue value) {
                            setState(() {
                              _categoryFilter = value.option('category');
                            });
                          },
                          trailingActions: <AppSearchBarAction>[
                            AppSearchBarAction(
                              icon: Icons.print_outlined,
                              label: l10n.hrRosterPrintStaffTableAction,
                              tooltip: l10n.hrRosterPrintStaffTableAction,
                              onPressed: () => _printRoster(staffOnly: true),
                            ),
                          ],
                        ),
                        columns: _staffColumns(l10n),
                        emptyBuilder: (_) => Text(l10n.hrRosterNoStaffLabel),
                        mobileItemBuilder:
                            (BuildContext context, _RosterStaffRow row) {
                              return AppListTableMobileItem(
                                title: row.title,
                                caption:
                                    row.staffNumber ??
                                    row.displayId ??
                                    row.staffProfileId,
                                meta: <AppListTableMobileMeta>[
                                  if ((row.staffCategory ?? '').isNotEmpty)
                                    AppListTableMobileMeta(
                                      label: _staffCategoryLabel(
                                        l10n,
                                        row.staffCategory,
                                      ),
                                    ),
                                ],
                              );
                            },
                      ),
                    ),
                  ),
                ],
              ],
            ),
      actions: <Widget>[
        AppAccessActionGate(
          requirement: HrShiftsAtomPermissions.write,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.secondary(
              leadingIcon: Icons.edit_outlined,
              label: l10n.commonEditActionLabel,
              tooltip: l10n.commonEditActionLabel,
              enabled: isAllowed && !_busy && _roster != null,
              onPressed: !isAllowed || _busy || _roster == null
                  ? null
                  : _editRoster,
            );
          },
        ),
        AppButton.secondary(
          leadingIcon: Icons.print_outlined,
          label: l10n.commonPrintActionLabel,
          tooltip: l10n.commonPrintActionLabel,
          enabled: _roster != null && !_busy,
          onPressed: _roster == null || _busy ? null : () => _printRoster(),
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  List<AppInfoSheetItem> _overviewItems(AppLocalizations l10n) {
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    return <AppInfoSheetItem>[
      AppInfoSheetItem(
        label: l10n.hrRosterNameLabel,
        value: _informativeName(l10n),
      ),
      AppInfoSheetItem(
        label: l10n.hrQueueItemColumnLabel,
        value: _rosterId,
        copyable: true,
      ),
      AppInfoSheetItem(
        label: l10n.hrPeriodColumnLabel,
        value:
            (roster['period_label'] ?? widget.item.periodLabel)?.toString() ??
            '',
      ),
      AppInfoSheetItem(
        label: l10n.hrRosterRecurringLabel,
        value: (roster['is_recurring'] == true || widget.item.isRecurring)
            ? l10n.commonYesLabel
            : l10n.commonNoLabel,
      ),
      AppInfoSheetItem(
        label: l10n.hrStatusColumnLabel,
        value: _rosterStatusLabel(
          l10n,
          (roster['status'] ?? widget.item.status)?.toString(),
        ),
      ),
      AppInfoSheetItem(
        label: l10n.hrAssignmentsSectionTitle,
        value: _staffRows.length.toString(),
      ),
      if ((roster['facility_name'] ?? '').toString().trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrDepartmentLabel,
          value: roster['facility_name']?.toString(),
        ),
      if ((roster['department_name'] ?? '').toString().trim().isNotEmpty)
        AppInfoSheetItem(
          label: l10n.hrDepartmentLabel,
          value: roster['department_name']?.toString(),
        ),
    ];
  }

  List<AppListTableColumn<_RosterStaffRow>> _staffColumns(
    AppLocalizations l10n,
  ) {
    return <AppListTableColumn<_RosterStaffRow>>[
      AppListTableColumn<_RosterStaffRow>(
        id: 'select',
        label: l10n.hrRosterSelectAllStaffAction,
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final bool selected = _selectedStaffIds.contains(row.staffProfileId);
          return Checkbox(
            value: selected,
            onChanged: _busy
                ? null
                : (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedStaffIds.add(row.staffProfileId);
                      } else {
                        _selectedStaffIds.remove(row.staffProfileId);
                      }
                    });
                  },
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'name',
        label: l10n.hrRosterNameLabel,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.title, right.title),
        cellBuilder: (BuildContext context, _RosterStaffRow row) =>
            Text(row.title),
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'staff_number',
        label: l10n.hrStaffNumberLabel,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(
              left.staffNumber ?? left.displayId,
              right.staffNumber ?? right.displayId,
            ),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          return AppCopyableIdentifierCell(
            title: row.staffNumber ?? row.displayId ?? row.staffProfileId,
            identifier: row.displayId ?? row.staffProfileId,
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'position',
        label: l10n.hrPositionLabel,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.position, right.position),
        cellBuilder: (BuildContext context, _RosterStaffRow row) => Text(
          (row.position ?? '').ifEmpty(context.l10n.profileUnknownValue),
        ),
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'practitioner_type',
        label: l10n.hrPractitionerTypeLabel,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(
              left.practitionerType,
              right.practitionerType,
            ),
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          final String value = (row.practitionerType ?? '').trim();
          return Text(
            value.isEmpty
                ? context.l10n.profileUnknownValue
                : context.l10n.hrReferencePractitionerTypeLabel(
                    value,
                    fallback: value,
                  ),
          );
        },
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'category',
        label: l10n.hrRosterStaffCategoryLabel,
        sortComparator: (_RosterStaffRow left, _RosterStaffRow right) =>
            appListTableCompareText(left.staffCategory, right.staffCategory),
        cellBuilder: (BuildContext context, _RosterStaffRow row) => Text(
          _staffCategoryLabel(context.l10n, row.staffCategory),
        ),
      ),
      AppListTableColumn<_RosterStaffRow>(
        id: 'actions',
        label: l10n.patientsQuickActionsTitle,
        alwaysVisible: true,
        cellBuilder: (BuildContext context, _RosterStaffRow row) {
          return AppAccessActionGate(
            requirement: HrShiftsAtomPermissions.write,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.tertiary(
                leadingIcon: Icons.person_remove_outlined,
                label: l10n.hrRosterRemoveStaffAction,
                tooltip: l10n.hrRosterRemoveStaffAction,
                color: Theme.of(context).colorScheme.error,
                enabled: isAllowed && !_busy,
                onPressed: !isAllowed || _busy
                    ? null
                    : () => _removeStaff(row.staffProfileId),
              );
            },
          );
        },
      ),
    ];
  }
}

class _RosterCountChip extends StatelessWidget {
  const _RosterCountChip({required this.count, required this.labeledCount});

  final int count;
  final String labeledCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppActionLabelScope? labelScope = AppActionLabelScope.maybeOf(
      context,
    );
    final bool showLabel =
        labelScope?.forceIconOnly != true && (labelScope?.showLabels ?? true);

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Chip(
        avatar: Icon(
          Icons.format_list_numbered_outlined,
          size: 16,
          color: colorScheme.primary,
        ),
        label: Text(showLabel ? labeledCount : '$count'),
        backgroundColor: colorScheme.primaryContainer,
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelSmall,
      ),
    );
  }
}

enum _RosterDayTone { holiday, off, busy, free, mixed }

class _RosterMinuteRange {
  const _RosterMinuteRange({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;

  String get label =>
      '${_formatMinutes(startMinutes)}–${_formatMinutes(endMinutes)}';
}

class _RosterShiftWindow {
  const _RosterShiftWindow({
    required this.start,
    required this.end,
    required this.staffNames,
    this.shiftType,
  });

  final DateTime start;
  final DateTime end;
  final List<String> staffNames;
  final String? shiftType;

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes {
    final int raw = end.hour * 60 + end.minute;
    return raw <= startMinutes ? raw + (24 * 60) : raw;
  }

  String get summary {
    final String staff = staffNames.isEmpty ? '' : ' (${staffNames.join(', ')})';
    return '${_formatHm(start)}–${_formatHm(end)}$staff';
  }
}

class _RosterDayPreview {
  const _RosterDayPreview({
    required this.date,
    required this.label,
    required this.isHoliday,
    required this.isWorkingDay,
    required this.dayStartMinutes,
    required this.dayEndMinutes,
    required this.shifts,
  });

  final DateTime date;
  final String label;
  final bool isHoliday;
  final bool isWorkingDay;
  final int dayStartMinutes;
  final int dayEndMinutes;
  final List<_RosterShiftWindow> shifts;

  List<_RosterMinuteRange> get busyRanges {
    if (!isWorkingDay) {
      return const <_RosterMinuteRange>[];
    }
    final List<_RosterMinuteRange> ranges = <_RosterMinuteRange>[];
    for (final _RosterShiftWindow shift in shifts) {
      final int start = shift.startMinutes.clamp(dayStartMinutes, dayEndMinutes);
      final int end = shift.endMinutes.clamp(dayStartMinutes, dayEndMinutes);
      if (end > start) {
        ranges.add(_RosterMinuteRange(startMinutes: start, endMinutes: end));
      }
    }
    return _mergeRanges(ranges);
  }

  List<_RosterMinuteRange> get freeRanges {
    if (!isWorkingDay) {
      return const <_RosterMinuteRange>[];
    }
    final List<_RosterMinuteRange> busy = busyRanges;
    if (busy.isEmpty) {
      return <_RosterMinuteRange>[
        _RosterMinuteRange(
          startMinutes: dayStartMinutes,
          endMinutes: dayEndMinutes,
        ),
      ];
    }
    final List<_RosterMinuteRange> free = <_RosterMinuteRange>[];
    int cursor = dayStartMinutes;
    for (final _RosterMinuteRange range in busy) {
      if (range.startMinutes > cursor) {
        free.add(
          _RosterMinuteRange(
            startMinutes: cursor,
            endMinutes: range.startMinutes,
          ),
        );
      }
      cursor = range.endMinutes > cursor ? range.endMinutes : cursor;
    }
    if (cursor < dayEndMinutes) {
      free.add(
        _RosterMinuteRange(startMinutes: cursor, endMinutes: dayEndMinutes),
      );
    }
    return free;
  }

  _RosterDayTone get tone {
    if (isHoliday) {
      return _RosterDayTone.holiday;
    }
    if (!isWorkingDay) {
      return _RosterDayTone.off;
    }
    if (shifts.isEmpty) {
      return _RosterDayTone.free;
    }
    if (freeRanges.isEmpty) {
      return _RosterDayTone.busy;
    }
    return _RosterDayTone.mixed;
  }

  String statusLabel(AppLocalizations l10n) {
    if (isHoliday) {
      return l10n.hrRosterPublicHolidayLabel;
    }
    if (!isWorkingDay) {
      return l10n.hrRosterDayOffLabel;
    }
    if (shifts.isEmpty) {
      return l10n.hrRosterUnassignedDayLabel;
    }
    if (freeRanges.isEmpty) {
      return l10n.hrRosterAvailableLabel;
    }
    return '${l10n.hrRosterAvailableLabel} / ${l10n.hrRosterFreeHoursLabel}';
  }

  List<String> get staffNames {
    final Set<String> names = <String>{};
    for (final _RosterShiftWindow shift in shifts) {
      names.addAll(shift.staffNames);
    }
    return names.toList(growable: false);
  }
}

enum _RosterPreviewMode { month, week, day }

enum _RosterPeriodScope { day, week, month }

class _RosterPeriodDetails {
  const _RosterPeriodDetails({
    required this.scope,
    required this.days,
    required this.focus,
  });

  final _RosterPeriodScope scope;
  final List<_RosterDayPreview> days;
  final DateTime focus;
}

class _RosterCalendarPreview extends StatefulWidget {
  const _RosterCalendarPreview({
    required this.days,
    required this.onShowDetails,
  });

  final List<_RosterDayPreview> days;
  final ValueChanged<_RosterPeriodDetails> onShowDetails;

  @override
  State<_RosterCalendarPreview> createState() => _RosterCalendarPreviewState();
}

class _RosterCalendarPreviewState extends State<_RosterCalendarPreview> {
  _RosterPreviewMode _mode = _RosterPreviewMode.month;
  late DateTime _focus;

  @override
  void initState() {
    super.initState();
    _focus = _dateOnly(widget.days.first.date);
  }

  @override
  void didUpdateWidget(covariant _RosterCalendarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days.isEmpty && widget.days.isNotEmpty) {
      _focus = _dateOnly(widget.days.first.date);
    }
  }

  Map<String, _RosterDayPreview> get _byKey => <String, _RosterDayPreview>{
    for (final _RosterDayPreview day in widget.days) day.label: day,
  };

  DateTime get _periodStart => _dateOnly(widget.days.first.date);
  DateTime get _periodEnd => _dateOnly(widget.days.last.date);

  void _shiftFocus(int months, int weeks, int days) {
    setState(() {
      if (months != 0) {
        _focus = DateTime(_focus.year, _focus.month + months, 1);
      } else if (weeks != 0) {
        _focus = _focus.add(Duration(days: 7 * weeks));
      } else {
        _focus = _focus.add(Duration(days: days));
      }
    });
  }

  void _jumpToRosterPeriod() {
    setState(() => _focus = _periodStart);
  }

  List<_RosterDayPreview> _daysInRange(DateTime start, DateTime end) {
    return widget.days
        .where(
          (_RosterDayPreview day) =>
              !day.date.isBefore(start) && !day.date.isAfter(end),
        )
        .toList(growable: false);
  }

  void _openDay(_RosterDayPreview day) {
    setState(() {
      _focus = _dateOnly(day.date);
      _mode = _RosterPreviewMode.day;
    });
    widget.onShowDetails(
      _RosterPeriodDetails(
        scope: _RosterPeriodScope.day,
        days: <_RosterDayPreview>[day],
        focus: day.date,
      ),
    );
  }

  void _openWeekSummary() {
    final DateTime weekStart = _weekStart(_focus);
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    widget.onShowDetails(
      _RosterPeriodDetails(
        scope: _RosterPeriodScope.week,
        days: _daysInRange(weekStart, weekEnd),
        focus: _focus,
      ),
    );
  }

  void _openMonthSummary() {
    final DateTime monthStart = DateTime(_focus.year, _focus.month, 1);
    final DateTime monthEnd = DateTime(_focus.year, _focus.month + 1, 0);
    widget.onShowDetails(
      _RosterPeriodDetails(
        scope: _RosterPeriodScope.month,
        days: _daysInRange(monthStart, monthEnd),
        focus: _focus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations materials = MaterialLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        final double maxBoardHeight = compact ? 320 : 380;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _RosterPreviewToolbar(
                  compact: compact,
                  mode: _mode,
                  title: _headerTitle(materials, l10n),
                  subtitle: _headerSubtitle(l10n),
                  onModeChanged: (_RosterPreviewMode mode) {
                    setState(() => _mode = mode);
                  },
                  onPrevious: () {
                    switch (_mode) {
                      case _RosterPreviewMode.month:
                        _shiftFocus(-1, 0, 0);
                      case _RosterPreviewMode.week:
                        _shiftFocus(0, -1, 0);
                      case _RosterPreviewMode.day:
                        _shiftFocus(0, 0, -1);
                    }
                  },
                  onNext: () {
                    switch (_mode) {
                      case _RosterPreviewMode.month:
                        _shiftFocus(1, 0, 0);
                      case _RosterPreviewMode.week:
                        _shiftFocus(0, 1, 0);
                      case _RosterPreviewMode.day:
                        _shiftFocus(0, 0, 1);
                    }
                  },
                  onJumpToPeriod: _jumpToRosterPeriod,
                  onMonthSummary: _openMonthSummary,
                  onWeekSummary: _openWeekSummary,
                ),
                SizedBox(height: theme.spacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxBoardHeight),
                  child: SingleChildScrollView(
                    child: switch (_mode) {
                      _RosterPreviewMode.month => _RosterMonthBoard(
                        focus: _focus,
                        byKey: _byKey,
                        periodStart: _periodStart,
                        periodEnd: _periodEnd,
                        compact: compact,
                        onDayTap: _openDay,
                      ),
                      _RosterPreviewMode.week => _RosterWeekBoard(
                        focus: _focus,
                        byKey: _byKey,
                        periodStart: _periodStart,
                        periodEnd: _periodEnd,
                        compact: compact,
                        onDayTap: _openDay,
                      ),
                      _RosterPreviewMode.day => _RosterDayBoard(
                        focus: _focus,
                        day: _byKey[_dateKey(_focus)],
                        inPeriod: !_focus.isBefore(_periodStart) &&
                            !_focus.isAfter(_periodEnd),
                        compact: compact,
                      ),
                    },
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                Text(
                  l10n.hrRosterPreviewTapHint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    _RosterLegendSwatch(
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      label: l10n.hrRosterAvailableLabel,
                    ),
                    _RosterLegendSwatch(
                      color: theme.colorScheme.tertiaryContainer,
                      label: l10n.hrRosterFreeHoursLabel,
                    ),
                    _RosterLegendSwatch(
                      color: theme.colorScheme.secondaryContainer,
                      label: l10n.hrRosterPublicHolidayLabel,
                    ),
                    _RosterLegendSwatch(
                      color: theme.colorScheme.surfaceContainerHighest,
                      label: l10n.hrRosterDayOffLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _headerTitle(MaterialLocalizations materials, AppLocalizations l10n) {
    return switch (_mode) {
      _RosterPreviewMode.month => materials.formatMonthYear(_focus),
      _RosterPreviewMode.week => _weekRangeLabel(materials, _focus),
      _RosterPreviewMode.day => materials.formatFullDate(_focus),
    };
  }

  String _headerSubtitle(AppLocalizations l10n) {
    return '${l10n.hrRosterPreviewSectionTitle}: ${_periodStart.labelYmd} – ${_periodEnd.labelYmd}';
  }
}

class _RosterPreviewToolbar extends StatelessWidget {
  const _RosterPreviewToolbar({
    required this.compact,
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onJumpToPeriod,
    required this.onMonthSummary,
    required this.onWeekSummary,
  });

  final bool compact;
  final _RosterPreviewMode mode;
  final String title;
  final String subtitle;
  final ValueChanged<_RosterPreviewMode> onModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToPeriod;
  final VoidCallback onMonthSummary;
  final VoidCallback onWeekSummary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final Widget modeToggle = SegmentedButton<_RosterPreviewMode>(
      segments: <ButtonSegment<_RosterPreviewMode>>[
        ButtonSegment<_RosterPreviewMode>(
          value: _RosterPreviewMode.month,
          label: compact ? null : Text(l10n.hrRosterPreviewMonthView),
          icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
          tooltip: l10n.hrRosterPreviewMonthView,
        ),
        ButtonSegment<_RosterPreviewMode>(
          value: _RosterPreviewMode.week,
          label: compact ? null : Text(l10n.hrRosterPreviewWeekView),
          icon: const Icon(Icons.view_week_outlined, size: 18),
          tooltip: l10n.hrRosterPreviewWeekView,
        ),
        ButtonSegment<_RosterPreviewMode>(
          value: _RosterPreviewMode.day,
          label: compact ? null : Text(l10n.hrRosterPreviewDayView),
          icon: const Icon(Icons.view_day_outlined, size: 18),
          tooltip: l10n.hrRosterPreviewDayView,
        ),
      ],
      selected: <_RosterPreviewMode>{mode},
      onSelectionChanged: (Set<_RosterPreviewMode> next) {
        if (next.isNotEmpty) {
          onModeChanged(next.first);
        }
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    final Widget nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.hrRosterPreviewPreviousAction,
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: l10n.hrRosterPreviewNextAction,
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final List<Widget> actions = <Widget>[
      AppButton.tertiary(
        leadingIcon: Icons.event_available_outlined,
        label: l10n.hrRosterPreviewJumpToPeriodAction,
        tooltip: l10n.hrRosterPreviewJumpToPeriodAction,
        onPressed: onJumpToPeriod,
      ),
      if (mode == _RosterPreviewMode.month)
        AppButton.tertiary(
          leadingIcon: Icons.summarize_outlined,
          label: l10n.hrRosterPreviewMonthSummaryAction,
          tooltip: l10n.hrRosterPreviewMonthSummaryAction,
          onPressed: onMonthSummary,
        ),
      if (mode == _RosterPreviewMode.week)
        AppButton.tertiary(
          leadingIcon: Icons.summarize_outlined,
          label: l10n.hrRosterPreviewWeekSummaryAction,
          tooltip: l10n.hrRosterPreviewWeekSummaryAction,
          onPressed: onWeekSummary,
        ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: titleBlock),
              nav,
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          modeToggle,
          SizedBox(height: theme.spacing.xs),
          Wrap(spacing: theme.spacing.xs, children: actions),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: titleBlock),
            modeToggle,
            SizedBox(width: theme.spacing.sm),
            nav,
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(spacing: theme.spacing.xs, runSpacing: theme.spacing.xs, children: actions),
      ],
    );
  }
}

class _RosterMonthBoard extends StatelessWidget {
  const _RosterMonthBoard({
    required this.focus,
    required this.byKey,
    required this.periodStart,
    required this.periodEnd,
    required this.compact,
    required this.onDayTap,
  });

  final DateTime focus;
  final Map<String, _RosterDayPreview> byKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool compact;
  final ValueChanged<_RosterDayPreview> onDayTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final DateTime first = DateTime(focus.year, focus.month, 1);
    final DateTime last = DateTime(focus.year, focus.month + 1, 0);
    final int leading = (first.weekday - DateTime.monday) % 7;
    final int trailing = (DateTime.sunday - last.weekday) % 7;
    final int cellCount = leading + last.day + trailing;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final int weekday in const <int>[1, 2, 3, 4, 5, 6, 7])
              Expanded(
                child: Text(
                  hrDayLabel(l10n, weekday == 7 ? 0 : weekday).substring(0, 2),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: compact ? 0.95 : 1.05,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (index < leading || index >= leading + last.day) {
              return const SizedBox.shrink();
            }
            final DateTime date = DateTime(
              focus.year,
              focus.month,
              index - leading + 1,
            );
            final _RosterDayPreview? day = byKey[_dateKey(date)];
            final bool inPeriod =
                !date.isBefore(periodStart) && !date.isAfter(periodEnd);
            return _RosterCompactDayCell(
              date: date,
              day: day,
              inPeriod: inPeriod,
              dense: true,
              selected: _dateKey(date) == _dateKey(focus),
              onTap: day == null ? null : () => onDayTap(day),
            );
          },
        ),
      ],
    );
  }
}

class _RosterWeekBoard extends StatelessWidget {
  const _RosterWeekBoard({
    required this.focus,
    required this.byKey,
    required this.periodStart,
    required this.periodEnd,
    required this.compact,
    required this.onDayTap,
  });

  final DateTime focus;
  final Map<String, _RosterDayPreview> byKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final bool compact;
  final ValueChanged<_RosterDayPreview> onDayTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime start = _weekStart(focus);
    final List<DateTime> dates = <DateTime>[
      for (int i = 0; i < 7; i++) start.add(Duration(days: i)),
    ];

    if (compact) {
      return Column(
        children: <Widget>[
          for (final DateTime date in dates) ...<Widget>[
            _RosterWeekDayRow(
              date: date,
              day: byKey[_dateKey(date)],
              inPeriod:
                  !date.isBefore(periodStart) && !date.isAfter(periodEnd),
              selected: _dateKey(date) == _dateKey(focus),
              onTap: () {
                final _RosterDayPreview? day = byKey[_dateKey(date)];
                if (day != null) {
                  onDayTap(day);
                }
              },
            ),
            SizedBox(height: theme.spacing.xs),
          ],
        ],
      );
    }

    return SizedBox(
      height: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final DateTime date in dates)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _RosterCompactDayCell(
                  date: date,
                  day: byKey[_dateKey(date)],
                  inPeriod:
                      !date.isBefore(periodStart) && !date.isAfter(periodEnd),
                  dense: false,
                  showWeekday: true,
                  selected: _dateKey(date) == _dateKey(focus),
                  onTap: () {
                    final _RosterDayPreview? day = byKey[_dateKey(date)];
                    if (day != null) {
                      onDayTap(day);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RosterWeekDayRow extends StatelessWidget {
  const _RosterWeekDayRow({
    required this.date,
    required this.day,
    required this.inPeriod,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final _RosterDayPreview? day;
  final bool inPeriod;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final _RosterDayPreview? preview = day;
    final Color bg = _toneColor(theme, preview, inPeriod);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: preview == null ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: theme.colorScheme.primary, width: 1.4)
                : null,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 72,
                child: Text(
                  '${hrDayLabel(l10n, date.weekday == 7 ? 0 : date.weekday).substring(0, 3)} ${date.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: preview == null || !inPeriod
                    ? Text(
                        l10n.hrRosterPeriodOutsideLabel,
                        style: theme.textTheme.labelSmall,
                      )
                    : preview.isWorkingDay
                    ? SizedBox(height: 10, child: _RosterHourBar(day: preview))
                    : Text(
                        preview.statusLabel(l10n),
                        style: theme.textTheme.labelSmall,
                      ),
              ),
              if (preview != null && preview.shifts.isNotEmpty)
                Text(
                  '${preview.shifts.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterDayBoard extends StatelessWidget {
  const _RosterDayBoard({
    required this.focus,
    required this.day,
    required this.inPeriod,
    required this.compact,
  });

  final DateTime focus;
  final _RosterDayPreview? day;
  final bool inPeriod;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    if (!inPeriod || day == null) {
      return Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Text(l10n.hrRosterPeriodOutsideLabel),
      );
    }

    final _RosterDayPreview preview = day!;
    final int start = preview.dayStartMinutes;
    final int end = preview.dayEndMinutes;
    final int span = (end - start).clamp(1, 24 * 60);
    final double height = compact ? 220.0 : 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(preview.statusLabel(l10n)),
            ),
            const Spacer(),
            Text(
              '${_formatMinutes(start)}–${_formatMinutes(end)}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (int m = start; m <= end; m += _max(60, span ~/ 4))
                      Text(
                        _formatMinutes(m > end ? end : m),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ColoredBox(
                          color: theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      for (final _RosterMinuteRange range in preview.busyRanges)
                        Positioned(
                          top: ((range.startMinutes - start) / span) * height,
                          height:
                              ((range.endMinutes - range.startMinutes) / span) *
                              height,
                          left: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.78,
                              ),
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.onPrimary,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (final _RosterShiftWindow shift in preview.shifts)
                        Positioned(
                          top:
                              ((shift.startMinutes.clamp(start, end) - start) /
                                  span) *
                              height +
                              4,
                          left: 10,
                          right: 10,
                          child: Text(
                            shift.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!preview.isWorkingDay)
                        Center(
                          child: Text(
                            preview.statusLabel(l10n),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RosterCompactDayCell extends StatelessWidget {
  const _RosterCompactDayCell({
    required this.date,
    required this.day,
    required this.inPeriod,
    required this.dense,
    required this.selected,
    this.showWeekday = false,
    this.onTap,
  });

  final DateTime date;
  final _RosterDayPreview? day;
  final bool inPeriod;
  final bool dense;
  final bool selected;
  final bool showWeekday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Color bg = _toneColor(theme, day, inPeriod);
    final bool enabled = day != null && onTap != null;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(dense ? 8 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(dense ? 8 : 12),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(dense ? 4 : theme.spacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dense ? 8 : 12),
            border: selected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (showWeekday)
                Text(
                  hrDayLabel(
                    l10n,
                    date.weekday == DateTime.sunday ? 0 : date.weekday,
                  ).substring(0, 3),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: inPeriod
                            ? null
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                      ),
                    ),
                  ),
                  if (day?.isHoliday == true)
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: theme.colorScheme.secondary,
                    ),
                ],
              ),
              if (!dense) SizedBox(height: theme.spacing.xs),
              Expanded(
                child: !inPeriod || day == null
                    ? const SizedBox.shrink()
                    : day!.isWorkingDay
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: dense ? 8 : 14,
                          child: _RosterHourBar(day: day!),
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          day!.isHoliday ? 'H' : '—',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterHourBar extends StatelessWidget {
  const _RosterHourBar({required this.day});

  final _RosterDayPreview day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int span = (day.dayEndMinutes - day.dayStartMinutes).clamp(1, 24 * 60);
    final List<_RosterMinuteRange> busy = day.busyRanges;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.tertiaryContainer.withValues(
                    alpha: 0.9,
                  ),
                ),
              ),
              for (final _RosterMinuteRange range in busy)
                Positioned(
                  left:
                      ((range.startMinutes - day.dayStartMinutes) / span) *
                      constraints.maxWidth,
                  width:
                      ((range.endMinutes - range.startMinutes) / span) *
                      constraints.maxWidth,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RosterLegendSwatch extends StatelessWidget {
  const _RosterLegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        SizedBox(width: theme.spacing.xs),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _RosterPeriodDetailsDialog extends StatelessWidget {
  const _RosterPeriodDetailsDialog({
    required this.details,
    required this.l10n,
  });

  final _RosterPeriodDetails details;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations materials = MaterialLocalizations.of(context);
    final List<_RosterDayPreview> days = details.days;
    final String title = switch (details.scope) {
      _RosterPeriodScope.day => l10n.hrRosterDayDetailsTitle,
      _RosterPeriodScope.week => l10n.hrRosterWeekDetailsTitle,
      _RosterPeriodScope.month => l10n.hrRosterMonthDetailsTitle,
    };
    final String heading = switch (details.scope) {
      _RosterPeriodScope.day when days.isNotEmpty =>
        '${hrDayLabel(l10n, days.first.date.weekday == DateTime.sunday ? 0 : days.first.date.weekday)} · ${days.first.label}',
      _RosterPeriodScope.week => _weekRangeLabel(materials, details.focus),
      _RosterPeriodScope.month => materials.formatMonthYear(details.focus),
      _ => materials.formatFullDate(details.focus),
    };

    final int working = days.where((_RosterDayPreview d) => d.isWorkingDay).length;
    final int busy = days.where((_RosterDayPreview d) => d.shifts.isNotEmpty).length;
    final int holidays = days.where((_RosterDayPreview d) => d.isHoliday).length;
    final Set<String> staff = <String>{
      for (final _RosterDayPreview day in days) ...day.staffNames,
    };

    return AppDialog(
      title: Text(title),
      icon: Icon(switch (details.scope) {
        _RosterPeriodScope.day => Icons.event_note_outlined,
        _RosterPeriodScope.week => Icons.view_week_outlined,
        _RosterPeriodScope.month => Icons.calendar_month_outlined,
      }),
      content: days.isEmpty
          ? Text(l10n.hrRosterPeriodNoDaysLabel)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(heading, style: theme.textTheme.titleMedium),
                SizedBox(height: theme.spacing.sm),
                if (details.scope != _RosterPeriodScope.day) ...<Widget>[
                  Text('${l10n.hrRosterPeriodWorkingDaysLabel}: $working'),
                  Text('${l10n.hrRosterPeriodBusyDaysLabel}: $busy'),
                  Text('${l10n.hrRosterPeriodHolidayDaysLabel}: $holidays'),
                  if (staff.isNotEmpty)
                    Text(
                      '${l10n.hrRosterAttachedStaffTitle}: ${staff.join(', ')}',
                    ),
                  SizedBox(height: theme.spacing.md),
                  for (final _RosterDayPreview day in days)
                    Padding(
                      padding: EdgeInsets.only(bottom: theme.spacing.xs),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 88,
                            child: Text(
                              day.label,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          Expanded(child: Text(day.statusLabel(l10n))),
                          if (day.shifts.isNotEmpty)
                            Text('${day.shifts.length}'),
                        ],
                      ),
                    ),
                ] else ...<Widget>[
                  _RosterDayDetailsBody(day: days.first, l10n: l10n),
                ],
              ],
            ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _RosterDayDetailsBody extends StatelessWidget {
  const _RosterDayDetailsBody({required this.day, required this.l10n});

  final _RosterDayPreview day;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(day.statusLabel(l10n), style: theme.textTheme.bodyMedium),
        if (day.isWorkingDay) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRosterDayWorkingHoursLabel,
            style: theme.textTheme.labelLarge,
          ),
          Text(
            '${_formatMinutes(day.dayStartMinutes)}–${_formatMinutes(day.dayEndMinutes)}',
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRosterDayBusyHoursLabel,
            style: theme.textTheme.labelLarge,
          ),
          if (day.busyRanges.isEmpty)
            Text(l10n.hrRosterDayNoShiftsLabel)
          else
            for (final _RosterMinuteRange range in day.busyRanges)
              Text('• ${range.label}'),
          SizedBox(height: theme.spacing.md),
          Text(
            l10n.hrRosterDayFreeHoursLabel,
            style: theme.textTheme.labelLarge,
          ),
          if (day.freeRanges.isEmpty)
            Text(l10n.hrRosterAvailableLabel)
          else
            for (final _RosterMinuteRange range in day.freeRanges)
              Text('• ${range.label}'),
        ],
        SizedBox(height: theme.spacing.md),
        Text(l10n.hrRosterDayShiftsLabel, style: theme.textTheme.labelLarge),
        if (day.shifts.isEmpty)
          Text(l10n.hrRosterDayNoShiftsLabel)
        else
          for (final _RosterShiftWindow shift in day.shifts) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(
              '${_formatHm(shift.start)}–${_formatHm(shift.end)}'
              '${shift.shiftType == null || shift.shiftType!.isEmpty ? '' : ' · ${hrShiftTypeLabel(l10n, shift.shiftType)}'}',
              style: theme.textTheme.bodyMedium,
            ),
            if (shift.staffNames.isNotEmpty)
              Text(
                shift.staffNames.join(', '),
                style: theme.textTheme.bodySmall,
              ),
          ],
      ],
    );
  }
}

class _HrRosterPrintSectionsDialog extends StatefulWidget {
  const _HrRosterPrintSectionsDialog({required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<_HrRosterPrintSectionsDialog> createState() =>
      _HrRosterPrintSectionsDialogState();
}

class _HrRosterPrintSectionsDialogState
    extends State<_HrRosterPrintSectionsDialog> {
  late Set<String> _selected = Set<String>.from(widget.initialSelection);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.hrRosterPrintDialogTitle),
      icon: const Icon(Icons.print_outlined),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CheckboxListTile(
            value: _selected.contains('overview'),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selected.add('overview');
                } else {
                  _selected.remove('overview');
                }
              });
            },
            title: Text(l10n.hrRosterPrintOverviewSection),
          ),
          CheckboxListTile(
            value: _selected.contains('staff'),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selected.add('staff');
                } else {
                  _selected.remove('staff');
                }
              });
            },
            title: Text(l10n.hrRosterPrintStaffSection),
          ),
          CheckboxListTile(
            value: _selected.contains('schedule'),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selected.add('schedule');
                } else {
                  _selected.remove('schedule');
                }
              });
            },
            title: Text(l10n.hrRosterPrintScheduleSection),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: l10n.commonPrintActionLabel,
          leadingIcon: Icons.print_outlined,
          enabled: _selected.isNotEmpty,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).maybePop(Set<String>.from(_selected)),
        ),
      ],
    );
  }
}

List<AppSelectOption<String>> _staffCategoryOptions(AppLocalizations l10n) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'FULL_TIME',
      label: l10n.hrRosterStaffCategoryFullTime,
    ),
    AppSelectOption<String>(
      value: 'PART_TIME',
      label: l10n.hrRosterStaffCategoryPartTime,
    ),
    AppSelectOption<String>(
      value: 'LOCUM',
      label: l10n.hrRosterStaffCategoryLocum,
    ),
    AppSelectOption<String>(
      value: 'SPECIALIST',
      label: l10n.hrRosterStaffCategorySpecialist,
    ),
    AppSelectOption<String>(
      value: 'CONTRACT',
      label: l10n.hrRosterStaffCategoryContract,
    ),
    AppSelectOption<String>(
      value: 'OTHER',
      label: l10n.hrRosterStaffCategoryOther,
    ),
  ];
}

String _staffCategoryLabel(AppLocalizations l10n, String? raw) {
  return switch ((raw ?? '').trim().toUpperCase()) {
    'FULL_TIME' => l10n.hrRosterStaffCategoryFullTime,
    'PART_TIME' => l10n.hrRosterStaffCategoryPartTime,
    'LOCUM' => l10n.hrRosterStaffCategoryLocum,
    'SPECIALIST' => l10n.hrRosterStaffCategorySpecialist,
    'CONTRACT' => l10n.hrRosterStaffCategoryContract,
    'OTHER' => l10n.hrRosterStaffCategoryOther,
    _ => (raw ?? '').trim().isEmpty ? l10n.profileUnknownValue : raw!,
  };
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

String _dateKey(DateTime value) {
  final DateTime local = value.isUtc ? value.toLocal() : value;
  final String y = local.year.toString().padLeft(4, '0');
  final String m = local.month.toString().padLeft(2, '0');
  final String d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime _dateOnly(DateTime value) {
  final DateTime local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

DateTime _weekStart(DateTime value) {
  final DateTime day = _dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _weekRangeLabel(MaterialLocalizations materials, DateTime focus) {
  final DateTime start = _weekStart(focus);
  final DateTime end = start.add(const Duration(days: 6));
  return '${materials.formatShortDate(start)} – ${materials.formatShortDate(end)}';
}

Color _toneColor(ThemeData theme, _RosterDayPreview? day, bool inPeriod) {
  if (!inPeriod || day == null) {
    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
  }
  return switch (day.tone) {
    _RosterDayTone.holiday => theme.colorScheme.secondaryContainer,
    _RosterDayTone.off => theme.colorScheme.surfaceContainerHighest,
    _RosterDayTone.free => theme.colorScheme.tertiaryContainer.withValues(
      alpha: 0.75,
    ),
    _RosterDayTone.busy => theme.colorScheme.primaryContainer.withValues(
      alpha: 0.9,
    ),
    _RosterDayTone.mixed => theme.colorScheme.surfaceContainerHigh,
  };
}

int _max(int a, int b) => a > b ? a : b;

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

(int, int) _parseHourMinute(String? raw, int fallbackHour, int fallbackMinute) {
  final List<String> parts = (raw ?? '').split(':');
  if (parts.length >= 2) {
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour != null && minute != null) {
      return (hour.clamp(0, 23), minute.clamp(0, 59));
    }
  }
  return (fallbackHour, fallbackMinute);
}

int _dayEndMinutesSafe(int startMinutes, int endMinutes) {
  if (endMinutes > startMinutes) {
    return endMinutes;
  }
  return startMinutes + 60;
}

String _formatMinutes(int minutes) {
  final int normalized = minutes % (24 * 60);
  final int hour = normalized ~/ 60;
  final int minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _formatHm(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

List<_RosterMinuteRange> _mergeRanges(List<_RosterMinuteRange> input) {
  if (input.isEmpty) {
    return const <_RosterMinuteRange>[];
  }
  final List<_RosterMinuteRange> sorted = List<_RosterMinuteRange>.from(input)
    ..sort(
      (_RosterMinuteRange a, _RosterMinuteRange b) =>
          a.startMinutes.compareTo(b.startMinutes),
    );
  final List<_RosterMinuteRange> merged = <_RosterMinuteRange>[sorted.first];
  for (int i = 1; i < sorted.length; i++) {
    final _RosterMinuteRange current = sorted[i];
    final _RosterMinuteRange last = merged.last;
    if (current.startMinutes <= last.endMinutes) {
      merged[merged.length - 1] = _RosterMinuteRange(
        startMinutes: last.startMinutes,
        endMinutes: current.endMinutes > last.endMinutes
            ? current.endMinutes
            : last.endMinutes,
      );
    } else {
      merged.add(current);
    }
  }
  return merged;
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

extension on DateTime {
  String get labelYmd => _dateKey(this);
}
