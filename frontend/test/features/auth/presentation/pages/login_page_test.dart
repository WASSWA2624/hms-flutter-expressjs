import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/entities/auth_identify_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/email_verification_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  testWidgets(
    'shows one Sign in primary and no secondary-link divider',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _IdleLoginRepository());

      final l10n = tester.element(find.byType(LoginPage)).l10n;

      expect(find.text(l10n.authLoginTitle), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.authForgotPasswordActionLabel), findsOneWidget);
      expect(find.text(l10n.authCreateAccountActionLabel), findsOneWidget);
      expect(find.text(l10n.authHowToRegisterActionLabel), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    },
  );

  testWidgets('How to register opens onboarding guide dialog', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, const _IdleLoginRepository());
    final l10n = tester.element(find.byType(LoginPage)).l10n;

    await tester.tap(find.text(l10n.authHowToRegisterActionLabel));
    await tester.pumpAndSettle();

    expect(find.text(l10n.authRegistrationGuideTitle), findsWidgets);
    expect(find.text(l10n.authRegistrationGuideStepCreateTitle), findsOneWidget);
    expect(find.text(l10n.authRegistrationGuideStepVerifyTitle), findsOneWidget);
    expect(
      find.text(l10n.authRegistrationGuideStepApproveTitle),
      findsOneWidget,
    );
    expect(find.text(l10n.authRegistrationGuideStepSignInTitle), findsOneWidget);
  });

  testWidgets('keeps wrong password message visible after login fails', (
    WidgetTester tester,
  ) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.unauthorized(code: 'auth.wrong_password'),
    );

    await _pumpLogin(tester, repository);
    final l10n = tester.element(find.byType(LoginPage)).l10n;
    await _submitLogin(tester);

    expect(find.text(l10n.authWrongPasswordMessage), findsOneWidget);
  });

  testWidgets('clears stale sibling failure on fresh visit', (
    WidgetTester tester,
  ) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.unauthorized(code: 'auth.wrong_password'),
    );
    await _pumpLogin(tester, repository);
    final l10n = tester.element(find.byType(LoginPage)).l10n;
    await _submitLogin(tester);

    expect(find.text(l10n.authWrongPasswordMessage), findsOneWidget);

    await tester.tap(find.text(l10n.authForgotPasswordActionLabel));
    await tester.pumpAndSettle();
    expect(find.text('forgot'), findsOneWidget);

    await tester.tap(find.text('back-login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(l10n.authWrongPasswordMessage), findsNothing);
  });

  testWidgets('Forgot password and Create account open their routes', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, const _IdleLoginRepository());
    final l10n = tester.element(find.byType(LoginPage)).l10n;

    await tester.tap(find.text(l10n.authForgotPasswordActionLabel));
    await tester.pumpAndSettle();
    expect(find.text('forgot'), findsOneWidget);

    await tester.tap(find.text('back-login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.text(l10n.authCreateAccountActionLabel));
    await tester.pumpAndSettle();
    expect(find.text('register'), findsOneWidget);
  });

  testWidgets('validation failure stays on login', (WidgetTester tester) async {
    await _pumpLogin(tester, const _IdleLoginRepository());
    final l10n = tester.element(find.byType(LoginPage)).l10n;

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(l10n.validationRequired), findsWidgets);
  });

  testWidgets('keeps missing account message visible after login fails', (
    WidgetTester tester,
  ) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.unauthorized(code: 'auth.account_not_found'),
    );

    await _pumpLogin(tester, repository);
    final l10n = tester.element(find.byType(LoginPage)).l10n;
    await _submitLogin(tester);

    expect(find.text(l10n.authAccountNotFoundMessage), findsOneWidget);
  });

  testWidgets('pending account opens verify-email', (WidgetTester tester) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.forbidden(code: 'auth.account_pending'),
    );

    await _pumpLogin(tester, repository);
    await _submitLogin(tester);

    expect(
      find.text('verify:pending:wasswawilson0001@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('successful login leaves login', (WidgetTester tester) async {
    await _pumpLogin(tester, const _SucceedingLoginRepository());
    await _submitLogin(tester);

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
    'pending approval stays on login with approval guidance',
    (WidgetTester tester) async {
      final repository = _FailingLoginRepository(
        failure: AppFailure.forbidden(
          code: 'auth.account_pending_approval',
          detailMessage:
              '{"email":"admin@hosspi.com","phone":"+256700000000"}',
        ),
      );

      await _pumpLogin(tester, repository);
      final l10n = tester.element(find.byType(LoginPage)).l10n;
      await _submitLogin(tester);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.textContaining(l10n.authAccountPendingApprovalMessage),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.authAccountPendingApprovalContactHint),
        findsOneWidget,
      );
      expect(find.textContaining('admin@hosspi.com'), findsOneWidget);
      expect(find.textContaining('+256700000000'), findsOneWidget);
    },
  );

  testWidgets('renders Sign in primary on narrow dark viewport', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      const _IdleLoginRepository(),
      theme: AppTheme.dark,
      size: const Size(320, 640),
    );

    final l10n = tester.element(find.byType(LoginPage)).l10n;

    expect(find.text(l10n.authLoginTitle), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
      findsOneWidget,
    );
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _createContainer(AuthRepository repository) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      // Avoid SessionState.ready() (unauthenticated): login persist would call
      // session isolation dispose and can keep the Sign-in spinner animating.
      initialSessionStateProvider.overrideWithValue(
        const SessionState.notReady(),
      ),
      secureSessionStorageProvider.overrideWithValue(
        SecureAppSessionStorage(_MemorySecureStorage()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpLogin(
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
    initialLocation: '/login',
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, _, Widget child) => AuthShellLayout(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/login',
            builder: (_, GoRouterState state) {
              return LoginPage(from: state.uri.queryParameters['from']);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, _) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('forgot'),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('back-login'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Scaffold(body: Center(child: Text('register'))),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, GoRouterState state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final reason = state.uri.queryParameters['reason'] ?? '';
          return Scaffold(
            body: Center(child: Text('verify:$reason:$email')),
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: Text('home'))),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _createContainer(repository),
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

Future<void> _submitLogin(WidgetTester tester) async {
  final l10n = tester.element(find.byType(LoginPage)).l10n;
  await tester.enterText(
    find.byType(EditableText).at(0),
    'wasswawilson0001@gmail.com',
  );
  await tester.enterText(find.byType(EditableText).at(1), 'Challenger2624.');
  await tester.tap(
    find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
  );
  // Flush async login / session persist / go_router navigation without
  // pumpAndSettle (the Sign-in spinner animates while isSubmitting).
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final class _IdleLoginRepository extends _BaseAuthRepository {
  const _IdleLoginRepository();

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    return const Result<AuthSession>.failure(
      AppFailure.unauthorized(code: 'auth.wrong_password'),
    );
  }
}

final class _FailingLoginRepository extends _BaseAuthRepository {
  const _FailingLoginRepository({required AppFailure failure})
    : _failure = failure;

  final AppFailure _failure;

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return Result<AuthSession>.failure(_failure);
  }
}

final class _SucceedingLoginRepository extends _BaseAuthRepository {
  const _SucceedingLoginRepository();

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return Result<AuthSession>.success(
      AuthSession(
        tokens: SessionTokens(accessToken: 'test-access'),
        subject: identifier,
        user: AuthUserProfile(
          id: 'user-1',
          email: identifier,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: const <String>['nurse'],
        ),
      ),
    );
  }
}

abstract class _BaseAuthRepository implements AuthRepository {
  const _BaseAuthRepository();

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
  Future<Result<AuthIdentifyResult>> identify({required String identifier}) {
    throw UnsupportedError('identify is not used by this test.');
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
  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session) {
    throw UnsupportedError('fetchCurrentUser is not used by this test.');
  }
}

final class _MemorySecureStorage implements AppSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
