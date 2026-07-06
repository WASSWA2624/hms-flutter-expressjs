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

List<String> pharmacyFormDisplayLabels(AppLocalizations l10n) {
  return pharmacyDrugFormOptions
      .map((PharmacyDrugFormOption option) => option.displayLabel(l10n))
      .toList(growable: false);
}

String? pharmacyCanonicalFormFromLabel(AppLocalizations l10n, String label) {
  final String trimmed = label.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  for (final PharmacyDrugFormOption option in pharmacyDrugFormOptions) {
    if (option.displayLabel(l10n) == trimmed || option.value == trimmed) {
      return option.value;
    }
  }
  return trimmed;
}

String pharmacyFormLabelForValue(AppLocalizations l10n, String? value) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  for (final PharmacyDrugFormOption option in pharmacyDrugFormOptions) {
    if (option.value.toLowerCase() == trimmed.toLowerCase()) {
      return option.displayLabel(l10n);
    }
  }
  return trimmed;
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

List<AppSelectOption<String>> pharmacyInventoryUnitSelectOptions(
  AppLocalizations l10n, {
  String? form,
}) {
  return pharmacyInventoryUnitsForForm(form)
      .map(
        (PharmacyInventoryUnitOption option) => AppSelectOption<String>(
          value: option.value,
          label: option.displayLabel(l10n),
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

class PharmacySearchableTextField extends StatefulWidget {
  const PharmacySearchableTextField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.enabled = true,
    this.isRequired = false,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final bool enabled;
  final bool isRequired;
  final String? hintText;
  final Widget? prefixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PharmacySearchableTextField> createState() =>
      _PharmacySearchableTextFieldState();
}

class _PharmacySearchableTextFieldState extends State<PharmacySearchableTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        final List<String> matches = widget.options
            .where(
              (String option) =>
                  query.isEmpty || option.toLowerCase().contains(query),
            )
            .take(12)
            .toList(growable: false);
        if (query.isEmpty ||
            matches.any((String option) => option.toLowerCase() == query)) {
          return matches;
        }
        return <String>[value.text.trim(), ...matches];
      },
      onSelected: (String value) {
        widget.controller.text = value;
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return AppTextField(
              controller: controller,
              focusNode: focusNode,
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              enabled: widget.enabled,
              isRequired: widget.isRequired,
              validator: widget.validator,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
                widget.onFieldSubmitted?.call(value);
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final ThemeData theme = Theme.of(context);
            final List<String> visibleOptions = options.toList(growable: false);
            if (visibleOptions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 420,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: visibleOptions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = visibleOptions[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}
