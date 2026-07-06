import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

const String kLabReferenceRangeAnyGender = '__ANY__';

class EditableLabReferenceRange {
  EditableLabReferenceRange({LabReferenceRange? range, String? defaultUnit})
    : id = range?.id,
      labelController = TextEditingController(text: range?.label ?? ''),
      ageMinController = TextEditingController(
        text: range?.ageMinValue?.toString() ?? '',
      ),
      ageMaxController = TextEditingController(
        text: range?.ageMaxValue?.toString() ?? '',
      ),
      rangeUnitController = TextEditingController(
        text: range?.unit ?? defaultUnit ?? '',
      ),
      normalMinController = TextEditingController(
        text: range?.normalMinValue ?? '',
      ),
      normalMaxController = TextEditingController(
        text: range?.normalMaxValue ?? '',
      ),
      criticalMinController = TextEditingController(
        text: range?.criticalMinValue ?? '',
      ),
      criticalMaxController = TextEditingController(
        text: range?.criticalMaxValue ?? '',
      ),
      referenceTextController = TextEditingController(
        text: range?.referenceText ?? '',
      ),
      notesController = TextEditingController(text: range?.notes ?? ''),
      gender = range?.gender ?? kLabReferenceRangeAnyGender,
      ageUnit = range?.ageMinUnit ?? range?.ageMaxUnit ?? 'YEAR';

  String? id;
  final TextEditingController labelController;
  final TextEditingController ageMinController;
  final TextEditingController ageMaxController;
  final TextEditingController rangeUnitController;
  final TextEditingController normalMinController;
  final TextEditingController normalMaxController;
  final TextEditingController criticalMinController;
  final TextEditingController criticalMaxController;
  final TextEditingController referenceTextController;
  final TextEditingController notesController;
  String? gender;
  String? ageUnit;

  void dispose() {
    labelController.dispose();
    ageMinController.dispose();
    ageMaxController.dispose();
    rangeUnitController.dispose();
    normalMinController.dispose();
    normalMaxController.dispose();
    criticalMinController.dispose();
    criticalMaxController.dispose();
    referenceTextController.dispose();
    notesController.dispose();
  }

  Map<String, Object?> toPayload({
    required int sortOrder,
    required String fallbackUnit,
  }) {
    return <String, Object?>{
      if (id != null) 'id': id,
      'label': labelController.text.trim(),
      if (gender != null && gender != kLabReferenceRangeAnyGender)
        'gender': gender,
      'age_min_value': ageMinController.text.trim(),
      'age_min_unit': ageMinController.text.trim().isEmpty ? null : ageUnit,
      'age_max_value': ageMaxController.text.trim(),
      'age_max_unit': ageMaxController.text.trim().isEmpty ? null : ageUnit,
      'unit': rangeUnitController.text.trim().isEmpty
          ? fallbackUnit
          : rangeUnitController.text.trim(),
      'normal_min_value': normalMinController.text.trim(),
      'normal_max_value': normalMaxController.text.trim(),
      'critical_min_value': criticalMinController.text.trim(),
      'critical_max_value': criticalMaxController.text.trim(),
      'reference_text': referenceTextController.text.trim(),
      'notes': notesController.text.trim(),
      'sort_order': sortOrder,
    };
  }

  bool hasContent(String fallbackUnit) {
    final Map<String, Object?> payload = toPayload(
      sortOrder: 0,
      fallbackUnit: fallbackUnit,
    );
    return payload.entries.any((MapEntry<String, Object?> entry) {
      if (entry.key == 'id' ||
          entry.key == 'sort_order' ||
          entry.key == 'unit' ||
          entry.key == 'age_min_unit' ||
          entry.key == 'age_max_unit') {
        return false;
      }
      final Object? value = entry.value;
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  bool isValid() {
    return _isRangeValid(
          normalMinController.text,
          normalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          criticalMinController.text,
          criticalMaxController.text,
          allowEqual: true,
        ) &&
        _isRangeValid(
          ageMinController.text,
          ageMaxController.text,
          allowEqual: false,
        );
  }

  bool _isRangeValid(
    String minValue,
    String maxValue, {
    required bool allowEqual,
  }) {
    final String minText = minValue.trim();
    final String maxText = maxValue.trim();
    if (minText.isEmpty || maxText.isEmpty) {
      return true;
    }
    final num? minNumber = num.tryParse(minText);
    final num? maxNumber = num.tryParse(maxText);
    if (minNumber == null || maxNumber == null) {
      return false;
    }
    return allowEqual ? minNumber <= maxNumber : minNumber < maxNumber;
  }
}

class LabReferenceRangeListField extends StatelessWidget {
  const LabReferenceRangeListField({
    required this.ranges,
    required this.enabled,
    required this.fallbackUnit,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<EditableLabReferenceRange> ranges;
  final bool enabled;
  final String fallbackUnit;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<EditableLabReferenceRange> onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.labReferenceRangeOverrideLabel,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              l10n.labReferenceRangeCount(ranges.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        for (int index = 0; index < ranges.length; index++)
          _LabReferenceRangeCard(
            key: ValueKey<String>(ranges[index].id ?? 'new-range-$index'),
            range: ranges[index],
            index: index,
            enabled: enabled,
            canRemove: ranges.length > 1,
            onChanged: onChanged,
            onRemove: () => onRemove(ranges[index]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.tertiary(
            label: l10n.labAddReferenceRangeAction,
            enabled: enabled,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

class _LabReferenceRangeCard extends StatelessWidget {
  const _LabReferenceRangeCard({
    required this.range,
    required this.index,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final EditableLabReferenceRange range;
  final int index;
  final bool enabled;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String title = range.labelController.text.trim().isEmpty
        ? l10n.labReferenceRangeCount(index + 1)
        : range.labelController.text.trim();

    return Card(
      margin: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (canRemove)
                  IconButton(
                    tooltip: l10n.commonRemoveActionLabel,
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            AppTextField(
              controller: range.labelController,
              labelText: l10n.labReferenceRangeLabel,
              enabled: enabled,
              prefixIcon: const Icon(Icons.label_outline),
              onChanged: (_) => onChanged(),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppSelectField<String>.searchable(
                value: range.gender,
                labelText: l10n.labGenderApplicabilityLabel,
                enabled: enabled,
                allowClear: false,
                options: <AppSelectOption<String>>[
                  AppSelectOption<String>(
                    value: kLabReferenceRangeAnyGender,
                    label: l10n.labGenderAnyLabel,
                    leadingIcon: const Icon(Icons.people_outline),
                  ),
                  AppSelectOption<String>(
                    value: 'MALE',
                    label: l10n.labGenderMaleLabel,
                    leadingIcon: const Icon(Icons.male),
                  ),
                  AppSelectOption<String>(
                    value: 'FEMALE',
                    label: l10n.labGenderFemaleLabel,
                    leadingIcon: const Icon(Icons.female),
                  ),
                  AppSelectOption<String>(
                    value: 'OTHER',
                    label: l10n.labGenderOtherLabel,
                    leadingIcon: const Icon(Icons.diversity_3_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'UNKNOWN',
                    label: l10n.labGenderUnknownLabel,
                    leadingIcon: const Icon(Icons.help_outline),
                  ),
                ],
                onChanged: (String? value) {
                  range.gender = value ?? kLabReferenceRangeAnyGender;
                  onChanged();
                },
              ),
              right: AppSelectField<String>.searchable(
                value: range.ageUnit,
                labelText: l10n.labAgeUnitLabel,
                enabled: enabled,
                allowClear: false,
                options: <AppSelectOption<String>>[
                  AppSelectOption<String>(
                    value: 'DAY',
                    label: l10n.labAgeUnitDays,
                    leadingIcon: const Icon(Icons.today_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'WEEK',
                    label: l10n.labAgeUnitWeeks,
                    leadingIcon: const Icon(Icons.view_week_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'MONTH',
                    label: l10n.labAgeUnitMonths,
                    leadingIcon: const Icon(Icons.calendar_view_month_outlined),
                  ),
                  AppSelectOption<String>(
                    value: 'YEAR',
                    label: l10n.labAgeUnitYears,
                    leadingIcon: const Icon(Icons.event_outlined),
                  ),
                ],
                onChanged: (String? value) {
                  range.ageUnit = value;
                  onChanged();
                },
              ),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: range.ageMinController,
                labelText: l10n.labAgeMinLabel,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              right: AppTextField(
                controller: range.ageMaxController,
                labelText: l10n.labAgeMaxLabel,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
            AppTextField(
              controller: range.rangeUnitController,
              labelText: l10n.labResultUnitLabel,
              enabled: enabled,
              prefixIcon: const Icon(Icons.straighten_outlined),
              onChanged: (_) => onChanged(),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: range.normalMinController,
                labelText: l10n.labNormalMinLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              right: AppTextField(
                controller: range.normalMaxController,
                labelText: l10n.labNormalMaxLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            AppResponsiveFieldRow.two(
              gap: AppResponsiveFieldRowGap.form,
              left: AppTextField(
                controller: range.criticalMinController,
                labelText: l10n.labCriticalMinLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              right: AppTextField(
                controller: range.criticalMaxController,
                labelText: l10n.labCriticalMaxLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ),
            AppTextField(
              controller: range.referenceTextController,
              labelText: l10n.labReferenceTextLabel,
              enabled: enabled,
              maxLines: 2,
            ),
            AppTextField(
              controller: range.notesController,
              labelText: l10n.labReferenceNotesLabel,
              enabled: enabled,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
