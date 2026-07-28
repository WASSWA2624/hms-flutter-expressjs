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
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/register_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  testWidgets(
    'shows one Create account primary and no Organization name field',
    (WidgetTester tester) async {
      await _pumpRegister(tester, const _IdleRegisterRepository());

      final l10n = tester.element(find.byType(RegisterPage)).l10n;

      expect(find.text(l10n.authRegisterTitle), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.authBackToLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.authTenantNameLabel), findsNothing);
      expect(find.text(l10n.authFacilityNameLabel), findsOneWidget);
      expect(find.text('Create facility account'), findsNothing);
    },
  );

  testWidgets('clears stale sibling failure on fresh visit', (
    WidgetTester tester,
  ) async {
    const repository = _FailingRegisterRepository(
      failure: AppFailure.unauthorized(code: 'auth.wrong_password'),
    );

    await _pumpRegister(tester, repository);
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await _fillRequiredFields(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(l10n.authWrongPasswordMessage), findsOneWidget);

    await tester.tap(find.text(l10n.authBackToLoginActionLabel));
    await tester.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);

    await tester.tap(find.text('back-register'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text(l10n.authWrongPasswordMessage), findsNothing);
  });

  testWidgets('Back to sign in opens login', (WidgetTester tester) async {
    await _pumpRegister(tester, const _IdleRegisterRepository());
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await tester.tap(find.text(l10n.authBackToLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('validation failure stays on register', (
    WidgetTester tester,
  ) async {
    await _pumpRegister(tester, const _IdleRegisterRepository());
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text(l10n.validationRequired), findsWidgets);
    expect(find.text('verify:'), findsNothing);
  });

  testWidgets(
    'successful register opens verify-email without tenant_name',
    (WidgetTester tester) async {
      final repository = _SucceedingRegisterRepository();

      await _pumpRegister(tester, repository);
      final l10n = tester.element(find.byType(RegisterPage)).l10n;

      await _fillRequiredFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsNothing);
      expect(find.text('verify:admin@example.com'), findsOneWidget);
      expect(repository.registerCalls, 1);
      expect(repository.lastEmail, 'admin@example.com');
      expect(repository.lastFacilityName, 'Mirembe Clinic');
      expect(repository.lastTenantName, isNull);
      expect(repository.lastPayloadContainsTenantName, isFalse);
    },
  );

  testWidgets('keeps conflict message visible after register fails', (
    WidgetTester tester,
  ) async {
    final failure = AppFailure.conflict(code: 'auth.email_already_registered');
    final repository = _FailingRegisterRepository(failure: failure);

    await _pumpRegister(tester, repository);
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await _fillRequiredFields(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text(l10n.failureMessage(failure)), findsOneWidget);
  });

  testWidgets('renders create primary on narrow dark viewport', (
    WidgetTester tester,
  ) async {
    await _pumpRegister(
      tester,
      const _IdleRegisterRepository(),
      theme: AppTheme.dark,
      size: const Size(320, 900),
    );

    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    expect(find.text(l10n.authRegisterTitle), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
      findsOneWidget,
    );
    expect(find.text(l10n.authTenantNameLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  final editable = find.byType(EditableText);
  // admin, email, password, facility, phone national digits, location
  await tester.enterText(editable.at(0), 'Jane Admin');
  await tester.enterText(editable.at(1), 'admin@example.com');
  await tester.enterText(editable.at(2), 'Password1!');
  await tester.enterText(editable.at(3), 'Mirembe Clinic');
  await tester.enterText(editable.at(4), '700000000');
  await tester.pump();
}

Future<void> _pumpRegister(
  WidgetTester tester,
  AuthRepository repository, {
  ThemeData? theme,
  Size size = const Size(1200, 1100),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/register',
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, _, Widget child) => AuthShellLayout(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/register',
            builder: (_, _) => const RegisterPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, _) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('login'),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('back-register'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, GoRouterState state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return Scaffold(body: Center(child: Text('verify:$email')));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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

final class _IdleRegisterRepository extends _BaseAuthRepository {
  const _IdleRegisterRepository();
}

final class _FailingRegisterRepository extends _BaseAuthRepository {
  const _FailingRegisterRepository({required this.failure});

  final AppFailure failure;

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
  }) async {
    await Future<void>.delayed(Duration.zero);
    return Result<void>.failure(failure);
  }
}

final class _SucceedingRegisterRepository extends _BaseAuthRepository {
  int registerCalls = 0;
  String? lastEmail;
  String? lastFacilityName;
  String? lastTenantName;
  bool lastPayloadContainsTenantName = false;

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
  }) async {
    await Future<void>.delayed(Duration.zero);
    registerCalls += 1;
    lastEmail = email;
    lastFacilityName = facilityName;
    lastTenantName = tenantName;
    lastPayloadContainsTenantName =
        tenantName != null && tenantName.trim().isNotEmpty;
    return const Result<void>.success(null);
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
  Future<Result<void>> verifyEmail({required String token, String? email}) {
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

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) {
    throw UnsupportedError('login is not used by this test.');
  }
}
