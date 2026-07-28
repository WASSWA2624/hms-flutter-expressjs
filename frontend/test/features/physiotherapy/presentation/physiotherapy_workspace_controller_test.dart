import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PhysiotherapyWorklistQuery());
  });

  group('PhysiotherapyWorkspaceController', () {
    test('acceptReferral refreshes worklist after mutation', () async {
      final _MockPhysiotherapyRepository repository =
          _MockPhysiotherapyRepository();
      const TherapyWorkItem item = TherapyWorkItem(
        id: 'TH-001',
        encounterId: 'ENC-001',
      );
      const PhysiotherapyDetail detail = PhysiotherapyDetail(item: item);

      when(() => repository.listWorkItems(any())).thenAnswer(
        (_) async => const Result<AppPage<TherapyWorkItem>>.success(
          AppPage<TherapyWorkItem>(
            items: <TherapyWorkItem>[item],
            request: AppPageRequest(pageSize: 25),
          ),
        ),
      );
      when(() => repository.loadDetail(item)).thenAnswer(
        (_) async => const Result<PhysiotherapyDetail>.success(detail),
      );
      when(
        () => repository.acceptReferral(item: item, note: 'Accepted'),
      ).thenAnswer(
        (_) async => const Result<PhysiotherapyDetail>.success(
          PhysiotherapyDetail(
            item: TherapyWorkItem(
              id: 'TH-001',
              encounterId: 'ENC-001',
              status: 'ACCEPTED',
            ),
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          physiotherapyRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(physiotherapyWorkspaceControllerProvider.future);
      await container
          .read(physiotherapyWorkspaceControllerProvider.notifier)
          .selectWorkItem(item);

      final AppFailure? failure = await container
          .read(physiotherapyWorkspaceControllerProvider.notifier)
          .acceptReferral('Accepted');

      expect(failure, isNull);
      verify(
        () => repository.acceptReferral(item: item, note: 'Accepted'),
      ).called(1);
      verify(() => repository.listWorkItems(any())).called(greaterThan(1));
    });

    test('applyScope clears status when leaving referrals / today', () async {
      final _MockPhysiotherapyRepository repository =
          _MockPhysiotherapyRepository();
      const TherapyWorkItem item = TherapyWorkItem(
        id: 'TH-001',
        encounterId: 'ENC-001',
        status: 'ACTIVE_PLAN',
      );

      when(() => repository.listWorkItems(any())).thenAnswer(
        (_) async => const Result<AppPage<TherapyWorkItem>>.success(
          AppPage<TherapyWorkItem>(
            items: <TherapyWorkItem>[item],
            request: AppPageRequest(pageSize: 25),
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          physiotherapyRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(physiotherapyWorkspaceControllerProvider.future);

      await container
          .read(physiotherapyWorkspaceControllerProvider.notifier)
          .applyWorklistFilters(
            scope: PhysiotherapyQueueScope.referrals,
            filters: const PhysiotherapyWorklistFilters(status: 'REFERRAL'),
          );

      PhysiotherapyWorkspaceState? state = container
          .read(physiotherapyWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (PhysiotherapyWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.query.filters.status, 'REFERRAL');

      await container
          .read(physiotherapyWorkspaceControllerProvider.notifier)
          .applyScope(PhysiotherapyQueueScope.activePlans);

      state = container
          .read(physiotherapyWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (PhysiotherapyWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.query.scope, PhysiotherapyQueueScope.activePlans);
      expect(state?.query.filters.status, isNull);
    });
  });
}
