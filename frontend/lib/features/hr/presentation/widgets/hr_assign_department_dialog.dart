import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Global entry point for assigning a staff member to facility structure.
Future<void> showHrAssignDepartmentDialog(
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

  final GlobalKey<_HrAssignDepartmentFieldsState> fieldsKey =
      GlobalKey<_HrAssignDepartmentFieldsState>();

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignDepartmentDialogTitle),
    icon: const Icon(Icons.account_tree_outlined),
    submitLabel: l10n.hrAssignDepartmentAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return _HrAssignDepartmentFields(
            key: fieldsKey,
            referenceData: referenceData,
          );
        },
    onSubmit: () => controller.createAssignment(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

class _HrAssignDepartmentFields extends StatefulWidget {
  const _HrAssignDepartmentFields({required this.referenceData, super.key});

  final HrReferenceData referenceData;

  @override
  State<_HrAssignDepartmentFields> createState() =>
      _HrAssignDepartmentFieldsState();
}

class _HrAssignDepartmentFieldsState extends State<_HrAssignDepartmentFields> {
  String? _departmentId;
  String? _unitId;
  final Set<String> _roomIds = <String>{};
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  Map<String, Object?> toPayload() {
    final List<String> roomIds = _roomIds.toList(growable: false);
    return <String, Object?>{
      'department_id': _departmentId,
      'unit_id': _unitId,
      if (roomIds.isNotEmpty) 'room_ids': roomIds,
      'start_date': _datePayload(_startDate),
      'end_date': _datePayload(_endDate),
    };
  }

  void _onDepartmentChanged(String? value) {
    setState(() {
      _departmentId = value;
      _unitId = null;
      _roomIds.clear();
    });
  }

  List<HrOption> get _scopedUnits =>
      _scopedOptions(widget.referenceData.units, departmentId: _departmentId);

  List<HrOption> get _scopedRooms =>
      _scopedOptions(widget.referenceData.rooms, departmentId: _departmentId);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _departmentId,
          labelText: l10n.hrDepartmentLabel,
          isRequired: true,
          options: hrSelectOptions(widget.referenceData.departments),
          validator: AppValidators.requiredValue(
            l10n.hrFieldRequiredLabel(l10n.hrDepartmentLabel),
          ),
          onChanged: _onDepartmentChanged,
        ),
        AppSelectField<String>.searchable(
          value: _unitId,
          labelText: l10n.hrUnitLabel,
          options: hrSelectOptions(_scopedUnits),
          onChanged: (String? value) => setState(() => _unitId = value),
        ),
        if (_departmentId != null && _scopedRooms.isNotEmpty) ...<Widget>[
          Text(l10n.hrRoomsLabel, style: theme.textTheme.titleSmall),
          SizedBox(height: theme.spacing.xs),
          _HrRoomMultiSelectHeader(
            selectAllLabel: l10n.hrSelectAllRoomsAction,
            clearLabel: l10n.hrClearRoomsAction,
            onSelectAll: () {
              setState(() {
                _roomIds
                  ..clear()
                  ..addAll(_scopedRooms.map((HrOption room) => room.value));
              });
            },
            onClear: () => setState(_roomIds.clear),
          ),
          for (final HrOption room in _scopedRooms)
            AppCheckboxField(
              title: room.label,
              value: _roomIds.contains(room.value),
              onChanged: (bool checked) {
                setState(() {
                  if (checked) {
                    _roomIds.add(room.value);
                  } else {
                    _roomIds.remove(room.value);
                  }
                });
              },
            ),
        ],
        AppDateField(
          value: _startDate,
          labelText: l10n.hrStartDateLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _startDate = value),
        ),
        AppDateField(
          value: _endDate,
          labelText: l10n.hrEndDateLabel,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) => setState(() => _endDate = value),
        ),
      ],
    );
  }
}

class _HrRoomMultiSelectHeader extends StatelessWidget {
  const _HrRoomMultiSelectHeader({
    required this.selectAllLabel,
    required this.clearLabel,
    required this.onSelectAll,
    required this.onClear,
  });

  final String selectAllLabel;
  final String clearLabel;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppButton.secondary(label: selectAllLabel, onPressed: onSelectAll),
        AppButton.secondary(label: clearLabel, onPressed: onClear),
      ],
    );
  }
}

List<HrOption> _scopedOptions(List<HrOption> options, {String? departmentId}) {
  final String selectedDepartment = departmentId?.trim() ?? '';
  return <HrOption>[
    for (final HrOption option in options)
      if (selectedDepartment.isEmpty ||
          (option.extra['department_id']?.toString().trim() ?? '').isEmpty ||
          option.extra['department_id'] == selectedDepartment)
        option,
  ];
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String().split('T').first;
}
