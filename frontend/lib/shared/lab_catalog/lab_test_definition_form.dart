import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_fields.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

/// Shared result-kind options for lab test create/edit/configure forms.
List<AppSelectOption<String>> labResultKindSelectOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'NUMERIC',
      label: l10n.labResultKindNumeric,
      leadingIcon: const Icon(Icons.pin_outlined),
    ),
    AppSelectOption<String>(
      value: 'QUALITATIVE',
      label: l10n.labResultKindQualitative,
      leadingIcon: const Icon(Icons.checklist_outlined),
    ),
    AppSelectOption<String>(
      value: 'TEXT',
      label: l10n.labResultKindText,
      leadingIcon: const Icon(Icons.notes_outlined),
    ),
  ];
}

List<AppSelectOption<String>> _stringSelectOptions(
  Iterable<String> values, {
  IconData? icon,
}) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: value,
        leadingIcon: icon == null ? null : Icon(icon),
      ),
  ];
}

String? _selectValueOrNull(TextEditingController controller) {
  final String trimmed = controller.text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Chronological lab-test definition fields used by catalog create/edit and
/// facility configure dialogs.
class LabTestDefinitionForm extends StatelessWidget {
  const LabTestDefinitionForm({
    required this.nameController,
    required this.codeController,
    required this.categoryController,
    required this.specimenController,
    required this.unitController,
    required this.descriptionController,
    required this.resultKind,
    required this.onResultKindChanged,
    required this.unitOptions,
    required this.resultOptions,
    required this.referenceRanges,
    required this.categoryOptions,
    required this.specimenOptions,
    required this.unitSuggestions,
    required this.resultSuggestions,
    required this.enabled,
    required this.onUnitOptionAdd,
    required this.onUnitOptionRemove,
    required this.onResultOptionAdd,
    required this.onResultOptionRemove,
    required this.onRangesChanged,
    required this.onRangeAdd,
    required this.onRangeRemove,
    this.nameEnabled = true,
    this.codeEnabled = true,
    this.nameValidator,
    this.codeValidator,
    this.nameErrorText,
    this.codeErrorText,
    this.rangeErrorText,
    this.namePrefixIcon = const Icon(Icons.biotech_outlined),
    this.density = AppFormSectionDensity.regular,
    this.showReferenceRanges = true,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController categoryController;
  final TextEditingController specimenController;
  final TextEditingController unitController;
  final TextEditingController descriptionController;
  final String? resultKind;
  final ValueChanged<String?> onResultKindChanged;
  final List<EditableLabValue> unitOptions;
  final List<EditableLabValue> resultOptions;
  final List<EditableLabReferenceRange> referenceRanges;
  final List<String> categoryOptions;
  final List<String> specimenOptions;
  final List<String> unitSuggestions;
  final List<String> resultSuggestions;
  final bool enabled;
  final bool nameEnabled;
  final bool codeEnabled;
  final FormFieldValidator<String>? nameValidator;
  final FormFieldValidator<String>? codeValidator;
  final String? nameErrorText;
  final String? codeErrorText;
  final String? rangeErrorText;
  final Widget namePrefixIcon;
  final ValueChanged<String> onUnitOptionAdd;
  final ValueChanged<EditableLabValue> onUnitOptionRemove;
  final ValueChanged<String> onResultOptionAdd;
  final ValueChanged<EditableLabValue> onResultOptionRemove;
  final VoidCallback onRangesChanged;
  final VoidCallback onRangeAdd;
  final ValueChanged<EditableLabReferenceRange> onRangeRemove;
  final AppFormSectionDensity density;
  final bool showReferenceRanges;

  bool get _isNumeric => resultKind == 'NUMERIC';
  bool get _isQualitative => resultKind == 'QUALITATIVE';
  bool get _showsUnit => _isNumeric || _isQualitative;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> categories = labUniqueNonEmpty(<String?>[
      ...categoryOptions,
      categoryController.text,
    ]);
    final List<String> specimens = labUniqueNonEmpty(<String?>[
      ...specimenOptions,
      specimenController.text,
    ]);
    final List<String> units = labUniqueNonEmpty(<String?>[
      ...unitSuggestions,
      unitController.text,
    ]);

    return AppFormSection(
      density: density,
      children: <Widget>[
        AppFormSection(
          title: l10n.labTestIdentitySectionTitle,
          description: l10n.labTestIdentitySectionBody,
          density: density,
          children: <Widget>[
            AppTextField(
              controller: nameController,
              labelText: l10n.labTestNameLabel,
              enabled: enabled && nameEnabled,
              isRequired: true,
              prefixIcon: namePrefixIcon,
              errorText: nameErrorText,
              validator: nameValidator,
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: codeController,
                labelText: l10n.labTestCodeLabel,
                enabled: enabled && codeEnabled,
                prefixIcon: const Icon(Icons.tag_outlined),
                errorText: codeErrorText,
                validator: codeValidator,
              ),
              right: AppSelectField<String>.searchable(
                value: _selectValueOrNull(categoryController),
                labelText: l10n.labCategoryLabel,
                enabled: enabled,
                allowClear: true,
                options: _stringSelectOptions(
                  categories,
                  icon: Icons.category_outlined,
                ),
                onChanged: (String? value) {
                  categoryController.text = value?.trim() ?? '';
                  onRangesChanged();
                },
              ),
            ),
          ],
        ),
        AppFormSection(
          title: l10n.labTestResultSectionTitle,
          description: l10n.labTestResultSectionBody,
          density: density,
          children: <Widget>[
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppSelectField<String>.searchable(
                value: _selectValueOrNull(specimenController),
                labelText: l10n.labSpecimenTypeLabel,
                enabled: enabled,
                allowClear: true,
                options: _stringSelectOptions(
                  specimens,
                  icon: Icons.bloodtype_outlined,
                ),
                onChanged: (String? value) {
                  specimenController.text = value?.trim() ?? '';
                  onRangesChanged();
                },
              ),
              right: AppSelectField<String>.searchable(
                value: resultKind,
                labelText: l10n.labResultKindLabel,
                enabled: enabled,
                allowClear: false,
                isRequired: true,
                validator: AppValidators.requiredValue(l10n.validationRequired),
                options: labResultKindSelectOptions(l10n),
                onChanged: onResultKindChanged,
              ),
            ),
            if (_showsUnit)
              AppSelectField<String>.searchable(
                value: _selectValueOrNull(unitController),
                labelText: l10n.labDefaultUnitLabel,
                enabled: enabled,
                allowClear: true,
                options: _stringSelectOptions(
                  units,
                  icon: Icons.straighten_outlined,
                ),
                onChanged: (String? value) {
                  unitController.text = value?.trim() ?? '';
                  onRangesChanged();
                },
              ),
            if (_isNumeric)
              LabEditableValueListField(
                labelText: l10n.labUnitOptionsLabel,
                values: unitOptions,
                suggestions: unitSuggestions,
                enabled: enabled,
                onAdd: onUnitOptionAdd,
                onRemove: onUnitOptionRemove,
              ),
            if (_isQualitative)
              LabEditableValueListField(
                labelText: l10n.labQualitativeOptionsLabel,
                values: resultOptions,
                suggestions: resultSuggestions,
                enabled: enabled,
                onAdd: onResultOptionAdd,
                onRemove: onResultOptionRemove,
              ),
            AppTextField(
              controller: descriptionController,
              labelText: l10n.labTestDescriptionLabel,
              enabled: enabled,
              maxLines: 2,
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ],
        ),
        if (showReferenceRanges)
          AppFormSection(
            title: l10n.labTestRangesSectionTitle,
            description: l10n.labTestRangesSectionBody,
            density: density,
            children: <Widget>[
              if (rangeErrorText != null && rangeErrorText!.trim().isNotEmpty)
                AppFormInformationBanner(
                  title: l10n.labReferenceRangeOverrideLabel,
                  message: rangeErrorText!,
                  variant: AppFormInformationVariant.error,
                  icon: Icons.error_outline,
                ),
              LabReferenceRangeListField(
                ranges: referenceRanges,
                enabled: enabled,
                fallbackUnit: unitController.text.trim(),
                showHeader: false,
                onChanged: onRangesChanged,
                onAdd: onRangeAdd,
                onRemove: onRangeRemove,
              ),
            ],
          ),
      ],
    );
  }
}
