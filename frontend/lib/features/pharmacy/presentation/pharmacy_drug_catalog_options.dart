import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

@immutable
final class PharmacyDrugFormOption {
  const PharmacyDrugFormOption({
    required this.value,
    this.shortLabel,
  });

  final String value;
  final String? shortLabel;

  String displayLabel(AppLocalizations l10n) {
    if (shortLabel == null || shortLabel == value) {
      return value;
    }
    return l10n.pharmacyDrugFormWithShortLabel(value, shortLabel!);
  }
}

@immutable
final class PharmacyInventoryUnitOption {
  const PharmacyInventoryUnitOption({
    required this.value,
    required this.label,
    this.shortLabel,
  });

  final String value;
  final String label;
  final String? shortLabel;

  String displayLabel(AppLocalizations l10n) {
    final String short = shortLabel ?? value;
    if (label == short) {
      return label;
    }
    return l10n.pharmacyInventoryUnitWithShortLabel(label, short);
  }
}

const List<PharmacyDrugFormOption> pharmacyDrugFormOptions =
    <PharmacyDrugFormOption>[
      PharmacyDrugFormOption(value: 'Tablet', shortLabel: 'tab'),
      PharmacyDrugFormOption(value: 'Capsule', shortLabel: 'cap'),
      PharmacyDrugFormOption(value: 'Chewable Tablet', shortLabel: 'tab'),
      PharmacyDrugFormOption(value: 'Syrup'),
      PharmacyDrugFormOption(value: 'Suspension'),
      PharmacyDrugFormOption(value: 'Injection', shortLabel: 'inj'),
      PharmacyDrugFormOption(value: 'Ampoule'),
      PharmacyDrugFormOption(value: 'Vial'),
      PharmacyDrugFormOption(value: 'Cream'),
      PharmacyDrugFormOption(value: 'Ointment'),
      PharmacyDrugFormOption(value: 'Gel'),
      PharmacyDrugFormOption(value: 'Drops'),
      PharmacyDrugFormOption(value: 'Inhaler'),
      PharmacyDrugFormOption(value: 'Suppository'),
      PharmacyDrugFormOption(value: 'Patch'),
      PharmacyDrugFormOption(value: 'Powder'),
      PharmacyDrugFormOption(value: 'Solution'),
      PharmacyDrugFormOption(value: 'Lotion'),
      PharmacyDrugFormOption(value: 'Spray'),
      PharmacyDrugFormOption(value: 'Other'),
    ];

const List<PharmacyInventoryUnitOption> pharmacyInventoryUnitCatalog =
    <PharmacyInventoryUnitOption>[
      PharmacyInventoryUnitOption(value: 'tablet', label: 'Tablet', shortLabel: 'tab'),
      PharmacyInventoryUnitOption(value: 'capsule', label: 'Capsule', shortLabel: 'cap'),
      PharmacyInventoryUnitOption(value: 'strip', label: 'Strip'),
      PharmacyInventoryUnitOption(value: 'box', label: 'Box'),
      PharmacyInventoryUnitOption(value: 'bottle', label: 'Bottle', shortLabel: 'btl'),
      PharmacyInventoryUnitOption(value: 'mL', label: 'Millilitre', shortLabel: 'mL'),
      PharmacyInventoryUnitOption(value: 'L', label: 'Litre', shortLabel: 'L'),
      PharmacyInventoryUnitOption(value: 'ampoule', label: 'Ampoule', shortLabel: 'amp'),
      PharmacyInventoryUnitOption(value: 'vial', label: 'Vial'),
      PharmacyInventoryUnitOption(value: 'tube', label: 'Tube'),
      PharmacyInventoryUnitOption(value: 'jar', label: 'Jar'),
      PharmacyInventoryUnitOption(value: 'g', label: 'Gram', shortLabel: 'g'),
      PharmacyInventoryUnitOption(value: 'inhaler', label: 'Inhaler'),
      PharmacyInventoryUnitOption(value: 'pack', label: 'Pack'),
      PharmacyInventoryUnitOption(value: 'unit', label: 'Unit'),
    ];

const Map<String, List<String>> _strengthSuggestionsByFormFamily =
    <String, List<String>>{
      'solid_oral': <String>[
        '5 mg',
        '10 mg',
        '20 mg',
        '40 mg',
        '50 mg',
        '81 mg',
        '100 mg',
        '250 mg',
        '400 mg',
        '500 mg',
        '625 mg',
        '960 mg',
      ],
      'liquid_oral': <String>[
        '2 mg/5 mL',
        '125 mg/5 mL',
        '250 mg/5 mL',
        '3.35 g/5 mL',
      ],
      'injectable': <String>[
        '1 g',
        '500 mg',
        '75 mg/3 mL',
        '10 mg/mL',
        '100 IU/mL',
        '600 mg/2 mL',
      ],
      'topical': <String>['1%', '2%', '5 g', '15 g', '30 g'],
      'inhaler_drops': <String>['100 mcg', '200 mcg', '0.5%', '1%'],
      'other': <String>['As directed'],
    };

const Map<String, List<String>> _unitValuesByFormFamily = <String, List<String>>{
  'solid_oral': <String>['tablet', 'capsule', 'strip', 'box'],
  'liquid_oral': <String>['bottle', 'mL', 'L'],
  'injectable': <String>['ampoule', 'vial', 'box'],
  'topical': <String>['tube', 'jar', 'g'],
  'inhaler_drops': <String>['inhaler', 'bottle', 'pack'],
  'other': <String>['unit', 'box', 'pack'],
};

String? pharmacyFormFamilyForValue(String? form) {
  final String normalized = (form ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (<String>{
    'tablet',
    'capsule',
    'chewable tablet',
  }.contains(normalized)) {
    return 'solid_oral';
  }
  if (<String>{'syrup', 'suspension', 'solution'}.contains(normalized)) {
    return 'liquid_oral';
  }
  if (<String>{'injection', 'ampoule', 'vial'}.contains(normalized)) {
    return 'injectable';
  }
  if (<String>{'cream', 'ointment', 'gel', 'lotion'}.contains(normalized)) {
    return 'topical';
  }
  if (<String>{'inhaler', 'drops', 'spray'}.contains(normalized)) {
    return 'inhaler_drops';
  }
  return 'other';
}

List<String> pharmacyStrengthSuggestionsForForm(String? form) {
  final String? family = pharmacyFormFamilyForValue(form);
  if (family == null) {
    return const <String>[];
  }
  return List<String>.from(
    _strengthSuggestionsByFormFamily[family] ?? const <String>[],
  );
}

List<AppSelectOption<String>> pharmacyDrugFormSelectOptions(
  AppLocalizations l10n,
) {
  return pharmacyDrugFormOptions
      .map(
        (PharmacyDrugFormOption option) => AppSelectOption<String>(
          value: option.value,
          label: option.displayLabel(l10n),
          searchText: '${option.value} ${option.shortLabel ?? ''}',
        ),
      )
      .toList(growable: false);
}

List<AppSelectOption<String>> pharmacyStrengthSelectOptions(String? form) {
  return pharmacyStrengthSuggestionsForForm(form)
      .map(
        (String strength) => AppSelectOption<String>(
          value: strength,
          label: strength,
        ),
      )
      .toList(growable: false);
}

List<PharmacyInventoryUnitOption> pharmacyInventoryUnitsForForm(String? form) {
  final String? family = pharmacyFormFamilyForValue(form);
  if (family == null) {
    return pharmacyInventoryUnitCatalog;
  }
  final List<String> values =
      _unitValuesByFormFamily[family] ?? const <String>[];
  final List<PharmacyInventoryUnitOption> prioritized = values
      .map(
        (String value) => pharmacyInventoryUnitCatalog.firstWhere(
          (PharmacyInventoryUnitOption option) => option.value == value,
          orElse: () => PharmacyInventoryUnitOption(
            value: value,
            label: value,
          ),
        ),
      )
      .toList(growable: false);
  final Set<String> seen = prioritized.map((e) => e.value).toSet();
  final List<PharmacyInventoryUnitOption> remainder = pharmacyInventoryUnitCatalog
      .where((PharmacyInventoryUnitOption option) => !seen.contains(option.value))
      .toList(growable: false);
  return <PharmacyInventoryUnitOption>[...prioritized, ...remainder];
}

IconData pharmacyInventoryUnitIcon(String value) {
  switch (value) {
    case 'tablet':
      return Icons.medication_outlined;
    case 'capsule':
      return Icons.medication_liquid_outlined;
    case 'strip':
      return Icons.view_week_outlined;
    case 'box':
      return Icons.inventory_2_outlined;
    case 'bottle':
      return Icons.local_drink_outlined;
    case 'ampoule':
    case 'vial':
      return Icons.science_outlined;
    case 'tube':
    case 'jar':
      return Icons.invert_colors_outlined;
    case 'inhaler':
      return Icons.air_outlined;
    case 'pack':
      return Icons.layers_outlined;
    case 'mL':
    case 'L':
    case 'g':
      return Icons.scale_outlined;
    default:
      return Icons.category_outlined;
  }
}

String? pharmacyInventoryUnitDisplayLabel(
  AppLocalizations l10n,
  String? unit,
) {
  if (unit == null || unit.trim().isEmpty) {
    return null;
  }
  for (final PharmacyInventoryUnitOption option in pharmacyInventoryUnitCatalog) {
    if (option.value == unit) {
      return option.displayLabel(l10n);
    }
  }
  return unit;
}

List<AppSelectOption<String>> pharmacyInventoryUnitSelectOptions(
  AppLocalizations l10n, {
  String? form,
}) {
  return pharmacyInventoryUnitsForForm(form)
      .map(
        (PharmacyInventoryUnitOption option) => AppSelectOption<String>(
          value: option.value,
          label: option.displayLabel(l10n),
          leadingIcon: Icon(pharmacyInventoryUnitIcon(option.value)),
          searchText: '${option.label} ${option.shortLabel ?? ''} ${option.value}',
        ),
      )
      .toList(growable: false);
}

String? pharmacyDefaultInventoryUnitForForm(String? form) {
  final List<PharmacyInventoryUnitOption> units = pharmacyInventoryUnitsForForm(
    form,
  );
  return units.isEmpty ? null : units.first.value;
}

@immutable
final class PharmacyExpiryAlertLeadOption {
  const PharmacyExpiryAlertLeadOption({
    required this.days,
    required this.label,
  });

  final int days;
  final String label;
}

List<PharmacyExpiryAlertLeadOption> pharmacyExpiryAlertLeadOptions(
  AppLocalizations l10n,
) {
  return <PharmacyExpiryAlertLeadOption>[
    PharmacyExpiryAlertLeadOption(
      days: 30,
      label: l10n.pharmacyExpiryAlertLeadDays(30),
    ),
    PharmacyExpiryAlertLeadOption(
      days: 60,
      label: l10n.pharmacyExpiryAlertLeadDays(60),
    ),
    PharmacyExpiryAlertLeadOption(
      days: 90,
      label: l10n.pharmacyExpiryAlertLeadMonths(3),
    ),
    PharmacyExpiryAlertLeadOption(
      days: 180,
      label: l10n.pharmacyExpiryAlertLeadMonths(6),
    ),
  ];
}
