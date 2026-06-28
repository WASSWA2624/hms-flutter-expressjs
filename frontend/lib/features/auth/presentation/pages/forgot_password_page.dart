import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (state.passwordResetSubmitted) {
      return AuthPageFrame(
        title: l10n.authForgotPasswordSubmittedTitle,
        subtitle: l10n.authForgotPasswordSubmittedBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppButton.primary(
              label: l10n.authResetPasswordWithCodeActionLabel,
              leadingIcon: Icons.pin_outlined,
              fullWidth: true,
              onPressed: () => context.go(
                AppRoutes.resetPassword.location(
                  queryParameters: <String, String>{
                    if (_emailController.text.trim().isNotEmpty)
                      'email': _emailController.text.trim().toLowerCase(),
                  },
                ),
              ),
            ),
            AuthTextLink(
              label: l10n.authBackToLoginActionLabel,
              onPressed: () => context.go(AppRoutes.login.location()),
            ),
          ],
        ),
      );
    }

    return AuthPageFrame(
      title: l10n.authForgotPasswordTitle,
      subtitle: l10n.authForgotPasswordBody,
      maxWidth: 460,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (state.failure != null) ...<Widget>[
              AuthFailureText(failure: state.failure!),
              SizedBox(height: theme.spacing.md),
            ],
            AppEmailField(
              controller: _emailController,
              labelText: l10n.authEmailLabel,
              textInputAction: TextInputAction.done,
              invalidEmailMessage: l10n.authEmailInvalidMessage,
              requiredMessage: l10n.validationRequired,
              isRequired: true,
              onChanged: (_) => _clearFormFeedback(),
              onFocusChanged: _handleFieldFocusChanged,
              focusNode: _emailFocusNode,
              enabled: !state.isSubmitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (state.identifyTenants.length > 1) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Text(
                l10n.authForgotPasswordTenantPrompt,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: theme.spacing.sm),
              for (final AuthTenantOption tenant in state.identifyTenants)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.sm),
                  child: AppButton.secondary(
                    label: tenant.tenantName.isEmpty
                        ? tenant.tenantId
                        : tenant.tenantName,
                    fullWidth: true,
                    isLoading: state.isSubmitting,
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(tenantId: tenant.tenantId),
                  ),
                ),
            ],
            if (state.identifyTenants.length <= 1) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              AppButton.primary(
                label: l10n.authForgotPasswordSubmitLabel,
                leadingIcon: Icons.mail_outline,
                isLoading: state.isSubmitting,
                fullWidth: true,
                onPressed: _submit,
              ),
            ],
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

  Future<void> _submit({String? tenantId}) async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _emailController.text, tenantId: tenantId);
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
