import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const double _kAssignDepartmentTwoColumnBreakpoint = 560;

/// Global entry point for assigning a staff member to facility structure.
Future<void> showHrAssignDepartmentDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!HrHumanResourcesAtomPermissions.assignDepartment.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  await controller.ensureAssignmentReferenceData();

  final HrWorkspaceState? workspace =
      ref
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
  final bool isChange =
      selectedStaff != null && staffHasAssignedDepartment(selectedStaff);

  final GlobalKey<_HrAssignDepartmentFieldsState> fieldsKey =
      GlobalKey<_HrAssignDepartmentFieldsState>();

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(
      isChange
          ? l10n.hrChangeDepartmentDialogTitle
          : l10n.hrAssignDepartmentDialogTitle,
    ),
    icon: const Icon(Icons.account_tree_outlined),
    submitLabel: isChange
        ? l10n.hrChangeDepartmentAction
        : l10n.hrAssignDepartmentAction,
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
            selectedStaff: selectedStaff,
            isChange: isChange,
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
  const _HrAssignDepartmentFields({
    required this.referenceData,
    required this.selectedStaff,
    required this.isChange,
    super.key,
  });

  final HrReferenceData referenceData;
  final HrStaffDetail? selectedStaff;
  final bool isChange;

  @override
  State<_HrAssignDepartmentFields> createState() =>
      _HrAssignDepartmentFieldsState();
}

class _HrAssignDepartmentFieldsState extends State<_HrAssignDepartmentFields> {
  late String? _departmentId;
  late String? _unitId;
  late final Set<String> _roomIds;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final HrStaffDetail? detail = widget.selectedStaff;
    if (widget.isChange && detail != null) {
      final HrStaffAssignment? current =
          resolveCurrentDepartmentAssignment(detail);
      final String? rawDepartmentId =
          (current?.departmentId ?? detail.profile.departmentId)?.trim();
      final String? departmentDisplayId =
          (current?.departmentDisplayId ?? detail.profile.departmentDisplayId)
              ?.trim();
      _departmentId =
          resolveHrOptionValue(
            options: widget.referenceData.departments,
            candidates: <String?>[departmentDisplayId, rawDepartmentId],
          ) ??
          (departmentDisplayId?.isNotEmpty == true
              ? departmentDisplayId
              : rawDepartmentId);
      if (_departmentId != null && _departmentId!.isEmpty) {
        _departmentId = null;
      }

      final String? rawUnitId = current?.unitId?.trim();
      final String? unitDisplayId = current?.unitDisplayId?.trim();
      _unitId =
          resolveHrOptionValue(
            options: widget.referenceData.units,
            candidates: <String?>[unitDisplayId, rawUnitId],
          ) ??
          (unitDisplayId?.isNotEmpty == true ? unitDisplayId : rawUnitId);
      if (_unitId != null && _unitId!.isEmpty) {
        _unitId = null;
      }

      final Set<String> rawRoomIds = resolveCurrentAssignmentRoomIds(detail);
      _roomIds = <String>{
        for (final String roomId in rawRoomIds)
          resolveHrOptionValue(
                options: widget.referenceData.rooms,
                candidates: <String?>[roomId],
              ) ??
              roomId,
      };
    } else {
      _departmentId = null;
      _unitId = null;
      _roomIds = <String>{};
    }
  }

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

  List<HrOption> get _scopedUnits => _scopedOptions(
    widget.referenceData.units,
    departmentId: _departmentId,
    departments: widget.referenceData.departments,
  );

  List<HrOption> get _scopedRooms => _scopedOptions(
    widget.referenceData.rooms,
    departmentId: _departmentId,
    departments: widget.referenceData.departments,
  );

  List<AppSelectOption<String>> _departmentOptions() {
    final List<AppSelectOption<String>> options = hrSelectOptions(
      widget.referenceData.departments,
    );
    final String? currentId = _departmentId;
    if (currentId == null || currentId.isEmpty) {
      return options;
    }
    if (options.any((AppSelectOption<String> o) => o.value == currentId)) {
      return options;
    }
    final HrStaffDetail? detail = widget.selectedStaff;
    final HrStaffAssignment? current = detail == null
        ? null
        : resolveCurrentDepartmentAssignment(detail);
    final String label =
        (current?.departmentName ??
                current?.departmentDisplayId ??
                detail?.profile.departmentName ??
                detail?.profile.departmentDisplayId ??
                currentId)
            .trim();
    return <AppSelectOption<String>>[
      ...options,
      AppSelectOption<String>(
        value: currentId,
        label: label.isEmpty ? currentId : label,
      ),
    ];
  }

  List<AppSelectOption<String>> _unitOptions() {
    final List<AppSelectOption<String>> options = hrSelectOptions(_scopedUnits);
    final String? currentId = _unitId;
    if (currentId == null || currentId.isEmpty) {
      return options;
    }
    if (options.any((AppSelectOption<String> o) => o.value == currentId)) {
      return options;
    }
    final HrStaffDetail? detail = widget.selectedStaff;
    final HrStaffAssignment? current = detail == null
        ? null
        : resolveCurrentDepartmentAssignment(detail);
    final String label =
        (current?.unitName ?? current?.unitDisplayId ?? currentId).trim();
    return <AppSelectOption<String>>[
      ...options,
      AppSelectOption<String>(
        value: currentId,
        label: label.isEmpty ? currentId : label,
      ),
    ];
  }

  Widget _responsivePair({required Widget left, required Widget right}) {
    return AppResponsiveFieldRow.two(
      left: left,
      right: right,
      breakpoint: _kAssignDepartmentTwoColumnBreakpoint,
      gap: AppResponsiveFieldRowGap.form,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormSection(
      children: <Widget>[
        _responsivePair(
          left: AppSelectField<String>.searchable(
            value: _departmentId,
            labelText: l10n.hrDepartmentLabel,
            isRequired: true,
            options: _departmentOptions(),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrDepartmentLabel),
            ),
            onChanged: _onDepartmentChanged,
          ),
          right: AppSelectField<String>.searchable(
            value: _unitId,
            labelText: l10n.hrUnitLabel,
            options: _unitOptions(),
            onChanged: (String? value) => setState(() => _unitId = value),
          ),
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
        _responsivePair(
          left: AppDateField(
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
          right: AppDateField(
            value: _endDate,
            labelText: l10n.hrEndDateLabel,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            currentDate: DateTime.now(),
            pickerButtonLabel: l10n.hrPickDateAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            onChanged: (DateTime? value) => setState(() => _endDate = value),
          ),
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

List<HrOption> _scopedOptions(
  List<HrOption> options, {
  String? departmentId,
  List<HrOption> departments = const <HrOption>[],
}) {
  final String selectedDepartment = departmentId?.trim() ?? '';
  if (selectedDepartment.isEmpty) {
    return options;
  }
  final String? entityId = hrOptionEntityId(departments, selectedDepartment);
  final Set<String> matchIds = <String>{
    selectedDepartment,
    if (entityId != null && entityId.isNotEmpty) entityId,
  };
  return <HrOption>[
    for (final HrOption option in options)
      if ((option.extra['department_id']?.toString().trim() ?? '').isEmpty ||
          matchIds.contains(
            option.extra['department_id']?.toString().trim() ?? '',
          ))
        option,
  ];
}

String? _datePayload(DateTime? value) {
  if (value == null) {
    return null;
  }
  return value.toIso8601String().split('T').first;
}
