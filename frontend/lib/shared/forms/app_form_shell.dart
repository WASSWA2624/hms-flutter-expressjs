import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

/// Standard Cancel + primary actions for [AppDialog.actions] footers.
///
/// [isSubmitting] drives Save loading and disables Save. Cancel stays enabled
/// unless [cancelEnabled] is false (defaults to `!isSubmitting`).
List<Widget> buildAppDialogFormActions({
  required String cancelLabel,
  required String submitLabel,
  required VoidCallback? onSubmit,
  VoidCallback? onCancel,
  IconData? cancelIcon,
  IconData? submitIcon,
  bool isSubmitting = false,
  bool? cancelEnabled,
  bool emphasized = false,
}) {
  final bool canCancel = cancelEnabled ?? !isSubmitting;
  if (emphasized) {
    return <Widget>[
      OutlinedButton.icon(
        onPressed: canCancel ? onCancel : null,
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
        enabled: canCancel,
        onPressed: canCancel ? onCancel : null,
      )
    else
      AppButton.tertiary(
        label: cancelLabel,
        enabled: canCancel,
        onPressed: canCancel ? onCancel : null,
      ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitIcon,
      isLoading: isSubmitting,
      onPressed: isSubmitting ? null : onSubmit,
    ),
  ];
}

/// Emphasized Cancel / optional Back / primary Next-or-Submit footer for wizards.
List<Widget> buildAppDialogWizardActions({
  required String cancelLabel,
  required String primaryLabel,
  required VoidCallback? onPrimary,
  VoidCallback? onCancel,
  String? backLabel,
  VoidCallback? onBack,
  IconData cancelIcon = Icons.close,
  IconData backIcon = Icons.arrow_back,
  IconData primaryIcon = Icons.arrow_forward,
  bool isSubmitting = false,
  bool showBack = false,
}) {
  return <Widget>[
    OutlinedButton.icon(
      onPressed: isSubmitting ? null : onCancel,
      icon: Icon(cancelIcon, size: 18),
      label: Text(cancelLabel),
    ),
    if (showBack && backLabel != null)
      OutlinedButton.icon(
        onPressed: isSubmitting ? null : onBack,
        icon: Icon(backIcon, size: 18),
        label: Text(backLabel),
      ),
    FilledButton.icon(
      onPressed: isSubmitting ? null : onPrimary,
      icon: isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(primaryIcon, size: 18),
      label: Text(primaryLabel),
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
