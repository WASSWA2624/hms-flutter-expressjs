import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

class AppFormShell extends StatelessWidget {
  const AppFormShell({
    required this.formKey,
    required this.children,
    this.formStatus,
    this.density = AppFormSectionDensity.regular,
    this.autovalidateMode,
    this.enabled = true,
    this.scrollable = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final Widget? formStatus;
  final AppFormSectionDensity density;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;
  final bool scrollable;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: AppFormSection(
        density: density,
        children: <Widget>[?formStatus, ...children],
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        keyboardDismissBehavior: keyboardDismissBehavior,
        child: content,
      );
    }

    return FocusTraversalGroup(
      child: Form(
        key: formKey,
        autovalidateMode: autovalidateMode,
        child: AbsorbPointer(absorbing: !enabled, child: content),
      ),
    );
  }
}

class AppFormActions extends StatelessWidget {
  const AppFormActions({
    required this.cancelLabel,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
    this.submitIcon,
    this.isSubmitting = false,
    this.enabled = true,
    this.cancelSemanticLabel,
    this.submitSemanticLabel,
    super.key,
  });

  final String cancelLabel;
  final String submitLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final IconData? submitIcon;
  final bool isSubmitting;
  final bool enabled;
  final String? cancelSemanticLabel;
  final String? submitSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool canInteract = enabled && !isSubmitting;

    return OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: Theme.of(context).spacing.sm,
      overflowSpacing: Theme.of(context).spacing.sm,
      children: <Widget>[
        AppButton.tertiary(
          label: cancelLabel,
          semanticLabel: cancelSemanticLabel,
          enabled: canInteract,
          onPressed: canInteract ? onCancel : null,
        ),
        AppButton.primary(
          label: submitLabel,
          semanticLabel: submitSemanticLabel,
          leadingIcon: submitIcon,
          isLoading: isSubmitting,
          enabled: enabled,
          onPressed: canInteract ? onSubmit : null,
        ),
      ],
    );
  }
}

bool validateAndSaveAppForm(GlobalKey<FormState> formKey) {
  final FormState? formState = formKey.currentState;
  if (formState == null || !formState.validate()) {
    return false;
  }

  formState.save();
  return true;
}
