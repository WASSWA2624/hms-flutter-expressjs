import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
  });

  group('MortuaryWorkspaceController', () {
    test('loads the workspace and selects the first case detail', () async {
      final _MockMortuaryRepository repository = _MockMortuaryRepository();
      final List<MortuaryWorkspaceQuery> queries = _stubWorkspace(repository);
      _stubItem(repository);

      final ProviderContainer container = ProviderContainer(
        overrides: [mortuaryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<MortuaryWorkspaceState> result = await container.read(
        mortuaryWorkspaceControllerProvider.future,
      );

      final MortuaryWorkspaceState state = result.when(
        success: (MortuaryWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );

      expect(state.summaryValue('total_cases'), 1);
      expect(state.workloadCount, 1);
      expect(state.selectedItem?.effectiveDisplayId, 'MOR-001');
      expect(state.selectedItem?.custodyEvents.single.eventType, 'RECEIVED');
      expect(queries.single.panel, mortuaryPanelOverview);
      verify(() => repository.getWorkspace(any())).called(1);
      verify(
        () => repository.getItem(
          resource: mortuaryResourceCases,
          id: 'MOR-001',
          baseQuery: any(named: 'baseQuery'),
        ),
      ).called(1);
    });

    test(
      'applies queue filters using the mounted workspace contract',
      () async {
        final _MockMortuaryRepository repository = _MockMortuaryRepository();
        final List<MortuaryWorkspaceQuery> queries = _stubWorkspace(repository);
        _stubItem(repository);

        final ProviderContainer container = ProviderContainer(
          overrides: [mortuaryRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        await container.read(mortuaryWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(mortuaryWorkspaceControllerProvider.notifier)
            .applyQueue(mortuaryQueueUnsettledBilling);

        expect(failure, isNull);
        final MortuaryWorkspaceQuery query = queries.last;
        expect(query.panel, mortuaryPanelRelease);
        expect(query.resource, mortuaryResourceBillableEvents);
        expect(query.queue, mortuaryQueueUnsettledBilling);
        expect(query.pageRequest.pageIndex, 0);
        verify(() => repository.getWorkspace(any())).called(2);
      },
    );
  });
}

List<MortuaryWorkspaceQuery> _stubWorkspace(
  _MockMortuaryRepository repository,
) {
  final List<MortuaryWorkspaceQuery> queries = <MortuaryWorkspaceQuery>[];
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    queries.add(query);
    return Result<MortuaryWorkspacePayload>.success(_payload(query));
  });
  return queries;
}

void _stubItem(_MockMortuaryRepository repository) {
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer((_) async {
    return const Result<MortuaryWorkspaceItem>.success(
      MortuaryWorkspaceItem(
        id: 'case-1',
        displayId: 'MOR-001',
        status: 'IN_STORAGE',
        identificationStatus: 'VERIFIED',
        billingStatus: 'SETTLED',
        deceasedProfileLabel: 'Amina K.',
        custodyEvents: <MortuaryTimelineEvent>[
          MortuaryTimelineEvent(id: 'custody-1', eventType: 'RECEIVED'),
        ],
      ),
    );
  });
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  final MortuaryWorkspaceItem item = MortuaryWorkspaceItem(
    id: query.resource == mortuaryResourceCases ? 'case-1' : 'item-1',
    displayId: query.resource == mortuaryResourceCases ? 'MOR-001' : 'ITEM-001',
    resource: query.resource,
    status: 'IN_STORAGE',
    identificationStatus: 'VERIFIED',
    billingStatus: 'SETTLED',
    deceasedProfileLabel: 'Amina K.',
    timelineAt: DateTime.parse('2026-05-20T09:00:00.000Z'),
  );

  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: <MortuaryWorkspaceItem>[item],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueUnsettledBilling,
        count: 1,
        panel: mortuaryPanelRelease,
        resource: mortuaryResourceBillableEvents,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}
