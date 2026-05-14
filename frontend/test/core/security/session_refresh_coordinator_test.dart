import 'dart:async';

import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRefreshCoordinator', () {
    test('shares concurrent refresh calls through one operation', () async {
      final coordinator = SessionRefreshCoordinator();
      final completer = Completer<Result<AuthSession>>();
      var callCount = 0;

      final firstRefresh = coordinator.run(() {
        callCount += 1;
        return completer.future;
      });
      final secondRefresh = coordinator.run(() {
        callCount += 1;
        return Future<Result<AuthSession>>.value(
          Result<AuthSession>.success(
            AuthSession(tokens: SessionTokens(accessToken: 'unused-token')),
          ),
        );
      });

      expect(callCount, 1);
      expect(coordinator.isRefreshing, isTrue);

      final result = Result<AuthSession>.success(
        AuthSession(tokens: SessionTokens(accessToken: 'new-token')),
      );
      completer.complete(result);

      expect(await firstRefresh, same(result));
      expect(await secondRefresh, same(result));
      expect(coordinator.isRefreshing, isFalse);
    });

    test('releases the lock after failed refresh results', () async {
      final coordinator = SessionRefreshCoordinator();
      var callCount = 0;

      final failedResult = await coordinator.run(() async {
        callCount += 1;
        return const Result<AuthSession>.failure(AppFailure.unauthorized());
      });
      final successResult = await coordinator.run(() async {
        callCount += 1;
        return Result<AuthSession>.success(
          AuthSession(tokens: SessionTokens(accessToken: 'new-token')),
        );
      });

      expect(callCount, 2);
      failedResult.when(
        success: (_) => fail('Expected failed refresh result.'),
        failure: (failure) =>
            expect(failure.category, AppFailureCategory.unauthorized),
      );
      successResult.when(
        success: (session) => expect(session.tokens.accessToken, 'new-token'),
        failure: (_) => fail('Expected successful refresh result.'),
      );
    });
  });
}
