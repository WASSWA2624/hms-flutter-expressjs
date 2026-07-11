import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';
import 'package:hosspi_hms/core/currency/fx_rate_service.dart';
import 'package:hosspi_hms/shared/components/app_currency.dart';
import 'package:hosspi_hms/shared/components/app_currency_select_field.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';

export 'package:hosspi_hms/shared/components/app_currency.dart';
export 'package:hosspi_hms/shared/components/app_currency_select_field.dart';

class AppCurrencyAmountField extends ConsumerStatefulWidget {
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
    this.fxConversionFailedMessage =
        'Could not convert amount for the selected currency.',
    this.enabled = true,
    this.amountReadOnly = false,
    this.isLoading = false,
    this.isRequired = false,
    this.allowZero = true,
    this.convertOnCurrencyChange = true,
    this.decimalDigits,
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
  final String fxConversionFailedMessage;
  final bool enabled;
  final bool amountReadOnly;
  final bool isLoading;
  final bool isRequired;
  final bool allowZero;
  /// When true, changing currency converts the current amount via FX rates.
  final bool convertOnCurrencyChange;
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
  ConsumerState<AppCurrencyAmountField> createState() =>
      _AppCurrencyAmountFieldState();
}

class _AppCurrencyAmountFieldState
    extends ConsumerState<AppCurrencyAmountField> {
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();
  late FocusNode _amountFocusNode;
  late bool _ownsFocusNode;
  bool _isConverting = false;
  String? _conversionWarning;

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

  int get _effectiveDecimalDigits {
    return widget.decimalDigits ?? decimalDigitsForCurrency(widget.currency);
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditAmount =
        widget.enabled &&
        !widget.isLoading &&
        !_isConverting &&
        !widget.amountReadOnly;
    final bool canEditCurrency =
        widget.enabled && !widget.isLoading && !_isConverting;
    final String? helperText = _conversionWarning ?? widget.helperText;

    Widget field = FormField<String>(
      key: _fieldKey,
      initialValue: widget.amountController.text,
      autovalidateMode: widget.autovalidateMode,
      validator: _validateAmount,
      onSaved: (_) => widget.onSaved?.call(widget.amountController.text),
      builder: (FormFieldState<String> formField) {
        return InputDecorator(
          isFocused: _amountFocusNode.hasFocus,
          isEmpty: widget.amountController.text.trim().isEmpty,
          decoration: InputDecoration(
            enabled: canEditAmount,
            label: appFieldLabelWidget(
              context,
              widget.amountLabelText,
              isRequired: widget.isRequired,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            helperText: helperText,
            errorText: widget.errorText ?? formField.errorText,
            contentPadding: EdgeInsets.zero,
          ),
          child: _UnifiedCurrencyAmountInput(
            amountController: widget.amountController,
            amountFocusNode: _amountFocusNode,
            amountHintText: widget.amountHintText,
            currencyHintText: widget.currencyHintText,
            currency: widget.currency,
            currencyLabelText:
                widget.currencySemanticLabel ?? widget.currencyLabelText,
            currencySearchLabelText: widget.currencySearchLabelText,
            currencyNoResultsText: widget.currencyNoResultsText,
            currencyOptions: widget.currencyOptions,
            canEditAmount: canEditAmount,
            canEditCurrency: canEditCurrency,
            isLoading: widget.isLoading || _isConverting,
            decimalDigits: _effectiveDecimalDigits,
            restorationId: widget.restorationId,
            textInputAction: widget.textInputAction,
            onAmountChanged: (String value) {
              if (_conversionWarning != null) {
                setState(() => _conversionWarning = null);
              }
              formField.didChange(value);
              widget.onAmountChanged?.call(value);
            },
            onFieldSubmitted: widget.onFieldSubmitted,
            onCurrencyChanged: (String? code) {
              unawaited(_handleCurrencyChanged(code, formField));
            },
          ),
        );
      },
    );

    final String semanticLabel =
        widget.amountSemanticLabel ?? widget.amountLabelText;
    if (semanticLabel.isNotEmpty) {
      field = Semantics(
        textField: true,
        enabled: canEditAmount,
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

  Future<void> _handleCurrencyChanged(
    String? nextCurrency,
    FormFieldState<String> formField,
  ) async {
    if (nextCurrency == null) {
      return;
    }
    final String next = nextCurrency.trim().toUpperCase();
    final String previous = widget.currency.trim().toUpperCase();
    if (next.isEmpty || next == previous) {
      return;
    }

    final String normalized = normalizeCurrencyAmount(
      widget.amountController.text,
    );
    final double? amount = double.tryParse(normalized);

    if (!widget.convertOnCurrencyChange ||
        amount == null ||
        amount == 0 ||
        normalized.isEmpty) {
      setState(() => _conversionWarning = null);
      widget.onCurrencyChanged(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          formField.validate();
        }
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _conversionWarning = null;
    });

    final double? converted = await ref
        .read(fxRateServiceProvider)
        .convertAmount(amount: amount, from: previous, to: next);

    if (!mounted) {
      return;
    }

    if (converted == null) {
      setState(() {
        _isConverting = false;
        _conversionWarning = widget.fxConversionFailedMessage;
      });
      widget.onCurrencyChanged(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          formField.validate();
        }
      });
      return;
    }

    final String formatted = formatConvertedAmount(converted, next);
    widget.amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {
      _isConverting = false;
      _conversionWarning = null;
    });
    widget.onCurrencyChanged(next);
    widget.onAmountChanged?.call(formatted);
    formField.didChange(formatted);
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

    if (!isValidCurrencyAmountSyntax(normalized)) {
      return widget.amountInvalidMessage;
    }

    final List<String> parts = normalized.split('.');
    if (parts.length == 2 && parts.last.length > _effectiveDecimalDigits) {
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
    if (lookupAppCurrencyOption(
          widget.currency,
          options: widget.currencyOptions,
        ) ==
        null) {
      return widget.currencyInvalidMessage;
    }

    return widget.validator?.call(rawValue);
  }
}

class _UnifiedCurrencyAmountInput extends StatelessWidget {
  const _UnifiedCurrencyAmountInput({
    required this.amountController,
    required this.amountFocusNode,
    required this.currency,
    required this.currencyLabelText,
    required this.currencyOptions,
    required this.canEditAmount,
    required this.canEditCurrency,
    required this.isLoading,
    required this.onAmountChanged,
    required this.onCurrencyChanged,
    required this.currencyNoResultsText,
    this.amountHintText,
    this.currencyHintText,
    this.currencySearchLabelText,
    this.decimalDigits,
    this.restorationId,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final String currency;
  final String currencyLabelText;
  final List<AppCurrencyOption> currencyOptions;
  final bool canEditAmount;
  final bool canEditCurrency;
  final bool isLoading;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final String currencyNoResultsText;
  final String? amountHintText;
  final String? currencyHintText;
  final String? currencySearchLabelText;
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
                  readOnly: !canEditAmount,
                  enabled: canEditAmount,
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
                            color: canEditAmount
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
                child: AppCurrencySelectField.embedded(
                  value: currency,
                  labelText: currencyLabelText,
                  hintText: currencyHintText,
                  searchLabelText: currencySearchLabelText,
                  noResultsText: currencyNoResultsText,
                  enabled: canEditCurrency,
                  isLoading: isLoading,
                  compact: compact,
                  veryCompact: veryCompact,
                  options: currencyOptions,
                  onChanged: onCurrencyChanged,
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
