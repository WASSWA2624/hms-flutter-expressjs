import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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
  bool _isVerifying = true;
  bool _isVerified = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_verify());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isVerified
        ? 'Email verified'
        : _failure == null
        ? 'Verifying email'
        : 'Verification failed';
    final body = _isVerified
        ? 'Your account email has been confirmed. Redirecting to sign in...'
        : _failure == null
        ? 'Please wait while we confirm your account.'
        : 'The verification link is invalid or has expired.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Align(child: AppLogo(size: 48)),
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
                  if (_failure != null) ...<Widget>[
                    SizedBox(height: theme.spacing.md),
                    AuthFailureText(failure: _failure!),
                  ],
                  SizedBox(height: theme.spacing.lg),
                  if (_isVerifying)
                    const Center(child: CircularProgressIndicator())
                  else
                    AppButton.primary(
                      label: context.l10n.authBackToLoginActionLabel,
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

  Future<void> _verify() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
        _failure = AppFailure.validation(
          code: 'auth.verify_email.invalid_token',
          validationFields: const <String>{'token'},
        );
      });
      return;
    }

    final result = await ref
        .read(authRepositoryProvider)
        .verifyEmail(token: token, email: widget.email);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _isVerifying = false;
          _isVerified = true;
          _failure = null;
        });
        unawaited(_redirectAfterSuccess());
      },
      failure: (failure) {
        setState(() {
          _isVerifying = false;
          _failure = failure;
        });
      },
    );
  }

  Future<void> _redirectAfterSuccess() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      context.go(_safeNextLocation(widget.next));
    }
  }

  static String _safeNextLocation(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return AppRoutes.login.location();
    }

    final route = AppRoutes.matchPath(uri.path);
    if (route == null || route.requiresAuthenticatedSession) {
      return AppRoutes.login.location();
    }

    return uri.toString();
  }
}
