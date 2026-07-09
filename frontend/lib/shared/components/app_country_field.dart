import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_phone_field.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

/// Searchable country selector backed by the shared phone metadata catalog.
class AppCountryField extends StatelessWidget {
  const AppCountryField({
    required this.value,
    required this.labelText,
    required this.onChanged,
    this.enabled = true,
    this.isRequired = false,
    this.validator,
    this.menuHeight = 320,
    super.key,
  });

  final String? value;
  final String labelText;
  final bool enabled;
  final bool isRequired;
  final double menuHeight;
  final ValueChanged<String?> onChanged;
  final String? Function(String? value)? validator;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: value?.trim().isEmpty ?? true ? null : value,
      enabled: enabled,
      labelText: labelText,
      isRequired: isRequired,
      menuHeight: menuHeight,
      options: buildAppCountrySelectOptions(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

List<AppSelectOption<String>> buildAppCountrySelectOptions() {
  return appCountryCatalogEntries
      .map(
        (AppCountryCatalogEntry country) => AppSelectOption<String>(
          value: country.name,
          label: country.name,
          searchText: '${country.isoCode.name} ${country.name}',
          leadingIcon: Text(
            isoCodeToFlagEmoji(country.isoCode),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      )
      .toList(growable: false);
}
