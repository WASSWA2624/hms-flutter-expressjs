import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hosspi_hms/features/auth/domain/entities/password_reset_request_result.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';

/// Regression coverage for the password field that stopped accepting keystrokes
/// until the page was reloaded.
///
/// Every "still accepts text" assertion drives the field the way the platform
/// keyboard does — a raw `TextInput` update aimed at whatever client is
/// attached — because [WidgetTester.enterText] re-requests the keyboard first
/// and would paper over a field that lost its input connection.
void main() {
  testWidgets(
    'password field still accepts text when retrying a rejected sign-in',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());
      final l10n = tester.element(find.byType(LoginPage)).l10n;

      await _submitCredentials(tester);
      expect(find.text(l10n.authWrongPasswordMessage), findsOneWidget);

      // The retry the report describes: clear the rejected password, go back up
      // to correct the address, hit Sign in while the password is still empty,
      // then click into the password box to type the new one.
      await tester.enterText(_passwordField, '');
      await tester.tap(_identifierField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.validationRequired), findsWidgets);

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      _typeFromPlatform(tester, 'retyped-after-failure');
      await tester.pump();

      expect(_passwordText(tester), 'retyped-after-failure');
    },
  );

  testWidgets(
    'password field still accepts text after a validation error clears',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());
      final l10n = tester.element(find.byType(LoginPage)).l10n;

      // Submitting an empty form turns autovalidation on; focusing a field then
      // relaxes it again. That reset used to swap the form's GlobalKey, which
      // remounted the form and silently detached the focused field.
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.validationRequired), findsWidgets);

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.validationRequired),
        findsNothing,
        reason: 'focusing a field still clears the stale required messages',
      );

      _typeFromPlatform(tester, 'retyped-after-validation');
      await tester.pump();

      expect(_passwordText(tester), 'retyped-after-validation');
    },
  );

  testWidgets(
    'password field still accepts text after switching identifier mode back',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());
      final l10n = tester.element(find.byType(LoginPage)).l10n;

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.authIdentifierModePhoneLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.authIdentifierModeEmailLabel));
      await tester.pumpAndSettle();

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      _typeFromPlatform(tester, 'retyped-after-mode-switch');
      await tester.pump();

      expect(_passwordText(tester), 'retyped-after-mode-switch');
    },
  );

  testWidgets(
    'ten consecutive rejected sign-ins leave the password field editable',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());

      for (int attempt = 0; attempt < 10; attempt++) {
        await _submitCredentials(tester);
      }

      final EditableText field = tester.widget<EditableText>(_passwordField);
      expect(field.readOnly, isFalse);
      expect(_isSubmitting(tester), isFalse);

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      _typeFromPlatform(tester, 'typed-on-attempt-eleven');
      await tester.pump();

      expect(_passwordText(tester), 'typed-on-attempt-eleven');
    },
  );

  testWidgets(
    'a sign-in that throws restores an editable field and reports the failure',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _ThrowingLoginRepository());

      await _submitCredentials(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: 'the timeout must not escape as an unhandled error',
      );
      expect(_isSubmitting(tester), isFalse);
      expect(tester.widget<EditableText>(_passwordField).readOnly, isFalse);
      expect(
        find.byType(AppFormInformationBanner),
        findsOneWidget,
        reason: 'the user is told the attempt failed',
      );

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      _typeFromPlatform(tester, 'typed-after-timeout');
      await tester.pump();

      expect(_passwordText(tester), 'typed-after-timeout');
    },
  );

  testWidgets(
    'a submit left in flight elsewhere does not disable the login fields',
    (WidgetTester tester) async {
      final ProviderContainer container = _createContainer(
        const _WrongPasswordRepository(),
      );
      // A sibling auth page stalls mid-submit; the notifier outlives its route.
      unawaited(
        container
            .read(authControllerProvider.notifier)
            .resendEmailVerification(email: 'wasswawilson0001@gmail.com'),
      );
      expect(container.read(authControllerProvider).isSubmitting, isTrue);

      await _pumpLogin(
        tester,
        const _WrongPasswordRepository(),
        container: container,
      );

      expect(_isSubmitting(tester), isFalse);
      expect(tester.widget<EditableText>(_passwordField).readOnly, isFalse);

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      _typeFromPlatform(tester, 'typed-after-stale-submit');
      await tester.pump();

      expect(_passwordText(tester), 'typed-after-stale-submit');
    },
  );

  testWidgets(
    'no overlay intercepts the login form after an attempt resolves',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());
      await _submitCredentials(tester);

      for (final AbsorbPointer absorber in tester.widgetList<AbsorbPointer>(
        find.ancestor(of: _passwordField, matching: find.byType(AbsorbPointer)),
      )) {
        expect(absorber.absorbing, isFalse);
      }
      for (final IgnorePointer ignorer in tester.widgetList<IgnorePointer>(
        find.ancestor(of: _passwordField, matching: find.byType(IgnorePointer)),
      )) {
        expect(ignorer.ignoring, isFalse);
      }

      // A pointer aimed at the field must actually land on it: nothing may sit
      // between the form and the viewer.
      final HitTestResult hit = tester.hitTestOnBinding(
        tester.getCenter(_passwordField),
      );
      expect(
        hit.path.map((HitTestEntry entry) => entry.target),
        contains(tester.renderObject(_passwordField)),
      );
    },
  );

  testWidgets(
    'returning to login yields an empty, focusable, editable password field',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());
      final l10n = tester.element(find.byType(LoginPage)).l10n;

      await tester.enterText(_passwordField, 'Challenger2624.');
      await tester.tap(find.text(l10n.authForgotPasswordActionLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('back-login'));
      await tester.pumpAndSettle();

      expect(_passwordText(tester), isEmpty);
      expect(tester.widget<EditableText>(_passwordField).readOnly, isFalse);

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(_passwordField).widget.focusNode.hasFocus,
        isTrue,
      );

      _typeFromPlatform(tester, 'typed-after-return');
      await tester.pump();

      expect(_passwordText(tester), 'typed-after-return');
    },
  );

  testWidgets(
    'browser autofill leaves the password field attached and editable',
    (WidgetTester tester) async {
      await _pumpLogin(tester, const _WrongPasswordRepository());

      await tester.tap(_passwordField);
      await tester.pumpAndSettle();

      // What a browser credential fill delivers: one tagged update for every
      // field in the AutofillGroup.
      _autofillGroup(tester, <Finder, String>{
        _identifierField: 'wasswawilson0001@gmail.com',
        _passwordField: 'Challenger2624.',
      });
      await tester.pump();

      expect(_identifierText(tester), 'wasswawilson0001@gmail.com');
      expect(_passwordText(tester), 'Challenger2624.');
      expect(tester.widget<EditableText>(_passwordField).readOnly, isFalse);

      _typeFromPlatform(tester, 'edited-after-autofill');
      await tester.pump();

      expect(_passwordText(tester), 'edited-after-autofill');
    },
  );
}

Finder get _identifierField => find.byType(EditableText).at(0);
Finder get _passwordField => find.byType(EditableText).at(1);

String _passwordText(WidgetTester tester) =>
    tester.widget<EditableText>(_passwordField).controller.text;

String _identifierText(WidgetTester tester) =>
    tester.widget<EditableText>(_identifierField).controller.text;

bool _isSubmitting(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(LoginPage)),
).read(authControllerProvider).isSubmitting;

/// Sends text the way the platform keyboard does: straight to whichever
/// [TextInput] client is currently attached, with no re-focus first. A field
/// that lost its input connection drops this silently.
void _typeFromPlatform(WidgetTester tester, String text) {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

/// Simulates a platform autofill of a whole [AutofillGroup], which arrives as a
/// single tagged update addressed to the focused client's autofill scope.
void _autofillGroup(WidgetTester tester, Map<Finder, String> values) {
  final editingValues = <String, dynamic>{
    for (final MapEntry<Finder, String> entry in values.entries)
      tester.state<EditableTextState>(entry.key).autofillId: TextEditingValue(
        text: entry.value,
        selection: TextSelection.collapsed(offset: entry.value.length),
      ).toJSON(),
  };

  TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.updateEditingStateWithTag', <dynamic>[
            -1,
            editingValues,
          ]),
        ),
        (ByteData? _) {},
      );
}

Future<void> _submitCredentials(WidgetTester tester) async {
  final l10n = tester.element(find.byType(LoginPage)).l10n;
  await tester.enterText(_identifierField, 'wasswawilson0001@gmail.com');
  await tester.enterText(_passwordField, 'Challenger2624.');
  await tester.tap(
    find.widgetWithText(FilledButton, l10n.authLoginActionLabel),
  );
  // Flush the async login without pumpAndSettle: the Sign-in spinner animates
  // while isSubmitting is set.
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
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
  Size size = const Size(1200, 800),
  ProviderContainer? container,
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
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('register'))),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const Scaffold(body: Center(child: Text('verify'))),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: Text('home'))),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container ?? _createContainer(repository),
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

final class _WrongPasswordRepository extends _BaseAuthRepository {
  const _WrongPasswordRepository();

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return const Result<AuthSession>.failure(
      AppFailure.unauthorized(code: 'auth.wrong_password'),
    );
  }

  @override
  Future<Result<void>> resendEmailVerification({required String email}) {
    // Never completes: stands in for a submit still in flight on another page.
    return Completer<Result<void>>().future;
  }
}

final class _ThrowingLoginRepository extends _BaseAuthRepository {
  const _ThrowingLoginRepository();

  @override
  Future<Result<AuthSession>> login({
    required String identifier,
    required String password,
    String? tenantId,
    String? facilityId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    throw Exception('simulated network timeout');
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
  Future<Result<void>> logout() async => const Result<void>.success(null);

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
  Future<Result<AuthSession?>> restoreSession() async =>
      const Result<AuthSession?>.success(null);

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
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
