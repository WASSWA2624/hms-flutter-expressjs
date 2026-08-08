import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_registration_guide_dialog.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.from, super.key});

  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _showEmailVerifiedNotice = false;
  List<AuthPlatformAdminContact> _verifiedNoticeContacts =
      const <AuthPlatformAdminContact>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Fresh visit: drop sibling-route failure / reset shells from shared auth state.
      // Keep one-shot success from /reset-password or /verify-email without a hub page.
      final AuthController auth = ref.read(authControllerProvider.notifier);
      final authState = ref.read(authControllerProvider);
      final bool showResetCompleted = authState.passwordResetCompleted;
      final bool showEmailVerified = authState.emailVerificationCompleted;
      final List<AuthPlatformAdminContact> verifiedContacts =
          List<AuthPlatformAdminContact>.from(authState.platformAdminContacts);
      auth.clearFailure();
      auth.clearIdentifyTenants();
      auth.clearPasswordResetSubmitted();
      if (showResetCompleted) {
        auth.clearPasswordResetCompleted();
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.authResetPasswordCompletedTitle}. '
              '${l10n.authResetPasswordCompletedBody}',
            ),
          ),
        );
      } else if (showEmailVerified) {
        auth.clearEmailVerificationCompleted();
        setState(() {
          _showEmailVerifiedNotice = true;
          _verifiedNoticeContacts = verifiedContacts;
        });
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final AppConfig config = ref.watch(appConfigProvider);

    return AuthPageFrame(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginBody,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_showEmailVerifiedNotice) ...<Widget>[
                AppFormInformationBanner.message(
                  title: l10n.authEmailVerifiedTitle,
                  message: ValidationMessagePresenter.pendingApprovalMessage(
                    l10n,
                    emailJustVerified: true,
                    contacts: _resolvedNoticeContacts(config),
                  ),
                  variant: AppFormInformationVariant.info,
                ),
                SizedBox(height: theme.spacing.md),
              ],
              if (state.failure != null) ...<Widget>[
                AppFormInformationBanner.failure(
                  context: context,
                  failure: state.failure!,
                ),
                SizedBox(height: theme.spacing.md),
              ],
              AppTextField(
                controller: _identifierController,
                labelText: l10n.authIdentifierLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
                validator: AppValidators.requiredText(l10n.validationRequired),
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _identifierFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _passwordController,
                labelText: l10n.authPasswordLabel,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                validator: AppValidators.requiredText(
                  l10n.validationRequired,
                  trim: false,
                ),
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _passwordFocusNode,
                enabled: !state.isSubmitting,
                onFieldSubmitted: (_) => _submit(),
              ),
              SizedBox(height: theme.spacing.xl),
              AuthPrimaryButton(
                label: l10n.authLoginActionLabel,
                leadingIcon: Icons.login_rounded,
                isLoading: state.isSubmitting,
                onPressed: _submit,
              ),
              AuthTextLink(
                label: l10n.authForgotPasswordActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.forgotPassword.location()),
              ),
              AuthTextLink(
                label: l10n.authCreateAccountActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.register.location()),
              ),
              AuthTextLink(
                label: l10n.authHowToRegisterActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => showAuthRegistrationGuideDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AuthPlatformAdminContact> _resolvedNoticeContacts(AppConfig config) {
    if (_verifiedNoticeContacts.isNotEmpty) {
      return _verifiedNoticeContacts;
    }

    final AuthPlatformAdminContact fallback = AuthPlatformAdminContact(
      fullName: config.appAdministratorName,
      email: config.appAdministratorEmail,
      phone: config.appAdministratorPhone,
    );
    if (fallback.hasContactDetails) {
      return <AuthPlatformAdminContact>[fallback];
    }
    return const <AuthPlatformAdminContact>[];
  }

  Future<void> _submit() async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    TextInput.finishAutofillContext();
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (!success) {
      final failure = ref.read(authControllerProvider).failure;
      if (failure?.code == 'auth.account_pending') {
        final identifier = _identifierController.text.trim();
        context.go(
          AppRoutes.verifyEmail.location(
            queryParameters: <String, String>{
              if (identifier.contains('@')) 'email': identifier.toLowerCase(),
              'reason': 'pending',
            },
          ),
        );
      } else if (failure?.code == 'auth.account_pending_approval') {
        // Stay on login — failure banner explains approval is pending.
        if (_showEmailVerifiedNotice) {
          setState(() {
            _showEmailVerifiedNotice = false;
          });
        }
      }
      return;
    }

    final from = widget.from;
    context.go(
      from == null || from.isEmpty || from == AppRoutes.login.path
          ? AppRoutes.home.location()
          : from,
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
