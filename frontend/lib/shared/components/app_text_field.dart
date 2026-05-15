import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onFieldSubmitted,
    this.onFocusChanged,
    this.focusNode,
    this.autovalidateMode,
    this.restorationId,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.isLoading = false,
    this.obscureText = false,
    this.enableObscureTextToggle = false,
    this.showObscuredTextLabel,
    this.hideObscuredTextLabel,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Provide either controller or initialValue, not both.',
       ),
       assert(
         !enableObscureTextToggle || obscureText,
         'Obscured text toggles are only valid when obscureText is true.',
       ),
       assert(
         !enableObscureTextToggle ||
             (showObscuredTextLabel != null && hideObscuredTextLabel != null),
         'Provide localized show and hide labels for password visibility.',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<bool>? onFocusChanged;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;
  final String? restorationId;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool isLoading;
  final bool obscureText;
  final bool enableObscureTextToggle;
  final String? showObscuredTextLabel;
  final String? hideObscuredTextLabel;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _attachFocusNode();
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscureText = widget.obscureText;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canEdit = widget.enabled && !widget.isLoading;
    final Widget field = TextFormField(
      key: widget.controller == null
          ? ValueKey<String?>(widget.initialValue)
          : null,
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: canEdit,
      readOnly: widget.readOnly,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      forceErrorText: widget.errorText,
      onChanged: widget.onChanged,
      onSaved: widget.onSaved,
      onFieldSubmitted: widget.onFieldSubmitted,
      focusNode: _focusNode,
      autovalidateMode: widget.autovalidateMode,
      restorationId: widget.restorationId,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      autofocus: widget.autofocus,
      autocorrect: widget.obscureText ? false : widget.autocorrect,
      enableSuggestions: widget.obscureText ? false : widget.enableSuggestions,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: canEdit
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.62),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: _buildSuffixIcon(context, canEdit),
      ),
    );

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

  Widget? _buildSuffixIcon(BuildContext context, bool canEdit) {
    final ThemeData theme = Theme.of(context);

    if (widget.isLoading) {
      return Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: SizedBox.square(
          dimension: theme.appTokens.listIconSize,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!widget.enableObscureTextToggle) {
      return widget.suffixIcon;
    }

    final String label = _obscureText
        ? widget.showObscuredTextLabel!
        : widget.hideObscuredTextLabel!;

    return AppIconButton(
      semanticLabel: label,
      tooltip: label,
      onPressed: canEdit
          ? () {
              setState(() {
                _obscureText = !_obscureText;
              });
            }
          : null,
      icon: _obscureText
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
    );
  }
}
