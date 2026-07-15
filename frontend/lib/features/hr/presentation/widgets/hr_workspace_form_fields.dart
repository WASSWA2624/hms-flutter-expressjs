import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class HrShiftAssignmentFields extends StatefulWidget {
  const HrShiftAssignmentFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<HrShiftAssignmentFields> createState() =>
      HrShiftAssignmentFieldsState();
}

class HrShiftAssignmentFieldsState extends State<HrShiftAssignmentFields> {
  String? _shiftId;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'shift_id': _shiftId ?? '',
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _shiftId,
          labelText: l10n.hrSelectShiftLabel,
          hintText: l10n.hrSelectShiftHint,
          isRequired: true,
          options: hrShiftSelectOptions(widget.referenceData.shifts),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrSelectShiftLabel),
          ),
          onChanged: (String? value) => setState(() => _shiftId = value),
        ),
      ],
    );
  }
}

class HrShiftSwapFields extends StatefulWidget {
  const HrShiftSwapFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<HrShiftSwapFields> createState() => HrShiftSwapFieldsState();
}

class HrShiftSwapFieldsState extends State<HrShiftSwapFields> {
  String? _shiftId;
  String? _targetStaffId;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'shift_id': _shiftId ?? '',
      'target_staff_id': _targetStaffId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _shiftId,
          labelText: l10n.hrSelectShiftLabel,
          hintText: l10n.hrSelectShiftHint,
          isRequired: true,
          options: hrShiftSelectOptions(widget.referenceData.shifts),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrSelectShiftLabel),
          ),
          onChanged: (String? value) => setState(() => _shiftId = value),
        ),
        AppSelectField<String>.searchable(
          value: _targetStaffId,
          labelText: l10n.hrTargetStaffLabel,
          options: hrSelectOptions(widget.referenceData.staffProfiles),
          onChanged: (String? value) => setState(() => _targetStaffId = value),
        ),
      ],
    );
  }
}

class HrReasonFields extends StatefulWidget {
  const HrReasonFields({required this.requiredReason, super.key});

  final bool requiredReason;

  @override
  State<HrReasonFields> createState() => HrReasonFieldsState();
}

class HrReasonFieldsState extends State<HrReasonFields> {
  final TextEditingController _reasonController = TextEditingController();

  String get reason => _reasonController.text.trim();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          isRequired: widget.requiredReason,
          maxLines: 3,
          validator: widget.requiredReason
              ? AppValidators.requiredText(
                  l10n.hrFieldRequiredLabel(l10n.hrReasonLabel),
                )
              : null,
        ),
      ],
    );
  }
}

class HrRosterPublishFields extends StatefulWidget {
  const HrRosterPublishFields({super.key});

  @override
  State<HrRosterPublishFields> createState() => HrRosterPublishFieldsState();
}

class HrRosterPublishFieldsState extends State<HrRosterPublishFields> {
  final TextEditingController _noteController = TextEditingController();
  bool _notifyStaff = true;
  bool _allowPartial = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'notify_staff': _notifyStaff,
      'allow_partial_publish': _allowPartial,
      'publish_note': _noteController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppCheckboxField(
          title: l10n.hrNotifyStaffLabel,
          value: _notifyStaff,
          onChanged: (bool value) => setState(() => _notifyStaff = value),
        ),
        AppCheckboxField(
          title: l10n.hrAllowPartialPublishLabel,
          value: _allowPartial,
          onChanged: (bool value) => setState(() => _allowPartial = value),
        ),
        AppTextField(
          controller: _noteController,
          labelText: l10n.hrPublishNoteLabel,
          maxLines: 3,
        ),
      ],
    );
  }
}

class HrOverrideShiftFields extends StatefulWidget {
  const HrOverrideShiftFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<HrOverrideShiftFields> createState() => HrOverrideShiftFieldsState();
}

class HrOverrideShiftFieldsState extends State<HrOverrideShiftFields> {
  final TextEditingController _reasonController = TextEditingController();
  String? _staffProfileId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'staff_profile_id': _staffProfileId,
      'reason': _reasonController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _staffProfileId,
          labelText: l10n.hrStaffLabel,
          isRequired: true,
          options: hrSelectOptions(widget.referenceData.staffProfiles),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrStaffLabel),
          ),
          onChanged: (String? value) => setState(() => _staffProfileId = value),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.hrReasonLabel,
          isRequired: true,
          maxLines: 3,
          validator: AppValidators.requiredText(
            l10n.hrFieldRequiredLabel(l10n.hrReasonLabel),
          ),
        ),
      ],
    );
  }
}

class HrProcessPayrollFields extends StatefulWidget {
  const HrProcessPayrollFields({super.key});

  @override
  State<HrProcessPayrollFields> createState() => HrProcessPayrollFieldsState();
}

class HrProcessPayrollFieldsState extends State<HrProcessPayrollFields> {
  final TextEditingController _notesController = TextEditingController();
  bool _replaceExistingItems = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'replace_existing_items': _replaceExistingItems,
      'notes': _notesController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        AppCheckboxField(
          title: l10n.hrReplacePayrollItemsLabel,
          value: _replaceExistingItems,
          onChanged: (bool value) {
            setState(() => _replaceExistingItems = value);
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.hrNotesLabel,
          maxLines: 3,
        ),
      ],
    );
  }
}

List<AppSelectOption<String>> hrShiftSelectOptions(List<HrOption> options) {
  return <AppSelectOption<String>>[
    for (final HrOption option in options)
      AppSelectOption<String>(
        value: option.value,
        label: option.label,
        searchText: _shiftSearchText(option),
      ),
  ];
}

String _shiftSearchText(HrOption option) {
  final List<String> parts = <String>[
    option.label,
    if (option.displayId != null) option.displayId!,
    for (final Object? value in option.extra.values)
      if (value != null) value.toString(),
  ];
  return parts.where((String part) => part.isNotEmpty).join(' ');
}
