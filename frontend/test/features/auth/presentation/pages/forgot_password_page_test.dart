import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/password_reset_request_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/reset_password_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  testWidgets(
    'shows one Send primary and no Enter reset code success hub',
    (WidgetTester tester) async {
      await _pumpForgotPassword(tester, _ForgotPasswordRepository());

      final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

      expect(find.text(l10n.authForgotPasswordTitle), findsOneWidget);
      expect(find.text(l10n.authForgotPasswordSubmitLabel), findsOneWidget);
      expect(find.text(l10n.authBackToLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.authCreateAccountActionLabel), findsOneWidget);
      expect(find.text(l10n.authHowToRegisterActionLabel), findsOneWidget);
      expect(
        find.text(l10n.authResetPasswordWithCodeActionLabel),
        findsNothing,
      );
      expect(find.text(l10n.authForgotPasswordSubmittedTitle), findsNothing);
    },
  );

  testWidgets(
    'unknown email shows not-found guidance and stays on page',
    (WidgetTester tester) async {
      final repository = _ForgotPasswordRepository(
        tenants: const <AuthTenantOption>[],
      );

      await _pumpForgotPassword(tester, repository);
      final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText), 'missing@example.com');
      await tester.tap(find.text(l10n.authForgotPasswordSubmitLabel));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.byType(ResetPasswordPage), findsNothing);
      expect(
        find.text(l10n.authForgotPasswordAccountNotFoundTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.authForgotPasswordAccountNotFoundBody),
        findsOneWidget,
      );
      expect(find.text(l10n.authCreateAccountActionLabel), findsOneWidget);
      expect(repository.forgotPasswordCalls, 0);
    },
  );

  testWidgets(
    'successful send opens reset-password with success banner',
    (WidgetTester tester) async {
      final repository = _ForgotPasswordRepository(
        tenants: const <AuthTenantOption>[
          AuthTenantOption(tenantId: 't1', tenantName: 'Clinic One'),
        ],
      );

      await _pumpForgotPassword(tester, repository);
      final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText), 'nurse@example.com');
      await tester.tap(find.text(l10n.authForgotPasswordSubmitLabel));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsNothing);
      expect(find.byType(ResetPasswordPage), findsOneWidget);
      expect(find.text(l10n.authForgotPasswordSubmittedTitle), findsNothing);
      expect(
        find.text(l10n.authForgotPasswordSubmittedMessage('nu***@e***.com')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.authResetPasswordWithCodeActionLabel),
        findsNothing,
      );
      expect(repository.forgotPasswordCalls, 1);
      expect(repository.lastForgotEmail, 'nurse@example.com');
      expect(repository.lastForgotTenantId, 't1');
    },
  );

  testWidgets(
    'multi-tenant shows one primary per workspace and completes via choice',
    (WidgetTester tester) async {
      final repository = _ForgotPasswordRepository(
        tenants: const <AuthTenantOption>[
          AuthTenantOption(tenantId: 't1', tenantName: 'North Clinic'),
          AuthTenantOption(tenantId: 't2', tenantName: 'South Clinic'),
        ],
      );

      await _pumpForgotPassword(tester, repository);
      final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText), 'multi@example.com');
      await tester.tap(find.text(l10n.authForgotPasswordSubmitLabel));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(l10n.authForgotPasswordSubmitLabel), findsNothing);
      expect(find.text(l10n.authForgotPasswordTenantPrompt), findsOneWidget);
      expect(find.text('North Clinic'), findsOneWidget);
      expect(find.text('South Clinic'), findsOneWidget);
      expect(
        find.text(l10n.authResetPasswordWithCodeActionLabel),
        findsNothing,
      );

      await tester.tap(find.text('South Clinic'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsOneWidget);
      expect(find.text(l10n.authForgotPasswordSubmittedTitle), findsNothing);
      expect(
        find.text(l10n.authForgotPasswordSubmittedMessage('mu***@e***.com')),
        findsOneWidget,
      );
      expect(repository.forgotPasswordCalls, 1);
      expect(repository.lastForgotTenantId, 't2');
    },
  );

  testWidgets(
    'changing email after tenants restores Send primary',
    (WidgetTester tester) async {
      final repository = _ForgotPasswordRepository(
        tenants: const <AuthTenantOption>[
          AuthTenantOption(tenantId: 't1', tenantName: 'North Clinic'),
          AuthTenantOption(tenantId: 't2', tenantName: 'South Clinic'),
        ],
      );

      await _pumpForgotPassword(tester, repository);
      final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText), 'multi@example.com');
      await tester.tap(find.text(l10n.authForgotPasswordSubmitLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.authForgotPasswordSubmitLabel), findsNothing);
      expect(find.text('North Clinic'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'other@example.com');
      await tester.pump();

      expect(find.text(l10n.authForgotPasswordSubmitLabel), findsOneWidget);
      expect(find.text('North Clinic'), findsNothing);
      expect(find.text('South Clinic'), findsNothing);
    },
  );

  testWidgets('validation keeps user on forgot-password', (
    WidgetTester tester,
  ) async {
    await _pumpForgotPassword(tester, _ForgotPasswordRepository());
    final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

    await tester.tap(find.text(l10n.authForgotPasswordSubmitLabel));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.byType(ResetPasswordPage), findsNothing);
  });

  testWidgets('renders send primary on narrow dark viewport', (
    WidgetTester tester,
  ) async {
    await _pumpForgotPassword(
      tester,
      _ForgotPasswordRepository(),
      theme: AppTheme.dark,
      size: const Size(320, 640),
    );

    final l10n = tester.element(find.byType(ForgotPasswordPage)).l10n;

    expect(find.text(l10n.authForgotPasswordTitle), findsOneWidget);
    expect(find.text(l10n.authForgotPasswordSubmitLabel), findsOneWidget);
    expect(find.text(l10n.authResetPasswordWithCodeActionLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpForgotPassword(
  WidgetTester tester,
  AuthRepository repository, {
  ThemeData? theme,
  Size size = const Size(1200, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final GoRouter router = GoRouter(
    initialLocation: '/forgot-password',
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, _, Widget child) => AuthShellLayout(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/forgot-password',
            builder: (_, _) => const ForgotPasswordPage(),
          ),
          GoRoute(
            path: '/reset-password',
            builder: (BuildContext context, GoRouterState state) {
              return ResetPasswordPage(
                token: state.uri.queryParameters['token'],
                email: state.uri.queryParameters['email'],
              );
            },
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('login')),
          ),
          GoRoute(
            path: '/register',
            builder: (_, _) => const Scaffold(body: Text('register')),
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

final class _ForgotPasswordRepository implements AuthRepository {
  _ForgotPasswordRepository({
    this.tenants = const <AuthTenantOption>[
      AuthTenantOption(tenantId: 'tenant-1', tenantName: 'Default Clinic'),
    ],
  });

  final List<AuthTenantOption> tenants;
  int forgotPasswordCalls = 0;
  String? lastForgotEmail;
  String? lastForgotTenantId;

  @override
  Future<Result<AuthIdentifyResult>> identify({
    required String identifier,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return Result<AuthIdentifyResult>.success(
      AuthIdentifyResult(tenants: tenants),
    );
  }

  @override
  Future<Result<PasswordResetRequestResult>> forgotPassword({
    required String email,
    required String tenantId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    forgotPasswordCalls += 1;
    lastForgotEmail = email;
    lastForgotTenantId = tenantId;
    return const Result<PasswordResetRequestResult>.success(
      PasswordResetRequestResult(),
    );
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
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    throw UnsupportedError('changePassword is not used by this test.');
  }

  @override
  Future<Result<void>> logout() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    throw UnsupportedError('refreshSession is not used by this test.');
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
  Future<Result<void>> resendEmailVerification({required String email}) {
    throw UnsupportedError('resendEmailVerification is not used by this test.');
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    return const Result<AuthSession?>.success(null);
  }

  @override
  Future<Result<EmailVerificationResult>> verifyEmail({
    required String token,
    String? email,
  }) {
    throw UnsupportedError('verifyEmail is not used by this test.');
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
  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session) {
    throw UnsupportedError('fetchCurrentUser is not used by this test.');
  }
}
