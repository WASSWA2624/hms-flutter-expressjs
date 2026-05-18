import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class PatientDateField extends StatelessWidget {
  const PatientDateField({
    required this.firstDate,
    required this.lastDate,
    this.value,
    this.onChanged,
    this.initialPickerDate,
    this.currentDate,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.focusNode,
    this.restorationId,
    this.initialEntryMode = DatePickerEntryMode.calendar,
    this.selectableDayPredicate,
    super.key,
  });

  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialPickerDate;
  final DateTime? currentDate;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<DateTime>? validator;
  final FormFieldSetter<DateTime>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final FocusNode? focusNode;
  final String? restorationId;
  final DatePickerEntryMode initialEntryMode;
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppDateField(
      value: value,
      onChanged: onChanged,
      firstDate: firstDate,
      lastDate: lastDate,
      initialPickerDate: initialPickerDate,
      currentDate: currentDate,
      pickerButtonLabel: l10n.patientsDatePickerAction,
      invalidDateMessage: l10n.appDateInvalidMessage,
      labelText: labelText,
      hintText: hintText ?? l10n.appDateFormatHint,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      isRequired: isRequired,
      focusNode: focusNode,
      restorationId: restorationId,
      initialEntryMode: initialEntryMode,
      selectableDayPredicate: selectableDayPredicate,
    );
  }
}

class PatientPhoneField extends StatelessWidget {
  const PatientPhoneField({
    required this.controller,
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
  });

  final TextEditingController controller;
  final String? labelText;
  final String? numberHintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? requiredMessage;
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppPhoneField(
      controller: controller,
      labelText: labelText,
      countryLabelText: l10n.appPhoneCountryLabel,
      countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
      countryNoResultsText: l10n.appPhoneCountryNoResults,
      numberLabelText: l10n.appPhoneNumberLabel,
      numberHintText: numberHintText ?? l10n.appPhoneNumberHint,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      requiredMessage: requiredMessage ?? l10n.validationRequired,
      invalidPhoneMessage: l10n.appPhoneInvalidMessage,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      onFieldSubmitted: onFieldSubmitted,
      onFocusChanged: onFocusChanged,
      focusNode: focusNode,
      autovalidateMode: autovalidateMode,
      restorationId: restorationId,
      textInputAction: textInputAction,
      enabled: enabled,
      isLoading: isLoading,
      isRequired: isRequired,
      initialCountryCode: initialCountryCode,
    );
  }
}

class PatientEmailField extends StatelessWidget {
  const PatientEmailField({
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
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? requiredMessage;
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
    final l10n = context.l10n;

    return AppEmailField(
      controller: controller,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      requiredMessage: requiredMessage ?? l10n.validationRequired,
      invalidEmailMessage: l10n.authEmailInvalidMessage,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      onFieldSubmitted: onFieldSubmitted,
      onFocusChanged: onFocusChanged,
      focusNode: focusNode,
      autovalidateMode: autovalidateMode,
      restorationId: restorationId,
      textInputAction: textInputAction,
      enabled: enabled,
      isLoading: isLoading,
      isRequired: isRequired,
      autofillHints: autofillHints,
    );
  }
}

class PatientFacilitySelectField extends StatelessWidget {
  const PatientFacilitySelectField({
    required this.facilities,
    this.value,
    this.onChanged,
    this.labelText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.isLoading = false,
    this.focusNode,
    this.restorationId,
    this.menuHeight,
    super.key,
  });

  final List<PatientReferenceOption> facilities;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final bool isLoading;
  final FocusNode? focusNode;
  final String? restorationId;
  final double? menuHeight;

  @override
  Widget build(BuildContext context) {
    return PatientReferenceSelectField(
      options: facilities,
      value: value,
      onChanged: onChanged,
      labelText: labelText ?? context.l10n.patientsFacilityLabel,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      isRequired: isRequired,
      isLoading: isLoading,
      focusNode: focusNode,
      restorationId: restorationId,
      menuHeight: menuHeight,
      leadingIconBuilder: (_) => const Icon(Icons.business_outlined),
    );
  }
}

class PatientReferenceSelectField extends StatelessWidget {
  const PatientReferenceSelectField({
    required this.options,
    required this.labelText,
    this.value,
    this.onChanged,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isRequired = false,
    this.isLoading = false,
    this.focusNode,
    this.restorationId,
    this.menuHeight,
    this.leadingIconBuilder,
    super.key,
  });

  final List<PatientReferenceOption> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String labelText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isRequired;
  final bool isLoading;
  final FocusNode? focusNode;
  final String? restorationId;
  final double? menuHeight;
  final Widget Function(PatientReferenceOption option)? leadingIconBuilder;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>.searchable(
      value: value,
      labelText: labelText,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      isRequired: isRequired,
      isLoading: isLoading,
      focusNode: focusNode,
      restorationId: restorationId,
      menuHeight: menuHeight,
      onChanged: onChanged,
      options: <AppSelectOption<String>>[
        for (final PatientReferenceOption option in options)
          AppSelectOption<String>(
            value: option.id,
            label: option.label,
            leadingIcon: leadingIconBuilder?.call(option),
          ),
      ],
    );
  }
}
