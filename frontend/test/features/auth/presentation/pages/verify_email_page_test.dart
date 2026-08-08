import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/verify_email_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  testWidgets(
    'shows one Verify primary and no Email verified hub',
    (WidgetTester tester) async {
      await _pumpVerifyEmail(
        tester,
        _VerifyEmailRepository(),
        location: '/verify-email?email=nurse%40example.com',
      );

      final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

      expect(find.text(l10n.authVerifyEmailTitle), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.authVerifyEmailActionLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.authSendNewCodeActionLabel), findsOneWidget);
      expect(find.text(l10n.authBackToLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.authEmailVerifiedTitle), findsNothing);
      expect(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
        findsNothing,
      );
    },
  );

  testWidgets(
    'successful verify opens login with success feedback and no hub',
    (WidgetTester tester) async {
      final repository = _VerifyEmailRepository();

      await _pumpVerifyEmail(
        tester,
        repository,
        location: '/verify-email?email=nurse%40example.com',
      );
      final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

      await tester.enterText(find.byType(EditableText), '123456');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authVerifyEmailActionLabel),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(l10n.authEmailVerifiedTitle.toUpperCase()), findsOneWidget);
      expect(
        find.textContaining(l10n.authEmailVerifiedAwaitingApprovalBody),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.authAccountPendingApprovalContactHint),
        findsOneWidget,
      );
      expect(find.textContaining('admin@hosspi.com'), findsOneWidget);
      expect(find.textContaining('+256700000000'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.authVerifyEmailTitle), findsNothing);
      expect(repository.verifyEmailCalls, 1);
      expect(repository.lastToken, '123456');
      expect(repository.lastEmail, 'nurse@example.com');
    },
  );

  testWidgets('Send new code stays on verify-email with confirmation', (
    WidgetTester tester,
  ) async {
    final repository = _VerifyEmailRepository();

    await _pumpVerifyEmail(
      tester,
      repository,
      location: '/verify-email?email=nurse%40example.com',
    );
    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    await tester.tap(find.text(l10n.authSendNewCodeActionLabel));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.text(l10n.authVerificationCodeResentMessage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text(l10n.authEmailVerifiedTitle), findsNothing);
    expect(repository.resendCalls, 1);
    expect(repository.lastResendEmail, 'nurse@example.com');
  });

  testWidgets('Send new code is disabled without email', (
    WidgetTester tester,
  ) async {
    final repository = _VerifyEmailRepository();

    await _pumpVerifyEmail(tester, repository, location: '/verify-email');
    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    final Finder sendNewCode = find.widgetWithText(
      TextButton,
      l10n.authSendNewCodeActionLabel,
    );
    expect(sendNewCode, findsOneWidget);
    expect(tester.widget<TextButton>(sendNewCode).onPressed, isNull);
    expect(repository.resendCalls, 0);
  });

  testWidgets('validation keeps user on verify-email', (
    WidgetTester tester,
  ) async {
    await _pumpVerifyEmail(
      tester,
      _VerifyEmailRepository(),
      location: '/verify-email?email=nurse%40example.com',
    );
    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authVerifyEmailActionLabel),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text(l10n.validationRequired), findsOneWidget);
  });

  testWidgets('API failure stays on verify-email with message', (
    WidgetTester tester,
  ) async {
    final repository = _VerifyEmailRepository(
      verifyFailure: const AppFailure.unauthorized(
        code: 'auth.verify_email.invalid_token',
      ),
    );

    await _pumpVerifyEmail(
      tester,
      repository,
      location: '/verify-email?email=nurse%40example.com',
    );
    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    await tester.enterText(find.byType(EditableText), '123456');
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authVerifyEmailActionLabel),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text(l10n.authEmailVerifiedTitle), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Back to sign in opens login without verified SnackBar', (
    WidgetTester tester,
  ) async {
    await _pumpVerifyEmail(
      tester,
      _VerifyEmailRepository(),
      location: '/verify-email?email=nurse%40example.com',
    );
    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    await tester.tap(find.text(l10n.authBackToLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining(l10n.authEmailVerifiedTitle), findsNothing);
  });

  testWidgets('renders Verify primary on narrow dark viewport', (
    WidgetTester tester,
  ) async {
    await _pumpVerifyEmail(
      tester,
      _VerifyEmailRepository(),
      location: '/verify-email?email=nurse%40example.com',
      theme: AppTheme.dark,
      size: const Size(320, 900),
    );

    final l10n = tester.element(find.byType(VerifyEmailPage)).l10n;

    expect(find.text(l10n.authVerifyEmailTitle), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l10n.authVerifyEmailActionLabel),
      findsOneWidget,
    );
    expect(find.text(l10n.authEmailVerifiedTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpVerifyEmail(
  WidgetTester tester,
  AuthRepository repository, {
  required String location,
  ThemeData? theme,
  Size size = const Size(1200, 1400),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);

  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, _, Widget child) => AuthShellLayout(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/verify-email',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return NoTransitionPage<void>(
                child: VerifyEmailPage(
                  token: state.uri.queryParameters['token'],
                  email: state.uri.queryParameters['email'],
                  reason: state.uri.queryParameters['reason'],
                ),
              );
            },
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (_, GoRouterState state) {
              return NoTransitionPage<void>(
                child: LoginPage(from: state.uri.queryParameters['from']),
              );
            },
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _VerifyEmailRepository implements AuthRepository {
  _VerifyEmailRepository({this.verifyFailure, this.resendFailure});

  final AppFailure? verifyFailure;
  final AppFailure? resendFailure;
  int verifyEmailCalls = 0;
  int resendCalls = 0;
  String? lastToken;
  String? lastEmail;
  String? lastResendEmail;

  @override
  Future<Result<EmailVerificationResult>> verifyEmail({
    required String token,
    String? email,
  }) async {
    await Future<void>.delayed(Duration.zero);
    verifyEmailCalls += 1;
    lastToken = token;
    lastEmail = email;
    if (verifyFailure != null) {
      return Result<EmailVerificationResult>.failure(verifyFailure!);
    }
    return const Result<EmailVerificationResult>.success(
      EmailVerificationResult(
        awaitingPlatformApproval: true,
        platformAdminContacts: <AuthPlatformAdminContact>[
          AuthPlatformAdminContact(
            email: 'admin@hosspi.com',
            phone: '+256700000000',
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<void>> resendEmailVerification({
    required String email,
  }) async {
    await Future<void>.delayed(Duration.zero);
    resendCalls += 1;
    lastResendEmail = email;
    if (resendFailure != null) {
      return Result<void>.failure(resendFailure!);
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<AuthIdentifyResult>> identify({required String identifier}) {
    throw UnsupportedError('identify is not used by this test.');
  }

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) {
    throw UnsupportedError('login is not used by this test.');
  }

  @override
  Future<Result<void>> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    String? tenantName,
    String? location,
    String? interests,
  }) {
    throw UnsupportedError('register is not used by this test.');
  }

  @override
  Future<Result<void>> forgotPassword({
    required String email,
    required String tenantId,
  }) {
    throw UnsupportedError('forgotPassword is not used by this test.');
  }

  @override
  Future<Result<void>> resetPassword({
    String? token,
    String? email,
    String? code,
    required String newPassword,
    required String confirmPassword,
  }) {
    throw UnsupportedError('resetPassword is not used by this test.');
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    throw UnsupportedError('changePassword is not used by this test.');
  }

  @override
  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    throw UnsupportedError('refreshSession is not used by this test.');
  }

  @override
  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session) {
    throw UnsupportedError('fetchCurrentUser is not used by this test.');
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    return const Result<AuthSession?>.success(null);
  }

  @override
  Future<Result<void>> logout() async {
    return const Result<void>.success(null);
  }
}
