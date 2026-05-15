import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/src/app_field_label.dart';
import 'package:phone_numbers_parser/metadata.dart' as phone_metadata;
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class AppPhoneField extends StatefulWidget {
  const AppPhoneField({
    required this.controller,
    required this.countryLabelText,
    required this.countrySearchLabelText,
    required this.countryNoResultsText,
    required this.numberLabelText,
    required this.invalidPhoneMessage,
    this.labelText,
    this.numberHintText,
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
  final String? numberHintText;
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
  late FocusNode _numberFocusNode;
  late bool _ownsFocusNode;
  late _PhoneCountry _country;
  bool _isSyncing = false;
  bool _isPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController();
    _country = _countryForCode(widget.initialCountryCode);
    _attachFocusNode();
    _hydrateFromController();
    widget.controller.addListener(_handleExternalChanged);
  }

  @override
  void didUpdateWidget(AppPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleExternalChanged);
      widget.controller.addListener(_handleExternalChanged);
      _hydrateFromController();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleExternalChanged);
    _detachFocusNode();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canEdit = widget.enabled && !widget.isLoading;
    Widget field = FormField<String>(
      initialValue: widget.controller.text,
      autovalidateMode: widget.autovalidateMode,
      validator: _validatePhone,
      onSaved: (_) => widget.onSaved?.call(widget.controller.text),
      builder: (FormFieldState<String> formField) {
        return InputDecorator(
          isFocused: _numberFocusNode.hasFocus || _isPickerOpen,
          isEmpty: _numberController.text.isEmpty,
          decoration: InputDecoration(
            enabled: canEdit,
            helperText: widget.helperText,
            errorText: widget.errorText ?? formField.errorText,
            contentPadding: EdgeInsets.zero,
          ),
          child: _UnifiedPhoneInput(
            country: _country,
            countryLabelText: widget.countryLabelText,
            numberHintText: widget.numberHintText ?? widget.numberLabelText,
            numberController: _numberController,
            numberFocusNode: _numberFocusNode,
            canEdit: canEdit,
            isLoading: widget.isLoading,
            maxNationalDigits: _maxNationalDigits,
            textInputAction: widget.textInputAction,
            restorationId: widget.restorationId,
            onSelectCountry: () => _selectCountry(formField),
            onNumberChanged: (_) => _syncController(formField),
            onFieldSubmitted: (_) =>
                widget.onFieldSubmitted?.call(widget.controller.text),
          ),
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
      enabled: canEdit,
      label: widget.semanticLabel,
      child: field,
    );
  }

  int get _maxNationalDigits {
    final int remainingDigits = 15 - _country.callingCodeDigits.length;
    return math.max(1, remainingDigits);
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _numberFocusNode = widget.focusNode ?? FocusNode();
    _numberFocusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _numberFocusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _numberFocusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_numberFocusNode.hasFocus);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCountry(FormFieldState<String> formField) async {
    if (!widget.enabled || widget.isLoading) {
      return;
    }

    setState(() {
      _isPickerOpen = true;
    });
    final _PhoneCountry? selected = await showAppDialog<_PhoneCountry>(
      context: context,
      builder: (_) => _PhoneCountryPickerDialog(
        title: widget.countryLabelText,
        searchLabelText: widget.countrySearchLabelText,
        noResultsText: widget.countryNoResultsText,
        selectedCountry: _country,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isPickerOpen = false;
    });

    if (selected == null || selected == _country) {
      return;
    }
    setState(() {
      _country = selected;
    });
    _syncController(formField);
    formField.validate();
  }

  void _handleExternalChanged() {
    if (_isSyncing) {
      return;
    }
    _hydrateFromController();
  }

  void _hydrateFromController() {
    final _ParsedPhone parsed = _parsePhone(widget.controller.text);
    _isSyncing = true;
    _country = parsed.country;
    _numberController.value = TextEditingValue(
      text: parsed.nationalNumber,
      selection: TextSelection.collapsed(offset: parsed.nationalNumber.length),
    );
    _isSyncing = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _syncController(FormFieldState<String> formField) {
    if (_isSyncing) {
      return;
    }
    final String nextValue = _composePhoneNumber();
    _isSyncing = true;
    if (widget.controller.text != nextValue) {
      widget.controller.text = nextValue;
      widget.onChanged?.call(nextValue);
    }
    _isSyncing = false;
    formField.didChange(nextValue);
  }

  String? _validatePhone(String? _) {
    final String digits = _normalizeNationalNumber(_numberController.text);
    if (digits.isEmpty) {
      return widget.isRequired ? widget.requiredMessage : null;
    }
    if (_country.callingCodeDigits.isEmpty ||
        digits.length > _maxNationalDigits) {
      return widget.invalidPhoneMessage;
    }

    final PhoneNumber phoneNumber = _phoneNumberFromNationalDigits(digits);
    if (!phoneNumber.isValid()) {
      return widget.invalidPhoneMessage;
    }

    return widget.validator?.call(phoneNumber.international);
  }

  String _composePhoneNumber() {
    final String digits = _normalizeNationalNumber(_numberController.text);
    if (digits.isEmpty) {
      return '';
    }
    return _phoneNumberFromNationalDigits(digits).international;
  }

  String _normalizeNationalNumber(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  PhoneNumber _phoneNumberFromNationalDigits(String digits) {
    if (!digits.startsWith(_country.callingCodeDigits)) {
      try {
        final PhoneNumber parsed = PhoneNumber.parse(
          digits,
          destinationCountry: _country.isoCode,
        );
        if (parsed.isoCode == _country.isoCode) {
          return parsed;
        }
      } catch (_) {
        // Fall through to direct construction so validation can report errors.
      }
    }
    return PhoneNumber(isoCode: _country.isoCode, nsn: digits);
  }

  _ParsedPhone _parsePhone(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return _ParsedPhone(country: _country, nationalNumber: '');
    }

    try {
      final PhoneNumber phoneNumber = normalized.startsWith('+')
          ? PhoneNumber.parse(normalized)
          : PhoneNumber.parse(normalized, destinationCountry: _country.isoCode);
      return _ParsedPhone(
        country: _countryForIsoCode(phoneNumber.isoCode),
        nationalNumber: phoneNumber.nsn,
      );
    } catch (_) {
      final String digits = _normalizeNationalNumber(normalized);
      if (digits.isEmpty) {
        return _ParsedPhone(country: _country, nationalNumber: '');
      }
      final _PhoneCountry country = normalized.startsWith('+')
          ? _countryForFullNumber(digits)
          : _country;
      final String national =
          normalized.startsWith('+') &&
              digits.startsWith(country.callingCodeDigits)
          ? digits.substring(country.callingCodeDigits.length)
          : digits;
      return _ParsedPhone(country: country, nationalNumber: national);
    }
  }

  _PhoneCountry _countryForFullNumber(String digits) {
    final List<_PhoneCountry> matches =
        _phoneCountries
            .where(
              (_PhoneCountry country) =>
                  digits.startsWith(country.callingCodeDigits),
            )
            .toList()
          ..sort(
            (_PhoneCountry a, _PhoneCountry b) => b.callingCodeDigits.length
                .compareTo(a.callingCodeDigits.length),
          );
    return matches.isEmpty ? _country : matches.first;
  }

  _PhoneCountry _countryForCode(String value) {
    final String digits = _normalizeNationalNumber(value);
    final List<_PhoneCountry> matches = _phoneCountries
        .where((_PhoneCountry country) => country.callingCodeDigits == digits)
        .toList(growable: false);
    if (matches.isEmpty) {
      return _countryForIsoCode(IsoCode.UG);
    }

    for (final _PhoneCountry country in matches) {
      if (country.isMainCountryForDialCode) {
        return country;
      }
    }
    return matches.first;
  }

  _PhoneCountry _countryForIsoCode(IsoCode isoCode) {
    return _phoneCountries.firstWhere(
      (_PhoneCountry country) => country.isoCode == isoCode,
      orElse: () => _phoneCountries.first,
    );
  }
}

class _UnifiedPhoneInput extends StatelessWidget {
  const _UnifiedPhoneInput({
    required this.country,
    required this.countryLabelText,
    required this.numberHintText,
    required this.numberController,
    required this.numberFocusNode,
    required this.canEdit,
    required this.isLoading,
    required this.maxNationalDigits,
    required this.onSelectCountry,
    required this.onNumberChanged,
    required this.onFieldSubmitted,
    this.textInputAction,
    this.restorationId,
  });

  final _PhoneCountry country;
  final String countryLabelText;
  final String numberHintText;
  final TextEditingController numberController;
  final FocusNode numberFocusNode;
  final bool canEdit;
  final bool isLoading;
  final int maxNationalDigits;
  final VoidCallback onSelectCountry;
  final ValueChanged<String> onNumberChanged;
  final ValueChanged<String> onFieldSubmitted;
  final TextInputAction? textInputAction;
  final String? restorationId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double countryWidth = constraints.maxWidth < 360
            ? 104
            : constraints.maxWidth < 520
            ? 124
            : 148;

        return SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: countryWidth,
                child: _PhoneCountryButton(
                  country: country,
                  labelText: countryLabelText,
                  enabled: canEdit,
                  isLoading: isLoading,
                  onPressed: onSelectCountry,
                ),
              ),
              VerticalDivider(
                width: theme.appTokens.dividerThickness,
                thickness: theme.appTokens.dividerThickness,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: TextField(
                  controller: numberController,
                  focusNode: numberFocusNode,
                  enabled: canEdit,
                  keyboardType: TextInputType.phone,
                  textInputAction: textInputAction,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxNationalDigits),
                  ],
                  autofillHints: const <String>[
                    AutofillHints.telephoneNumberNational,
                  ],
                  restorationId: restorationId,
                  onChanged: onNumberChanged,
                  onSubmitted: onFieldSubmitted,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: canEdit
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    filled: false,
                    isDense: true,
                    hintText: numberHintText,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.md,
                      vertical: 13,
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhoneCountryButton extends StatelessWidget {
  const _PhoneCountryButton({
    required this.country,
    required this.labelText,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final _PhoneCountry country;
  final String labelText;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color contentColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.62);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$labelText ${country.callingCode}',
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.public_outlined,
                  size: theme.appTokens.listIconSize,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                SizedBox(width: theme.spacing.xs),
                Flexible(
                  child: Text(
                    country.callingCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isLoading) ...<Widget>[
                  SizedBox(width: theme.spacing.xs),
                  SizedBox.square(
                    dimension: theme.appTokens.listIconSize,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else ...<Widget>[
                  SizedBox(width: theme.spacing.xs),
                  Icon(
                    Icons.arrow_drop_down,
                    color: enabled
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ],
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
      maxWidth: 460,
      content: SizedBox(
        height: 440,
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
                          subtitle: Text(
                            '${country.callingCode}  ${country.isoCode.name}',
                          ),
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

    final String codeQuery = _query.replaceAll(RegExp(r'\D'), '');
    return _phoneCountries
        .where((_PhoneCountry country) {
          final String haystack =
              '${country.name} ${country.isoCode.name} ${country.callingCode} '
                      '${country.callingCodeDigits}'
                  .toLowerCase();
          return haystack.contains(_query) ||
              (codeQuery.isNotEmpty &&
                  country.callingCodeDigits.contains(codeQuery));
        })
        .toList(growable: false);
  }
}

@immutable
class _PhoneCountry {
  const _PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.callingCodeDigits,
    required this.isMainCountryForDialCode,
  });

  final String name;
  final IsoCode isoCode;
  final String callingCodeDigits;
  final bool isMainCountryForDialCode;

  String get callingCode => '+$callingCodeDigits';

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

final List<_PhoneCountry> _phoneCountries = _buildPhoneCountries();

List<_PhoneCountry> _buildPhoneCountries() {
  final List<_PhoneCountry> countries = <_PhoneCountry>[];
  for (final IsoCode isoCode in IsoCode.values) {
    final metadata = phone_metadata.metadataByIsoCode[isoCode];
    if (metadata == null) {
      continue;
    }
    countries.add(
      _PhoneCountry(
        name: _countryNames[isoCode] ?? isoCode.name,
        isoCode: isoCode,
        callingCodeDigits: metadata.countryCode,
        isMainCountryForDialCode: metadata.isMainCountryForDialCode,
      ),
    );
  }
  countries.sort((_PhoneCountry a, _PhoneCountry b) {
    final int nameComparison = a.name.compareTo(b.name);
    if (nameComparison != 0) {
      return nameComparison;
    }
    return a.callingCodeDigits.compareTo(b.callingCodeDigits);
  });
  return List<_PhoneCountry>.unmodifiable(countries);
}

const Map<IsoCode, String> _countryNames = <IsoCode, String>{
  IsoCode.AC: 'Ascension Island',
  IsoCode.AD: 'Andorra',
  IsoCode.AE: 'United Arab Emirates',
  IsoCode.AF: 'Afghanistan',
  IsoCode.AG: 'Antigua and Barbuda',
  IsoCode.AI: 'Anguilla',
  IsoCode.AL: 'Albania',
  IsoCode.AM: 'Armenia',
  IsoCode.AO: 'Angola',
  IsoCode.AR: 'Argentina',
  IsoCode.AS: 'American Samoa',
  IsoCode.AT: 'Austria',
  IsoCode.AU: 'Australia',
  IsoCode.AW: 'Aruba',
  IsoCode.AX: 'Aland Islands',
  IsoCode.AZ: 'Azerbaijan',
  IsoCode.BA: 'Bosnia and Herzegovina',
  IsoCode.BB: 'Barbados',
  IsoCode.BD: 'Bangladesh',
  IsoCode.BE: 'Belgium',
  IsoCode.BF: 'Burkina Faso',
  IsoCode.BG: 'Bulgaria',
  IsoCode.BH: 'Bahrain',
  IsoCode.BI: 'Burundi',
  IsoCode.BJ: 'Benin',
  IsoCode.BL: 'Saint Barthelemy',
  IsoCode.BM: 'Bermuda',
  IsoCode.BN: 'Brunei',
  IsoCode.BO: 'Bolivia',
  IsoCode.BQ: 'Bonaire, Sint Eustatius and Saba',
  IsoCode.BR: 'Brazil',
  IsoCode.BS: 'Bahamas',
  IsoCode.BT: 'Bhutan',
  IsoCode.BW: 'Botswana',
  IsoCode.BY: 'Belarus',
  IsoCode.BZ: 'Belize',
  IsoCode.CA: 'Canada',
  IsoCode.CC: 'Cocos Islands',
  IsoCode.CD: 'Congo DRC',
  IsoCode.CF: 'Central African Republic',
  IsoCode.CG: 'Congo',
  IsoCode.CH: 'Switzerland',
  IsoCode.CI: 'Cote d Ivoire',
  IsoCode.CK: 'Cook Islands',
  IsoCode.CL: 'Chile',
  IsoCode.CM: 'Cameroon',
  IsoCode.CN: 'China',
  IsoCode.CO: 'Colombia',
  IsoCode.CR: 'Costa Rica',
  IsoCode.CU: 'Cuba',
  IsoCode.CV: 'Cabo Verde',
  IsoCode.CW: 'Curacao',
  IsoCode.CX: 'Christmas Island',
  IsoCode.CY: 'Cyprus',
  IsoCode.CZ: 'Czechia',
  IsoCode.DE: 'Germany',
  IsoCode.DJ: 'Djibouti',
  IsoCode.DK: 'Denmark',
  IsoCode.DM: 'Dominica',
  IsoCode.DO: 'Dominican Republic',
  IsoCode.DZ: 'Algeria',
  IsoCode.EC: 'Ecuador',
  IsoCode.EE: 'Estonia',
  IsoCode.EG: 'Egypt',
  IsoCode.EH: 'Western Sahara',
  IsoCode.ER: 'Eritrea',
  IsoCode.ES: 'Spain',
  IsoCode.ET: 'Ethiopia',
  IsoCode.FI: 'Finland',
  IsoCode.FJ: 'Fiji',
  IsoCode.FK: 'Falkland Islands',
  IsoCode.FM: 'Micronesia',
  IsoCode.FO: 'Faroe Islands',
  IsoCode.FR: 'France',
  IsoCode.GA: 'Gabon',
  IsoCode.GB: 'United Kingdom',
  IsoCode.GD: 'Grenada',
  IsoCode.GE: 'Georgia',
  IsoCode.GF: 'French Guiana',
  IsoCode.GG: 'Guernsey',
  IsoCode.GH: 'Ghana',
  IsoCode.GI: 'Gibraltar',
  IsoCode.GL: 'Greenland',
  IsoCode.GM: 'Gambia',
  IsoCode.GN: 'Guinea',
  IsoCode.GP: 'Guadeloupe',
  IsoCode.GQ: 'Equatorial Guinea',
  IsoCode.GR: 'Greece',
  IsoCode.GT: 'Guatemala',
  IsoCode.GU: 'Guam',
  IsoCode.GW: 'Guinea-Bissau',
  IsoCode.GY: 'Guyana',
  IsoCode.HK: 'Hong Kong',
  IsoCode.HN: 'Honduras',
  IsoCode.HR: 'Croatia',
  IsoCode.HT: 'Haiti',
  IsoCode.HU: 'Hungary',
  IsoCode.ID: 'Indonesia',
  IsoCode.IE: 'Ireland',
  IsoCode.IL: 'Israel',
  IsoCode.IM: 'Isle of Man',
  IsoCode.IN: 'India',
  IsoCode.IO: 'British Indian Ocean Territory',
  IsoCode.IQ: 'Iraq',
  IsoCode.IR: 'Iran',
  IsoCode.IS: 'Iceland',
  IsoCode.IT: 'Italy',
  IsoCode.JE: 'Jersey',
  IsoCode.JM: 'Jamaica',
  IsoCode.JO: 'Jordan',
  IsoCode.JP: 'Japan',
  IsoCode.KE: 'Kenya',
  IsoCode.KG: 'Kyrgyzstan',
  IsoCode.KH: 'Cambodia',
  IsoCode.KI: 'Kiribati',
  IsoCode.KM: 'Comoros',
  IsoCode.KN: 'Saint Kitts and Nevis',
  IsoCode.KP: 'North Korea',
  IsoCode.KR: 'South Korea',
  IsoCode.KW: 'Kuwait',
  IsoCode.KY: 'Cayman Islands',
  IsoCode.KZ: 'Kazakhstan',
  IsoCode.LA: 'Laos',
  IsoCode.LB: 'Lebanon',
  IsoCode.LC: 'Saint Lucia',
  IsoCode.LI: 'Liechtenstein',
  IsoCode.LK: 'Sri Lanka',
  IsoCode.LR: 'Liberia',
  IsoCode.LS: 'Lesotho',
  IsoCode.LT: 'Lithuania',
  IsoCode.LU: 'Luxembourg',
  IsoCode.LV: 'Latvia',
  IsoCode.LY: 'Libya',
  IsoCode.MA: 'Morocco',
  IsoCode.MC: 'Monaco',
  IsoCode.MD: 'Moldova',
  IsoCode.ME: 'Montenegro',
  IsoCode.MF: 'Saint Martin',
  IsoCode.MG: 'Madagascar',
  IsoCode.MH: 'Marshall Islands',
  IsoCode.MK: 'North Macedonia',
  IsoCode.ML: 'Mali',
  IsoCode.MM: 'Myanmar',
  IsoCode.MN: 'Mongolia',
  IsoCode.MO: 'Macao',
  IsoCode.MP: 'Northern Mariana Islands',
  IsoCode.MQ: 'Martinique',
  IsoCode.MR: 'Mauritania',
  IsoCode.MS: 'Montserrat',
  IsoCode.MT: 'Malta',
  IsoCode.MU: 'Mauritius',
  IsoCode.MV: 'Maldives',
  IsoCode.MW: 'Malawi',
  IsoCode.MX: 'Mexico',
  IsoCode.MY: 'Malaysia',
  IsoCode.MZ: 'Mozambique',
  IsoCode.NA: 'Namibia',
  IsoCode.NC: 'New Caledonia',
  IsoCode.NE: 'Niger',
  IsoCode.NF: 'Norfolk Island',
  IsoCode.NG: 'Nigeria',
  IsoCode.NI: 'Nicaragua',
  IsoCode.NL: 'Netherlands',
  IsoCode.NO: 'Norway',
  IsoCode.NP: 'Nepal',
  IsoCode.NR: 'Nauru',
  IsoCode.NU: 'Niue',
  IsoCode.NZ: 'New Zealand',
  IsoCode.OM: 'Oman',
  IsoCode.PA: 'Panama',
  IsoCode.PE: 'Peru',
  IsoCode.PF: 'French Polynesia',
  IsoCode.PG: 'Papua New Guinea',
  IsoCode.PH: 'Philippines',
  IsoCode.PK: 'Pakistan',
  IsoCode.PL: 'Poland',
  IsoCode.PM: 'Saint Pierre and Miquelon',
  IsoCode.PR: 'Puerto Rico',
  IsoCode.PS: 'Palestine',
  IsoCode.PT: 'Portugal',
  IsoCode.PW: 'Palau',
  IsoCode.PY: 'Paraguay',
  IsoCode.QA: 'Qatar',
  IsoCode.RE: 'Reunion',
  IsoCode.RO: 'Romania',
  IsoCode.RS: 'Serbia',
  IsoCode.RU: 'Russia',
  IsoCode.RW: 'Rwanda',
  IsoCode.SA: 'Saudi Arabia',
  IsoCode.SB: 'Solomon Islands',
  IsoCode.SC: 'Seychelles',
  IsoCode.SD: 'Sudan',
  IsoCode.SE: 'Sweden',
  IsoCode.SG: 'Singapore',
  IsoCode.SH: 'Saint Helena',
  IsoCode.SI: 'Slovenia',
  IsoCode.SJ: 'Svalbard and Jan Mayen',
  IsoCode.SK: 'Slovakia',
  IsoCode.SL: 'Sierra Leone',
  IsoCode.SM: 'San Marino',
  IsoCode.SN: 'Senegal',
  IsoCode.SO: 'Somalia',
  IsoCode.SR: 'Suriname',
  IsoCode.SS: 'South Sudan',
  IsoCode.ST: 'Sao Tome and Principe',
  IsoCode.SV: 'El Salvador',
  IsoCode.SX: 'Sint Maarten',
  IsoCode.SY: 'Syria',
  IsoCode.SZ: 'Eswatini',
  IsoCode.TA: 'Tristan da Cunha',
  IsoCode.TC: 'Turks and Caicos Islands',
  IsoCode.TD: 'Chad',
  IsoCode.TG: 'Togo',
  IsoCode.TH: 'Thailand',
  IsoCode.TJ: 'Tajikistan',
  IsoCode.TK: 'Tokelau',
  IsoCode.TL: 'Timor-Leste',
  IsoCode.TM: 'Turkmenistan',
  IsoCode.TN: 'Tunisia',
  IsoCode.TO: 'Tonga',
  IsoCode.TR: 'Turkiye',
  IsoCode.TT: 'Trinidad and Tobago',
  IsoCode.TV: 'Tuvalu',
  IsoCode.TW: 'Taiwan',
  IsoCode.TZ: 'Tanzania',
  IsoCode.UA: 'Ukraine',
  IsoCode.UG: 'Uganda',
  IsoCode.US: 'United States',
  IsoCode.UY: 'Uruguay',
  IsoCode.UZ: 'Uzbekistan',
  IsoCode.VA: 'Vatican City',
  IsoCode.VC: 'Saint Vincent and the Grenadines',
  IsoCode.VE: 'Venezuela',
  IsoCode.VG: 'British Virgin Islands',
  IsoCode.VI: 'U.S. Virgin Islands',
  IsoCode.VN: 'Vietnam',
  IsoCode.VU: 'Vanuatu',
  IsoCode.WF: 'Wallis and Futuna',
  IsoCode.WS: 'Samoa',
  IsoCode.XK: 'Kosovo',
  IsoCode.YE: 'Yemen',
  IsoCode.YT: 'Mayotte',
  IsoCode.ZA: 'South Africa',
  IsoCode.ZM: 'Zambia',
  IsoCode.ZW: 'Zimbabwe',
};
