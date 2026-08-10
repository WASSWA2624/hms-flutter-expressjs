import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_hour_grid.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_similarity_dialog.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const Map<int, String> _kWeekdayCodes = <int, String>{
  1: 'MON',
  2: 'TUE',
  3: 'WED',
  4: 'THU',
  5: 'FRI',
  6: 'SAT',
  0: 'SUN',
};

/// Sentinel for “All departments” (any staff may be attached).
const String _kRosterAllDepartments = '__all_departments__';

String hrRosterStatusLabel(AppLocalizations l10n, String? status) {
  switch ((status ?? '').trim().toUpperCase()) {
    case 'PUBLISHED':
      return l10n.hrRosterStatusCompleted;
    case 'DRAFT':
      return l10n.hrRosterStatusDraft;
    case 'DELETED':
      return l10n.hrRosterStatusDeleted;
    default:
      return (status ?? '').trim().isEmpty
          ? l10n.profileUnknownValue
          : status!;
  }
}

String? _resolveRosterFacilityId(WidgetRef ref, HrWorkspaceState? state) {
  final String? sessionFacilityId = ref
      .read(sessionStateProvider)
      .session
      ?.user
      ?.facilityId
      ?.trim();
  if (sessionFacilityId != null && sessionFacilityId.isNotEmpty) {
    return sessionFacilityId;
  }
  final List<HrOption> facilities =
      state?.referenceData.facilities ?? const <HrOption>[];
  if (facilities.isEmpty) {
    return null;
  }
  return facilities.first.value;
}

({List<String> workingDays, String? defaultStart, String? defaultEnd})
_scheduleLegacyDefaults(HrWeeklyScheduleDraft schedule) {
  final List<String> workingDays = <String>[];
  String? defaultStart;
  String? defaultEnd;
  for (final int day in kHrWeekDayOrder) {
    final List<HrScheduleSlotDraft> slots = schedule.days[day]!.filledSlots;
    if (slots.isEmpty) {
      continue;
    }
    final String? code = _kWeekdayCodes[day];
    if (code != null) {
      workingDays.add(code);
    }
    defaultStart ??= slots.first.start?.format24();
    defaultEnd ??= slots.first.end?.format24();
  }
  return (
    workingDays: workingDays,
    defaultStart: defaultStart,
    defaultEnd: defaultEnd,
  );
}

int _maxDayOfMonthForRoster({
  required bool isRecurring,
  required DateTime? periodStart,
  required DateTime? periodEnd,
}) {
  if (!isRecurring && periodStart != null && periodEnd != null) {
    int maxDay = 28;
    DateTime cursor = DateTime(periodStart.year, periodStart.month);
    final DateTime lastMonth = DateTime(periodEnd.year, periodEnd.month);
    while (!cursor.isAfter(lastMonth)) {
      final int daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
      if (daysInMonth > maxDay) {
        maxDay = daysInMonth;
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return maxDay.clamp(28, 31);
  }
  return 31;
}

Set<int> _allMonthDays(int maxDay) => <int>{
  for (int day = 1; day <= maxDay; day++) day,
};

void _clampMonthDays(Set<int> monthDays, int maxDay) {
  monthDays.removeWhere((int day) => day < 1 || day > maxDay);
}

bool? _monthDaysTriState(Set<int> monthDays, int maxDay) {
  final int selected = monthDays.where((int day) => day <= maxDay).length;
  if (selected <= 0) {
    return false;
  }
  if (selected >= maxDay) {
    return true;
  }
  return null;
}

List<int> _monthDaysForPayload({
  required Set<int> monthDays,
  required bool isRecurring,
  required DateTime? periodStart,
  required DateTime? periodEnd,
}) {
  final List<int> selected = monthDays.toList()..sort();
  if (isRecurring || periodStart == null || periodEnd == null) {
    return selected.where((int day) => day >= 1 && day <= 31).toList();
  }

  // Keep only day numbers that exist in at least one month of the period.
  final Set<int> valid = <int>{};
  DateTime cursor = DateTime(periodStart.year, periodStart.month);
  final DateTime lastMonth = DateTime(periodEnd.year, periodEnd.month);
  while (!cursor.isAfter(lastMonth)) {
    final int daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
    for (final int day in selected) {
      if (day >= 1 && day <= daysInMonth) {
        valid.add(day);
      }
    }
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return valid.toList()..sort();
}

Map<String, Object?> _rosterMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

DateTime? _parseRosterDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  final String raw = (value ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

Set<int> _monthDaysFromConstraints(Map<String, Object?> constraints) {
  final Object? raw = constraints['month_days'];
  if (raw is! List || raw.isEmpty) {
    return _allMonthDays(31);
  }
  final Set<int> days = <int>{};
  for (final Object? entry in raw) {
    final int? day = entry is int
        ? entry
        : int.tryParse(entry?.toString() ?? '');
    if (day != null && day >= 1 && day <= 31) {
      days.add(day);
    }
  }
  return days.isEmpty ? _allMonthDays(31) : days;
}

List<Object?> _listConstraintValue(
  Map<String, Object?> constraints,
  String key,
) {
  final Object? raw = constraints[key];
  if (raw is List) {
    return List<Object?>.from(raw);
  }
  return const <Object?>[];
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final String normalized = (value ?? '').toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

String _rosterDisplayName(Map<String, Object?> roster) {
  final String name = (roster['name'] ?? '').toString().trim();
  if (name.isNotEmpty) {
    return name;
  }
  final String periodLabel = (roster['period_label'] ?? '').toString().trim();
  if (periodLabel.isNotEmpty) {
    return periodLabel;
  }
  final String friendly =
      (roster['human_friendly_id'] ?? roster['display_id'] ?? '')
          .toString()
          .trim();
  return friendly;
}

String _resolveDepartmentOptionValue({
  required Map<String, Object?> roster,
  required List<HrOption> departments,
}) {
  final Map<String, Object?> nested = _rosterMap(roster['department']);
  final List<String> candidates = <String>[
    for (final Object? value in <Object?>[
      nested['human_friendly_id'],
      nested['display_id'],
      nested['id'],
      roster['department_display_id'],
      roster['department_id'],
    ])
      if ((value?.toString().trim().isNotEmpty ?? false))
        value!.toString().trim(),
  ];
  if (candidates.isEmpty) {
    return _kRosterAllDepartments;
  }

  for (final String candidate in candidates) {
    for (final HrOption option in departments) {
      final String extraId = (option.extra['entity_id'] ?? option.extra['id'] ?? '')
          .toString()
          .trim();
      if (option.value == candidate ||
          (option.displayId?.trim() == candidate) ||
          (extraId.isNotEmpty && extraId == candidate)) {
        return option.value;
      }
    }
  }

  // Prefer public/friendly identifiers when options are not yet loaded.
  return candidates.first;
}

Future<bool> showHrCreateRosterDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showHrRosterTemplateDialog(context, ref);
}

Future<bool> showHrEditRosterDialog(
  BuildContext context,
  WidgetRef ref, {
  required String rosterId,
  required Map<String, Object?> roster,
}) async {
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  Map<String, Object?> existing = Map<String, Object?>.from(roster);
  final Result<Map<String, Object?>> fresh = await controller.getRoster(rosterId);
  fresh.when(
    success: (Map<String, Object?> value) {
      existing = <String, Object?>{...existing, ...value};
    },
    failure: (_) {},
  );
  if (!context.mounted) {
    return false;
  }
  return showHrRosterTemplateDialog(
    context,
    ref,
    rosterId: rosterId,
    existingRoster: existing,
  );
}

Future<bool> showHrRosterTemplateDialog(
  BuildContext context,
  WidgetRef ref, {
  String? rosterId,
  Map<String, Object?>? existingRoster,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool isEdit = rosterId != null && rosterId.trim().isNotEmpty;
  final Map<String, Object?> existing = existingRoster ?? <String, Object?>{};
  final Map<String, Object?> existingConstraints = _rosterMap(
    existing['constraints'],
  );

  String? tenantId = resolveHrAccessTenantId(ref);
  final String? policyTenant = ref.read(appAccessPolicyProvider).tenantId;
  if (!isHrAccessTenantUuid(tenantId) && isHrAccessTenantUuid(policyTenant)) {
    tenantId = policyTenant;
  }
  if (!isEdit && !isHrAccessTenantUuid(tenantId)) {
    showHrMutationSnackBar(
      context,
      AppFailure.validation(detailMessage: l10n.hrFieldRequiredLabel('Tenant')),
    );
    return false;
  }

  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final List<HrOption> departments =
      state?.referenceData.departments ?? const <HrOption>[];
  final TextEditingController nameController = TextEditingController(
    text: _rosterDisplayName(existing),
  );
  final HrWeeklyScheduleDraft schedule = isEdit
      ? () {
          final HrWeeklyScheduleDraft hydrated =
              HrWeeklyScheduleDraft.fromTemplateExtra(existingConstraints);
          if (kHrWeekDayOrder.any(
            (int day) => hydrated.days[day]!.filledSlots.isNotEmpty,
          )) {
            return hydrated;
          }
          // Legacy rows without schedule payload: start from weekday defaults.
          return HrWeeklyScheduleDraft(weekdayDefaults: true);
        }()
      : HrWeeklyScheduleDraft(weekdayDefaults: true);
  DateTime? periodStart =
      _parseRosterDate(existing['period_start']) ?? DateTime.now();
  DateTime? periodEnd =
      _parseRosterDate(existing['period_end']) ??
      DateTime.now().add(const Duration(days: 7));
  final String? facilityId =
      (existing['facility_id']?.toString().trim().isNotEmpty ?? false)
      ? existing['facility_id']!.toString().trim()
      : _resolveRosterFacilityId(ref, state);
  String departmentId = isEdit
      ? _resolveDepartmentOptionValue(
          roster: existing,
          departments: departments,
        )
      : _kRosterAllDepartments;
  final String status =
      ((existing['status'] ?? 'DRAFT').toString().trim().isEmpty
      ? 'DRAFT'
      : (existing['status'] ?? 'DRAFT').toString().trim().toUpperCase());
  bool isRecurring = isEdit
      ? _asBool(existing['is_recurring'], fallback: false)
      : true;
  bool respectHolidays = _asBool(
    existingConstraints['respect_public_holidays'],
    fallback: true,
  );
  bool respectWeekends = _asBool(
    existingConstraints['respect_weekends'],
    fallback: true,
  );
  final Set<int> monthDays = isEdit
      ? _monthDaysFromConstraints(existingConstraints)
      : _allMonthDays(31);
  final List<Object?> preservedPublicHolidays = _listConstraintValue(
    existingConstraints,
    'public_holidays',
  );
  final List<Object?> preservedAttachedStaffIds = _listConstraintValue(
    existingConstraints,
    'attached_staff_ids',
  );
  final List<Object?> preservedAttachedStaffMeta = _listConstraintValue(
    existingConstraints,
    'attached_staff_meta',
  );

  if (isEdit && respectWeekends) {
    for (final int day in <int>[0, 6]) {
      schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
    }
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      isEdit ? l10n.hrRosterEditDialogTitle : l10n.hrCreateRosterDialogTitle,
    ),
    icon: Icon(
      isEdit ? Icons.edit_outlined : Icons.edit_calendar_outlined,
    ),
    submitLabel: isEdit
        ? l10n.hrSaveRosterTemplateAction
        : l10n.hrShiftTemplateAction,
    cancelLabel: l10n.commonCloseActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 1040,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setLocal) {
              final ThemeData theme = Theme.of(context);
              final AppBreakpoint breakpoint = AppBreakpoints.of(context);
              final bool compact = breakpoint.isMobile;
              final EdgeInsets detailsPadding = EdgeInsets.fromLTRB(
                compact ? theme.spacing.sm : theme.spacing.md,
                compact ? theme.spacing.xs : theme.spacing.sm,
                compact ? theme.spacing.sm : theme.spacing.md,
                compact ? theme.spacing.sm : theme.spacing.md,
              );
              final int maxMonthDay = _maxDayOfMonthForRoster(
                isRecurring: isRecurring,
                periodStart: periodStart,
                periodEnd: periodEnd,
              );
              final bool? monthDaysValue = _monthDaysTriState(
                monthDays,
                maxMonthDay,
              );

              void syncWeekendsOnHours() {
                if (!respectWeekends) {
                  return;
                }
                for (final int day in <int>[0, 6]) {
                  schedule.days[day]!.replaceSlots(
                    const <HrAvailabilitySlot>[],
                  );
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppCollapsibleSection(
                    title: l10n.hrRosterDetailsSectionTitle,
                    titleIcon: Icons.info_outline,
                    contentPadding: detailsPadding,
                    child: AppFormSection(
                      density: AppFormSectionDensity.compact,
                      children: <Widget>[
                        AppTextField(
                          controller: nameController,
                          labelText: l10n.hrRosterNameLabel,
                          hintText: l10n.hrRosterNameHelper,
                          isRequired: true,
                          isDense: true,
                          validator: AppValidators.requiredText(
                            l10n.hrFieldRequiredLabel(l10n.hrRosterNameLabel),
                          ),
                        ),
                        AppResponsiveFieldRow(
                          breakpoint: AppBreakpoints.lg,
                          children: <Widget>[
                            AppCheckboxField(
                              title: l10n.hrRosterRecurringLabel,
                              value: isRecurring,
                              onChanged: (bool value) {
                                setLocal(() {
                                  isRecurring = value;
                                  final int nextMax = _maxDayOfMonthForRoster(
                                    isRecurring: isRecurring,
                                    periodStart: periodStart,
                                    periodEnd: periodEnd,
                                  );
                                  _clampMonthDays(monthDays, nextMax);
                                  if (monthDays.isEmpty) {
                                    monthDays.addAll(_allMonthDays(nextMax));
                                  }
                                  syncWeekendsOnHours();
                                });
                              },
                            ),
                            AppCheckboxField(
                              title: l10n.hrRosterRespectHolidaysLabel,
                              value: respectHolidays,
                              onChanged: (bool value) =>
                                  setLocal(() => respectHolidays = value),
                            ),
                            AppCheckboxField(
                              title: l10n.hrRosterRespectWeekendsLabel,
                              value: respectWeekends,
                              onChanged: (bool value) {
                                setLocal(() {
                                  respectWeekends = value;
                                  syncWeekendsOnHours();
                                });
                              },
                            ),
                          ],
                        ),
                        if (!isRecurring)
                          AppResponsiveFieldRow(
                            children: <Widget>[
                              AppDateField(
                                value: periodStart,
                                labelText: l10n.hrStartDateLabel,
                                isRequired: true,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                currentDate: DateTime.now(),
                                pickerButtonLabel: l10n.hrPickDateAction,
                                invalidDateMessage: l10n.appDateInvalidMessage,
                                enableSpeechToText: false,
                                onChanged: (DateTime? value) {
                                  setLocal(() {
                                    periodStart = value;
                                    final int nextMax = _maxDayOfMonthForRoster(
                                      isRecurring: isRecurring,
                                      periodStart: periodStart,
                                      periodEnd: periodEnd,
                                    );
                                    _clampMonthDays(monthDays, nextMax);
                                  });
                                },
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
                                enableSpeechToText: false,
                                onChanged: (DateTime? value) {
                                  setLocal(() {
                                    periodEnd = value;
                                    final int nextMax = _maxDayOfMonthForRoster(
                                      isRecurring: isRecurring,
                                      periodStart: periodStart,
                                      periodEnd: periodEnd,
                                    );
                                    _clampMonthDays(monthDays, nextMax);
                                  });
                                },
                              ),
                            ],
                          ),
                        AppSelectField<String>.searchable(
                          value: departmentId,
                          labelText: l10n.hrDepartmentLabel,
                          hintText: l10n.hrRosterDepartmentHelper,
                          allowClear: false,
                          isDense: true,
                          enableSpeechToText: true,
                          options: <AppSelectOption<String>>[
                            AppSelectOption<String>(
                              value: _kRosterAllDepartments,
                              label: l10n.hrRosterAllDepartmentsLabel,
                            ),
                            ...hrSelectOptions(
                              state?.referenceData.departments ??
                                  const <HrOption>[],
                            ),
                          ],
                          onChanged: (String? value) {
                            setLocal(() {
                              departmentId = (value == null || value.isEmpty)
                                  ? _kRosterAllDepartments
                                  : value;
                            });
                          },
                        ),
                        Builder(
                          builder: (BuildContext context) {
                            void toggleAllMonthDays() {
                              setLocal(() {
                                if (monthDaysValue == true) {
                                  monthDays.clear();
                                } else {
                                  monthDays
                                    ..clear()
                                    ..addAll(_allMonthDays(maxMonthDay));
                                }
                              });
                            }

                            return Row(
                              children: <Widget>[
                                Checkbox(
                                  tristate: true,
                                  value: monthDaysValue,
                                  onChanged: (_) => toggleAllMonthDays(),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: toggleAllMonthDays,
                                    child: Text(
                                      l10n.hrRosterMonthDaysLabel,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Wrap(
                          spacing: compact
                              ? theme.spacing.xs
                              : theme.spacing.xs + 2,
                          runSpacing: compact
                              ? theme.spacing.xs
                              : theme.spacing.xs + 2,
                          children: <Widget>[
                            for (int day = 1; day <= maxMonthDay; day++)
                              _HrMonthDayChip(
                                day: day,
                                selected: monthDays.contains(day),
                                compact: compact,
                                onTap: () {
                                  setLocal(() {
                                    if (monthDays.contains(day)) {
                                      monthDays.remove(day);
                                    } else {
                                      monthDays.add(day);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? theme.spacing.sm : theme.spacing.md),
                  AppCollapsibleSection(
                    title: l10n.hrRosterWeekHoursTitle,
                    titleIcon: Icons.view_week_outlined,
                    contentPadding: EdgeInsets.fromLTRB(
                      compact ? theme.spacing.sm : theme.spacing.md,
                      theme.spacing.sm,
                      compact ? theme.spacing.sm : theme.spacing.md,
                      compact ? theme.spacing.sm : theme.spacing.md,
                    ),
                    child: HrRosterHourGrid(
                      schedule: schedule,
                      respectWeekends: respectWeekends,
                      showSectionChrome: false,
                      onChanged: () => setLocal(() {}),
                    ),
                  ),
                ],
              );
            },
          );
        },
    onSubmit: () {
      if (!isRecurring) {
        if (periodStart == null || periodEnd == null) {
          return Future<AppFailure?>.value(
            AppFailure.validation(
              detailMessage: l10n.hrFieldRequiredLabel(l10n.hrPeriodColumnLabel),
            ),
          );
        }
        if (!periodEnd!.isAfter(periodStart!)) {
          return Future<AppFailure?>.value(
            AppFailure.validation(
              detailMessage: l10n.hrFieldRequiredLabel(l10n.hrPeriodColumnLabel),
            ),
          );
        }
      }

      if (respectWeekends) {
        for (final int day in <int>[0, 6]) {
          schedule.days[day]!.replaceSlots(const <HrAvailabilitySlot>[]);
        }
      }

      final int maxMonthDay = _maxDayOfMonthForRoster(
        isRecurring: isRecurring,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      _clampMonthDays(monthDays, maxMonthDay);
      final List<int> monthDayList = _monthDaysForPayload(
        monthDays: monthDays,
        isRecurring: isRecurring,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      if (monthDayList.isEmpty) {
        return Future<AppFailure?>.value(
          AppFailure.validation(
            detailMessage: l10n.hrRosterMonthDaysRequiredMessage,
          ),
        );
      }

      final String? scheduleError = schedule.validate(l10n);
      if (scheduleError != null) {
        return Future<AppFailure?>.value(
          AppFailure.validation(detailMessage: scheduleError),
        );
      }

      final scheduleDefaults = _scheduleLegacyDefaults(schedule);
      final List<String> workingDays = scheduleDefaults.workingDays;
      final String? defaultStart = scheduleDefaults.defaultStart;
      final String? defaultEnd = scheduleDefaults.defaultEnd;

      final DateTime effectiveStart = periodStart ?? DateTime.now();
      final DateTime effectiveEnd =
          periodEnd ?? DateTime.now().add(const Duration(days: 7));

      final Map<String, Object?> constraints = <String, Object?>{
        'respect_public_holidays': respectHolidays,
        'respect_weekends': respectWeekends,
        'public_holidays': preservedPublicHolidays,
        'month_days': monthDayList,
        'working_days': workingDays,
        'default_start_time': defaultStart,
        'default_end_time': defaultEnd,
        'weekly_schedule_json': schedule.toTemplateWeeklySchedulePayload(),
        'attached_staff_ids': isEdit
            ? preservedAttachedStaffIds
            : const <String>[],
        if (isEdit) 'attached_staff_meta': preservedAttachedStaffMeta,
      };

      final Map<String, Object?> payload = <String, Object?>{
        if (!isEdit) 'tenant_id': tenantId,
        'name': nameController.text.trim(),
        'is_recurring': isRecurring,
        'period_start': effectiveStart.toUtc().toIso8601String(),
        'period_end': effectiveEnd.toUtc().toIso8601String(),
        if (!isEdit) 'status': status,
        'facility_id': facilityId,
        'department_id': departmentId == _kRosterAllDepartments
            ? null
            : departmentId,
        'materialize_shifts': true,
        'constraints': constraints,
      };

      Future<AppFailure?> submit({required bool confirmSimilar}) async {
        final Map<String, Object?> request = <String, Object?>{
          ...payload,
          if (confirmSimilar) 'confirm_similar': true,
        };
        final AppFailure? failure = isEdit
            ? await controller.updateRoster(rosterId, request)
            : await controller.createRoster(request);
        if (failure == null || !context.mounted) {
          return failure;
        }
        if (!isHrRosterSimilarityConflict(failure)) {
          return failure;
        }
        final bool exact = isHrRosterExactNameConflict(failure);
        final List<HrRosterSimilarityMatch> matches =
            hrRosterSimilarityMatchesFromConflict(failure, l10n: l10n);
        final bool proceed = await showHrRosterSimilarityDialog(
          context: context,
          proposedName: nameController.text.trim(),
          matches: matches,
          blockProceed: exact,
          isEdit: isEdit,
        );
        if (!proceed || !context.mounted) {
          return failure;
        }
        if (exact) {
          return failure;
        }
        return submit(confirmSimilar: true);
      }

      return submit(confirmSimilar: false);
    },
  );

  schedule.dispose();
  nameController.dispose();
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
  return saved == true;
}

class _HrMonthDayChip extends StatelessWidget {
  const _HrMonthDayChip({
    required this.day,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color fill = selected
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.error.withValues(alpha: 0.10);
    final Color edge = selected
        ? scheme.primary.withValues(alpha: 0.72)
        : scheme.error.withValues(alpha: 0.48);
    final Color accent = selected ? scheme.primary : scheme.error;
    final Color labelColor = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.72);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(theme.radius.sm),
            border: Border.all(color: edge),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? theme.spacing.xs : theme.spacing.xs + 2,
              vertical: compact ? 4 : theme.spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? Icons.check_rounded : Icons.close_rounded,
                  size: compact ? 12 : 14,
                  color: accent,
                ),
                SizedBox(width: compact ? 4 : theme.spacing.xs),
                Text(
                  '$day',
                  style: (compact
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
