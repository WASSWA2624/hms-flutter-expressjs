import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({this.token, this.email, super.key});

  final String? token;
  final String? email;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.email?.trim().toLowerCase();
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
    final initialToken = widget.token?.trim();
    if (initialToken != null && RegExp(r'^\d{6}$').hasMatch(initialToken)) {
      _codeController.text = initialToken;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  bool get _usesLinkToken {
    final token = widget.token?.trim();
    return token != null &&
        token.isNotEmpty &&
        !RegExp(r'^\d{6}$').hasMatch(token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (state.passwordResetCompleted) {
      return AuthPageFrame(
        title: l10n.authResetPasswordCompletedTitle,
        subtitle: l10n.authResetPasswordCompletedBody,
        maxWidth: 460,
        child: AppButton.primary(
          label: l10n.authLoginActionLabel,
          leadingIcon: Icons.login,
          fullWidth: true,
          onPressed: () => context.go(AppRoutes.login.location()),
        ),
      );
    }

    return AuthPageFrame(
      title: l10n.authResetPasswordTitle,
      subtitle: _usesLinkToken
          ? l10n.authResetPasswordBody
          : l10n.authResetPasswordCodeModeBody,
      maxWidth: 460,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (state.failure != null) ...<Widget>[
              AppFormInformationBanner.failure(
                context: context,
                failure: state.failure!,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            if (!_usesLinkToken) ...<Widget>[
              AppEmailField(
                controller: _emailController,
                labelText: l10n.authEmailLabel,
                textInputAction: TextInputAction.next,
                invalidEmailMessage: l10n.authEmailInvalidMessage,
                requiredMessage: l10n.validationRequired,
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _emailFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _codeController,
                labelText: l10n.authResetPasswordCodeLabel,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: AppValidators.compose<String>([
                  AppValidators.requiredText(l10n.validationRequired),
                  AppValidators.minLength(
                    6,
                    l10n.authResetPasswordCodeInvalidMessage,
                    allowEmpty: false,
                  ),
                ]),
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _codeFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            AppTextField(
              controller: _passwordController,
              labelText: l10n.authNewPasswordLabel,
              obscureText: true,
              enableObscureTextToggle: true,
              showObscuredTextLabel: l10n.authShowPasswordLabel,
              hideObscuredTextLabel: l10n.authHidePasswordLabel,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              validator: AppValidators.minLength(
                8,
                l10n.authPasswordMinLengthMessage,
                allowEmpty: false,
              ),
              isRequired: true,
              onChanged: (_) => _clearFormFeedback(),
              onFocusChanged: _handleFieldFocusChanged,
              focusNode: _passwordFocusNode,
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
              textInputAction: TextInputAction.done,
              validator: (value) {
                final requiredError = AppValidators.requiredText(
                  l10n.validationRequired,
                  trim: false,
                )(value);
                if (requiredError != null) {
                  return requiredError;
                }

                return value == _passwordController.text
                    ? null
                    : l10n.authPasswordMismatchMessage;
              },
              isRequired: true,
              onChanged: (_) => _clearFormFeedback(),
              onFocusChanged: _handleFieldFocusChanged,
              focusNode: _confirmPasswordFocusNode,
              enabled: !state.isSubmitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            SizedBox(height: theme.spacing.lg),
            AppButton.primary(
              label: l10n.authResetPasswordActionLabel,
              leadingIcon: Icons.lock_reset_outlined,
              isLoading: state.isSubmitting,
              fullWidth: true,
              onPressed: _submit,
            ),
            if (!_usesLinkToken)
              AuthTextLink(
                label: l10n.authForgotPasswordActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.forgotPassword.location()),
              ),
            AuthTextLink(
              label: l10n.authBackToLoginActionLabel,
              onPressed: state.isSubmitting
                  ? null
                  : () => context.go(AppRoutes.login.location()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    final token = _usesLinkToken ? widget.token!.trim() : null;
    final code = !_usesLinkToken ? _codeController.text.trim() : null;
    final email = !_usesLinkToken
        ? _emailController.text.trim().toLowerCase()
        : null;

    await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          token: token,
          email: email,
          code: code,
          newPassword: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
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
