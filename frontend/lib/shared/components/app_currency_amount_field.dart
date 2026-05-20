import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

const String appDefaultCurrencyCode = 'UGX';

String normalizeCurrencyAmount(String value) {
  return value.replaceAll(',', '').trim();
}

class AppCurrencyOption {
  const AppCurrencyOption({
    required this.code,
    required this.name,
    required this.country,
    this.flagCode,
  });

  final String code;
  final String name;
  final String country;
  final String? flagCode;

  String get normalizedCode => code.trim().toUpperCase();
  String get label => '$normalizedCode - $name';
  String? get effectiveFlagCode =>
      flagCode ?? _currencyFlagCodes[normalizedCode];
  String? get flagEmoji => _flagEmojiForRegionCode(effectiveFlagCode);
  String get searchText {
    return '$normalizedCode $name $country ${effectiveFlagCode ?? ''}'
        .toLowerCase();
  }
}

class AppCurrencyAmountField extends StatefulWidget {
  const AppCurrencyAmountField({
    required this.amountController,
    required this.currency,
    required this.onCurrencyChanged,
    required this.amountLabelText,
    required this.currencyLabelText,
    this.amountHintText,
    this.currencyHintText,
    this.helperText,
    this.errorText,
    this.amountSemanticLabel,
    this.currencySemanticLabel,
    this.currencySearchLabelText,
    this.currencyNoResultsText = 'No matching currencies found.',
    this.requiredMessage = 'This field is required.',
    this.amountInvalidMessage = 'Enter a valid amount.',
    this.currencyInvalidMessage = 'Choose a supported currency.',
    this.enabled = true,
    this.isLoading = false,
    this.isRequired = false,
    this.allowZero = true,
    this.decimalDigits = 2,
    this.maxAmount,
    this.validator,
    this.onAmountChanged,
    this.onSaved,
    this.onFieldSubmitted,
    this.onFocusChanged,
    this.focusNode,
    this.autovalidateMode,
    this.restorationId,
    this.textInputAction,
    this.currencyOptions = appCurrencyOptions,
    super.key,
  }) : assert(decimalDigits == null || decimalDigits >= 0);

  final TextEditingController amountController;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final String amountLabelText;
  final String currencyLabelText;
  final String? amountHintText;
  final String? currencyHintText;
  final String? helperText;
  final String? errorText;
  final String? amountSemanticLabel;
  final String? currencySemanticLabel;
  final String? currencySearchLabelText;
  final String currencyNoResultsText;
  final String requiredMessage;
  final String amountInvalidMessage;
  final String currencyInvalidMessage;
  final bool enabled;
  final bool isLoading;
  final bool isRequired;
  final bool allowZero;
  final int? decimalDigits;
  final num? maxAmount;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onAmountChanged;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;
  final String? restorationId;
  final TextInputAction? textInputAction;
  final List<AppCurrencyOption> currencyOptions;

  @override
  State<AppCurrencyAmountField> createState() => _AppCurrencyAmountFieldState();
}

class _AppCurrencyAmountFieldState extends State<AppCurrencyAmountField> {
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();
  late FocusNode _amountFocusNode;
  late bool _ownsFocusNode;
  bool _isPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
    widget.amountController.addListener(_handleAmountControllerChanged);
  }

  @override
  void didUpdateWidget(AppCurrencyAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountController != widget.amountController) {
      oldWidget.amountController.removeListener(_handleAmountControllerChanged);
      widget.amountController.addListener(_handleAmountControllerChanged);
      _fieldKey.currentState?.didChange(widget.amountController.text);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_handleAmountControllerChanged);
    _detachFocusNode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = widget.enabled && !widget.isLoading;
    Widget field = FormField<String>(
      key: _fieldKey,
      initialValue: widget.amountController.text,
      autovalidateMode: widget.autovalidateMode,
      validator: _validateAmount,
      onSaved: (_) => widget.onSaved?.call(widget.amountController.text),
      builder: (FormFieldState<String> formField) {
        return InputDecorator(
          isFocused: _amountFocusNode.hasFocus || _isPickerOpen,
          isEmpty: widget.amountController.text.trim().isEmpty,
          decoration: InputDecoration(
            enabled: canEdit,
            label: appFieldLabelWidget(
              context,
              widget.amountLabelText,
              isRequired: widget.isRequired,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            helperText: widget.helperText,
            errorText: widget.errorText ?? formField.errorText,
            contentPadding: EdgeInsets.zero,
          ),
          child: _UnifiedCurrencyAmountInput(
            amountController: widget.amountController,
            amountFocusNode: _amountFocusNode,
            amountHintText: widget.amountHintText,
            currencyHintText: widget.currencyHintText,
            currency: widget.currency,
            selectedCurrency: _optionForCode(widget.currency),
            currencyLabelText:
                widget.currencySemanticLabel ?? widget.currencyLabelText,
            canEdit: canEdit,
            isLoading: widget.isLoading,
            decimalDigits: widget.decimalDigits,
            restorationId: widget.restorationId,
            textInputAction: widget.textInputAction,
            onAmountChanged: (String value) {
              formField.didChange(value);
              widget.onAmountChanged?.call(value);
            },
            onFieldSubmitted: widget.onFieldSubmitted,
            onSelectCurrency: () => _selectCurrency(formField),
          ),
        );
      },
    );

    final String semanticLabel =
        widget.amountSemanticLabel ?? widget.amountLabelText;
    if (semanticLabel.isNotEmpty) {
      field = Semantics(
        textField: true,
        enabled: canEdit,
        label: semanticLabel,
        child: field,
      );
    }

    return field;
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _amountFocusNode = widget.focusNode ?? FocusNode();
    _amountFocusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _amountFocusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _amountFocusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_amountFocusNode.hasFocus);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAmountControllerChanged() {
    _fieldKey.currentState?.didChange(widget.amountController.text);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCurrency(FormFieldState<String> formField) async {
    if (!widget.enabled || widget.isLoading || widget.currencyOptions.isEmpty) {
      return;
    }

    setState(() {
      _isPickerOpen = true;
    });
    final AppCurrencyOption? selected = await showAppDialog<AppCurrencyOption>(
      context: context,
      builder: (_) => _CurrencyPickerDialog(
        title: widget.currencyLabelText,
        searchLabelText: widget.currencySearchLabelText,
        noResultsText: widget.currencyNoResultsText,
        selectedCode: widget.currency,
        options: widget.currencyOptions,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isPickerOpen = false;
    });

    if (selected == null || selected.normalizedCode == _normalizedCurrency) {
      return;
    }

    widget.onCurrencyChanged(selected.normalizedCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        formField.validate();
      }
    });
  }

  String? _validateAmount(String? _) {
    final String rawValue = widget.amountController.text;
    final String normalized = normalizeCurrencyAmount(rawValue);
    if (normalized.isEmpty) {
      return widget.validator?.call(rawValue) ??
          (widget.isRequired ? widget.requiredMessage : null);
    }

    if (!_validCurrencyAmountPattern.hasMatch(normalized)) {
      return widget.amountInvalidMessage;
    }

    final List<String> parts = normalized.split('.');
    if (parts.length == 2 &&
        widget.decimalDigits != null &&
        parts.last.length > widget.decimalDigits!) {
      return widget.amountInvalidMessage;
    }

    final double? parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return widget.amountInvalidMessage;
    }
    if (!widget.allowZero && parsed == 0) {
      return widget.amountInvalidMessage;
    }
    if (widget.maxAmount != null && parsed > widget.maxAmount!) {
      return widget.amountInvalidMessage;
    }
    if (_optionForCode(widget.currency) == null) {
      return widget.currencyInvalidMessage;
    }

    return widget.validator?.call(rawValue);
  }

  AppCurrencyOption? _optionForCode(String code) {
    final String normalized = code.trim().toUpperCase();
    for (final AppCurrencyOption option in widget.currencyOptions) {
      if (option.normalizedCode == normalized) {
        return option;
      }
    }
    return null;
  }

  String get _normalizedCurrency => widget.currency.trim().toUpperCase();
}

class CurrencyAmountInputFormatter extends TextInputFormatter {
  const CurrencyAmountInputFormatter({this.decimalDigits});

  final int? decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String raw = newValue.text.replaceAll(',', '').trim();
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (raw.startsWith('.')) {
      raw = '0$raw';
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) {
      return oldValue;
    }

    final List<String> parts = raw.split('.');
    if (parts.length > 2) {
      return oldValue;
    }
    if (parts.length == 2 &&
        decimalDigits != null &&
        parts.last.length > decimalDigits!) {
      return oldValue;
    }

    final String integerPart = parts.first;
    final String decimalPart = parts.length == 2 ? parts.last : '';
    final String formattedInteger = _groupInteger(integerPart);
    final String formatted = parts.length == 2
        ? '$formattedInteger.$decimalPart'
        : formattedInteger;
    final int offsetFromEnd = newValue.text.length - newValue.selection.end;
    final int selectionOffset = math.max(0, formatted.length - offsetFromEnd);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: math.min(selectionOffset, formatted.length),
      ),
    );
  }

  String _groupInteger(String value) {
    if (value.length <= 3) {
      return value;
    }

    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < value.length; index += 1) {
      final int remaining = value.length - index;
      buffer.write(value[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _UnifiedCurrencyAmountInput extends StatelessWidget {
  const _UnifiedCurrencyAmountInput({
    required this.amountController,
    required this.amountFocusNode,
    required this.currency,
    required this.currencyLabelText,
    required this.canEdit,
    required this.isLoading,
    required this.onAmountChanged,
    required this.onSelectCurrency,
    this.amountHintText,
    this.currencyHintText,
    this.selectedCurrency,
    this.decimalDigits,
    this.restorationId,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final String currency;
  final String currencyLabelText;
  final bool canEdit;
  final bool isLoading;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onSelectCurrency;
  final String? amountHintText;
  final String? currencyHintText;
  final AppCurrencyOption? selectedCurrency;
  final int? decimalDigits;
  final String? restorationId;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360;
        final bool veryCompact = availableWidth < 280;
        final bool compact = availableWidth < 420;
        final double currencyWidth = _currencyButtonWidth(availableWidth);

        return SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: amountController,
                  focusNode: amountFocusNode,
                  enabled: canEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: textInputAction,
                  inputFormatters: <TextInputFormatter>[
                    CurrencyAmountInputFormatter(decimalDigits: decimalDigits),
                  ],
                  autofillHints: const <String>[
                    AutofillHints.transactionAmount,
                  ],
                  restorationId: restorationId,
                  onChanged: onAmountChanged,
                  onSubmitted: onFieldSubmitted,
                  autocorrect: false,
                  enableSuggestions: false,
                  style:
                      (compact
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            color: canEdit
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w700,
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
                    hintText: amountHintText,
                    contentPadding: EdgeInsetsDirectional.only(
                      start: veryCompact ? theme.spacing.md : theme.spacing.lg,
                      end: theme.spacing.sm,
                      top: 17,
                      bottom: 15,
                    ),
                    counterText: '',
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
                child: VerticalDivider(
                  width: theme.appTokens.dividerThickness,
                  thickness: theme.appTokens.dividerThickness,
                  color: colorScheme.outlineVariant,
                ),
              ),
              SizedBox(
                width: currencyWidth,
                child: _CurrencySelectButton(
                  option: selectedCurrency,
                  currency: currency,
                  hintText: currencyHintText,
                  labelText: currencyLabelText,
                  enabled: canEdit,
                  isLoading: isLoading,
                  compact: compact,
                  veryCompact: veryCompact,
                  onPressed: onSelectCurrency,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _currencyButtonWidth(double availableWidth) {
    if (availableWidth < 220) {
      return math.max(76, availableWidth * 0.44);
    }
    if (availableWidth < 280) {
      return 104;
    }
    if (availableWidth < 420) {
      return 124;
    }
    return 156;
  }
}

class _CurrencySelectButton extends StatelessWidget {
  const _CurrencySelectButton({
    required this.option,
    required this.currency,
    required this.labelText,
    required this.enabled,
    required this.isLoading,
    required this.compact,
    required this.veryCompact,
    required this.onPressed,
    this.hintText,
  });

  final AppCurrencyOption? option;
  final String currency;
  final String labelText;
  final bool enabled;
  final bool isLoading;
  final bool compact;
  final bool veryCompact;
  final VoidCallback onPressed;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String normalizedCurrency = currency.trim().toUpperCase();
    final String code =
        option?.normalizedCode ??
        (normalizedCurrency.isEmpty
            ? hintText ?? labelText
            : normalizedCurrency);
    final bool hasCurrency = option != null || normalizedCurrency.isNotEmpty;
    final Color contentColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.62);
    final Color iconColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$labelText $code',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: veryCompact ? theme.spacing.xs : theme.spacing.sm,
              end: theme.spacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (!veryCompact) ...<Widget>[
                  _CurrencyFlagIcon(
                    option: hasCurrency ? option : null,
                    size: compact ? 26 : 30,
                    enabled: enabled,
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Flexible(
                  child: Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.headlineSmall)
                            ?.copyWith(
                              color: hasCurrency
                                  ? contentColor
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
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
                  SizedBox(
                    width: veryCompact ? theme.spacing.xs : theme.spacing.sm,
                  ),
                  Icon(Icons.keyboard_arrow_down, color: iconColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPickerDialog extends StatefulWidget {
  const _CurrencyPickerDialog({
    required this.title,
    required this.noResultsText,
    required this.selectedCode,
    required this.options,
    this.searchLabelText,
  });

  final String title;
  final String? searchLabelText;
  final String noResultsText;
  final String selectedCode;
  final List<AppCurrencyOption> options;

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
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
    final List<AppCurrencyOption> options = _filteredOptions;

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.payments_outlined),
      maxWidth: 520,
      content: SizedBox(
        height: math.min(MediaQuery.sizeOf(context).height * 0.62, 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _searchController,
              labelText:
                  widget.searchLabelText ??
                  MaterialLocalizations.of(context).searchFieldLabel,
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
              child: options.isEmpty
                  ? Center(
                      child: Text(
                        widget.noResultsText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colorScheme.outlineVariant),
                      itemBuilder: (BuildContext context, int index) {
                        final AppCurrencyOption option = options[index];
                        final bool selected =
                            option.normalizedCode ==
                            widget.selectedCode.trim().toUpperCase();

                        return ListTile(
                          leading: _CurrencyFlagIcon(option: option),
                          title: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            option.country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          onTap: () {
                            Navigator.of(context).pop(option);
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

  List<AppCurrencyOption> get _filteredOptions {
    if (_query.isEmpty) {
      return widget.options;
    }

    return widget.options
        .where((AppCurrencyOption option) => option.searchText.contains(_query))
        .toList(growable: false);
  }
}

class _CurrencyFlagIcon extends StatelessWidget {
  const _CurrencyFlagIcon({
    required this.option,
    this.size = 32,
    this.enabled = true,
  });

  final AppCurrencyOption? option;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? emoji = option?.flagEmoji;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: emoji == null
          ? Icon(
              Icons.public_outlined,
              size: size * 0.58,
              color: enabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface.withValues(alpha: 0.38),
            )
          : Text(
              emoji,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 0.62,
                height: 1,
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
    );
  }
}

String? _flagEmojiForRegionCode(String? regionCode) {
  final String normalized = regionCode?.trim().toUpperCase() ?? '';
  if (!_regionCodePattern.hasMatch(normalized)) {
    return null;
  }

  return String.fromCharCodes(
    normalized.codeUnits.map((int unit) => 0x1F1E6 + unit - 0x41),
  );
}

final RegExp _regionCodePattern = RegExp(r'^[A-Z]{2}$');
final RegExp _validCurrencyAmountPattern = RegExp(r'^\d+(?:\.\d*)?$');

const Map<String, String> _currencyFlagCodes = <String, String>{
  'AED': 'AE',
  'AFN': 'AF',
  'ALL': 'AL',
  'AMD': 'AM',
  'ANG': 'CW',
  'AOA': 'AO',
  'ARS': 'AR',
  'AUD': 'AU',
  'AWG': 'AW',
  'AZN': 'AZ',
  'BAM': 'BA',
  'BBD': 'BB',
  'BDT': 'BD',
  'BGN': 'BG',
  'BHD': 'BH',
  'BIF': 'BI',
  'BMD': 'BM',
  'BND': 'BN',
  'BOB': 'BO',
  'BRL': 'BR',
  'BSD': 'BS',
  'BTN': 'BT',
  'BWP': 'BW',
  'BYN': 'BY',
  'BZD': 'BZ',
  'CAD': 'CA',
  'CDF': 'CD',
  'CHF': 'CH',
  'CLP': 'CL',
  'CNY': 'CN',
  'COP': 'CO',
  'CRC': 'CR',
  'CUP': 'CU',
  'CVE': 'CV',
  'CZK': 'CZ',
  'DJF': 'DJ',
  'DKK': 'DK',
  'DOP': 'DO',
  'DZD': 'DZ',
  'EGP': 'EG',
  'ERN': 'ER',
  'ETB': 'ET',
  'EUR': 'EU',
  'FJD': 'FJ',
  'FKP': 'FK',
  'GBP': 'GB',
  'GEL': 'GE',
  'GHS': 'GH',
  'GIP': 'GI',
  'GMD': 'GM',
  'GNF': 'GN',
  'GTQ': 'GT',
  'GYD': 'GY',
  'HKD': 'HK',
  'HNL': 'HN',
  'HTG': 'HT',
  'HUF': 'HU',
  'IDR': 'ID',
  'ILS': 'IL',
  'INR': 'IN',
  'IQD': 'IQ',
  'IRR': 'IR',
  'ISK': 'IS',
  'JMD': 'JM',
  'JOD': 'JO',
  'JPY': 'JP',
  'KES': 'KE',
  'KGS': 'KG',
  'KHR': 'KH',
  'KMF': 'KM',
  'KRW': 'KR',
  'KWD': 'KW',
  'KYD': 'KY',
  'KZT': 'KZ',
  'LAK': 'LA',
  'LBP': 'LB',
  'LKR': 'LK',
  'LRD': 'LR',
  'LSL': 'LS',
  'LYD': 'LY',
  'MAD': 'MA',
  'MDL': 'MD',
  'MGA': 'MG',
  'MKD': 'MK',
  'MMK': 'MM',
  'MNT': 'MN',
  'MOP': 'MO',
  'MRU': 'MR',
  'MUR': 'MU',
  'MVR': 'MV',
  'MWK': 'MW',
  'MXN': 'MX',
  'MYR': 'MY',
  'MZN': 'MZ',
  'NAD': 'NA',
  'NGN': 'NG',
  'NIO': 'NI',
  'NOK': 'NO',
  'NPR': 'NP',
  'NZD': 'NZ',
  'OMR': 'OM',
  'PAB': 'PA',
  'PEN': 'PE',
  'PGK': 'PG',
  'PHP': 'PH',
  'PKR': 'PK',
  'PLN': 'PL',
  'PYG': 'PY',
  'QAR': 'QA',
  'RON': 'RO',
  'RSD': 'RS',
  'RUB': 'RU',
  'RWF': 'RW',
  'SAR': 'SA',
  'SBD': 'SB',
  'SCR': 'SC',
  'SDG': 'SD',
  'SEK': 'SE',
  'SGD': 'SG',
  'SHP': 'SH',
  'SLE': 'SL',
  'SOS': 'SO',
  'SRD': 'SR',
  'SSP': 'SS',
  'STN': 'ST',
  'SYP': 'SY',
  'SZL': 'SZ',
  'THB': 'TH',
  'TJS': 'TJ',
  'TMT': 'TM',
  'TND': 'TN',
  'TOP': 'TO',
  'TRY': 'TR',
  'TTD': 'TT',
  'TWD': 'TW',
  'TZS': 'TZ',
  'UAH': 'UA',
  'UGX': 'UG',
  'USD': 'US',
  'UYU': 'UY',
  'UZS': 'UZ',
  'VES': 'VE',
  'VND': 'VN',
  'VUV': 'VU',
  'WST': 'WS',
  'XAF': 'CM',
  'XCD': 'AG',
  'XOF': 'SN',
  'XPF': 'PF',
  'YER': 'YE',
  'ZAR': 'ZA',
  'ZMW': 'ZM',
  'ZWL': 'ZW',
};

const List<AppCurrencyOption> appCurrencyOptions = <AppCurrencyOption>[
  AppCurrencyOption(code: 'UGX', name: 'Uganda Shilling', country: 'Uganda'),
  AppCurrencyOption(
    code: 'AED',
    name: 'UAE Dirham',
    country: 'United Arab Emirates',
  ),
  AppCurrencyOption(
    code: 'AFN',
    name: 'Afghan Afghani',
    country: 'Afghanistan',
  ),
  AppCurrencyOption(code: 'ALL', name: 'Albanian Lek', country: 'Albania'),
  AppCurrencyOption(code: 'AMD', name: 'Armenian Dram', country: 'Armenia'),
  AppCurrencyOption(
    code: 'ANG',
    name: 'Netherlands Antillean Guilder',
    country: 'Curacao and Sint Maarten',
  ),
  AppCurrencyOption(code: 'AOA', name: 'Angolan Kwanza', country: 'Angola'),
  AppCurrencyOption(code: 'ARS', name: 'Argentine Peso', country: 'Argentina'),
  AppCurrencyOption(
    code: 'AUD',
    name: 'Australian Dollar',
    country: 'Australia',
  ),
  AppCurrencyOption(code: 'AWG', name: 'Aruban Florin', country: 'Aruba'),
  AppCurrencyOption(
    code: 'AZN',
    name: 'Azerbaijani Manat',
    country: 'Azerbaijan',
  ),
  AppCurrencyOption(
    code: 'BAM',
    name: 'Convertible Mark',
    country: 'Bosnia and Herzegovina',
  ),
  AppCurrencyOption(code: 'BBD', name: 'Barbadian Dollar', country: 'Barbados'),
  AppCurrencyOption(
    code: 'BDT',
    name: 'Bangladeshi Taka',
    country: 'Bangladesh',
  ),
  AppCurrencyOption(code: 'BGN', name: 'Bulgarian Lev', country: 'Bulgaria'),
  AppCurrencyOption(code: 'BHD', name: 'Bahraini Dinar', country: 'Bahrain'),
  AppCurrencyOption(code: 'BIF', name: 'Burundian Franc', country: 'Burundi'),
  AppCurrencyOption(code: 'BMD', name: 'Bermudian Dollar', country: 'Bermuda'),
  AppCurrencyOption(code: 'BND', name: 'Brunei Dollar', country: 'Brunei'),
  AppCurrencyOption(
    code: 'BOB',
    name: 'Bolivian Boliviano',
    country: 'Bolivia',
  ),
  AppCurrencyOption(code: 'BRL', name: 'Brazilian Real', country: 'Brazil'),
  AppCurrencyOption(code: 'BSD', name: 'Bahamian Dollar', country: 'Bahamas'),
  AppCurrencyOption(code: 'BTN', name: 'Bhutanese Ngultrum', country: 'Bhutan'),
  AppCurrencyOption(code: 'BWP', name: 'Botswana Pula', country: 'Botswana'),
  AppCurrencyOption(code: 'BYN', name: 'Belarusian Ruble', country: 'Belarus'),
  AppCurrencyOption(code: 'BZD', name: 'Belize Dollar', country: 'Belize'),
  AppCurrencyOption(code: 'CAD', name: 'Canadian Dollar', country: 'Canada'),
  AppCurrencyOption(
    code: 'CDF',
    name: 'Congolese Franc',
    country: 'Democratic Republic of the Congo',
  ),
  AppCurrencyOption(code: 'CHF', name: 'Swiss Franc', country: 'Switzerland'),
  AppCurrencyOption(code: 'CLP', name: 'Chilean Peso', country: 'Chile'),
  AppCurrencyOption(code: 'CNY', name: 'Chinese Yuan', country: 'China'),
  AppCurrencyOption(code: 'COP', name: 'Colombian Peso', country: 'Colombia'),
  AppCurrencyOption(
    code: 'CRC',
    name: 'Costa Rican Colon',
    country: 'Costa Rica',
  ),
  AppCurrencyOption(code: 'CUP', name: 'Cuban Peso', country: 'Cuba'),
  AppCurrencyOption(
    code: 'CVE',
    name: 'Cape Verdean Escudo',
    country: 'Cabo Verde',
  ),
  AppCurrencyOption(
    code: 'CZK',
    name: 'Czech Koruna',
    country: 'Czech Republic',
  ),
  AppCurrencyOption(code: 'DJF', name: 'Djiboutian Franc', country: 'Djibouti'),
  AppCurrencyOption(code: 'DKK', name: 'Danish Krone', country: 'Denmark'),
  AppCurrencyOption(
    code: 'DOP',
    name: 'Dominican Peso',
    country: 'Dominican Republic',
  ),
  AppCurrencyOption(code: 'DZD', name: 'Algerian Dinar', country: 'Algeria'),
  AppCurrencyOption(code: 'EGP', name: 'Egyptian Pound', country: 'Egypt'),
  AppCurrencyOption(code: 'ERN', name: 'Eritrean Nakfa', country: 'Eritrea'),
  AppCurrencyOption(code: 'ETB', name: 'Ethiopian Birr', country: 'Ethiopia'),
  AppCurrencyOption(code: 'EUR', name: 'Euro', country: 'European Union'),
  AppCurrencyOption(code: 'FJD', name: 'Fijian Dollar', country: 'Fiji'),
  AppCurrencyOption(
    code: 'FKP',
    name: 'Falkland Islands Pound',
    country: 'Falkland Islands',
  ),
  AppCurrencyOption(
    code: 'GBP',
    name: 'Pound Sterling',
    country: 'United Kingdom',
  ),
  AppCurrencyOption(code: 'GEL', name: 'Georgian Lari', country: 'Georgia'),
  AppCurrencyOption(code: 'GHS', name: 'Ghanaian Cedi', country: 'Ghana'),
  AppCurrencyOption(code: 'GIP', name: 'Gibraltar Pound', country: 'Gibraltar'),
  AppCurrencyOption(code: 'GMD', name: 'Gambian Dalasi', country: 'Gambia'),
  AppCurrencyOption(code: 'GNF', name: 'Guinean Franc', country: 'Guinea'),
  AppCurrencyOption(
    code: 'GTQ',
    name: 'Guatemalan Quetzal',
    country: 'Guatemala',
  ),
  AppCurrencyOption(code: 'GYD', name: 'Guyanese Dollar', country: 'Guyana'),
  AppCurrencyOption(
    code: 'HKD',
    name: 'Hong Kong Dollar',
    country: 'Hong Kong',
  ),
  AppCurrencyOption(code: 'HNL', name: 'Honduran Lempira', country: 'Honduras'),
  AppCurrencyOption(code: 'HTG', name: 'Haitian Gourde', country: 'Haiti'),
  AppCurrencyOption(code: 'HUF', name: 'Hungarian Forint', country: 'Hungary'),
  AppCurrencyOption(
    code: 'IDR',
    name: 'Indonesian Rupiah',
    country: 'Indonesia',
  ),
  AppCurrencyOption(code: 'ILS', name: 'Israeli New Shekel', country: 'Israel'),
  AppCurrencyOption(code: 'INR', name: 'Indian Rupee', country: 'India'),
  AppCurrencyOption(code: 'IQD', name: 'Iraqi Dinar', country: 'Iraq'),
  AppCurrencyOption(code: 'IRR', name: 'Iranian Rial', country: 'Iran'),
  AppCurrencyOption(code: 'ISK', name: 'Icelandic Krona', country: 'Iceland'),
  AppCurrencyOption(code: 'JMD', name: 'Jamaican Dollar', country: 'Jamaica'),
  AppCurrencyOption(code: 'JOD', name: 'Jordanian Dinar', country: 'Jordan'),
  AppCurrencyOption(code: 'JPY', name: 'Japanese Yen', country: 'Japan'),
  AppCurrencyOption(code: 'KES', name: 'Kenyan Shilling', country: 'Kenya'),
  AppCurrencyOption(
    code: 'KGS',
    name: 'Kyrgyzstani Som',
    country: 'Kyrgyzstan',
  ),
  AppCurrencyOption(code: 'KHR', name: 'Cambodian Riel', country: 'Cambodia'),
  AppCurrencyOption(code: 'KMF', name: 'Comorian Franc', country: 'Comoros'),
  AppCurrencyOption(
    code: 'KRW',
    name: 'South Korean Won',
    country: 'South Korea',
  ),
  AppCurrencyOption(code: 'KWD', name: 'Kuwaiti Dinar', country: 'Kuwait'),
  AppCurrencyOption(
    code: 'KYD',
    name: 'Cayman Islands Dollar',
    country: 'Cayman Islands',
  ),
  AppCurrencyOption(
    code: 'KZT',
    name: 'Kazakhstani Tenge',
    country: 'Kazakhstan',
  ),
  AppCurrencyOption(code: 'LAK', name: 'Lao Kip', country: 'Laos'),
  AppCurrencyOption(code: 'LBP', name: 'Lebanese Pound', country: 'Lebanon'),
  AppCurrencyOption(
    code: 'LKR',
    name: 'Sri Lankan Rupee',
    country: 'Sri Lanka',
  ),
  AppCurrencyOption(code: 'LRD', name: 'Liberian Dollar', country: 'Liberia'),
  AppCurrencyOption(code: 'LSL', name: 'Lesotho Loti', country: 'Lesotho'),
  AppCurrencyOption(code: 'LYD', name: 'Libyan Dinar', country: 'Libya'),
  AppCurrencyOption(code: 'MAD', name: 'Moroccan Dirham', country: 'Morocco'),
  AppCurrencyOption(code: 'MDL', name: 'Moldovan Leu', country: 'Moldova'),
  AppCurrencyOption(
    code: 'MGA',
    name: 'Malagasy Ariary',
    country: 'Madagascar',
  ),
  AppCurrencyOption(
    code: 'MKD',
    name: 'Macedonian Denar',
    country: 'North Macedonia',
  ),
  AppCurrencyOption(code: 'MMK', name: 'Myanmar Kyat', country: 'Myanmar'),
  AppCurrencyOption(code: 'MNT', name: 'Mongolian Tugrik', country: 'Mongolia'),
  AppCurrencyOption(code: 'MOP', name: 'Macanese Pataca', country: 'Macau'),
  AppCurrencyOption(
    code: 'MRU',
    name: 'Mauritanian Ouguiya',
    country: 'Mauritania',
  ),
  AppCurrencyOption(code: 'MUR', name: 'Mauritian Rupee', country: 'Mauritius'),
  AppCurrencyOption(
    code: 'MVR',
    name: 'Maldivian Rufiyaa',
    country: 'Maldives',
  ),
  AppCurrencyOption(code: 'MWK', name: 'Malawian Kwacha', country: 'Malawi'),
  AppCurrencyOption(code: 'MXN', name: 'Mexican Peso', country: 'Mexico'),
  AppCurrencyOption(
    code: 'MYR',
    name: 'Malaysian Ringgit',
    country: 'Malaysia',
  ),
  AppCurrencyOption(
    code: 'MZN',
    name: 'Mozambican Metical',
    country: 'Mozambique',
  ),
  AppCurrencyOption(code: 'NAD', name: 'Namibian Dollar', country: 'Namibia'),
  AppCurrencyOption(code: 'NGN', name: 'Nigerian Naira', country: 'Nigeria'),
  AppCurrencyOption(
    code: 'NIO',
    name: 'Nicaraguan Cordoba',
    country: 'Nicaragua',
  ),
  AppCurrencyOption(code: 'NOK', name: 'Norwegian Krone', country: 'Norway'),
  AppCurrencyOption(code: 'NPR', name: 'Nepalese Rupee', country: 'Nepal'),
  AppCurrencyOption(
    code: 'NZD',
    name: 'New Zealand Dollar',
    country: 'New Zealand',
  ),
  AppCurrencyOption(code: 'OMR', name: 'Omani Rial', country: 'Oman'),
  AppCurrencyOption(code: 'PAB', name: 'Panamanian Balboa', country: 'Panama'),
  AppCurrencyOption(code: 'PEN', name: 'Peruvian Sol', country: 'Peru'),
  AppCurrencyOption(
    code: 'PGK',
    name: 'Papua New Guinean Kina',
    country: 'Papua New Guinea',
  ),
  AppCurrencyOption(
    code: 'PHP',
    name: 'Philippine Peso',
    country: 'Philippines',
  ),
  AppCurrencyOption(code: 'PKR', name: 'Pakistani Rupee', country: 'Pakistan'),
  AppCurrencyOption(code: 'PLN', name: 'Polish Zloty', country: 'Poland'),
  AppCurrencyOption(
    code: 'PYG',
    name: 'Paraguayan Guarani',
    country: 'Paraguay',
  ),
  AppCurrencyOption(code: 'QAR', name: 'Qatari Riyal', country: 'Qatar'),
  AppCurrencyOption(code: 'RON', name: 'Romanian Leu', country: 'Romania'),
  AppCurrencyOption(code: 'RSD', name: 'Serbian Dinar', country: 'Serbia'),
  AppCurrencyOption(code: 'RUB', name: 'Russian Ruble', country: 'Russia'),
  AppCurrencyOption(code: 'RWF', name: 'Rwandan Franc', country: 'Rwanda'),
  AppCurrencyOption(code: 'SAR', name: 'Saudi Riyal', country: 'Saudi Arabia'),
  AppCurrencyOption(
    code: 'SBD',
    name: 'Solomon Islands Dollar',
    country: 'Solomon Islands',
  ),
  AppCurrencyOption(
    code: 'SCR',
    name: 'Seychellois Rupee',
    country: 'Seychelles',
  ),
  AppCurrencyOption(code: 'SDG', name: 'Sudanese Pound', country: 'Sudan'),
  AppCurrencyOption(code: 'SEK', name: 'Swedish Krona', country: 'Sweden'),
  AppCurrencyOption(
    code: 'SGD',
    name: 'Singapore Dollar',
    country: 'Singapore',
  ),
  AppCurrencyOption(
    code: 'SHP',
    name: 'Saint Helena Pound',
    country: 'Saint Helena',
  ),
  AppCurrencyOption(
    code: 'SLE',
    name: 'Sierra Leonean Leone',
    country: 'Sierra Leone',
  ),
  AppCurrencyOption(code: 'SOS', name: 'Somali Shilling', country: 'Somalia'),
  AppCurrencyOption(
    code: 'SRD',
    name: 'Surinamese Dollar',
    country: 'Suriname',
  ),
  AppCurrencyOption(
    code: 'SSP',
    name: 'South Sudanese Pound',
    country: 'South Sudan',
  ),
  AppCurrencyOption(
    code: 'STN',
    name: 'Sao Tome and Principe Dobra',
    country: 'Sao Tome and Principe',
  ),
  AppCurrencyOption(code: 'SYP', name: 'Syrian Pound', country: 'Syria'),
  AppCurrencyOption(
    code: 'SZL',
    name: 'Eswatini Lilangeni',
    country: 'Eswatini',
  ),
  AppCurrencyOption(code: 'THB', name: 'Thai Baht', country: 'Thailand'),
  AppCurrencyOption(
    code: 'TJS',
    name: 'Tajikistani Somoni',
    country: 'Tajikistan',
  ),
  AppCurrencyOption(
    code: 'TMT',
    name: 'Turkmenistani Manat',
    country: 'Turkmenistan',
  ),
  AppCurrencyOption(code: 'TND', name: 'Tunisian Dinar', country: 'Tunisia'),
  AppCurrencyOption(code: 'TOP', name: 'Tongan Paanga', country: 'Tonga'),
  AppCurrencyOption(code: 'TRY', name: 'Turkish Lira', country: 'Turkey'),
  AppCurrencyOption(
    code: 'TTD',
    name: 'Trinidad and Tobago Dollar',
    country: 'Trinidad and Tobago',
  ),
  AppCurrencyOption(code: 'TWD', name: 'New Taiwan Dollar', country: 'Taiwan'),
  AppCurrencyOption(
    code: 'TZS',
    name: 'Tanzanian Shilling',
    country: 'Tanzania',
  ),
  AppCurrencyOption(code: 'UAH', name: 'Ukrainian Hryvnia', country: 'Ukraine'),
  AppCurrencyOption(code: 'USD', name: 'US Dollar', country: 'United States'),
  AppCurrencyOption(code: 'UYU', name: 'Uruguayan Peso', country: 'Uruguay'),
  AppCurrencyOption(
    code: 'UZS',
    name: 'Uzbekistani Som',
    country: 'Uzbekistan',
  ),
  AppCurrencyOption(
    code: 'VES',
    name: 'Venezuelan Bolivar',
    country: 'Venezuela',
  ),
  AppCurrencyOption(code: 'VND', name: 'Vietnamese Dong', country: 'Vietnam'),
  AppCurrencyOption(code: 'VUV', name: 'Vanuatu Vatu', country: 'Vanuatu'),
  AppCurrencyOption(code: 'WST', name: 'Samoan Tala', country: 'Samoa'),
  AppCurrencyOption(
    code: 'XAF',
    name: 'Central African CFA Franc',
    country: 'Central Africa',
  ),
  AppCurrencyOption(
    code: 'XCD',
    name: 'East Caribbean Dollar',
    country: 'East Caribbean',
  ),
  AppCurrencyOption(
    code: 'XOF',
    name: 'West African CFA Franc',
    country: 'West Africa',
  ),
  AppCurrencyOption(
    code: 'XPF',
    name: 'CFP Franc',
    country: 'French Pacific Territories',
  ),
  AppCurrencyOption(code: 'YER', name: 'Yemeni Rial', country: 'Yemen'),
  AppCurrencyOption(
    code: 'ZAR',
    name: 'South African Rand',
    country: 'South Africa',
  ),
  AppCurrencyOption(code: 'ZMW', name: 'Zambian Kwacha', country: 'Zambia'),
  AppCurrencyOption(
    code: 'ZWL',
    name: 'Zimbabwean Dollar',
    country: 'Zimbabwe',
  ),
];
