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
  final _emailFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
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
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _usesLinkToken {
    final token = widget.token?.trim();
    return token != null &&
        token.isNotEmpty &&
        !RegExp(r'^\d{6}$').hasMatch(token);
  }

  bool get _hasKnownEmail {
    final String fromWidget = widget.email?.trim() ?? '';
    if (fromWidget.isNotEmpty) {
      return true;
    }
    return _emailController.text.trim().isNotEmpty;
  }

  String get _resolvedEmail {
    final String fromWidget = widget.email?.trim().toLowerCase() ?? '';
    if (fromWidget.isNotEmpty) {
      return fromWidget;
    }
    return _emailController.text.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AuthControllerState state = ref.watch(authControllerProvider);
    final ThemeData theme = Theme.of(context);

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
            if (state.passwordResetSubmitted && !_usesLinkToken) ...<Widget>[
              AppFormInformationBanner.message(
                message: _deliveryMessage(l10n, state),
                variant: AppFormInformationVariant.success,
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
            if (!_usesLinkToken) ...<Widget>[
              if (!_hasKnownEmail) ...<Widget>[
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
              ],
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
              textInputAction: TextInputAction.done,
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
              onFieldSubmitted: (_) => _submit(),
            ),
            SizedBox(height: theme.spacing.lg),
            AuthPrimaryButton(
              label: l10n.authResetPasswordActionLabel,
              leadingIcon: Icons.lock_reset_outlined,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
            SizedBox(height: theme.spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (!_usesLinkToken) ...<Widget>[
                  Flexible(
                    child: AuthTextLink(
                      label: l10n.authForgotPasswordActionLabel,
                      onPressed: state.isSubmitting
                          ? null
                          : () =>
                              context.go(AppRoutes.forgotPassword.location()),
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Flexible(
                  child: AuthTextLink(
                    label: l10n.authBackToLoginActionLabel,
                    onPressed: state.isSubmitting
                        ? null
                        : () => context.go(AppRoutes.login.location()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _deliveryMessage(AppLocalizations l10n, AuthControllerState state) {
    final String? maskedEmail =
        state.passwordResetMaskedEmail ?? _maskEmail(_resolvedEmail);
    final String? maskedPhone = state.passwordResetMaskedPhone;

    if (maskedEmail != null &&
        maskedEmail.isNotEmpty &&
        maskedPhone != null &&
        maskedPhone.isNotEmpty) {
      return l10n.authForgotPasswordSubmittedMessageWithPhone(
        maskedEmail,
        maskedPhone,
      );
    }
    if (maskedEmail != null && maskedEmail.isNotEmpty) {
      return l10n.authForgotPasswordSubmittedMessage(maskedEmail);
    }
    return l10n.authForgotPasswordSubmittedBody;
  }

  Future<void> _submit() async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    final String? token = _usesLinkToken ? widget.token!.trim() : null;
    final String? code = !_usesLinkToken ? _codeController.text.trim() : null;
    final String? email = !_usesLinkToken ? _resolvedEmail : null;

    if (!_usesLinkToken && (email == null || email.isEmpty)) {
      _enableValidationRefresh();
      return;
    }

    final String password = _passwordController.text;
    final String knownEmail = _resolvedEmail;
    final bool completed = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          token: token,
          email: email,
          code: code,
          newPassword: password,
          confirmPassword: password,
          loginPrefillIdentifier:
              knownEmail.isNotEmpty ? knownEmail : null,
        );
    if (!mounted || !completed) {
      return;
    }

    // Skip the intermediate "password updated" hub: next step is sign-in.
    // Success copy is shown on /login.
    context.go(AppRoutes.login.location());
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

String? _maskEmail(String? value) {
  final String email = (value ?? '').trim().toLowerCase();
  final int at = email.indexOf('@');
  if (at <= 0 || at == email.length - 1) {
    return null;
  }
  final String local = email.substring(0, at);
  final String domain = email.substring(at + 1);
  final String visibleLocal = local.substring(0, local.length >= 2 ? 2 : local.length);
  final List<String> domainParts = domain.split('.');
  final String maskedDomain = domainParts
      .asMap()
      .entries
      .map((MapEntry<int, String> entry) {
        final String part = entry.value;
        if (part.isEmpty) {
          return part;
        }
        if (entry.key == domainParts.length - 1) {
          return part;
        }
        return '${part.substring(0, 1)}***';
      })
      .join('.');
  return '$visibleLocal***@$maskedDomain';
}
