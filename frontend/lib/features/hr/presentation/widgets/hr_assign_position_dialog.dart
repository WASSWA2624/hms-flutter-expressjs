import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Global entry point for assigning a job position to a staff profile.
Future<void> showHrAssignPositionDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  await controller.ensureOnboardingReferenceData();

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

  final GlobalKey<_HrAssignPositionFieldsState> fieldsKey =
      GlobalKey<_HrAssignPositionFieldsState>();

  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrAssignPositionDialogTitle),
    icon: const Icon(Icons.work_outline),
    submitLabel: l10n.hrAssignPositionAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.save_outlined,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> formKey,
          bool _, [
          AppFailure? failure,
        ]) {
          return _HrAssignPositionFields(
            key: fieldsKey,
            staff: staff,
            referenceData: referenceData,
          );
        },
    onSubmit: () => controller.updateSelectedStaffProfile(
      fieldsKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );

  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

class _HrAssignPositionFields extends StatefulWidget {
  const _HrAssignPositionFields({
    required this.staff,
    required this.referenceData,
    super.key,
  });

  final HrStaffProfile staff;
  final HrReferenceData referenceData;

  @override
  State<_HrAssignPositionFields> createState() =>
      _HrAssignPositionFieldsState();
}

class _HrAssignPositionFieldsState extends State<_HrAssignPositionFields> {
  late final TextEditingController _newPositionController;
  String? _position;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _newPositionController = TextEditingController();
    _position = (widget.staff.position ?? '').trim().isEmpty
        ? null
        : widget.staff.position!.trim();
  }

  @override
  void dispose() {
    _newPositionController.dispose();
    super.dispose();
  }

  /// Existing positions keyed by their human name so a selection submits the
  /// position label (the `position` column is a free-text name, not an id).
  List<AppSelectOption<String>> _positionOptions() {
    final Map<String, String> byLabel = <String, String>{};
    for (final HrOption option in widget.referenceData.staffPositions) {
      final String label = option.label.trim().isEmpty
          ? option.value.trim()
          : option.label.trim();
      if (label.isNotEmpty) {
        byLabel[label] = label;
      }
    }
    final String? current = _position;
    if (current != null && current.isNotEmpty) {
      byLabel.putIfAbsent(current, () => current);
    }
    return <AppSelectOption<String>>[
      for (final String label in byLabel.keys)
        AppSelectOption<String>(value: label, label: label),
    ];
  }

  Map<String, Object?> toPayload() {
    final String position = _isAddingNew
        ? _newPositionController.text.trim()
        : (_position ?? '').trim();
    return <String, Object?>{'position': position};
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      children: <Widget>[
        if (_isAddingNew)
          AppTextField(
            controller: _newPositionController,
            labelText: l10n.hrNewPositionLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.hrFieldRequiredLabel(l10n.hrNewPositionLabel),
            ),
          )
        else
          AppSelectField<String>.searchable(
            value: _position,
            labelText: l10n.hrPositionLabel,
            isRequired: true,
            options: _positionOptions(),
            validator: AppValidators.requiredValue(
              l10n.hrFieldRequiredLabel(l10n.hrPositionLabel),
            ),
            onChanged: (String? value) => setState(() => _position = value),
          ),
        AppCheckboxField(
          title: l10n.hrAddNewPositionLabel,
          value: _isAddingNew,
          onChanged: (bool value) => setState(() => _isAddingNew = value),
        ),
      ],
    );
  }
}
