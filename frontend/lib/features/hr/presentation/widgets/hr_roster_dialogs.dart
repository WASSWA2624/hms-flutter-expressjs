import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
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
  final TextEditingController holidaysController = TextEditingController();
  DateTime? periodStart = DateTime.now();
  DateTime? periodEnd = DateTime.now().add(const Duration(days: 7));
  final String? facilityId = _resolveRosterFacilityId(ref, state);
  String? departmentId;
  String status = 'DRAFT';
  bool isRecurring = false;
  bool respectHolidays = true;
  final Set<int> workingDays = Set<int>.from(kDefaultAvailabilityWeekdays);
  AppTimeValue startTime = kDefaultAvailabilityStartTime;
  AppTimeValue endTime = kDefaultAvailabilityEndTime;

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrCreateRosterDialogTitle),
    icon: const Icon(Icons.edit_calendar_outlined),
    submitLabel: l10n.hrShiftTemplateAction,
    cancelLabel: l10n.commonCloseActionLabel,
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
                    hintText: l10n.hrRosterNameHelper,
                    isRequired: true,
                    validator: AppValidators.requiredText(
                      l10n.hrFieldRequiredLabel(l10n.hrRosterNameLabel),
                    ),
                  ),
                  AppCheckboxField(
                    title: l10n.hrRosterRecurringLabel,
                    subtitle: l10n.hrRosterRecurringHelper,
                    value: isRecurring,
                    onChanged: (bool value) =>
                        setLocal(() => isRecurring = value),
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
                    helperText: l10n.hrRosterDepartmentHelper,
                    options: hrSelectOptions(
                      state?.referenceData.departments ?? const <HrOption>[],
                    ),
                    onChanged: (String? value) =>
                        setLocal(() => departmentId = value),
                  ),
                  Text(
                    l10n.hrRosterStatusFieldLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  AppResponsiveFieldRow(
                    gap: AppResponsiveFieldRowGap.form,
                    children: <Widget>[
                      AppCheckboxField(
                        title: l10n.hrRosterStatusDraft,
                        value: status == 'DRAFT',
                        onChanged: (bool value) {
                          if (value) {
                            setLocal(() => status = 'DRAFT');
                          }
                        },
                      ),
                      AppCheckboxField(
                        title: l10n.hrRosterStatusCompleted,
                        value: status == 'PUBLISHED',
                        onChanged: (bool value) {
                          if (value) {
                            setLocal(() => status = 'PUBLISHED');
                          }
                        },
                      ),
                    ],
                  ),
                  AppCheckboxField(
                    title: l10n.hrRosterRespectHolidaysLabel,
                    subtitle: l10n.hrRosterRespectHolidaysHelper,
                    value: respectHolidays,
                    onChanged: (bool value) =>
                        setLocal(() => respectHolidays = value),
                  ),
                  Text(
                    l10n.hrRosterWorkingDaysLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final int day in kHrWeekDayOrder)
                        FilterChip(
                          label: Text(hrDayLabel(l10n, day)),
                          selected: workingDays.contains(day),
                          onSelected: (bool selected) {
                            setLocal(() {
                              if (selected) {
                                workingDays.add(day);
                              } else {
                                workingDays.remove(day);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  AppResponsiveFieldRow(
                    gap: AppResponsiveFieldRowGap.form,
                    children: <Widget>[
                      AppTimeField(
                        value: startTime,
                        labelText: l10n.hrRosterDefaultStartTimeLabel,
                        pickerButtonLabel: l10n.appTimePickerAction,
                        invalidTimeMessage: l10n.appTimeInvalidMessage,
                        enableSpeechToText: false,
                        onChanged: (AppTimeValue? value) {
                          if (value != null) {
                            setLocal(() => startTime = value);
                          }
                        },
                      ),
                      AppTimeField(
                        value: endTime,
                        labelText: l10n.hrRosterDefaultEndTimeLabel,
                        pickerButtonLabel: l10n.appTimePickerAction,
                        invalidTimeMessage: l10n.appTimeInvalidMessage,
                        enableSpeechToText: false,
                        onChanged: (AppTimeValue? value) {
                          if (value != null) {
                            setLocal(() => endTime = value);
                          }
                        },
                      ),
                    ],
                  ),
                  if (respectHolidays)
                    AppTextField(
                      controller: holidaysController,
                      labelText: l10n.hrRosterPublicHolidaysLabel,
                      maxLines: 2,
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
      if (workingDays.isEmpty) {
        return Future<AppFailure?>.value(
          AppFailure.validation(
            detailMessage: l10n.hrFieldRequiredLabel(
              l10n.hrRosterWorkingDaysLabel,
            ),
          ),
        );
      }

      final List<String> holidays = respectHolidays
          ? holidaysController.text
                .split(RegExp(r'[\s,;]+'))
                .map((String part) => part.trim())
                .where((String part) => part.isNotEmpty)
                .toList(growable: false)
          : const <String>[];

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
        'department_id': departmentId,
        'materialize_shifts': true,
        'constraints': <String, Object?>{
          'respect_public_holidays': respectHolidays,
          'public_holidays': holidays,
          'working_days': workingDays
              .map((int day) => _kWeekdayCodes[day])
              .whereType<String>()
              .toList(growable: false),
          'default_start_time':
              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
          'default_end_time':
              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
          'attached_staff_ids': <String>[],
        },
      };
      return controller.createRoster(payload);
    },
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}
