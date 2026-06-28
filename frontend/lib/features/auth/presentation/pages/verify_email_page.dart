import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
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
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _isVerified = false;
  bool _codeResent = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final initialCode = widget.token?.trim();
    if (initialCode != null && RegExp(r'^\d{6}$').hasMatch(initialCode)) {
      _codeController.text = initialCode;
    }
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

    return AuthPageFrame(
      title: _isVerified
          ? l10n.authEmailVerifiedTitle
          : l10n.authVerifyEmailTitle,
      subtitle: _bodyText(l10n, email),
      maxWidth: 460,
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
            if (_failure != null) ...<Widget>[
              AuthFailureText(failure: _failure!),
              SizedBox(height: theme.spacing.md),
            ],
            if (_isVerified) ...<Widget>[
              AppButton.primary(
                label: l10n.authLoginActionLabel,
                leadingIcon: Icons.login,
                fullWidth: true,
                onPressed: () => context.go(AppRoutes.login.location()),
              ),
            ] else ...<Widget>[
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
                useFloatingLabel: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _codeFocusNode,
                enabled: !_isSubmitting && !_isResending,
                onFieldSubmitted: (_) => _verifyCode(),
              ),
              SizedBox(height: theme.spacing.lg),
              AppButton.primary(
                label: l10n.authVerifyEmailActionLabel,
                leadingIcon: Icons.mark_email_read_outlined,
                isLoading: _isSubmitting,
                fullWidth: true,
                onPressed: _isResending ? null : _verifyCode,
              ),
              SizedBox(height: theme.spacing.sm),
              AppButton.secondary(
                label: l10n.authSendNewCodeActionLabel,
                leadingIcon: Icons.refresh,
                isLoading: _isResending,
                fullWidth: true,
                onPressed: email == null || _isSubmitting ? null : _resendCode,
              ),
            ],
            AuthTextLink(
              label: l10n.authBackToLoginActionLabel,
              onPressed: _isSubmitting || _isResending
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
    if (_isVerified) {
      return l10n.authEmailVerifiedBody;
    }

    if (widget.reason == 'pending' && email != null) {
      return l10n.authPendingVerificationBody(email);
    }

    if (email == null) {
      return l10n.authVerifyEmailBodyNoEmail;
    }

    return l10n.authVerifyEmailBody(email);
  }

  Future<void> _verifyCode() async {
    _clearFormFeedback();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
      _codeResent = false;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmail(token: _codeController.text, email: _normalizedEmail);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _isSubmitting = false;
          _isVerified = true;
        });
      },
      failure: (failure) {
        setState(() {
          _isSubmitting = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _resendCode() async {
    final email = _normalizedEmail;
    if (email == null) {
      return;
    }

    setState(() {
      _isResending = true;
      _failure = null;
      _codeResent = false;
      _formKey = GlobalKey<FormState>();
      _autovalidateMode = AutovalidateMode.disabled;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .resendEmailVerification(email: email);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _isResending = false;
          _codeResent = true;
        });
      },
      failure: (failure) {
        setState(() {
          _isResending = false;
          _failure = failure;
        });
      },
    );
  }

  void _handleFieldFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _clearFormFeedback();
    }
    _resetValidationFeedback();
  }

  void _clearFormFeedback() {
    if (_failure == null && !_codeResent) {
      return;
    }

    setState(() {
      _failure = null;
      _codeResent = false;
    });
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
