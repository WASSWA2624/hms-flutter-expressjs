import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_currency.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_field_label.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

/// Circular flag badge for a currency option.
class AppCurrencyFlagIcon extends StatelessWidget {
  const AppCurrencyFlagIcon({
    this.option,
    this.currencyCode,
    this.size = 32,
    this.enabled = true,
    super.key,
  });

  final AppCurrencyOption? option;
  final String? currencyCode;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppCurrencyOption? resolved =
        option ?? lookupAppCurrencyOption(currencyCode ?? '');
    final String? emoji = resolved?.flagEmoji;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: theme.borders.all(),
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

/// Opens the searchable currency picker dialog.
Future<AppCurrencyOption?> showAppCurrencyPicker({
  required BuildContext context,
  required String title,
  required String selectedCode,
  List<AppCurrencyOption> options = appCurrencyOptions,
  String? searchLabelText,
  String noResultsText = 'No matching currencies found.',
}) {
  return showAppDialog<AppCurrencyOption>(
    context: context,
    builder: (_) => _AppCurrencyPickerDialog(
      title: title,
      searchLabelText: searchLabelText,
      noResultsText: noResultsText,
      selectedCode: selectedCode,
      options: options,
    ),
  );
}

/// Reusable currency selector with flag rendering.
///
/// Use the default constructor for a labeled form field, or
/// [AppCurrencySelectField.embedded] inside composite inputs like
/// [AppCurrencyAmountField].
class AppCurrencySelectField extends StatefulWidget {
  const AppCurrencySelectField({
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.searchLabelText,
    this.noResultsText = 'No matching currencies found.',
    this.enabled = true,
    this.isLoading = false,
    this.isRequired = false,
    this.allowClear = false,
    this.options = appCurrencyOptions,
    super.key,
  }) : embedded = false,
       compact = false,
       veryCompact = false;

  const AppCurrencySelectField.embedded({
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.hintText,
    this.semanticLabel,
    this.searchLabelText,
    this.noResultsText = 'No matching currencies found.',
    this.enabled = true,
    this.isLoading = false,
    this.compact = false,
    this.veryCompact = false,
    this.options = appCurrencyOptions,
    super.key,
  }) : embedded = true,
       helperText = null,
       errorText = null,
       isRequired = false,
       allowClear = false;

  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? searchLabelText;
  final String noResultsText;
  final bool enabled;
  final bool isLoading;
  final bool isRequired;
  final bool allowClear;
  final bool embedded;
  final bool compact;
  final bool veryCompact;
  final List<AppCurrencyOption> options;

  @override
  State<AppCurrencySelectField> createState() => _AppCurrencySelectFieldState();
}

class _AppCurrencySelectFieldState extends State<AppCurrencySelectField> {
  bool _isPickerOpen = false;

  AppCurrencyOption? get _selected =>
      lookupAppCurrencyOption(widget.value ?? '', options: widget.options);

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _CurrencySelectButton(
        option: _selected,
        currency: widget.value ?? '',
        hintText: widget.hintText,
        labelText: widget.semanticLabel ?? widget.labelText,
        enabled: widget.enabled && !widget.isLoading,
        isLoading: widget.isLoading || _isPickerOpen,
        compact: widget.compact,
        veryCompact: widget.veryCompact,
        onPressed: _openPicker,
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canEdit = widget.enabled && !widget.isLoading;
    final AppCurrencyOption? selected = _selected;
    final String code =
        selected?.normalizedCode ?? (widget.value?.trim().toUpperCase() ?? '');

    return InputDecorator(
      isFocused: _isPickerOpen,
      isEmpty: code.isEmpty,
      decoration: InputDecoration(
        enabled: canEdit,
        label: appFieldLabelWidget(
          context,
          widget.labelText,
          isRequired: widget.isRequired,
          style:
              Theme.of(context).inputDecorationTheme.labelStyle ??
              Theme.of(context).inputDecorationTheme.hintStyle ??
              Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w300,
              ),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        helperText: widget.helperText,
        errorText: widget.errorText,
        contentPadding: EdgeInsets.zero,
      ),
      child: InkWell(
        onTap: canEdit ? _openPicker : null,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: theme.spacing.md,
              end: theme.spacing.sm,
            ),
            child: Row(
              children: <Widget>[
                AppCurrencyFlagIcon(
                  option: selected,
                  currencyCode: code,
                  enabled: canEdit,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        code.isNotEmpty
                            ? code
                            : (widget.hintText ?? widget.labelText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: code.isNotEmpty
                            ? theme.textTheme.titleMedium?.copyWith(
                                color: canEdit
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.62,
                                      ),
                                fontWeight: FontWeight.w600,
                              )
                            : theme.inputDecorationTheme.hintStyle,
                      ),
                      if (selected != null)
                        Text(
                          selected.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: canEdit
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                if (widget.isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: canEdit
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

  Future<void> _openPicker() async {
    if (!widget.enabled || widget.isLoading || widget.options.isEmpty) {
      return;
    }

    setState(() => _isPickerOpen = true);
    final AppCurrencyOption? selected = await showAppCurrencyPicker(
      context: context,
      title: widget.labelText,
      searchLabelText: widget.searchLabelText,
      noResultsText: widget.noResultsText,
      selectedCode: widget.value ?? '',
      options: widget.options,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isPickerOpen = false);

    if (selected == null) {
      return;
    }
    final String next = selected.normalizedCode;
    if (next == (widget.value ?? '').trim().toUpperCase()) {
      return;
    }
    widget.onChanged(next);
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
                  AppCurrencyFlagIcon(
                    option: hasCurrency ? option : null,
                    currencyCode: hasCurrency ? normalizedCurrency : null,
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
                    style: hasCurrency
                        ? (compact
                                  ? theme.textTheme.titleMedium
                                  : theme.textTheme.headlineSmall)
                              ?.copyWith(
                                color: contentColor,
                                fontWeight: FontWeight.w600,
                              )
                        : theme.inputDecorationTheme.hintStyle,
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

class _AppCurrencyPickerDialog extends StatefulWidget {
  const _AppCurrencyPickerDialog({
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
  State<_AppCurrencyPickerDialog> createState() =>
      _AppCurrencyPickerDialogState();
}

class _AppCurrencyPickerDialogState extends State<_AppCurrencyPickerDialog> {
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
                          leading: AppCurrencyFlagIcon(option: option),
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
