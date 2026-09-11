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
import 'package:hosspi_hms/features/auth/domain/entities/password_reset_request_result.dart';
import 'package:hosspi_hms/features/auth/domain/entities/registration_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/register_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

/// A registration request that never completes must not be reported as a
/// failed registration. These cover the timeout-then-resolve path: the client
/// asks the backend what actually happened and renders that.
void main() {
  testWidgets(
    'timeout with a created account opens verify-email and shows no error',
    (WidgetTester tester) async {
      final repository = _ResolvingRegisterRepository(
        statuses: <RegistrationResult>[
          const RegistrationResult(
            outcome: RegistrationOutcome.accountCreatedEmailSent,
            email: 'admin@example.com',
          ),
        ],
      );

      await _pumpRegister(tester, repository);
      final l10n = tester.element(find.byType(RegisterPage)).l10n;

      await _fillRequiredFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsNothing);
      expect(find.text('verify:admin@example.com|'), findsOneWidget);
      expect(
        find.text(l10n.failureMessage(const AppFailure.timeout())),
        findsNothing,
      );
      expect(repository.statusCalls, 1);
    },
  );

  testWidgets(
    'timeout with a delayed verification email asks for a resend',
    (WidgetTester tester) async {
      final repository = _ResolvingRegisterRepository(
        statuses: <RegistrationResult>[
          const RegistrationResult(
            outcome: RegistrationOutcome.accountCreatedEmailPending,
            email: 'admin@example.com',
          ),
        ],
      );

      await _pumpRegister(tester, repository);
      final l10n = tester.element(find.byType(RegisterPage)).l10n;

      await _fillRequiredFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('verify:admin@example.com|email_delayed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'timeout with no backend record keeps the user on register with the error',
    (WidgetTester tester) async {
      final repository = _ResolvingRegisterRepository(
        statuses: <RegistrationResult>[
          const RegistrationResult(outcome: RegistrationOutcome.unknown),
        ],
      );

      await _pumpRegister(tester, repository);
      final l10n = tester.element(find.byType(RegisterPage)).l10n;

      await _fillRequiredFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsOneWidget);
      expect(
        find.text(l10n.failureMessage(const AppFailure.timeout())),
        findsOneWidget,
      );
    },
  );

  testWidgets('re-checks while the attempt is still running', (
    WidgetTester tester,
  ) async {
    final repository = _ResolvingRegisterRepository(
      statuses: <RegistrationResult>[
        const RegistrationResult(outcome: RegistrationOutcome.inProgress),
        const RegistrationResult(
          outcome: RegistrationOutcome.accountCreatedEmailSent,
          email: 'admin@example.com',
        ),
      ],
    );

    await _pumpRegister(tester, repository);
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await _fillRequiredFields(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.authRegisterActionLabel),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 2);
    expect(find.text('verify:admin@example.com|'), findsOneWidget);
  });

  testWidgets('an unresolved attempt reuses its idempotency key on resubmit', (
    WidgetTester tester,
  ) async {
    // The backend never confirms what happened, so a resubmit must replay the
    // same attempt rather than bootstrap a second workspace.
    final repository = _ResolvingRegisterRepository(
      statuses: <RegistrationResult>[
        const RegistrationResult(outcome: RegistrationOutcome.inProgress),
      ],
    );

    await _pumpRegister(tester, repository);
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await _fillRequiredFields(tester);
    await _submitAndSettle(tester, l10n.authRegisterActionLabel);
    await _submitAndSettle(tester, l10n.authRegisterActionLabel);

    expect(repository.idempotencyKeys, hasLength(2));
    expect(repository.idempotencyKeys.first, isNotEmpty);
    expect(repository.idempotencyKeys.first, repository.idempotencyKeys.last);
  });

  testWidgets('a confirmed non-registration starts a new attempt on resubmit', (
    WidgetTester tester,
  ) async {
    final repository = _ResolvingRegisterRepository(
      statuses: <RegistrationResult>[
        const RegistrationResult(outcome: RegistrationOutcome.unknown),
      ],
    );

    await _pumpRegister(tester, repository);
    final l10n = tester.element(find.byType(RegisterPage)).l10n;

    await _fillRequiredFields(tester);
    await _submitAndSettle(tester, l10n.authRegisterActionLabel);
    await _submitAndSettle(tester, l10n.authRegisterActionLabel);

    expect(repository.idempotencyKeys, hasLength(2));
    expect(
      repository.idempotencyKeys.first,
      isNot(repository.idempotencyKeys.last),
    );
  });
}

Future<void> _submitAndSettle(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  final editable = find.byType(EditableText);
  await tester.enterText(editable.at(0), 'Jane Admin');
  await tester.enterText(editable.at(1), 'admin@example.com');
  await tester.enterText(editable.at(2), 'Password1!');
  await tester.enterText(editable.at(3), 'Mirembe Clinic');
  await tester.enterText(editable.at(5), '700000000');
  await tester.pump();
}

Future<void> _pumpRegister(
  WidgetTester tester,
  AuthRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final ProviderContainer container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/register',
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, _, Widget child) => AuthShellLayout(child: child),
        routes: <RouteBase>[
          GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const Scaffold(body: Text('forgot-password')),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, GoRouterState state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final reason = state.uri.queryParameters['reason'] ?? '';
          return Scaffold(body: Center(child: Text('verify:$email|$reason')));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Registration always times out; the status lookup returns the queued
/// outcomes in order, repeating the last one.
final class _ResolvingRegisterRepository extends _BaseAuthRepository {
  _ResolvingRegisterRepository({required this.statuses});

  final List<RegistrationResult> statuses;
  final List<String> idempotencyKeys = <String>[];
  int statusCalls = 0;

  @override
  Future<Result<RegistrationResult>> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    required String idempotencyKey,
    String? tenantName,
    String? location,
    String? interests,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    await Future<void>.delayed(Duration.zero);
    return const Result<RegistrationResult>.failure(AppFailure.timeout());
  }

  @override
  Future<Result<RegistrationResult>> registrationStatus({
    required String idempotencyKey,
  }) async {
    final RegistrationResult status =
        statuses[statusCalls.clamp(0, statuses.length - 1)];
    statusCalls += 1;
    await Future<void>.delayed(Duration.zero);
    return Result<RegistrationResult>.success(status);
  }
}

abstract class _BaseAuthRepository implements AuthRepository {
  _BaseAuthRepository();

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    throw UnsupportedError('changePassword is not used by this test.');
  }

  @override
  Future<Result<void>> logout() async => const Result<void>.success(null);

  @override
  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    throw UnsupportedError('refreshSession is not used by this test.');
  }

  @override
  Future<Result<RegistrationResult>> register({
    required String email,
    required String password,
    required String facilityName,
    required String adminName,
    required String facilityType,
    required String phone,
    required String idempotencyKey,
    String? tenantName,
    String? location,
    String? interests,
  }) {
    throw UnsupportedError('register is not used by this test.');
  }

  @override
  Future<Result<RegistrationResult>> registrationStatus({
    required String idempotencyKey,
  }) {
    throw UnsupportedError('registrationStatus is not used by this test.');
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
  Future<Result<PasswordResetRequestResult>> forgotPassword({
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
