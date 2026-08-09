import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_hour_grid.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_weekly_schedule_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

export 'hr_roster_detail_dialog.dart' show showHrRosterDetailDialog;

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

Future<void> showHrCreateRosterDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  String? tenantId = resolveHrAccessTenantId(ref);
  final String? policyTenant = ref.read(appAccessPolicyProvider).tenantId;
  if (!isHrAccessTenantUuid(tenantId) && isHrAccessTenantUuid(policyTenant)) {
    tenantId = policyTenant;
  }
  if (!isHrAccessTenantUuid(tenantId)) {
    showHrMutationSnackBar(
      context,
      AppFailure.validation(detailMessage: l10n.hrFieldRequiredLabel('Tenant')),
    );
    return;
  }

  final HrWorkspaceState? state = readHrWorkspaceState(ref);
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final TextEditingController nameController = TextEditingController();
  final HrWeeklyScheduleDraft schedule = HrWeeklyScheduleDraft(
    weekdayDefaults: true,
  );
  DateTime? periodStart = DateTime.now();
  DateTime? periodEnd = DateTime.now().add(const Duration(days: 7));
  final String? facilityId = _resolveRosterFacilityId(ref, state);
  String departmentId = _kRosterAllDepartments;
  const String status = 'DRAFT';
  bool isRecurring = true;
  bool respectHolidays = true;

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCreateRosterDialogTitle),
    icon: const Icon(Icons.edit_calendar_outlined),
    submitLabel: l10n.hrShiftTemplateAction,
    cancelLabel: l10n.commonCloseActionLabel,
    submitIcon: Icons.save_outlined,
    maxWidth: 980,
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
                    hintText: l10n.hrRosterNameHelper,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.hrFieldRequiredLabel(l10n.hrRosterNameLabel),
                    ),
                  ),
                  AppResponsiveFieldRow(
                    gap: AppResponsiveFieldRowGap.form,
                    children: <Widget>[
                      AppCheckboxField(
                        title: l10n.hrRosterRecurringLabel,
                        value: isRecurring,
                        onChanged: (bool value) =>
                            setLocal(() => isRecurring = value),
                      ),
                      AppCheckboxField(
                        title: l10n.hrRosterRespectHolidaysLabel,
                        value: respectHolidays,
                        onChanged: (bool value) =>
                            setLocal(() => respectHolidays = value),
                      ),
                    ],
                  ),
                  if (!isRecurring)
                    AppResponsiveFieldRow(
                      gap: AppResponsiveFieldRowGap.form,
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
                          enableSpeechToText: false,
                          onChanged: (DateTime? value) =>
                              setLocal(() => periodEnd = value),
                        ),
                      ],
                    ),
                  AppSelectField<String>.searchable(
                    value: departmentId,
                    labelText: l10n.hrDepartmentLabel,
                    hintText: l10n.hrRosterDepartmentHelper,
                    allowClear: false,
                    enableSpeechToText: false,
                    options: <AppSelectOption<String>>[
                      AppSelectOption<String>(
                        value: _kRosterAllDepartments,
                        label: l10n.hrRosterAllDepartmentsLabel,
                      ),
                      ...hrSelectOptions(
                        state?.referenceData.departments ?? const <HrOption>[],
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
                  HrRosterHourGrid(
                    schedule: schedule,
                    onChanged: () => setLocal(() {}),
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

      final Map<String, Object?> payload = <String, Object?>{
        'tenant_id': tenantId,
        'name': nameController.text.trim(),
        'is_recurring': isRecurring,
        'period_start': effectiveStart.toUtc().toIso8601String(),
        'period_end': effectiveEnd.toUtc().toIso8601String(),
        'status': status,
        'facility_id': facilityId,
        'department_id': departmentId == _kRosterAllDepartments
            ? null
            : departmentId,
        'materialize_shifts': true,
        'constraints': <String, Object?>{
          'respect_public_holidays': respectHolidays,
          'public_holidays': <String>[],
          'working_days': workingDays,
          'default_start_time': defaultStart,
          'default_end_time': defaultEnd,
          'weekly_schedule_json': schedule.toTemplateWeeklySchedulePayload(),
          'attached_staff_ids': <String>[],
        },
      };
      return controller.createRoster(payload);
    },
  );

  schedule.dispose();
  nameController.dispose();
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}
