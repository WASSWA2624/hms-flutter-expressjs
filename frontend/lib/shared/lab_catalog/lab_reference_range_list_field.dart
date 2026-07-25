import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_fields.dart';

const String kLabReferenceRangeAnyGender = '__ANY__';

/// Clinical age-band preset applied to min/max/unit (and optionally the range name).
class LabAgeBandPreset {
  const LabAgeBandPreset({
    required this.id,
    required this.min,
    required this.max,
    required this.unit,
  });

  final String id;
  final int? min;
  final int? max;
  final String unit;
}

/// Standard catalog age bands used as quick-fill presets.
const List<LabAgeBandPreset> kLabAgeBandPresets = <LabAgeBandPreset>[
  LabAgeBandPreset(id: 'neonate', min: 0, max: 28, unit: 'DAY'),
  LabAgeBandPreset(id: 'infant', min: 1, max: 12, unit: 'MONTH'),
  LabAgeBandPreset(id: 'child', min: 1, max: 12, unit: 'YEAR'),
  LabAgeBandPreset(id: 'adolescent', min: 13, max: 17, unit: 'YEAR'),
  LabAgeBandPreset(id: 'adult', min: 18, max: 64, unit: 'YEAR'),
  LabAgeBandPreset(id: 'geriatric', min: 65, max: null, unit: 'YEAR'),
  LabAgeBandPreset(id: 'pediatric', min: 0, max: 17, unit: 'YEAR'),
];

String labAgeBandPresetLabel(AppLocalizations l10n, String id) {
  switch (id) {
    case 'neonate':
      return l10n.labNeonateRangeLabel;
    case 'infant':
      return l10n.labInfantRangeLabel;
    case 'child':
      return l10n.labChildRangeLabel;
    case 'adolescent':
      return l10n.labAdolescentRangeLabel;
    case 'adult':
      return l10n.labAdultRangeLabel;
    case 'geriatric':
      return l10n.labGeriatricRangeLabel;
    case 'pediatric':
      return l10n.labPediatricRangeLabel;
    default:
      return id;
  }
}

IconData labAgeBandPresetIcon(String id) {
  switch (id) {
    case 'neonate':
      return Icons.baby_changing_station_outlined;
    case 'infant':
      return Icons.child_care_outlined;
    case 'child':
      return Icons.face_outlined;
    case 'adolescent':
      return Icons.school_outlined;
    case 'adult':
      return Icons.person_outline;
    case 'geriatric':
      return Icons.elderly;
    case 'pediatric':
      return Icons.family_restroom;
    default:
      return Icons.event_outlined;
  }
}

class EditableLabReferenceRange {
  EditableLabReferenceRange({
    LabReferenceRange? range,
    String? defaultUnit,
    String? defaultLabel,
  }) : id = range?.id,
       labelController = TextEditingController(
         text: range?.label ?? defaultLabel ?? '',
       ),
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
       ageUnit = range?.ageMinUnit ?? range?.ageMaxUnit ?? 'YEAR',
       // New ranges and ranges without bounds default to All ages.
       allAges =
           range?.ageMinValue == null && range?.ageMaxValue == null;

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

  /// When true, age bounds are cleared and omitted from the payload.
  bool allAges;

  bool get appliesToAllGenders =>
      gender == null || gender == kLabReferenceRangeAnyGender;

  void setAllGenders() {
    gender = kLabReferenceRangeAnyGender;
  }

  void setSpecificGender(String value) {
    gender = value;
  }

  void setAllAges({required bool value}) {
    allAges = value;
    if (value) {
      ageMinController.clear();
      ageMaxController.clear();
    }
  }

  /// Typing into age bounds turns off "All ages".
  void syncAllAgesFromBounds() {
    final bool hasBound =
        ageMinController.text.trim().isNotEmpty ||
        ageMaxController.text.trim().isNotEmpty;
    if (hasBound) {
      allAges = false;
    } else if (!allAges) {
      // Both cleared while in specific mode → treat as all ages again.
      allAges = true;
    }
  }

  /// Quick-fill age bounds from a catalog age band; optionally seed the range name
  /// when empty or still set to the All ages default label.
  void applyAgePreset(
    LabAgeBandPreset preset, {
    String? labelIfEmpty,
    String? allAgesLabel,
  }) {
    allAges = false;
    ageUnit = preset.unit;
    ageMinController.text = preset.min?.toString() ?? '';
    ageMaxController.text = preset.max?.toString() ?? '';
    final String? seed = labelIfEmpty?.trim();
    if (seed == null || seed.isEmpty) {
      return;
    }
    final String current = labelController.text.trim();
    final String anyLabel = (allAgesLabel ?? '').trim().toLowerCase();
    if (current.isEmpty ||
        (anyLabel.isNotEmpty && current.toLowerCase() == anyLabel)) {
      labelController.text = seed;
    }
  }

  /// Returns the matching preset id when current bounds equal a catalog band.
  String? matchingAgePresetId() {
    if (allAges) {
      return null;
    }
    final String unit = (ageUnit ?? 'YEAR').trim().toUpperCase();
    final String minText = ageMinController.text.trim();
    final String maxText = ageMaxController.text.trim();
    for (final LabAgeBandPreset preset in kLabAgeBandPresets) {
      if (preset.unit != unit) {
        continue;
      }
      final String expectedMin = preset.min?.toString() ?? '';
      final String expectedMax = preset.max?.toString() ?? '';
      if (minText == expectedMin && maxText == expectedMax) {
        return preset.id;
      }
    }
    return null;
  }

  /// Only "All ages" as a range name affects age applicability — other category
  /// names stay labels and leave All ages as the default.
  void applyAgePresetFromLabel(String? label, AppLocalizations l10n) {
    final String normalized = (label ?? '').trim().toLowerCase();
    if (normalized == l10n.labAgeAnyLabel.toLowerCase()) {
      setAllAges(value: true);
    }
  }

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
    final String? ageMin = allAges
        ? null
        : _emptyToNull(ageMinController.text);
    final String? ageMax = allAges
        ? null
        : _emptyToNull(ageMaxController.text);
    final String? unit = _emptyToNull(rangeUnitController.text) ??
        _emptyToNull(fallbackUnit);
    return <String, Object?>{
      if (id != null) 'id': id,
      'label': _emptyToNull(labelController.text),
      if (gender != null && gender != kLabReferenceRangeAnyGender)
        'gender': gender,
      'age_min_value': ageMin,
      'age_min_unit': ageMin == null ? null : ageUnit,
      'age_max_value': ageMax,
      'age_max_unit': ageMax == null ? null : ageUnit,
      'unit': unit,
      'normal_min_value': _emptyToNull(normalMinController.text),
      'normal_max_value': _emptyToNull(normalMaxController.text),
      'critical_min_value': _emptyToNull(criticalMinController.text),
      'critical_max_value': _emptyToNull(criticalMaxController.text),
      'reference_text': _emptyToNull(referenceTextController.text),
      'notes': _emptyToNull(notesController.text),
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
    if (allAges) {
      // Age bounds are intentionally empty when applying to all ages.
    } else if (!_isRangeValid(
      ageMinController.text,
      ageMaxController.text,
      allowEqual: false,
    )) {
      return false;
    }
    if (!_isRangeValid(
          normalMinController.text,
          normalMaxController.text,
          allowEqual: true,
        ) ||
        !_isRangeValid(
          criticalMinController.text,
          criticalMaxController.text,
          allowEqual: true,
        )) {
      return false;
    }
    return !_criticalContradictsNormal();
  }

  bool hasNonNumericBound() {
    if (!allAges &&
        (_hasNonNumericSide(ageMinController.text) ||
            _hasNonNumericSide(ageMaxController.text))) {
      return true;
    }
    return _hasNonNumericSide(normalMinController.text) ||
        _hasNonNumericSide(normalMaxController.text) ||
        _hasNonNumericSide(criticalMinController.text) ||
        _hasNonNumericSide(criticalMaxController.text);
  }

  /// Stable key for exact label + gender + age band + age unit applicability.
  String applicabilityKey() {
    final String label = labelController.text.trim().toLowerCase();
    final String genderKey = (gender ?? kLabReferenceRangeAnyGender)
        .trim()
        .toUpperCase();
    final String ageMin = allAges ? '' : ageMinController.text.trim();
    final String ageMax = allAges ? '' : ageMaxController.text.trim();
    final String unit = allAges
        ? 'ANY'
        : (ageUnit ?? 'YEAR').trim().toUpperCase();
    return '$label|$genderKey|$ageMin|$ageMax|$unit';
  }

  bool contradictsCriticalVsNormal() => _criticalContradictsNormal();

  bool _criticalContradictsNormal() {
    final num? normalMin = num.tryParse(normalMinController.text.trim());
    final num? normalMax = num.tryParse(normalMaxController.text.trim());
    final num? criticalMin = num.tryParse(criticalMinController.text.trim());
    final num? criticalMax = num.tryParse(criticalMaxController.text.trim());

    if (criticalMin != null && normalMin != null && criticalMin > normalMin) {
      return true;
    }
    if (criticalMax != null && normalMax != null && criticalMax < normalMax) {
      return true;
    }
    return false;
  }

  bool _hasNonNumericSide(String value) {
    final String text = value.trim();
    return text.isNotEmpty && num.tryParse(text) == null;
  }

  bool _isRangeValid(
    String minValue,
    String maxValue, {
    required bool allowEqual,
  }) {
    final String minText = minValue.trim();
    final String maxText = maxValue.trim();
    if (minText.isEmpty && maxText.isEmpty) {
      return true;
    }
    final num? minNumber = minText.isEmpty ? null : num.tryParse(minText);
    final num? maxNumber = maxText.isEmpty ? null : num.tryParse(maxText);
    // Filled sides must be numeric; open-ended (one-sided) bounds are allowed.
    if (minText.isNotEmpty && minNumber == null) {
      return false;
    }
    if (maxText.isNotEmpty && maxNumber == null) {
      return false;
    }
    if (minNumber != null && maxNumber != null) {
      return allowEqual ? minNumber <= maxNumber : minNumber < maxNumber;
    }
    return true;
  }
}

/// True when two ranges share a label and their gender/age applicability overlaps
/// (including All genders / All ages covering more specific rows).
bool labReferenceRangesOverlap(
  EditableLabReferenceRange left,
  EditableLabReferenceRange right,
) {
  final String leftLabel = left.labelController.text.trim().toLowerCase();
  final String rightLabel = right.labelController.text.trim().toLowerCase();
  if (leftLabel.isEmpty || rightLabel.isEmpty || leftLabel != rightLabel) {
    return false;
  }
  return _labGendersOverlap(left, right) && _labAgesOverlap(left, right);
}

bool _labGendersOverlap(
  EditableLabReferenceRange left,
  EditableLabReferenceRange right,
) {
  if (left.appliesToAllGenders || right.appliesToAllGenders) {
    return true;
  }
  return (left.gender ?? '').trim().toUpperCase() ==
      (right.gender ?? '').trim().toUpperCase();
}

bool _labAgesOverlap(
  EditableLabReferenceRange left,
  EditableLabReferenceRange right,
) {
  if (left.allAges || right.allAges) {
    return true;
  }
  final String leftUnit = (left.ageUnit ?? 'YEAR').trim().toUpperCase();
  final String rightUnit = (right.ageUnit ?? 'YEAR').trim().toUpperCase();
  if (leftUnit != rightUnit) {
    return false;
  }
  final num leftMin =
      num.tryParse(left.ageMinController.text.trim()) ?? double.negativeInfinity;
  final num leftMax =
      num.tryParse(left.ageMaxController.text.trim()) ?? double.infinity;
  final num rightMin =
      num.tryParse(right.ageMinController.text.trim()) ??
      double.negativeInfinity;
  final num rightMax =
      num.tryParse(right.ageMaxController.text.trim()) ?? double.infinity;
  return leftMin <= rightMax && rightMin <= leftMax;
}

bool labReferenceRangesHaveDuplicateApplicability(
  Iterable<EditableLabReferenceRange> ranges,
) {
  final List<EditableLabReferenceRange> candidates = ranges
      .where((EditableLabReferenceRange range) {
        final String label = range.labelController.text.trim();
        final bool hasAge =
            !range.allAges &&
            (range.ageMinController.text.trim().isNotEmpty ||
                range.ageMaxController.text.trim().isNotEmpty);
        return label.isNotEmpty || hasAge || !range.appliesToAllGenders;
      })
      .toList(growable: false);

  final Set<String> seen = <String>{};
  for (int i = 0; i < candidates.length; i++) {
    final EditableLabReferenceRange range = candidates[i];
    if (!seen.add(range.applicabilityKey())) {
      return true;
    }
    for (int j = i + 1; j < candidates.length; j++) {
      if (labReferenceRangesOverlap(range, candidates[j])) {
        return true;
      }
    }
  }
  return false;
}

String? _emptyToNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class LabReferenceRangeListField extends StatelessWidget {
  const LabReferenceRangeListField({
    required this.ranges,
    required this.enabled,
    required this.fallbackUnit,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    this.showHeader = true,
    super.key,
  });

  final List<EditableLabReferenceRange> ranges;
  final bool enabled;
  final String fallbackUnit;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<EditableLabReferenceRange> onRemove;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHeader) ...<Widget>[
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
        ] else
          Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton.tertiary(
                    label: l10n.labAddReferenceRangeAction,
                    leadingIcon: Icons.add,
                    enabled: enabled,
                    onPressed: onAdd,
                  ),
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
        if (showHeader) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tertiary(
              label: l10n.labAddReferenceRangeAction,
              leadingIcon: Icons.add,
              enabled: enabled,
              onPressed: onAdd,
            ),
          ),
          SizedBox(height: theme.spacing.md),
        ] else
          SizedBox(height: theme.spacing.md),
        for (int index = 0; index < ranges.length; index++) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.md),
          _LabReferenceRangeCard(
            key: ValueKey<String>(ranges[index].id ?? 'new-range-$index'),
            range: ranges[index],
            index: index,
            enabled: enabled,
            canRemove: ranges.length > 1,
            onChanged: onChanged,
            onRemove: () => onRemove(ranges[index]),
          ),
        ],
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

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          context.responsiveRadius(theme.radius.md),
        ),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (canRemove)
                  AppButton(
                    iconOnly: true,
                    leadingIcon: Icons.delete_outline,
                    label: l10n.commonRemoveActionLabel,
                    semanticLabel: l10n.commonRemoveActionLabel,
                    tooltip: l10n.commonRemoveActionLabel,
                    enabled: enabled,
                    onPressed: enabled ? onRemove : null,
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            AppSelectField<String>.searchable(
              value: range.labelController.text.trim().isEmpty
                  ? null
                  : range.labelController.text.trim(),
              labelText: l10n.labReferenceRangeLabel,
              enabled: enabled,
              allowClear: true,
              options: <AppSelectOption<String>>[
                for (final String label in labUniqueNonEmpty(<String?>[
                  l10n.labAgeAnyLabel,
                  l10n.labNeonateRangeLabel,
                  l10n.labInfantRangeLabel,
                  l10n.labChildRangeLabel,
                  l10n.labAdolescentRangeLabel,
                  l10n.labAdultRangeLabel,
                  l10n.labGeriatricRangeLabel,
                  l10n.labPediatricRangeLabel,
                  range.labelController.text,
                ]))
                  AppSelectOption<String>(
                    value: label,
                    label: label,
                    leadingIcon: const Icon(Icons.label_outline),
                  ),
              ],
              onChanged: (String? value) {
                range.labelController.text = value?.trim() ?? '';
                range.applyAgePresetFromLabel(value, l10n);
                onChanged();
              },
            ),
            SizedBox(height: theme.spacing.xs),
            _LabGenderApplicabilityField(
              gender: range.gender,
              enabled: enabled,
              onChanged: (String value) {
                range.gender = value;
                onChanged();
              },
            ),
            SizedBox(height: theme.spacing.xs),
            _LabAgeApplicabilityField(
              range: range,
              enabled: enabled,
              onChanged: onChanged,
            ),
            SizedBox(height: theme.spacing.xs),
            AppTextField(
              controller: range.rangeUnitController,
              labelText: l10n.labResultUnitLabel,
              enabled: enabled,
              prefixIcon: const Icon(Icons.straighten_outlined),
              onChanged: (_) => onChanged(),
            ),
            SizedBox(height: theme.spacing.xs),
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
                onChanged: (_) => onChanged(),
              ),
              right: AppTextField(
                controller: range.normalMaxController,
                labelText: l10n.labNormalMaxLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            SizedBox(height: theme.spacing.xs),
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
                onChanged: (_) => onChanged(),
              ),
              right: AppTextField(
                controller: range.criticalMaxController,
                labelText: l10n.labCriticalMaxLabel,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            AppTextField(
              controller: range.referenceTextController,
              labelText: l10n.labReferenceTextLabel,
              enabled: enabled,
              maxLines: 1,
              prefixIcon: const Icon(Icons.notes_outlined),
              onChanged: (_) => onChanged(),
            ),
            SizedBox(height: theme.spacing.xs),
            AppTextField(
              controller: range.notesController,
              labelText: l10n.labReferenceNotesLabel,
              enabled: enabled,
              maxLines: 1,
              prefixIcon: const Icon(Icons.sticky_note_2_outlined),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gender applicability as a horizontal chip row. "All genders" is exclusive
/// with specifics, but specifics stay enabled so they can be chosen directly.
class _LabGenderApplicabilityField extends StatelessWidget {
  const _LabGenderApplicabilityField({
    required this.gender,
    required this.enabled,
    required this.onChanged,
  });

  final String? gender;
  final bool enabled;
  final ValueChanged<String> onChanged;

  bool get _isAllGenders =>
      gender == null || gender == kLabReferenceRangeAnyGender;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<({String value, String label, IconData icon})> options =
        <({String value, String label, IconData icon})>[
          (
            value: kLabReferenceRangeAnyGender,
            label: l10n.labGenderAnyLabel,
            icon: Icons.people_outline,
          ),
          (
            value: 'MALE',
            label: l10n.labGenderMaleLabel,
            icon: Icons.male,
          ),
          (
            value: 'FEMALE',
            label: l10n.labGenderFemaleLabel,
            icon: Icons.female,
          ),
          (
            value: 'OTHER',
            label: l10n.labGenderOtherLabel,
            icon: Icons.diversity_3_outlined,
          ),
          (
            value: 'UNKNOWN',
            label: l10n.labGenderUnknownLabel,
            icon: Icons.help_outline,
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.labGenderApplicabilityLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            for (final ({String value, String label, IconData icon}) option
                in options)
              FilterChip(
                avatar: Icon(option.icon, size: 16),
                label: Text(option.label),
                selected: option.value == kLabReferenceRangeAnyGender
                    ? _isAllGenders
                    : !_isAllGenders && gender == option.value,
                showCheckmark: false,
                onSelected: !enabled
                    ? null
                    : (bool selected) {
                        if (option.value == kLabReferenceRangeAnyGender) {
                          if (selected) {
                            onChanged(kLabReferenceRangeAnyGender);
                          } else {
                            // Leaving All requires a specific gender — default Male.
                            onChanged('MALE');
                          }
                          return;
                        }
                        if (selected) {
                          onChanged(option.value);
                        } else if (gender == option.value) {
                          onChanged(kLabReferenceRangeAnyGender);
                        }
                      },
              ),
          ],
        ),
      ],
    );
  }
}

/// Age applicability with horizontal All ages + age-band presets; bounds hidden
/// when All ages is selected to spare vertical space.
class _LabAgeApplicabilityField extends StatelessWidget {
  const _LabAgeApplicabilityField({
    required this.range,
    required this.enabled,
    required this.onChanged,
  });

  final EditableLabReferenceRange range;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool boundsEnabled = enabled && !range.allAges;
    final String? matchedPresetId = range.matchingAgePresetId();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.labAgeApplicabilityLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            FilterChip(
              avatar: const Icon(Icons.all_inclusive, size: 16),
              label: Text(l10n.labAgeAnyLabel),
              selected: range.allAges,
              showCheckmark: false,
              onSelected: !enabled
                  ? null
                  : (bool selected) {
                      range.setAllAges(value: selected);
                      onChanged();
                    },
            ),
            for (final LabAgeBandPreset preset in kLabAgeBandPresets)
              FilterChip(
                avatar: Icon(labAgeBandPresetIcon(preset.id), size: 16),
                label: Text(labAgeBandPresetLabel(l10n, preset.id)),
                selected: !range.allAges && matchedPresetId == preset.id,
                showCheckmark: false,
                onSelected: !enabled
                    ? null
                    : (bool selected) {
                        if (selected) {
                          range.applyAgePreset(
                            preset,
                            labelIfEmpty: labAgeBandPresetLabel(
                              l10n,
                              preset.id,
                            ),
                            allAgesLabel: l10n.labAgeAnyLabel,
                          );
                        } else if (matchedPresetId == preset.id) {
                          range.setAllAges(value: true);
                        }
                        onChanged();
                      },
              ),
          ],
        ),
        if (range.allAges) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.labAgeAnyHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppSelectField<String>.searchable(
            value: range.ageUnit,
            labelText: l10n.labAgeUnitLabel,
            enabled: boundsEnabled,
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
            onChanged: boundsEnabled
                ? (String? value) {
                    range.ageUnit = value;
                    onChanged();
                  }
                : null,
          ),
          SizedBox(height: theme.spacing.xs),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: range.ageMinController,
              labelText: l10n.labAgeMinLabel,
              enabled: boundsEnabled,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              prefixIcon: const Icon(Icons.arrow_downward),
              onChanged: boundsEnabled
                  ? (_) {
                      range.syncAllAgesFromBounds();
                      onChanged();
                    }
                  : null,
            ),
            right: AppTextField(
              controller: range.ageMaxController,
              labelText: l10n.labAgeMaxLabel,
              enabled: boundsEnabled,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              prefixIcon: const Icon(Icons.arrow_upward),
              onChanged: boundsEnabled
                  ? (_) {
                      range.syncAllAgesFromBounds();
                      onChanged();
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
