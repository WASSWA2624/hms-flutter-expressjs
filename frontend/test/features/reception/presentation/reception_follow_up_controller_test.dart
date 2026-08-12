import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_follow_up_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

ReceptionFollowUpEntry _entry(int index) {
  return ReceptionFollowUpEntry(
    id: 'fu-$index',
    encounterId: 'enc-$index',
    patientId: 'pat-$index',
    patientIdentifier: 'PAT-$index',
    patientDisplayName: 'Patient $index',
    scheduledAt: DateTime.utc(2026, 7, 1).add(Duration(minutes: index)),
    status: 'SCHEDULED',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
    );
  });

  test('loadMore appends pages until the server total is reached', () async {
    final _MockFollowUpRepository repository = _MockFollowUpRepository();
    final List<ReceptionFollowUpEntry> all = <ReceptionFollowUpEntry>[
      for (int i = 0; i < 250; i += 1) _entry(i),
    ];

    when(
      () => repository.listScheduledFollowUpsPage(
        encounterType: any(named: 'encounterType'),
        pageRequest: any(named: 'pageRequest'),
      ),
    ).thenAnswer((Invocation invocation) async {
      final AppPageRequest request =
          invocation.namedArguments[#pageRequest] as AppPageRequest? ??
          const AppPageRequest(pageSize: AppPageRequest.maxPageSize);
      final int start = request.offset;
      final int end = (start + request.pageSize).clamp(0, all.length);
      return Result<({List<ReceptionFollowUpEntry> entries, int total})>.success((
        entries: start >= all.length
            ? const <ReceptionFollowUpEntry>[]
            : all.sublist(start, end),
        total: all.length,
      ));
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        receptionFollowUpRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(receptionFollowUpControllerProvider.future);
    ReceptionFollowUpState state = container
        .read(receptionFollowUpControllerProvider)
        .requireValue
        .when(
          success: (ReceptionFollowUpState value) => value,
          failure: (AppFailure failure) => throw failure,
        );

    expect(state.entries, hasLength(AppPageRequest.maxPageSize));
    expect(state.totalCount, 250);
    expect(state.hasMore, isTrue);

    final AppFailure? firstLoadMore = await container
        .read(receptionFollowUpControllerProvider.notifier)
        .loadMore();
    expect(firstLoadMore, isNull);
    state = container
        .read(receptionFollowUpControllerProvider)
        .requireValue
        .when(
          success: (ReceptionFollowUpState value) => value,
          failure: (AppFailure failure) => throw failure,
        );
    expect(state.entries, hasLength(200));
    expect(state.hasMore, isTrue);

    final AppFailure? secondLoadMore = await container
        .read(receptionFollowUpControllerProvider.notifier)
        .loadMore();
    expect(secondLoadMore, isNull);
    state = container
        .read(receptionFollowUpControllerProvider)
        .requireValue
        .when(
          success: (ReceptionFollowUpState value) => value,
          failure: (AppFailure failure) => throw failure,
        );
    expect(state.entries, hasLength(250));
    expect(state.hasMore, isFalse);
    expect(state.totalCount, 250);

    verify(
      () => repository.listScheduledFollowUpsPage(
        encounterType: any(named: 'encounterType'),
        pageRequest: any(named: 'pageRequest'),
      ),
    ).called(3);
  });
}
