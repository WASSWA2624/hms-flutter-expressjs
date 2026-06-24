import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
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
      return _SubmittedScaffold(
        title: l10n.authForgotPasswordSubmittedTitle,
        body: l10n.authForgotPasswordSubmittedBody,
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
                      l10n.authForgotPasswordTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      l10n.authForgotPasswordBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: theme.spacing.lg),
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

  Future<void> _submit({String? tenantId}) async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    await ref.read(authControllerProvider.notifier).requestPasswordReset(
          email: _emailController.text,
          tenantId: tenantId,
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

class _SubmittedScaffold extends StatelessWidget {
  const _SubmittedScaffold({required this.title, required this.body});

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
                    label: context.l10n.authBackToLoginActionLabel,
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
