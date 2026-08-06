import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

/// Standard Close + primary actions for [AppDialog.actions] footers.
///
/// [isSubmitting] drives Save loading and disables Save. Close stays enabled
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
        icon: Icon(cancelIcon ?? AppActionIcons.cancel),
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
    AppButton.close(
      label: cancelLabel,
      leadingIcon: cancelIcon ?? AppActionIcons.cancel,
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
  IconData cancelIcon = AppActionIcons.cancel,
  IconData backIcon = Icons.arrow_back,
  IconData primaryIcon = Icons.arrow_forward,
  bool isSubmitting = false,
  bool showBack = false,
}) {
  final Widget closeButton = AppButton.close(
    label: cancelLabel,
    leadingIcon: cancelIcon,
    enabled: !isSubmitting,
    onPressed: isSubmitting ? null : onCancel,
  );
  final Widget primaryButton = AppButton.primary(
    label: primaryLabel,
    leadingIcon: isSubmitting ? null : primaryIcon,
    isLoading: isSubmitting,
    onPressed: isSubmitting ? null : onPrimary,
  );
  if (showBack && backLabel != null) {
    // Length > 2: AppDialog keeps source order; Close stays extreme-right.
    return <Widget>[
      AppButton.secondary(
        label: backLabel,
        leadingIcon: backIcon,
        enabled: !isSubmitting,
        onPressed: isSubmitting ? null : onBack,
      ),
      primaryButton,
      closeButton,
    ];
  }
  // Two-action: author [Close, Primary] so AppDialog reverses Close right.
  return <Widget>[closeButton, primaryButton];
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
    Widget content = AppFormSection(
      density: density,
      children: <Widget>[?formStatus, ...children],
    );

    if (scrollable) {
      // Padding lives on the scroll view so the scrollbar/gutter stays outside
      // form sections (same pattern as [AppDialog] scrollable bodies).
      content = Scrollbar(
        child: SingleChildScrollView(
          keyboardDismissBehavior: keyboardDismissBehavior,
          padding: padding,
          child: content,
        ),
      );
    } else {
      content = Padding(padding: padding, child: content);
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

/// Inline form action row (Close + primary submit).
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
    this.cancelIcon = AppActionIcons.cancel,
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
  final IconData cancelIcon;
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
        AppButton.close(
          label: cancelLabel,
          leadingIcon: cancelIcon,
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
