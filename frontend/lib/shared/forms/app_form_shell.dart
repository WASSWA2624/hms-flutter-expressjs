import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

/// Standard Cancel + primary actions for [AppDialog.actions] footers.
List<Widget> buildAppDialogFormActions({
  required String cancelLabel,
  required String submitLabel,
  required VoidCallback? onSubmit,
  VoidCallback? onCancel,
  IconData? cancelIcon,
  IconData? submitIcon,
  bool isSubmitting = false,
  bool emphasized = false,
}) {
  if (emphasized) {
    return <Widget>[
      OutlinedButton.icon(
        onPressed: isSubmitting ? null : onCancel,
        icon: Icon(cancelIcon ?? Icons.close),
        label: Text(cancelLabel),
      ),
      FilledButton.icon(
        onPressed: isSubmitting ? null : onSubmit,
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(submitIcon ?? Icons.check),
        label: Text(submitLabel),
      ),
    ];
  }

  return <Widget>[
    if (cancelIcon != null)
      AppButton.secondary(
        label: cancelLabel,
        leadingIcon: cancelIcon,
        enabled: !isSubmitting,
        onPressed: isSubmitting ? null : onCancel,
      )
    else
      AppButton.tertiary(
        label: cancelLabel,
        enabled: !isSubmitting,
        onPressed: isSubmitting ? null : onCancel,
      ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitIcon,
      isLoading: isSubmitting,
      onPressed: isSubmitting ? null : onSubmit,
    ),
  ];
}

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

/// Inline form action row (Cancel + primary submit).
///
/// For modal dialogs, use [AppDialog.actions] or [showAppWorkspaceMutationDialog]
/// — not [AppFormActions].
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
