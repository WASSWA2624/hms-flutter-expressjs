import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.authChangePasswordTitle),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (state.failure != null) ...<Widget>[
                AuthFailureText(failure: state.failure!),
                SizedBox(height: theme.spacing.md),
              ],
              AppTextField(
                controller: _currentPasswordController,
                labelText: l10n.authCurrentPasswordLabel,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                validator: AppValidators.requiredText(
                  l10n.validationRequired,
                  trim: false,
                ),
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _newPasswordController,
                labelText: l10n.authNewPasswordLabel,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                validator: AppValidators.minLength(
                  8,
                  l10n.authPasswordMinLengthMessage,
                  allowEmpty: false,
                ),
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _confirmPasswordController,
                labelText: l10n.authConfirmPasswordLabel,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                validator: (value) {
                  final requiredError = AppValidators.requiredText(
                    l10n.validationRequired,
                    trim: false,
                  )(value);
                  if (requiredError != null) {
                    return requiredError;
                  }

                  return value == _newPasswordController.text
                      ? null
                      : l10n.authPasswordMismatchMessage;
                },
                enabled: !state.isSubmitting,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: state.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.authChangePasswordActionLabel,
          isLoading: state.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          confirmPassword: _confirmPasswordController.text,
        );

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }
}
