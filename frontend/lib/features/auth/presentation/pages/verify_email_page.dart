import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({
    required this.token,
    required this.email,
    required this.reason,
    super.key,
  });

  final String? token;
  final String? email;
  final String? reason;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _codeResent = false;
  bool _isResending = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final initialCode = widget.token?.trim();
    if (initialCode != null && RegExp(r'^\d{6}$').hasMatch(initialCode)) {
      _codeController.text = initialCode;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Fresh visit: drop sibling-route failure / reset shells from shared auth state.
      final AuthController auth = ref.read(authControllerProvider.notifier);
      auth.clearFailure();
      auth.clearIdentifyTenants();
      auth.clearPasswordResetSubmitted();
      auth.clearEmailVerificationCompleted();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _normalizedEmail;
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final bool busy = state.isSubmitting;

    return AuthPageFrame(
      title: l10n.authVerifyEmailTitle,
      subtitle: _bodyText(l10n, email),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_codeResent) ...<Widget>[
              Text(
                l10n.authVerificationCodeResentMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
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
              controller: _codeController,
              labelText: l10n.authVerificationCodeLabel,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: AppValidators.compose<String>([
                AppValidators.requiredText(l10n.validationRequired),
                AppValidators.minLength(
                  6,
                  l10n.authVerificationCodeInvalidMessage,
                  allowEmpty: false,
                ),
              ]),
              isRequired: true,
              onChanged: (_) => _clearFormFeedback(),
              onFocusChanged: _handleFieldFocusChanged,
              focusNode: _codeFocusNode,
              enabled: !busy,
              onFieldSubmitted: (_) => _verifyCode(),
            ),
            SizedBox(height: theme.spacing.lg),
            AuthPrimaryButton(
              label: l10n.authVerifyEmailActionLabel,
              leadingIcon: Icons.mark_email_read_outlined,
              isLoading: busy && !_isResending,
              onPressed: _isResending ? null : _verifyCode,
            ),
            SizedBox(height: theme.spacing.sm),
            AppButton.secondary(
              label: l10n.authSendNewCodeActionLabel,
              leadingIcon: Icons.refresh,
              isLoading: _isResending,
              fullWidth: true,
              onPressed: email == null || busy ? null : _resendCode,
            ),
            AuthTextLink(
              label: l10n.authBackToLoginActionLabel,
              onPressed: busy
                  ? null
                  : () => context.go(AppRoutes.login.location()),
            ),
          ],
        ),
      ),
    );
  }

  String? get _normalizedEmail {
    final email = widget.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return null;
    }
    return email;
  }

  String _bodyText(AppLocalizations l10n, String? email) {
    if (widget.reason == 'pending' && email != null) {
      return l10n.authPendingVerificationBody(email);
    }

    if (email == null) {
      return l10n.authVerifyEmailBodyNoEmail;
    }

    return l10n.authVerifyEmailBody(email);
  }

  Future<void> _verifyCode() async {
    ref.read(authControllerProvider.notifier).clearFailure();
    setState(() => _codeResent = false);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    final bool completed = await ref
        .read(authControllerProvider.notifier)
        .verifyEmail(token: _codeController.text, email: _normalizedEmail);
    if (!mounted || !completed) {
      return;
    }

    // Skip the intermediate "email verified" hub: next step is sign-in readiness.
    // Awaiting-approval copy is shown once on /login.
    context.go(AppRoutes.login.location());
  }

  Future<void> _resendCode() async {
    final email = _normalizedEmail;
    if (email == null) {
      return;
    }

    setState(() {
      _isResending = true;
      _codeResent = false;
      _formKey = GlobalKey<FormState>();
      _autovalidateMode = AutovalidateMode.disabled;
    });

    final bool sent = await ref
        .read(authControllerProvider.notifier)
        .resendEmailVerification(email: email);
    if (!mounted) {
      return;
    }

    setState(() {
      _isResending = false;
      _codeResent = sent;
    });
  }

  void _handleFieldFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _clearFormFeedback();
    }
    _resetValidationFeedback();
  }

  void _clearFormFeedback() {
    ref.read(authControllerProvider.notifier).clearFailure();
    if (!_codeResent) {
      return;
    }

    setState(() => _codeResent = false);
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
