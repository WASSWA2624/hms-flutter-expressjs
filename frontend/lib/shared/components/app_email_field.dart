import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';

class AppEmailField extends StatelessWidget {
  const AppEmailField({
    required this.invalidEmailMessage,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
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
    this.autofillHints = const <String>[AutofillHints.email],
    super.key,
  }) : assert(
         !isRequired || requiredMessage != null,
         'requiredMessage must be provided when isRequired is true.',
       );

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? requiredMessage;
  final String invalidEmailMessage;
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
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      validator: _validator(),
      onChanged: onChanged,
      onSaved: onSaved,
      onFieldSubmitted: onFieldSubmitted,
      onFocusChanged: onFocusChanged,
      focusNode: focusNode,
      autovalidateMode: autovalidateMode,
      restorationId: restorationId,
      enabled: enabled,
      isLoading: isLoading,
      isRequired: isRequired,
      autocorrect: false,
      enableSuggestions: false,
    );
  }

  FormFieldValidator<String> _validator() {
    return AppValidators.compose<String>(<FormFieldValidator<String>>[
      if (isRequired) AppValidators.requiredText(requiredMessage!),
      AppValidators.email(invalidEmailMessage, allowEmpty: !isRequired),
      ?validator,
    ]);
  }
}
