import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({
    required this.token,
    required this.email,
    required this.next,
    super.key,
  });

  final String? token;
  final String? email;
  final String? next;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _isVerified = false;
  bool _codeResent = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _normalizedEmail;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Align(child: AppLogo(size: 48)),
                    SizedBox(height: theme.spacing.lg),
                    Text(
                      _isVerified ? 'Email verified' : 'Verify your email',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      _isVerified
                          ? 'Your account is verified. You can now sign in.'
                          : email == null
                          ? 'Enter the verification code sent to your email.'
                          : 'Enter the verification code sent to $email.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_codeResent) ...<Widget>[
                      SizedBox(height: theme.spacing.md),
                      Text(
                        'A new verification code has been sent.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (_failure != null) ...<Widget>[
                      SizedBox(height: theme.spacing.md),
                      AuthFailureText(failure: _failure!),
                    ],
                    if (!_isVerified) ...<Widget>[
                      SizedBox(height: theme.spacing.lg),
                      AppTextField(
                        controller: _codeController,
                        labelText: 'Verification code',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: AppValidators.compose<String>([
                          AppValidators.requiredText(
                            context.l10n.validationRequired,
                          ),
                          AppValidators.minLength(
                            6,
                            'Enter the 6-digit verification code.',
                            allowEmpty: false,
                          ),
                        ]),
                        enabled: !_isSubmitting && !_isResending,
                        onFieldSubmitted: (_) => _verifyCode(),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      AppButton.primary(
                        label: context.l10n.authVerifyEmailActionLabel,
                        leadingIcon: Icons.mark_email_read_outlined,
                        isLoading: _isSubmitting,
                        fullWidth: true,
                        onPressed: _isResending ? null : _verifyCode,
                      ),
                      SizedBox(height: theme.spacing.sm),
                      AppButton.secondary(
                        label: context.l10n.authSendNewCodeActionLabel,
                        leadingIcon: Icons.refresh,
                        isLoading: _isResending,
                        fullWidth: true,
                        onPressed: email == null || _isSubmitting
                            ? null
                            : _resendCode,
                      ),
                    ],
                    SizedBox(height: theme.spacing.sm),
                    AppButton.tertiary(
                      label: context.l10n.authBackToLoginActionLabel,
                      onPressed: _isSubmitting || _isResending
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

  String? get _normalizedEmail {
    final email = widget.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return null;
    }
    return email;
  }

  Future<void> _verifyCode() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
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
}
