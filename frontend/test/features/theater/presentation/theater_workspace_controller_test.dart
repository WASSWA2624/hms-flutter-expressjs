import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockTheaterRepository extends Mock implements TheaterRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const TheaterCaseQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('TheaterWorkspaceController', () {
    test('loads daily cases and selects the first case detail', () async {
      final _MockTheaterRepository repository = _MockTheaterRepository();
      const TheaterCase summary = TheaterCase(
        id: 'TC-001',
        patientDisplayName: 'Jane Doe',
        status: 'SCHEDULED',
      );
      const TheaterCase detail = TheaterCase(
        id: 'TC-001',
        patientDisplayName: 'Jane Doe',
        status: 'SCHEDULED',
        checklistCompleted: 1,
        checklistTotal: 2,
      );

      _stubInitialLoad(
        repository,
        cases: <TheaterCase>[summary],
        detail: detail,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [theaterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<TheaterWorkspaceState> result = await container.read(
        theaterWorkspaceControllerProvider.future,
      );

      final TheaterWorkspaceState state = result.when(
        success: (TheaterWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
      expect(state.cases.items.single.id, 'TC-001');
      expect(state.selectedCase?.checklistCompleted, 1);
      verify(() => repository.listCases(any())).called(1);
      verify(() => repository.getCase('TC-001')).called(1);
    });

    test('submits checklist updates for the selected case', () async {
      final _MockTheaterRepository repository = _MockTheaterRepository();
      const TheaterCase detail = TheaterCase(id: 'TC-001', status: 'SCHEDULED');
      String? submittedCaseId;
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(
        repository,
        cases: <TheaterCase>[detail],
        detail: detail,
      );
      when(() => repository.toggleChecklistItem(any(), any())).thenAnswer((
        invocation,
      ) async {
        submittedCaseId = invocation.positionalArguments[0] as String;
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<TheaterCase>.success(
          TheaterCase(
            id: 'TC-001',
            status: 'SCHEDULED',
            checklistCompleted: 1,
            checklistTotal: 1,
          ),
        );
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [theaterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(theaterWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(theaterWorkspaceControllerProvider.notifier)
          .toggleChecklistItem(<String, Object?>{
            'phase': 'SIGN_IN',
            'item_code': 'CONSENT',
            'is_checked': true,
          });

      expect(failure, isNull);
      expect(submittedCaseId, 'TC-001');
      expect(submittedPayload, containsPair('phase', 'SIGN_IN'));
      expect(submittedPayload, containsPair('item_code', 'CONSENT'));
      verify(() => repository.toggleChecklistItem(any(), any())).called(1);
    });
  });
}

void _stubInitialLoad(
  _MockTheaterRepository repository, {
  List<TheaterCase> cases = const <TheaterCase>[],
  TheaterCase? detail,
}) {
  when(() => repository.listCases(any())).thenAnswer(
    (invocation) async => Result<AppPage<TheaterCase>>.success(
      AppPage<TheaterCase>(
        items: cases,
        request: (invocation.positionalArguments.single as TheaterCaseQuery)
            .pageRequest,
        totalItemCount: cases.length,
      ),
    ),
  );
  when(() => repository.getCase(any())).thenAnswer(
    (_) async => Result<TheaterCase>.success(
      detail ?? cases.firstOrNull ?? const TheaterCase(id: 'TC-001'),
    ),
  );
}
