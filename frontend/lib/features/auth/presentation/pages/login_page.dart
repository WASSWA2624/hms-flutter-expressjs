import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_pending_approval_dialog.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_registration_guide_dialog.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Which credential the sign-in form is currently collecting.
enum AuthIdentifierMode { email, phone }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.from, super.key});

  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  AuthIdentifierMode _identifierMode = AuthIdentifierMode.email;

  /// Active credential: the email box or the composed E.164 phone number.
  String get _identifier => switch (_identifierMode) {
    AuthIdentifierMode.email => _identifierController.text,
    AuthIdentifierMode.phone => _phoneController.text,
  };

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
      final bool awaitingPlatformApproval = authState.awaitingPlatformApproval;
      final List<AuthPlatformAdminContact> verifiedContacts =
          List<AuthPlatformAdminContact>.from(authState.platformAdminContacts);
      final String? loginPrefillIdentifier = authState.loginPrefillIdentifier;
      final String? loginPrefillPassword = authState.loginPrefillPassword;
      auth.clearFailure();
      auth.clearIdentifyTenants();
      auth.clearPasswordResetSubmitted();
      if (loginPrefillIdentifier != null && loginPrefillIdentifier.isNotEmpty) {
        _applyPrefillIdentifier(loginPrefillIdentifier);
      }
      if (loginPrefillPassword != null && loginPrefillPassword.isNotEmpty) {
        _passwordController.text = loginPrefillPassword;
      }
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
      } else if (loginPrefillIdentifier != null || loginPrefillPassword != null) {
        auth.clearLoginPrefill();
      } else if (showEmailVerified) {
        auth.clearEmailVerificationCompleted();
        if (awaitingPlatformApproval) {
          final AppConfig config = ref.read(appConfigProvider);
          _openPendingApprovalDialog(
            contacts: _resolvedContacts(verifiedContacts, config),
            emailJustVerified: true,
          );
        } else {
          final l10n = context.l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.authEmailVerifiedTitle}. ${l10n.authEmailVerifiedBody}',
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Routes a remembered identifier to the matching input and selects its mode.
  void _applyPrefillIdentifier(String identifier) {
    final String trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.contains('@')) {
      _identifierController.text = trimmed;
      return;
    }
    setState(() {
      _identifierMode = AuthIdentifierMode.phone;
      _phoneController.text = trimmed;
    });
  }

  void _selectIdentifierMode(AuthIdentifierMode mode) {
    if (mode == _identifierMode) {
      return;
    }
    _clearFormFeedback();
    setState(() {
      _identifierMode = mode;
      // The retired field leaves the tree; drop its value so a stale
      // credential cannot be submitted after switching back.
      switch (mode) {
        case AuthIdentifierMode.email:
          _phoneController.clear();
        case AuthIdentifierMode.phone:
          _identifierController.clear();
      }
      _formKey = GlobalKey<FormState>();
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final bool showInlineFailure =
        state.failure != null &&
        state.failure!.code != 'auth.account_pending_approval' &&
        state.failure!.code != 'auth.account_pending';

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
              if (showInlineFailure) ...<Widget>[
                AppFormInformationBanner.failure(
                  context: context,
                  failure: state.failure!,
                ),
                SizedBox(height: theme.spacing.md),
              ],
              _IdentifierModeSelector(
                mode: _identifierMode,
                label: l10n.authIdentifierModeLabel,
                emailLabel: l10n.authIdentifierModeEmailLabel,
                phoneLabel: l10n.authIdentifierModePhoneLabel,
                enabled: !state.isSubmitting,
                onChanged: _selectIdentifierMode,
              ),
              SizedBox(height: theme.spacing.md),
              if (_identifierMode == AuthIdentifierMode.email)
                AppEmailField(
                  controller: _identifierController,
                  labelText: l10n.authEmailLabel,
                  textInputAction: TextInputAction.next,
                  invalidEmailMessage: l10n.authEmailInvalidMessage,
                  requiredMessage: l10n.validationRequired,
                  autofillHints: const <String>[
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  isRequired: true,
                  onChanged: (_) => _clearFormFeedback(),
                  onFocusChanged: _handleFieldFocusChanged,
                  focusNode: _identifierFocusNode,
                  enabled: !state.isSubmitting,
                )
              else
                AppPhoneField(
                  controller: _phoneController,
                  labelText: l10n.authPhoneLabel,
                  countryLabelText: l10n.appPhoneCountryLabel,
                  countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
                  countryNoResultsText: l10n.appPhoneCountryNoResults,
                  numberLabelText: l10n.appPhoneNumberLabel,
                  numberHintText: l10n.appPhoneNumberHint,
                  invalidPhoneMessage: l10n.appPhoneInvalidMessage,
                  textInputAction: TextInputAction.next,
                  isRequired: true,
                  requiredMessage: l10n.validationRequired,
                  onChanged: (_) => _clearFormFeedback(),
                  onFocusChanged: _handleFieldFocusChanged,
                  focusNode: _phoneFocusNode,
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
              SizedBox(height: theme.spacing.sm),
              _LoginSecondaryLinks(
                forgotPasswordLabel: l10n.authForgotPasswordActionLabel,
                createAccountLabel: l10n.authCreateAccountActionLabel,
                howToRegisterLabel: l10n.authHowToRegisterActionLabel,
                enabled: !state.isSubmitting,
                onForgotPassword: () =>
                    context.go(AppRoutes.forgotPassword.location()),
                onCreateAccount: () =>
                    context.go(AppRoutes.register.location()),
                onHowToRegister: () =>
                    showAuthRegistrationGuideDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AuthPlatformAdminContact> _resolvedContacts(
    List<AuthPlatformAdminContact> contacts,
    AppConfig config,
  ) {
    final List<AuthPlatformAdminContact> resolved = contacts
        .where((AuthPlatformAdminContact contact) => contact.hasContactDetails)
        .toList(growable: false);
    if (resolved.isNotEmpty) {
      return resolved;
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

  Future<void> _openPendingApprovalDialog({
    required List<AuthPlatformAdminContact> contacts,
    bool emailJustVerified = false,
  }) {
    return showAuthPendingApprovalDialog(
      context,
      contacts: contacts,
      emailJustVerified: emailJustVerified,
    );
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
          identifier: _identifier,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (!success) {
      final AppFailure? failure = ref.read(authControllerProvider).failure;
      if (failure?.code == 'auth.account_pending') {
        final identifier = _identifier.trim();
        ref.read(authControllerProvider.notifier).clearFailure();
        context.go(
          AppRoutes.verifyEmail.location(
            queryParameters: <String, String>{
              if (identifier.contains('@')) 'email': identifier.toLowerCase(),
              'reason': 'pending',
            },
          ),
        );
      } else if (failure?.code == 'auth.account_pending_approval') {
        final AppConfig config = ref.read(appConfigProvider);
        final List<AuthPlatformAdminContact> contacts = _resolvedContacts(
          ValidationMessagePresenter.platformAdminContactsFromDetail(
            failure?.detailMessage,
          ),
          config,
        );
        ref.read(authControllerProvider.notifier).clearFailure();
        await _openPendingApprovalDialog(contacts: contacts);
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

class _IdentifierModeSelector extends StatelessWidget {
  const _IdentifierModeSelector({
    required this.mode,
    required this.label,
    required this.emailLabel,
    required this.phoneLabel,
    required this.enabled,
    required this.onChanged,
  });

  final AuthIdentifierMode mode;
  final String label;
  final String emailLabel;
  final String phoneLabel;
  final bool enabled;
  final ValueChanged<AuthIdentifierMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AuthIdentifierMode>(
            showSelectedIcon: false,
            selected: <AuthIdentifierMode>{mode},
            style: SegmentedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.radius.sm),
              ),
            ),
            segments: <ButtonSegment<AuthIdentifierMode>>[
              ButtonSegment<AuthIdentifierMode>(
                value: AuthIdentifierMode.email,
                label: Text(emailLabel),
                icon: const Icon(Icons.alternate_email_rounded),
                enabled: enabled,
              ),
              ButtonSegment<AuthIdentifierMode>(
                value: AuthIdentifierMode.phone,
                label: Text(phoneLabel),
                icon: const Icon(Icons.phone_outlined),
                enabled: enabled,
              ),
            ],
            onSelectionChanged: enabled
                ? (Set<AuthIdentifierMode> selection) {
                    if (selection.isNotEmpty) {
                      onChanged(selection.first);
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _LoginSecondaryLinks extends StatelessWidget {
  const _LoginSecondaryLinks({
    required this.forgotPasswordLabel,
    required this.createAccountLabel,
    required this.howToRegisterLabel,
    required this.enabled,
    required this.onForgotPassword,
    required this.onCreateAccount,
    required this.onHowToRegister,
  });

  final String forgotPasswordLabel;
  final String createAccountLabel;
  final String howToRegisterLabel;
  final bool enabled;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback onHowToRegister;

  @override
  Widget build(BuildContext context) {
    return AuthSecondaryLinkRow(
      links: <AuthTextLink>[
        AuthTextLink(
          label: forgotPasswordLabel,
          onPressed: enabled ? onForgotPassword : null,
        ),
        AuthTextLink(
          label: createAccountLabel,
          onPressed: enabled ? onCreateAccount : null,
        ),
        AuthTextLink(
          label: howToRegisterLabel,
          onPressed: enabled ? onHowToRegister : null,
        ),
      ],
    );
  }
}
