import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';

class AppPhoneField extends StatefulWidget {
  const AppPhoneField({
    required this.controller,
    required this.countryLabelText,
    required this.countrySearchLabelText,
    required this.countryNoResultsText,
    required this.numberLabelText,
    required this.invalidPhoneMessage,
    this.labelText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.requiredMessage,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onFieldSubmitted,
    this.onFocusChanged,
    this.focusNode,
    this.autovalidateMode,
    this.restorationId,
    this.textInputAction,
    this.enabled = true,
    this.isLoading = false,
    this.isRequired = false,
    this.initialCountryCode = '+256',
    super.key,
  }) : assert(
         !isRequired || requiredMessage != null,
         'requiredMessage must be provided when isRequired is true.',
       );

  final TextEditingController controller;
  final String? labelText;
  final String countryLabelText;
  final String countrySearchLabelText;
  final String countryNoResultsText;
  final String numberLabelText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? requiredMessage;
  final String invalidPhoneMessage;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;
  final String? restorationId;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool isLoading;
  final bool isRequired;
  final String initialCountryCode;

  @override
  State<AppPhoneField> createState() => _AppPhoneFieldState();
}

class _AppPhoneFieldState extends State<AppPhoneField> {
  late final TextEditingController _numberController;
  late _PhoneCountry _country;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController();
    _country = _countryForCode(widget.initialCountryCode);
    _hydrateFromController();
    widget.controller.addListener(_handleExternalChanged);
    _numberController.addListener(_handleNumberChanged);
  }

  @override
  void didUpdateWidget(AppPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleExternalChanged);
      widget.controller.addListener(_handleExternalChanged);
      _hydrateFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleExternalChanged);
    _numberController
      ..removeListener(_handleNumberChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget countryField = _PhoneCountryField(
      country: _country,
      labelText: widget.countryLabelText,
      searchLabelText: widget.countrySearchLabelText,
      noResultsText: widget.countryNoResultsText,
      enabled: widget.enabled && !widget.isLoading,
      onChanged: (value) {
        if (value == _country) {
          return;
        }
        setState(() {
          _country = value;
        });
        _syncController();
      },
    );
    final Widget numberField = AppTextField(
      controller: _numberController,
      labelText: widget.numberLabelText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: _validateNumber,
      onSaved: (_) => widget.onSaved?.call(widget.controller.text),
      onFieldSubmitted: (_) =>
          widget.onFieldSubmitted?.call(widget.controller.text),
      onFocusChanged: widget.onFocusChanged,
      focusNode: widget.focusNode,
      autovalidateMode: widget.autovalidateMode,
      restorationId: widget.restorationId,
      enabled: widget.enabled,
      isLoading: widget.isLoading,
      isRequired: widget.isRequired,
      autofillHints: const <String>[AutofillHints.telephoneNumberNational],
    );

    Widget field = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              countryField,
              SizedBox(height: theme.spacing.sm),
              numberField,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 240, child: countryField),
            SizedBox(width: theme.spacing.sm),
            Expanded(child: numberField),
          ],
        );
      },
    );

    if (widget.labelText != null) {
      field = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            appFieldLabel(widget.labelText, isRequired: widget.isRequired)!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          field,
        ],
      );
    }

    if (widget.semanticLabel == null) {
      return field;
    }

    return Semantics(
      textField: true,
      enabled: widget.enabled && !widget.isLoading,
      label: widget.semanticLabel,
      child: field,
    );
  }

  void _handleExternalChanged() {
    if (_isSyncing) {
      return;
    }
    _hydrateFromController();
  }

  void _handleNumberChanged() {
    _syncController();
  }

  void _hydrateFromController() {
    final _ParsedPhone parsed = _parsePhone(widget.controller.text);
    _isSyncing = true;
    _country = parsed.country;
    _numberController.text = parsed.nationalNumber;
    _isSyncing = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _syncController() {
    if (_isSyncing) {
      return;
    }
    final String nextValue = _composePhoneNumber();
    if (widget.controller.text == nextValue) {
      return;
    }
    _isSyncing = true;
    widget.controller.text = nextValue;
    _isSyncing = false;
    widget.onChanged?.call(nextValue);
  }

  String? _validateNumber(String? value) {
    final String digits = _normalizeNationalNumber(value ?? '');
    if (digits.isEmpty) {
      return widget.isRequired ? widget.requiredMessage : null;
    }
    if (digits.length < _country.minLength ||
        digits.length > _country.maxLength) {
      return widget.invalidPhoneMessage;
    }
    return widget.validator?.call('${_country.callingCode}$digits');
  }

  String _composePhoneNumber() {
    final String digits = _normalizeNationalNumber(_numberController.text);
    if (digits.isEmpty) {
      return '';
    }
    return '${_country.callingCode}$digits';
  }

  String _normalizeNationalNumber(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.replaceFirst(RegExp(r'^0+'), '');
  }

  _ParsedPhone _parsePhone(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (normalized.isEmpty) {
      return _ParsedPhone(country: _country, nationalNumber: '');
    }

    final _PhoneCountry country = normalized.startsWith('+')
        ? _countryForFullNumber(normalized)
        : _country;
    final String national = normalized.startsWith(country.callingCode)
        ? normalized.substring(country.callingCode.length)
        : normalized.replaceAll(RegExp(r'\D'), '');
    return _ParsedPhone(
      country: country,
      nationalNumber: national.replaceFirst(RegExp(r'^0+'), ''),
    );
  }

  _PhoneCountry _countryForFullNumber(String value) {
    final List<_PhoneCountry> matches =
        _phoneCountries
            .where(
              (_PhoneCountry country) => value.startsWith(country.callingCode),
            )
            .toList()
          ..sort(
            (_PhoneCountry a, _PhoneCountry b) =>
                b.callingCode.length.compareTo(a.callingCode.length),
          );
    return matches.isEmpty ? _country : matches.first;
  }

  _PhoneCountry _countryForCode(String value) {
    return _phoneCountries.firstWhere(
      (_PhoneCountry country) => country.callingCode == value,
      orElse: () => _phoneCountries.first,
    );
  }
}

class _PhoneCountryField extends StatelessWidget {
  const _PhoneCountryField({
    required this.country,
    required this.labelText,
    required this.searchLabelText,
    required this.noResultsText,
    required this.enabled,
    required this.onChanged,
  });

  final _PhoneCountry country;
  final String labelText;
  final String searchLabelText;
  final String noResultsText;
  final bool enabled;
  final ValueChanged<_PhoneCountry> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: labelText,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () async {
                  final _PhoneCountry? selected =
                      await showAppDialog<_PhoneCountry>(
                        context: context,
                        builder: (_) => _PhoneCountryPickerDialog(
                          title: labelText,
                          searchLabelText: searchLabelText,
                          noResultsText: noResultsText,
                          selectedCountry: country,
                        ),
                      );
                  if (selected != null) {
                    onChanged(selected);
                  }
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(labelText: labelText, enabled: enabled),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.public_outlined,
                  size: theme.appTokens.listIconSize,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    country.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneCountryPickerDialog extends StatefulWidget {
  const _PhoneCountryPickerDialog({
    required this.title,
    required this.searchLabelText,
    required this.noResultsText,
    required this.selectedCountry,
  });

  final String title;
  final String searchLabelText;
  final String noResultsText;
  final _PhoneCountry selectedCountry;

  @override
  State<_PhoneCountryPickerDialog> createState() =>
      _PhoneCountryPickerDialogState();
}

class _PhoneCountryPickerDialogState extends State<_PhoneCountryPickerDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<_PhoneCountry> countries = _filteredCountries;

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.public_outlined),
      maxWidth: 420,
      content: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _searchController,
              labelText: widget.searchLabelText,
              prefixIcon: const Icon(Icons.search),
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            SizedBox(height: theme.spacing.sm),
            Expanded(
              child: countries.isEmpty
                  ? Center(
                      child: Text(
                        widget.noResultsText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: countries.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colorScheme.outlineVariant),
                      itemBuilder: (BuildContext context, int index) {
                        final _PhoneCountry country = countries[index];
                        final bool selected = country == widget.selectedCountry;

                        return ListTile(
                          leading: const Icon(Icons.public_outlined),
                          title: Text(country.name),
                          subtitle: Text(country.callingCode),
                          trailing: selected
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          onTap: () {
                            Navigator.of(context).pop(country);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_PhoneCountry> get _filteredCountries {
    if (_query.isEmpty) {
      return _phoneCountries;
    }

    return _phoneCountries
        .where((_PhoneCountry country) {
          final String haystack =
              '${country.name} ${country.isoCode} ${country.callingCode}'
                  .toLowerCase();
          return haystack.contains(_query);
        })
        .toList(growable: false);
  }
}

@immutable
class _PhoneCountry {
  const _PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.callingCode,
    this.minLength = 6,
    this.maxLength = 14,
  });

  final String name;
  final String isoCode;
  final String callingCode;
  final int minLength;
  final int maxLength;

  String get displayLabel => '$name $callingCode';

  @override
  bool operator ==(Object other) {
    return other is _PhoneCountry && other.isoCode == isoCode;
  }

  @override
  int get hashCode => isoCode.hashCode;
}

@immutable
class _ParsedPhone {
  const _ParsedPhone({required this.country, required this.nationalNumber});

  final _PhoneCountry country;
  final String nationalNumber;
}

const List<_PhoneCountry> _phoneCountries = <_PhoneCountry>[
  _PhoneCountry(
    name: 'Uganda',
    isoCode: 'UG',
    callingCode: '+256',
    minLength: 9,
    maxLength: 9,
  ),
  _PhoneCountry(
    name: 'Kenya',
    isoCode: 'KE',
    callingCode: '+254',
    minLength: 9,
    maxLength: 9,
  ),
  _PhoneCountry(
    name: 'Tanzania',
    isoCode: 'TZ',
    callingCode: '+255',
    minLength: 9,
    maxLength: 9,
  ),
  _PhoneCountry(name: 'Rwanda', isoCode: 'RW', callingCode: '+250'),
  _PhoneCountry(name: 'Burundi', isoCode: 'BI', callingCode: '+257'),
  _PhoneCountry(name: 'South Sudan', isoCode: 'SS', callingCode: '+211'),
  _PhoneCountry(name: 'Congo', isoCode: 'CD', callingCode: '+243'),
  _PhoneCountry(name: 'Ethiopia', isoCode: 'ET', callingCode: '+251'),
  _PhoneCountry(
    name: 'South Africa',
    isoCode: 'ZA',
    callingCode: '+27',
    minLength: 9,
    maxLength: 9,
  ),
  _PhoneCountry(name: 'Nigeria', isoCode: 'NG', callingCode: '+234'),
  _PhoneCountry(name: 'Ghana', isoCode: 'GH', callingCode: '+233'),
  _PhoneCountry(
    name: 'United States',
    isoCode: 'US',
    callingCode: '+1',
    minLength: 10,
    maxLength: 10,
  ),
  _PhoneCountry(
    name: 'United Kingdom',
    isoCode: 'GB',
    callingCode: '+44',
    minLength: 10,
    maxLength: 10,
  ),
  _PhoneCountry(name: 'India', isoCode: 'IN', callingCode: '+91'),
  _PhoneCountry(
    name: 'United Arab Emirates',
    isoCode: 'AE',
    callingCode: '+971',
  ),
];
