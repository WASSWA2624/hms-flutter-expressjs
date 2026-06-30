import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_reference_localizations.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Global entry point for requesting staff leave with full leave metadata.
Future<void> showHrRequestLeaveDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  await controller.ensureAssignmentReferenceData();

  final HrReferenceData referenceData =
      ref
          .read(hrWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (HrWorkspaceState state) => state.referenceData,
            failure: (_) => const HrReferenceData(),
          ) ??
      const HrReferenceData();

  final String? currentStaffId =
      ref
          .read(hrWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (HrWorkspaceState state) =>
                state.selectedStaff?.profile.effectiveId,
            failure: (_) => null,
          );

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
    maxWidth: 640,
    buildFields: (BuildContext context, GlobalKey<FormState> formKey, bool _, [
      AppFailure? failure,
    ]) {
      return _HrRequestLeaveFields(
        key: fieldsKey,
        referenceData: referenceData,
        currentStaffId: currentStaffId,
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
      return controller.createLeave(state?.toPayload() ?? const <String, Object?>{});
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
    super.key,
  });

  final HrReferenceData referenceData;
  final String? currentStaffId;

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
  String? _halfDayPeriod = 'MORNING';
  String? _coveringStaffId;
  bool _isHalfDay = false;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  @override
  void dispose() {
    _reasonController.dispose();
    _handoverController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  static int _inclusiveDays(DateTime start, DateTime end) {
    final DateTime from = DateTime(start.year, start.month, start.day);
    final DateTime to = DateTime(end.year, end.month, end.day);
    return to.difference(from).inDays + 1;
  }

  int get _days {
    final int parsed = int.tryParse(_daysController.text.trim()) ?? 1;
    return parsed < 1 ? 1 : parsed;
  }

  void _setDaysText(int value) {
    final String text = value.toString();
    if (_daysController.text != text) {
      _daysController.text = text;
    }
  }

  void _onStartChanged(DateTime? value) {
    setState(() {
      _startDate = value;
      if (value != null) {
        if (_isHalfDay) {
          _endDate = DateTime(value.year, value.month, value.day);
          _setDaysText(1);
        } else {
          _endDate = DateTime(
            value.year,
            value.month,
            value.day,
          ).add(Duration(days: _days - 1));
        }
      }
    });
  }

  void _onDaysChanged(String _) {
    if (_isHalfDay) {
      return;
    }
    final DateTime? start = _startDate;
    if (start == null) {
      return;
    }
    setState(() {
      _endDate = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: _days - 1));
    });
  }

  void _onEndChanged(DateTime? value) {
    setState(() {
      _endDate = value;
      final DateTime? start = _startDate;
      if (start != null && value != null && !_isHalfDay) {
        final int days = _inclusiveDays(start, value);
        _setDaysText(days < 1 ? 1 : days);
      }
    });
  }

  void _onHalfDayChanged(bool? value) {
    final bool isHalfDay = value == true;
    setState(() {
      _isHalfDay = isHalfDay;
      if (isHalfDay) {
        _setDaysText(1);
        final DateTime? start = _startDate;
        if (start != null) {
          _endDate = DateTime(start.year, start.month, start.day);
        }
        _halfDayPeriod ??= 'MORNING';
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
    ];
  }

  List<AppSelectOption<String>> get _halfDayPeriodOptions {
    final AppLocalizations l10n = context.l10n;
    if (widget.referenceData.leaveHalfDayPeriods.isNotEmpty) {
      return <AppSelectOption<String>>[
        for (final HrOption option in widget.referenceData.leaveHalfDayPeriods)
          AppSelectOption<String>(
            value: option.value,
            label: l10n.hrLocalizedOptionLabel(option),
          ),
      ];
    }
    return <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: 'MORNING',
        label: l10n.hrReferenceLeaveHalfDayPeriodMorning,
      ),
      AppSelectOption<String>(
        value: 'AFTERNOON',
        label: l10n.hrReferenceLeaveHalfDayPeriodAfternoon,
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
    if (_isHalfDay) {
      if ((_halfDayPeriod ?? '').trim().isEmpty) {
        return l10n.hrFieldRequiredLabel(l10n.hrLeaveHalfDayPeriodLabel);
      }
      if (_inclusiveDays(_startDate!, _endDate!) != 1) {
        return l10n.hrLeaveHalfDaySingleDayError;
      }
    }
    return null;
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'leave_type': _leaveType,
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
      'is_half_day': _isHalfDay,
      if (_isHalfDay) 'half_day_period': _halfDayPeriod,
      'reason': _reasonController.text.trim(),
      'handover_notes': _handoverController.text.trim(),
      if ((_coveringStaffId ?? '').trim().isNotEmpty)
        'covering_staff_profile_id': _coveringStaffId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>(
          value: _leaveType,
          labelText: l10n.hrLeaveTypeLabel,
          isRequired: true,
          options: _leaveTypeOptions,
          onChanged: (String? value) => setState(() => _leaveType = value),
        ),
        AppDateField(
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
        AppCheckboxField(
          title: l10n.hrLeaveHalfDayLabel,
          subtitle: l10n.hrLeaveHalfDayHelper,
          value: _isHalfDay,
          onChanged: _onHalfDayChanged,
        ),
        if (_isHalfDay)
          AppSelectField<String>(
            value: _halfDayPeriod,
            labelText: l10n.hrLeaveHalfDayPeriodLabel,
            isRequired: true,
            options: _halfDayPeriodOptions,
            onChanged: (String? value) =>
                setState(() => _halfDayPeriod = value),
          ),
        if (!_isHalfDay)
          AppTextField(
            controller: _daysController,
            labelText: l10n.hrLeaveDaysLabel,
            helperText: l10n.hrLeaveDaysHelper,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _onDaysChanged,
          ),
        AppDateField(
          value: _endDate,
          labelText: l10n.hrEndDateLabel,
          isRequired: true,
          enabled: !_isHalfDay,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: _onEndChanged,
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
