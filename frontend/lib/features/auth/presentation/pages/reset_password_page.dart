import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final token = widget.token?.trim();

    if (state.passwordResetCompleted) {
      return _CompletedScaffold(
        title: l10n.authResetPasswordCompletedTitle,
        body: l10n.authResetPasswordCompletedBody,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Align(child: AppLogo(size: 48)),
                    SizedBox(height: theme.spacing.lg),
                    Text(
                      l10n.authResetPasswordTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      l10n.authResetPasswordBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    if (token == null || token.isEmpty) ...<Widget>[
                      Text(
                        l10n.authResetPasswordMissingTokenMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ] else ...<Widget>[
                      if (state.failure != null) ...<Widget>[
                        AuthFailureText(failure: state.failure!),
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
                        onChanged: (_) => _clearFormFeedback(),
                        onFocusChanged: _handleFieldFocusChanged,
                        focusNode: _confirmPasswordFocusNode,
                        enabled: !state.isSubmitting,
                        onFieldSubmitted: (_) => _submit(token),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      AppButton.primary(
                        label: l10n.authResetPasswordActionLabel,
                        leadingIcon: Icons.lock_reset_outlined,
                        isLoading: state.isSubmitting,
                        fullWidth: true,
                        onPressed: () => _submit(token),
                      ),
                    ],
                    SizedBox(height: theme.spacing.sm),
                    AppButton.tertiary(
                      label: l10n.authBackToLoginActionLabel,
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.go(AppRoutes.login.location()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(String token) async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    await ref.read(authControllerProvider.notifier).resetPassword(
          token: token,
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

class _CompletedScaffold extends StatelessWidget {
  const _CompletedScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const AppLogo(size: 48),
                  SizedBox(height: theme.spacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: theme.spacing.lg),
                  AppButton.primary(
                    label: context.l10n.authLoginActionLabel,
                    leadingIcon: Icons.login,
                    fullWidth: true,
                    onPressed: () => context.go(AppRoutes.login.location()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
