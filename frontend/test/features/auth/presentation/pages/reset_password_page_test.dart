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
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/reset_password_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  testWidgets(
    'code mode shows one Reset primary and no Password updated hub',
    (WidgetTester tester) async {
      await _pumpResetPassword(tester, _ResetPasswordRepository());

      final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

      expect(find.text(l10n.authResetPasswordTitle), findsOneWidget);
      expect(find.text(l10n.authResetPasswordActionLabel), findsOneWidget);
      expect(find.text(l10n.authForgotPasswordActionLabel), findsOneWidget);
      expect(find.text(l10n.authBackToLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.authResetPasswordCompletedTitle), findsNothing);
      expect(find.text(l10n.authLoginActionLabel), findsNothing);
      expect(
        find.text(l10n.authResetPasswordWithCodeActionLabel),
        findsNothing,
      );
    },
  );

  testWidgets(
    'link-token mode omits code fields and Forgot password link',
    (WidgetTester tester) async {
      await _pumpResetPassword(
        tester,
        _ResetPasswordRepository(),
        location: '/reset-password?token=link-token-abc',
      );

      final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

      expect(find.text(l10n.authResetPasswordTitle), findsOneWidget);
      expect(find.text(l10n.authResetPasswordActionLabel), findsOneWidget);
      expect(find.text(l10n.authResetPasswordCodeLabel), findsNothing);
      expect(find.text(l10n.authForgotPasswordActionLabel), findsNothing);
      expect(find.text(l10n.authBackToLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.authResetPasswordCompletedTitle), findsNothing);
    },
  );

  testWidgets(
    'successful reset opens login with success feedback and no hub',
    (WidgetTester tester) async {
      final repository = _ResetPasswordRepository();

      await _pumpResetPassword(
        tester,
        repository,
        location: '/reset-password?email=nurse%40example.com',
      );
      final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText).at(1), '123456');
      await tester.enterText(find.byType(EditableText).at(2), 'NewPass12');
      await tester.enterText(find.byType(EditableText).at(3), 'NewPass12');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.tap(find.text(l10n.authResetPasswordActionLabel));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining(l10n.authResetPasswordCompletedTitle),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
        findsOneWidget,
      );
      expect(find.text(l10n.authResetPasswordTitle), findsNothing);
      expect(repository.resetPasswordCalls, 1);
      expect(repository.lastEmail, 'nurse@example.com');
      expect(repository.lastCode, '123456');
      expect(repository.lastToken, isNull);
    },
  );

  testWidgets(
    'successful link-token reset opens login without code payload',
    (WidgetTester tester) async {
      final repository = _ResetPasswordRepository();

      await _pumpResetPassword(
        tester,
        repository,
        location: '/reset-password?token=link-token-abc',
      );
      final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

      await tester.enterText(find.byType(EditableText).at(0), 'NewPass12');
      await tester.enterText(find.byType(EditableText).at(1), 'NewPass12');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.tap(find.text(l10n.authResetPasswordActionLabel));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining(l10n.authResetPasswordCompletedTitle),
        findsOneWidget,
      );
      expect(repository.resetPasswordCalls, 1);
      expect(repository.lastToken, 'link-token-abc');
      expect(repository.lastEmail, isNull);
      expect(repository.lastCode, isNull);
    },
  );

  testWidgets('validation keeps user on reset-password', (
    WidgetTester tester,
  ) async {
    await _pumpResetPassword(tester, _ResetPasswordRepository());
    final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

    await tester.tap(find.text(l10n.authResetPasswordActionLabel));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('API failure stays on reset-password with message', (
    WidgetTester tester,
  ) async {
    final repository = _ResetPasswordRepository(
      failure: const AppFailure.unauthorized(code: 'auth.token_invalid'),
    );

    await _pumpResetPassword(
      tester,
      repository,
      location: '/reset-password?token=link-token-abc',
    );
    final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

    await tester.enterText(find.byType(EditableText).at(0), 'NewPass12');
    await tester.enterText(find.byType(EditableText).at(1), 'NewPass12');
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.tap(find.text(l10n.authResetPasswordActionLabel));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(
      find.text(l10n.authResetPasswordInvalidTokenMessage),
      findsOneWidget,
    );
    expect(find.text(l10n.authResetPasswordCompletedTitle), findsNothing);
  });

  testWidgets('Forgot password and Back to sign in open their routes', (
    WidgetTester tester,
  ) async {
    await _pumpResetPassword(tester, _ResetPasswordRepository());
    final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

    final Finder forgotLink = find.text(l10n.authForgotPasswordActionLabel);
    await tester.ensureVisible(forgotLink);
    await tester.tap(forgotLink);
    await tester.pumpAndSettle();
    expect(find.text('forgot'), findsOneWidget);

    await tester.tap(find.text('back-reset'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordPage), findsOneWidget);

    final Finder backLink = find.text(l10n.authBackToLoginActionLabel);
    await tester.ensureVisible(backLink);
    await tester.tap(backLink);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('renders reset primary on narrow dark viewport', (
    WidgetTester tester,
  ) async {
    await _pumpResetPassword(
      tester,
      _ResetPasswordRepository(),
      theme: AppTheme.dark,
      size: const Size(320, 900),
    );

    final l10n = tester.element(find.byType(ResetPasswordPage)).l10n;

    expect(find.text(l10n.authResetPasswordTitle), findsOneWidget);
    expect(find.text(l10n.authResetPasswordActionLabel), findsOneWidget);
    expect(find.text(l10n.authResetPasswordCompletedTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpResetPassword(
  WidgetTester tester,
  AuthRepository repository, {
  String location = '/reset-password',
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
                    onPressed: () => context.go('/reset-password'),
                    child: const Text('back-reset'),
                  ),
                ],
              ),
            ),
          );
        },
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

final class _ResetPasswordRepository implements AuthRepository {
  _ResetPasswordRepository({this.failure});

  final AppFailure? failure;
  int resetPasswordCalls = 0;
  String? lastToken;
  String? lastEmail;
  String? lastCode;

  @override
  Future<Result<void>> resetPassword({
    String? token,
    String? email,
    String? code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await Future<void>.delayed(Duration.zero);
    resetPasswordCalls += 1;
    lastToken = token;
    lastEmail = email;
    lastCode = code;
    if (failure != null) {
      return Result<void>.failure(failure!);
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<AuthIdentifyResult>> identify({required String identifier}) {
    throw UnsupportedError('identify is not used by this test.');
  }

  @override
  Future<Result<void>> forgotPassword({
    required String email,
    required String tenantId,
  }) async {
    return const Result<void>.success(null);
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
  Future<Result<void>> verifyEmail({required String token, String? email}) {
    throw UnsupportedError('verifyEmail is not used by this test.');
  }

  @override
  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session) {
    throw UnsupportedError('fetchCurrentUser is not used by this test.');
  }
}
