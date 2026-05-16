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
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.authChangePasswordTitle),
      scrollable: true,
      closeEnabled: !state.isSubmitting,
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
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
                isRequired: true,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                validator: AppValidators.requiredText(
                  l10n.validationRequired,
                  trim: false,
                ),
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _currentPasswordFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _newPasswordController,
                labelText: l10n.authNewPasswordLabel,
                isRequired: true,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                validator: AppValidators.minLength(
                  8,
                  l10n.authPasswordMinLengthMessage,
                  allowEmpty: false,
                ),
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _newPasswordFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _confirmPasswordController,
                labelText: l10n.authConfirmPasswordLabel,
                isRequired: true,
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
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _confirmPasswordFocusNode,
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
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
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

  void _handleFieldFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _clearFormFeedback();
    }
    _resetValidationFeedback();
  }

  void _clearFormFeedback() {
    ref.read(authControllerProvider.notifier).clearFailure();
  }

  void _enableValidationRefresh() {
    if (_autovalidateMode == AutovalidateMode.onUserInteraction) {
      return;
    }

    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
  }

  void _resetValidationFeedback() {
    if (_autovalidateMode == AutovalidateMode.disabled) {
      return;
    }

    setState(() {
      _formKey = GlobalKey<FormState>();
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }
}
