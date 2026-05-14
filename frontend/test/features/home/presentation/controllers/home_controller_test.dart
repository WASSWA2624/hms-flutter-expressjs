import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/features/home/data/repositories/home_repository_impl.dart';
import 'package:flutter_template/features/home/domain/entities/home_readiness_snapshot.dart';
import 'package:flutter_template/features/home/domain/repositories/home_repository.dart';
import 'package:flutter_template/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeController', () {
    test('loads readiness through an overridden repository provider', () async {
      const snapshot = HomeReadinessSnapshot(
        providerGraphReady: true,
        dependenciesOverrideable: true,
        asyncStateReady: true,
      );
      final repository = _FakeHomeRepository(
        const Result<HomeReadinessSnapshot>.success(snapshot),
      );
      final container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final value = await container.read(homeControllerProvider.future);

      value.when(
        success: (loadedSnapshot) => expect(loadedSnapshot, same(snapshot)),
        failure: (_) => fail('Expected a successful readiness result.'),
      );
      expect(repository.callCount, 1);
      expect(
        container.read(homeControllerProvider),
        isA<AsyncData<Result<HomeReadinessSnapshot>>>(),
      );
    });

    test('exposes repository failures as typed result state', () async {
      const failure = AppFailure.network();
      final repository = _FakeHomeRepository(
        const Result<HomeReadinessSnapshot>.failure(failure),
      );
      final container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final value = await container.read(homeControllerProvider.future);

      value.when(
        success: (_) => fail('Expected a failed readiness result.'),
        failure: (mappedFailure) => expect(mappedFailure, failure),
      );
      expect(container.read(homeControllerProvider).hasError, isFalse);
      expect(repository.callCount, 1);
    });
  });
}

final class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.result);

  final Result<HomeReadinessSnapshot> result;
  int callCount = 0;

  @override
  Future<Result<HomeReadinessSnapshot>> loadReadiness() async {
    callCount += 1;
    return result;
  }
}
