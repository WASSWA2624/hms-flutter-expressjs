import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_registration_guide_dialog.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Fresh visit: drop sticky success / tenant shells from a prior attempt.
      ref.read(authControllerProvider.notifier).clearPasswordResetSubmitted();
      ref.read(authControllerProvider.notifier).clearIdentifyTenants();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AuthControllerState state = ref.watch(authControllerProvider);
    final ThemeData theme = Theme.of(context);
    final bool needsTenantChoice = state.identifyTenants.length > 1;
    final bool accountNotFound =
        state.failure?.code == 'auth.account_not_found';

    return AuthPageFrame(
      title: l10n.authForgotPasswordTitle,
      subtitle: l10n.authForgotPasswordBody,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (accountNotFound) ...<Widget>[
              AppFormInformationBanner.message(
                title: l10n.authForgotPasswordAccountNotFoundTitle,
                message:
                    '${l10n.authForgotPasswordAccountNotFoundBody}\n\n'
                    '${l10n.authForgotPasswordAccountNotFoundNextStep}',
              ),
              SizedBox(height: theme.spacing.md),
            ] else if (state.failure != null) ...<Widget>[
              AppFormInformationBanner.failure(
                context: context,
                failure: state.failure!,
              ),
              SizedBox(height: theme.spacing.md),
            ],
            AppEmailField(
              controller: _emailController,
              labelText: l10n.authEmailLabel,
              textInputAction: TextInputAction.done,
              invalidEmailMessage: l10n.authEmailInvalidMessage,
              requiredMessage: l10n.validationRequired,
              isRequired: true,
              onChanged: (_) => _onEmailChanged(),
              onFocusChanged: _handleFieldFocusChanged,
              focusNode: _emailFocusNode,
              enabled: !state.isSubmitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (needsTenantChoice) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Text(
                l10n.authForgotPasswordTenantPrompt,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: theme.spacing.sm),
              for (final AuthTenantOption tenant in state.identifyTenants)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.sm),
                  child: AuthPrimaryButton(
                    label: tenant.tenantName.isEmpty
                        ? tenant.tenantId
                        : tenant.tenantName,
                    leadingIcon: Icons.apartment_outlined,
                    isLoading: state.isSubmitting,
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submit(tenantId: tenant.tenantId),
                  ),
                ),
            ] else ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              AuthPrimaryButton(
                label: l10n.authForgotPasswordSubmitLabel,
                leadingIcon: Icons.mail_outline_rounded,
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting ? null : _submit,
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: AuthTextLink(
                    label: l10n.authBackToLoginActionLabel,
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.go(AppRoutes.login.location()),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Flexible(
                  child: AuthTextLink(
                    label: l10n.authCreateAccountActionLabel,
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.go(AppRoutes.register.location()),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Flexible(
                  child: AuthTextLink(
                    label: l10n.authHowToRegisterActionLabel,
                    onPressed: state.isSubmitting
                        ? null
                        : () => showAuthRegistrationGuideDialog(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({String? tenantId}) async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    final bool submitted = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _emailController.text, tenantId: tenantId);
    if (!mounted || !submitted) {
      return;
    }

    // Skip the intermediate "check email" hub: next required input is the
    // reset form (code + new password). Success copy is shown there.
    final String email = _emailController.text.trim().toLowerCase();
    context.go(
      AppRoutes.resetPassword.location(
        queryParameters: <String, String>{
          if (email.isNotEmpty) 'email': email,
        },
      ),
    );
  }

  void _onEmailChanged() {
    _clearFormFeedback();
    ref.read(authControllerProvider.notifier).clearIdentifyTenants();
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
