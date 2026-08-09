import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart'
    show showHrPreviewRosterDialog;
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
  String? facilityId;
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
                  AppSelectField<String>.searchable(
                    value: facilityId,
                    labelText: l10n.hrDepartmentLabel,
                    options: hrSelectOptions(
                      state?.referenceData.facilities ?? const <HrOption>[],
                    ),
                    onChanged: (String? value) =>
                        setLocal(() => facilityId = value),
                  ),
                  AppSelectField<String>.searchable(
                    value: departmentId,
                    labelText: l10n.hrDepartmentLabel,
                    options: hrSelectOptions(
                      state?.referenceData.departments ?? const <HrOption>[],
                    ),
                    onChanged: (String? value) =>
                        setLocal(() => departmentId = value),
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
                  AppSwitchField(
                    value: respectHolidays,
                    title: l10n.hrRosterRespectHolidaysLabel,
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
                  AppTimeField(
                    value: startTime,
                    labelText: l10n.hrRosterDefaultStartTimeLabel,
                    pickerButtonLabel: l10n.appTimePickerAction,
                    invalidTimeMessage: l10n.appTimeInvalidMessage,
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
                    onChanged: (AppTimeValue? value) {
                      if (value != null) {
                        setLocal(() => endTime = value);
                      }
                    },
                  ),
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
      if (workingDays.isEmpty) {
        return Future<AppFailure?>.value(
          AppFailure.validation(
            detailMessage: l10n.hrFieldRequiredLabel(
              l10n.hrRosterWorkingDaysLabel,
            ),
          ),
        );
      }

      final List<String> holidays = holidaysController.text
          .split(RegExp(r'[\s,;]+'))
          .map((String part) => part.trim())
          .where((String part) => part.isNotEmpty)
          .toList(growable: false);

      final Map<String, Object?> payload = <String, Object?>{
        'tenant_id': tenantId,
        'name': nameController.text.trim(),
        'is_recurring': isRecurring,
        'period_start': periodStart!.toUtc().toIso8601String(),
        'period_end': periodEnd!.toUtc().toIso8601String(),
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
      return Consumer(
        builder: (BuildContext context, WidgetRef dialogRef, _) {
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
    },
  );
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

  List<Map<String, Object?>> get _staff {
    final Object? raw = _roster?['staff'];
    if (raw is! List) {
      return const <Map<String, Object?>>[];
    }
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) => Map<String, Object?>.from(item),
        )
        .toList(growable: false);
  }

  Future<void> _addStaff() async {
    final AppLocalizations l10n = context.l10n;
    final HrWorkspaceState? state = readHrWorkspaceState(ref);
    String? staffProfileId;
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
            return AppFormSection(
              children: <Widget>[
                AppSelectField<String>.searchable(
                  value: staffProfileId,
                  labelText: l10n.hrRosterSelectStaffLabel,
                  isRequired: true,
                  options: hrSelectOptions(
                    state?.referenceData.staffProfiles ?? const <HrOption>[],
                  ),
                  validator: AppValidators.requiredValue(
                    l10n.hrFieldRequiredLabel(l10n.hrRosterSelectStaffLabel),
                  ),
                  onChanged: (String? value) => staffProfileId = value,
                ),
              ],
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
              rosterId: widget.item.rosterId ?? widget.item.effectiveId,
              staffProfileId: staffProfileId!,
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
        .detachRosterStaff(
          rosterId: widget.item.rosterId ?? widget.item.effectiveId,
          staffProfileId: staffProfileId,
        );
    setState(() => _busy = false);
    result.when(
      success: (Map<String, Object?> value) {
        setState(() => _roster = value);
        showHrMutationSnackBar(context, null);
      },
      failure: (AppFailure failure) {
        showHrMutationSnackBar(context, failure);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, Object?> roster = _roster ?? <String, Object?>{};
    final String name =
        (roster['name'] ?? widget.item.rosterName ?? widget.item.periodLabel)
            ?.toString() ??
        l10n.hrRosterDraftTitle;
    final String status = (roster['status'] ?? widget.item.status)?.toString() ??
        '';
    final bool recurring =
        roster['is_recurring'] == true || widget.item.isRecurring;
    final String period =
        (roster['period_label'] ?? widget.item.periodLabel)?.toString() ??
        l10n.profileUnknownValue;

    return AppDialog(
      title: Text(l10n.hrRosterDetailDialogTitle),
      icon: const Icon(Icons.calendar_month_outlined),
      scrollable: true,
      maxWidth: 720,
      content: widget.isLoading && _roster == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.failure != null && _roster == null)
                  Text(
                    widget.failure!.detailMessage ??
                        widget.failure!.messageKey,
                  )
                else ...<Widget>[
                  AppInfoTileGrid(
                    emptyValue: l10n.profileUnknownValue,
                    items: <AppInfoTileData>[
                      AppInfoTileData(
                        label: l10n.hrRosterNameLabel,
                        value: name,
                        icon: Icons.badge_outlined,
                      ),
                      AppInfoTileData(
                        label: l10n.hrQueueItemColumnLabel,
                        value:
                            (roster['human_friendly_id'] ??
                                    widget.item.effectiveId)
                                .toString(),
                        icon: Icons.confirmation_number_outlined,
                        copyable: true,
                      ),
                      AppInfoTileData(
                        label: l10n.hrPeriodColumnLabel,
                        value: period,
                        icon: Icons.date_range_outlined,
                      ),
                      AppInfoTileData(
                        label: l10n.hrRosterRecurringLabel,
                        value: recurring
                            ? l10n.commonYesLabel
                            : l10n.commonNoLabel,
                        icon: Icons.repeat_outlined,
                      ),
                      AppInfoTileData(
                        label: l10n.hrStatusColumnLabel,
                        value: hrRosterStatusLabel(l10n, status),
                        icon: Icons.radio_button_checked,
                      ),
                      AppInfoTileData(
                        label: l10n.hrAssignmentsSectionTitle,
                        value: _staff.length.toString(),
                        icon: Icons.groups_outlined,
                      ),
                    ],
                  ),
                  SizedBox(height: Theme.of(context).spacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.hrRosterAttachedStaffTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      AppAccessActionGate(
                        requirement: HrShiftsAtomPermissions.write,
                        builder: (BuildContext context, bool isAllowed) {
                          return AppButton.secondary(
                            label: l10n.hrRosterAddStaffAction,
                            leadingIcon: Icons.person_add_alt_1_outlined,
                            enabled: isAllowed && !_busy,
                            onPressed: !isAllowed || _busy ? null : _addStaff,
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: Theme.of(context).spacing.sm),
                  if (_staff.isEmpty)
                    Text(l10n.hrRosterNoStaffLabel)
                  else
                    for (final Map<String, Object?> staff in _staff)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          (staff['name'] ??
                                  staff['staff_number'] ??
                                  staff['display_id'] ??
                                  l10n.profileUnknownValue)
                              .toString(),
                        ),
                        subtitle: Text(
                          [
                            staff['staff_number'],
                            staff['display_id'],
                          ].whereType<Object>().join(' · '),
                        ),
                        trailing: AppAccessActionGate(
                          requirement: HrShiftsAtomPermissions.write,
                          builder: (BuildContext context, bool isAllowed) {
                            return IconButton(
                              tooltip: l10n.hrRosterRemoveStaffAction,
                              onPressed: !isAllowed || _busy
                                  ? null
                                  : () => _removeStaff(
                                      (staff['staff_profile_id'] ?? '')
                                          .toString(),
                                    ),
                              icon: const Icon(Icons.person_remove_outlined),
                            );
                          },
                        ),
                      ),
                ],
              ],
            ),
      actions: <Widget>[
        AppAccessActionGate(
          requirement: HrShiftsAtomPermissions.previewRoster,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.secondary(
              label: l10n.hrPreviewRosterAction,
              leadingIcon: Icons.visibility_outlined,
              enabled: isAllowed && !_busy,
              onPressed: !isAllowed || _busy
                  ? null
                  : () => showHrPreviewRosterDialog(context, ref, widget.item),
            );
          },
        ),
        AppAccessActionGate(
          requirement: HrShiftsAtomPermissions.generateRoster,
          builder: (BuildContext context, bool isAllowed) {
            return AppButton.secondary(
              label: l10n.hrGenerateRosterAction,
              leadingIcon: Icons.auto_awesome_outlined,
              enabled: isAllowed && !_busy,
              onPressed: !isAllowed || _busy
                  ? null
                  : () async {
                      final AppFailure? failure = await ref
                          .read(hrWorkspaceControllerProvider.notifier)
                          .generateRoster(widget.item);
                      if (context.mounted) {
                        showHrMutationSnackBar(context, failure);
                      }
                    },
            );
          },
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
