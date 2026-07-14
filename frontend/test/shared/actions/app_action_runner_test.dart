import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/actions/app_action_lifecycle.dart';

void main() {
  group('AppActionRunner', () {
    test('prevents duplicate submission while in-flight', () async {
      final AppActionRunner runner = AppActionRunner(
        createKey: () => 'fixed-key',
      );
      var calls = 0;

      final Future<AppFailure?> first = runner.run((context) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return null;
      });

      final AppFailure? duplicate = await runner.run((context) async {
        calls += 1;
        return null;
      });

      expect(duplicate, const AppFailure.cancelled());
      expect(await first, isNull);
      expect(calls, 1);
      expect(runner.phase, AppActionPhase.success);
      expect(runner.idempotencyKey, 'fixed-key');
    });

    test('reuses the same idempotency key on retry', () async {
      var keySequence = 0;
      final AppActionRunner runner = AppActionRunner(
        createKey: () => 'key-${++keySequence}',
      );
      final List<String> seenKeys = <String>[];

      final AppFailure? failure = await runner.run((context) async {
        seenKeys.add(context.idempotencyKey);
        expect(context.isRetry, isFalse);
        return const AppFailure.network();
      });

      expect(failure, const AppFailure.network());
      expect(runner.canRetry, isTrue);

      final AppFailure? retryResult = await runner.retry((context) async {
        seenKeys.add(context.idempotencyKey);
        expect(context.isRetry, isTrue);
        return null;
      });

      expect(retryResult, isNull);
      expect(seenKeys, <String>['key-1', 'key-1']);
      expect(keySequence, 1);
      expect(runner.phase, AppActionPhase.success);
    });

    test('cancel leaves runner idle without success', () async {
      final AppActionRunner runner = AppActionRunner(createKey: () => 'c-key');
      var patched = false;

      final AppFailure? result = await runner.run((context) async {
        return const AppFailure.cancelled();
      });

      if (result == null) {
        patched = true;
      }

      expect(result, const AppFailure.cancelled());
      expect(patched, isFalse);
      expect(runner.phase, AppActionPhase.idle);
      expect(runner.failure, isNull);
    });

    test('failure leaves domain patch skipped and exposes retry', () async {
      final AppActionRunner runner = AppActionRunner(createKey: () => 'f-key');
      var domainValue = 0;

      final AppFailure? result = await runner.run((context) async {
        return const AppFailure.timeout();
      });

      if (result == null) {
        domainValue = 1;
      }

      expect(result, const AppFailure.timeout());
      expect(domainValue, 0);
      expect(runner.phase, AppActionPhase.failure);
      expect(runner.canRetry, isTrue);
    });

    test('online-only mutations are refused while offline', () async {
      final AppActionRunner runner = AppActionRunner(
        onlineOnly: true,
        createKey: () => 'online-key',
      );
      var calls = 0;

      final AppFailure? result = await runner.run((context) async {
        calls += 1;
        return null;
      }, isOnline: false);

      expect(result, const AppFailure.offline());
      expect(calls, 0);
      expect(runner.phase, AppActionPhase.failure);
    });

    test('success then reset clears key for the next logical action', () async {
      var keySequence = 0;
      final AppActionRunner runner = AppActionRunner(
        createKey: () => 'key-${++keySequence}',
      );

      await runner.run((context) async => null);
      expect(runner.phase, AppActionPhase.success);
      runner.reset();
      expect(runner.phase, AppActionPhase.idle);

      await runner.run((context) async {
        expect(context.idempotencyKey, 'key-2');
        return null;
      });
      expect(keySequence, 2);
    });
  });
}
