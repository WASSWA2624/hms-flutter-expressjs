import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
    registerFallbackValue(
      const ClaimsQueueItem.authorization(
        PreAuthorizationRecord(
          id: 'auth-1',
          displayId: 'AUTH-001',
          coveragePlanId: 'plan-1',
          coveragePlanDisplayId: 'PLAN-001',
          status: 'PENDING',
        ),
      ),
    );
  });

  group('ClaimsWorkspaceController', () {
    test('loads queue and reference data on build', () async {
      final _MockClaimsRepository repository = _MockClaimsRepository();
      const ClaimsQueueItem item = ClaimsQueueItem.authorization(
        PreAuthorizationRecord(
          id: 'auth-1',
          displayId: 'AUTH-001',
          coveragePlanId: 'plan-1',
          coveragePlanDisplayId: 'PLAN-001',
          status: 'PENDING',
        ),
      );

      when(() => repository.listQueue(any())).thenAnswer(
        (_) async => const Result<AppPage<ClaimsQueueItem>>.success(
          AppPage<ClaimsQueueItem>(
            items: <ClaimsQueueItem>[item],
            request: AppPageRequest(),
          ),
        ),
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async => const Result<ClaimsReferenceData>.success(
          ClaimsReferenceData(),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [claimsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<ClaimsWorkspaceState> result = await container.read(
        claimsWorkspaceControllerProvider.future,
      );

      final ClaimsWorkspaceState state = result.when(
        success: (ClaimsWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
      expect(state.queue.items, hasLength(1));
      expect(state.queue.items.first.displayId, 'AUTH-001');
      verify(() => repository.listQueue(any())).called(1);
      verify(() => repository.loadReferenceData()).called(1);
    });

    test('updates pre-authorization status through repository', () async {
      final _MockClaimsRepository repository = _MockClaimsRepository();
      const ClaimsQueueItem item = ClaimsQueueItem.authorization(
        PreAuthorizationRecord(
          id: 'auth-1',
          displayId: 'AUTH-001',
          coveragePlanId: 'plan-1',
          coveragePlanDisplayId: 'PLAN-001',
          status: 'PENDING',
        ),
      );

      when(() => repository.listQueue(any())).thenAnswer(
        (_) async => const Result<AppPage<ClaimsQueueItem>>.success(
          AppPage<ClaimsQueueItem>(
            items: <ClaimsQueueItem>[item],
            request: AppPageRequest(),
          ),
        ),
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async => const Result<ClaimsReferenceData>.success(
          ClaimsReferenceData(),
        ),
      );
      when(
        () => repository.updatePreAuthorization(any(), any()),
      ).thenAnswer(
        (_) async => const Result<PreAuthorizationRecord>.success(
          PreAuthorizationRecord(
            id: 'auth-1',
            displayId: 'AUTH-001',
            coveragePlanId: 'plan-1',
            coveragePlanDisplayId: 'PLAN-001',
            status: 'APPROVED',
          ),
        ),
      );
      when(() => repository.getDetail(any())).thenAnswer(
        (_) async => const Result<ClaimsQueueDetail>.success(
          ClaimsQueueDetail(
            item: item,
            authorization: PreAuthorizationRecord(
              id: 'auth-1',
              displayId: 'AUTH-001',
              coveragePlanId: 'plan-1',
              coveragePlanDisplayId: 'PLAN-001',
              status: 'APPROVED',
            ),
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [claimsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(claimsWorkspaceControllerProvider.future);
      await container
          .read(claimsWorkspaceControllerProvider.notifier)
          .selectItem(item);

      final AppFailure? failure = await container
          .read(claimsWorkspaceControllerProvider.notifier)
          .updateAuthorizationStatus(status: 'APPROVED');

      expect(failure, isNull);
      verify(() => repository.updatePreAuthorization('AUTH-001', any())).called(1);
    });
  });
}
