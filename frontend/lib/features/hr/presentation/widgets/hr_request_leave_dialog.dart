import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Global entry point for requesting staff leave with full leave metadata.
///
/// Leave created from HR is auto-approved (no approval workflow).
Future<void> showHrRequestLeaveDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  // Shared by Human resources Staff actions and Leave requests strip primary
  // (both matrix ∩ `hr:write`).
  if (!HrHumanResourcesAtomPermissions.requestLeave.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  await controller.ensureAssignmentReferenceData();

  final HrWorkspaceState? workspace = ref
      .read(hrWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (HrWorkspaceState state) => state,
        failure: (_) => null,
      );

  final HrReferenceData referenceData =
      workspace?.referenceData ?? const HrReferenceData();
  final HrStaffDetail? selectedStaff = workspace?.selectedStaff;
  final String? currentStaffId = selectedStaff?.profile.effectiveId;

  final GlobalKey<_HrRequestLeaveFieldsState> fieldsKey =
      GlobalKey<_HrRequestLeaveFieldsState>();

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrLeaveDialogTitle),
    icon: const Icon(Icons.event_busy_outlined),
    submitLabel: l10n.hrRequestLeaveAction,
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
          return _HrRequestLeaveFields(
            key: fieldsKey,
            referenceData: referenceData,
            currentStaffId: currentStaffId,
            shiftAssignments:
                selectedStaff?.shiftAssignments ?? const <HrShiftAssignment>[],
          );
        },
    onSubmit: () {
      final _HrRequestLeaveFieldsState? state = fieldsKey.currentState;
      final String? validationError = state?.validate(context.l10n);
      if (validationError != null) {
        return Future<AppFailure?>.value(
          AppFailure.validation(detailMessage: validationError),
        );
      }
      return controller.createLeave(
        state?.toPayload() ?? const <String, Object?>{},
      );
    },
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

class _HrRequestLeaveFields extends StatefulWidget {
  const _HrRequestLeaveFields({
    required this.referenceData,
    this.currentStaffId,
    this.shiftAssignments = const <HrShiftAssignment>[],
    super.key,
  });

  final HrReferenceData referenceData;
  final String? currentStaffId;
  final List<HrShiftAssignment> shiftAssignments;

  @override
  State<_HrRequestLeaveFields> createState() => _HrRequestLeaveFieldsState();
}

class _HrRequestLeaveFieldsState extends State<_HrRequestLeaveFields> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _handoverController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(
    text: '1',
  );

  String? _leaveType = 'ANNUAL';
  String? _coveringStaffId;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  /// Prevents recursive updates while syncing the three duration fields.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncFromStartAndDays();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _handoverController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Set<int> get _rosterWeekdays {
    final Set<int> days = <int>{};
    for (final HrShiftAssignment assignment in widget.shiftAssignments) {
      final DateTime? start = assignment.startTime?.toLocal();
      if (start == null) {
        continue;
      }
      days.add(start.weekday);
    }
    return days;
  }

  bool _isWorkingDay(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final Set<int> rosterDays = _rosterWeekdays;
    if (rosterDays.isNotEmpty) {
      return rosterDays.contains(day.weekday);
    }
    // Fallback when no roster: Mon–Fri count as working days.
    return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
  }

  int _countWorkingDays(DateTime start, DateTime end) {
    DateTime cursor = DateTime(start.year, start.month, start.day);
    final DateTime last = DateTime(end.year, end.month, end.day);
    if (last.isBefore(cursor)) {
      return 0;
    }
    int count = 0;
    while (!cursor.isAfter(last)) {
      if (_isWorkingDay(cursor)) {
        count += 1;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  DateTime _endAfterWorkingDays(DateTime start, int workingDays) {
    final int target = workingDays < 1 ? 1 : workingDays;
    DateTime cursor = DateTime(start.year, start.month, start.day);
    int counted = 0;
    // Safety bound: never walk more than ~2 years.
    for (int i = 0; i < 800; i += 1) {
      if (_isWorkingDay(cursor)) {
        counted += 1;
        if (counted >= target) {
          return cursor;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return cursor;
  }

  int get _days {
    final int parsed = int.tryParse(_daysController.text.trim()) ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  void _setDaysText(int value) {
    final String text = (value < 1 ? 1 : value).toString();
    if (_daysController.text != text) {
      _daysController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _syncFromStartAndDays() {
    final DateTime? start = _startDate;
    if (start == null) {
      return;
    }
    _syncing = true;
    _endDate = _endAfterWorkingDays(start, _days);
    _syncing = false;
  }

  void _onStartChanged(DateTime? value) {
    if (_syncing) {
      return;
    }
    setState(() {
      _startDate = value;
      if (value != null) {
        _syncing = true;
        _endDate = _endAfterWorkingDays(value, _days);
        _syncing = false;
      }
    });
  }

  void _onDaysChanged(String _) {
    if (_syncing) {
      return;
    }
    final DateTime? start = _startDate;
    if (start == null) {
      return;
    }
    setState(() {
      _syncing = true;
      _endDate = _endAfterWorkingDays(start, _days);
      _syncing = false;
    });
  }

  void _onEndChanged(DateTime? value) {
    if (_syncing) {
      return;
    }
    setState(() {
      _endDate = value;
      final DateTime? start = _startDate;
      if (start != null && value != null) {
        _syncing = true;
        final int days = _countWorkingDays(start, value);
        _setDaysText(days < 1 ? 1 : days);
        _syncing = false;
      }
    });
  }

  List<AppSelectOption<String>> get _leaveTypeOptions {
    final AppLocalizations l10n = context.l10n;
    if (widget.referenceData.leaveTypes.isNotEmpty) {
      return <AppSelectOption<String>>[
        for (final HrOption option in widget.referenceData.leaveTypes)
          AppSelectOption<String>(
            value: option.value,
            label: l10n.hrLocalizedOptionLabel(option),
          ),
      ];
    }
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: 'ANNUAL',
        label: l10n.hrReferenceLeaveTypeAnnual,
      ),
      AppSelectOption<String>(
        value: 'SICK',
        label: l10n.hrReferenceLeaveTypeSick,
      ),
      AppSelectOption<String>(
        value: 'MATERNITY',
        label: l10n.hrReferenceLeaveTypeMaternity,
      ),
      AppSelectOption<String>(
        value: 'PATERNITY',
        label: l10n.hrReferenceLeaveTypePaternity,
      ),
      AppSelectOption<String>(
        value: 'COMPASSIONATE',
        label: l10n.hrReferenceLeaveTypeCompassionate,
      ),
      AppSelectOption<String>(
        value: 'UNPAID',
        label: l10n.hrReferenceLeaveTypeUnpaid,
      ),
      AppSelectOption<String>(
        value: 'STUDY',
        label: l10n.hrReferenceLeaveTypeStudy,
      ),
      AppSelectOption<String>(
        value: 'EMERGENCY',
        label: l10n.hrReferenceLeaveTypeEmergency,
      ),
      AppSelectOption<String>(
        value: 'OTHER',
        label: l10n.hrReferenceLeaveTypeOther,
      ),
    ];
  }

  List<AppSelectOption<String>> get _coveringStaffOptions {
    final String? currentId = widget.currentStaffId?.trim();
    return <AppSelectOption<String>>[
      for (final HrOption option in widget.referenceData.staffProfiles)
        if (currentId == null || option.value != currentId)
          AppSelectOption<String>(value: option.value, label: option.label),
    ];
  }

  String? validate(AppLocalizations l10n) {
    if ((_leaveType ?? '').trim().isEmpty) {
      return l10n.hrFieldRequiredLabel(l10n.hrLeaveTypeLabel);
    }
    if (_startDate == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrStartDateLabel);
    }
    if (_endDate == null) {
      return l10n.hrFieldRequiredLabel(l10n.hrEndDateLabel);
    }
    if (_endDate!.isBefore(
      DateTime(_startDate!.year, _startDate!.month, _startDate!.day),
    )) {
      return l10n.hrFieldRequiredLabel(l10n.hrEndDateLabel);
    }
    return null;
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'leave_type': _leaveType,
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
      'is_half_day': false,
      'reason': _reasonController.text.trim(),
      'handover_notes': _handoverController.text.trim(),
      if ((_coveringStaffId ?? '').trim().isNotEmpty)
        'covering_staff_profile_id': _coveringStaffId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasRoster = _rosterWeekdays.isNotEmpty;

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>(
          value: _leaveType,
          labelText: l10n.hrLeaveTypeLabel,
          isRequired: true,
          options: _leaveTypeOptions,
          onChanged: (String? value) => setState(() => _leaveType = value),
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppDateField(
            value: _startDate,
            labelText: l10n.hrStartDateLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: _onStartChanged,
          ),
          right: AppDateField(
            value: _endDate,
            labelText: l10n.hrEndDateLabel,
            isRequired: true,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: _onEndChanged,
          ),
        ),
        AppTextField(
          controller: _daysController,
          labelText: l10n.hrLeaveDaysLabel,
          helperText: hasRoster
              ? l10n.hrLeaveDaysRosterHelper
              : l10n.hrLeaveDaysHelper,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: _onDaysChanged,
        ),
        if (_coveringStaffOptions.isNotEmpty)
          AppSelectField<String>.searchable(
            value: _coveringStaffId,
            labelText: l10n.hrCoveringStaffLabel,
            options: _coveringStaffOptions,
            onChanged: (String? value) =>
                setState(() => _coveringStaffId = value),
          ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          maxLines: 3,
        ),
        AppTextField(
          controller: _handoverController,
          labelText: l10n.hrHandoverNotesLabel,
          helperText: l10n.hrHandoverNotesHelper,
          maxLines: 3,
        ),
      ],
    );
  }
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day).toUtc().toIso8601String();
}
