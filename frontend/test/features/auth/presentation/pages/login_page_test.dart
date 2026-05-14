import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets('keeps missing account message visible after login fails', (
    WidgetTester tester,
  ) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.unauthorized(code: 'auth.account_not_found'),
    );

    await _pumpLoginPage(tester, repository);
    await _submitLogin(tester);

    expect(
      find.text(
        'No account exists for that email or phone. Check the details or create an account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps wrong password message visible after login fails', (
    WidgetTester tester,
  ) async {
    const repository = _FailingLoginRepository(
      failure: AppFailure.unauthorized(code: 'auth.wrong_password'),
    );

    await _pumpLoginPage(tester, repository);
    await _submitLogin(tester);

    expect(
      find.text('The password is incorrect for this account.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpLoginPage(
  WidgetTester tester,
  AuthRepository repository,
) async {
  await pumpHosspiHmsApp(
    tester,
    overrides: <Object?>[
      ...testReadyAppOverrides(initialLocation: '/login'),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byType(EditableText).at(0),
    'wasswawilson0001@gmail.com',
  );
  await tester.enterText(find.byType(EditableText).at(1), 'Challenger2624.');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pump();
  await tester.pumpAndSettle();
}

final class _FailingLoginRepository implements AuthRepository {
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
    String? phone,
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
}
