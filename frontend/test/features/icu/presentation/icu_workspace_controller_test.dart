import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

ProviderContainer _icuContainer(IcuRepository repository) {
  return ProviderContainer(
    overrides: [
      initialSessionStateProvider.overrideWithValue(const SessionState.ready()),
      icuRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
    );
    registerFallbackValue(
      const IcuPatientDetail(
        summary: IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
      ),
    );
  });

  group('IcuBoardQuery.fromUri', () {
    test('parses focus admission id and panel', () {
      final IcuBoardQuery query = IcuBoardQuery.fromUri(
        Uri.parse('/icu?id=ADM0001&panel=vitals'),
      );
      expect(query.focusAdmissionId, 'ADM0001');
      expect(query.focusPanel, IcuDetailPanel.vitals);
      expect(query.search, 'ADM0001');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('returns empty targeting when no params', () {
      final IcuBoardQuery query = IcuBoardQuery.fromUri(Uri.parse('/icu'));
      expect(query.focusAdmissionId, isNull);
      expect(query.focusPanel, isNull);
      expect(query.hasRouteTargeting, isFalse);
      expect(query.section, isEmpty);
    });

    test('parses section query parameter', () {
      final IcuBoardQuery query = IcuBoardQuery.fromUri(
        Uri.parse('/icu?section=critical'),
      );
      expect(query.section, 'critical');
      expect(query.hasRouteTargeting, isFalse);
    });

    test('parses section alongside focus id', () {
      final IcuBoardQuery query = IcuBoardQuery.fromUri(
        Uri.parse('/icu?section=transfers&id=ADM0001&panel=vitals'),
      );
      expect(query.section, 'transfers');
      expect(query.focusAdmissionId, 'ADM0001');
      expect(query.focusPanel, IcuDetailPanel.vitals);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('section defaults to empty when beds tab is selected', () {
      final IcuBoardQuery query = IcuBoardQuery.fromUri(
        Uri.parse('/icu?section=beds'),
      );
      expect(query.section, 'beds');
    });

    test('copyWith preserves section', () {
      const IcuBoardQuery original = IcuBoardQuery(section: 'critical');
      final IcuBoardQuery copied = original.copyWith(search: 'test');
      expect(copied.section, 'critical');
      expect(copied.search, 'test');
    });

    test('copyWith overrides section', () {
      const IcuBoardQuery original = IcuBoardQuery(section: 'critical');
      final IcuBoardQuery copied = original.copyWith(section: 'beds');
      expect(copied.section, 'beds');
    });
  });

  group('IcuWorkspaceSection', () {
    test('toBoardScope maps to correct IcuBoardScope', () {
      expect(IcuWorkspaceSection.active.toBoardScope(), IcuBoardScope.active);
      expect(
        IcuWorkspaceSection.critical.toBoardScope(),
        IcuBoardScope.critical,
      );
      expect(
        IcuWorkspaceSection.transfers.toBoardScope(),
        IcuBoardScope.transfer,
      );
      expect(
        IcuWorkspaceSection.discharge.toBoardScope(),
        IcuBoardScope.discharge,
      );
      expect(IcuWorkspaceSection.ended.toBoardScope(), IcuBoardScope.ended);
      expect(IcuWorkspaceSection.all.toBoardScope(), IcuBoardScope.all);
      expect(IcuWorkspaceSection.beds.toBoardScope(), isNull);
    });

    test('isBedBoard returns true only for beds section', () {
      expect(IcuWorkspaceSection.beds.isBedBoard, isTrue);
      expect(IcuWorkspaceSection.active.isBedBoard, isFalse);
      expect(IcuWorkspaceSection.all.isBedBoard, isFalse);
    });
  });

  group('Transfer + panel enums', () {
    test('transfer action tokens map to backend values', () {
      expect(IcuTransferAction.approve.apiToken, 'APPROVE');
      expect(IcuTransferAction.start.apiToken, 'START');
      expect(IcuTransferAction.complete.apiToken, 'COMPLETE');
      expect(IcuTransferAction.cancel.apiToken, 'CANCEL');
      expect(IcuTransferAction.complete.requiresBed, isTrue);
      expect(IcuTransferAction.approve.requiresBed, isFalse);
    });

    test('detail panel parsing is case-insensitive', () {
      expect(IcuDetailPanelX.fromValue('ALERTS'), IcuDetailPanel.alerts);
      expect(IcuDetailPanelX.fromValue('orders'), IcuDetailPanel.orders);
      expect(IcuDetailPanelX.fromValue('nope'), isNull);
      expect(IcuDetailPanelX.fromValue(null), isNull);
    });
  });

  group('IcuWorkspaceController', () {
    test('loads the active board on build', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(
        repository,
        board: const <IcuPatientSummary>[
          IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            icuStatus: 'ACTIVE',
            hasCriticalAlert: true,
            criticalSeverity: 'HIGH',
          ),
        ],
      );

      final ProviderContainer container = _icuContainer(repository);
      addTearDown(container.dispose);

      final Result<IcuWorkspaceState> result = await container.read(
        icuWorkspaceControllerProvider.future,
      );
      final IcuWorkspaceState state = result.when(
        success: (IcuWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );

      expect(state.query.scope, IcuBoardScope.active);
      expect(state.board.items.single.displayId, 'ADM0001');
      expect(state.criticalCount, 1);
      verify(
        () => repository.listIcuBoard(any()),
      ).called(greaterThanOrEqualTo(1));
    });

    test('startIcuStay delegates to the repository', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      const IcuPatientSummary summary = IcuPatientSummary(
        id: 'ADM-1',
        admissionId: 'ADM-1',
        displayId: 'ADM0001',
      );
      const IcuPatientDetail detail = IcuPatientDetail(summary: summary);
      const IcuPatientDetail started = IcuPatientDetail(
        summary: IcuPatientSummary(
          id: 'ADM-1',
          admissionId: 'ADM-1',
          displayId: 'ADM0001',
          icuStatus: 'ACTIVE',
        ),
        activeStay: IcuStaySummary(id: 'ICU-1'),
      );

      _stubInitialLoad(repository, board: const <IcuPatientSummary>[summary]);
      when(
        () => repository.loadIcuDetail(any()),
      ).thenAnswer((_) async => const Result<IcuPatientDetail>.success(detail));
      when(
        () => repository.startIcuStay(
          detail: any(named: 'detail'),
          startedAt: any(named: 'startedAt'),
        ),
      ).thenAnswer(
        (_) async => const Result<IcuPatientDetail>.success(started),
      );

      final ProviderContainer container = _icuContainer(repository);
      addTearDown(container.dispose);
      await container.read(icuWorkspaceControllerProvider.future);

      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      await controller.selectPatient(summary);
      final AppFailure? failure = await controller.startIcuStay();

      expect(failure, isNull);
      verify(
        () => repository.startIcuStay(
          detail: any(named: 'detail'),
          startedAt: any(named: 'startedAt'),
        ),
      ).called(1);
    });

    test('applyScope refreshes board with the requested scope', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      _stubInitialLoad(
        repository,
        board: const <IcuPatientSummary>[
          IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            hasCriticalAlert: true,
          ),
        ],
      );

      final ProviderContainer container = _icuContainer(repository);
      addTearDown(container.dispose);
      await container.read(icuWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .applyScope(IcuBoardScope.critical);

      expect(failure, isNull);
      final Result<IcuWorkspaceState> result = container
          .read(icuWorkspaceControllerProvider)
          .requireValue;
      final IcuWorkspaceState state = result.when(
        success: (IcuWorkspaceState value) => value,
        failure: (AppFailure f) => fail(f.code),
      );
      expect(state.query.scope, IcuBoardScope.critical);
      verify(
        () => repository.listIcuBoard(any()),
      ).called(greaterThanOrEqualTo(2));
    });

    test('selectPatientByDisplayId selects a matching board row', () async {
      final _MockIcuRepository repository = _MockIcuRepository();
      const IcuPatientSummary summary = IcuPatientSummary(
        id: 'ADM-1',
        admissionId: 'ADM-1',
        displayId: 'ADM0001',
      );
      _stubInitialLoad(repository, board: const <IcuPatientSummary>[summary]);
      when(() => repository.loadIcuDetail(any())).thenAnswer(
        (_) async => const Result<IcuPatientDetail>.success(
          IcuPatientDetail(summary: summary),
        ),
      );

      final ProviderContainer container = _icuContainer(repository);
      addTearDown(container.dispose);
      await container.read(icuWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(icuWorkspaceControllerProvider.notifier)
          .selectPatientByDisplayId('ADM0001');

      expect(failure, isNull);
      verify(() => repository.loadIcuDetail(any())).called(1);
    });

    test(
      'requestTransfer patches selected detail and refresh board on success',
      () async {
        final _MockIcuRepository repository = _MockIcuRepository();
        const IcuPatientSummary summary = IcuPatientSummary(
          id: 'ADM-1',
          admissionId: 'ADM-1',
          displayId: 'ADM0001',
          wardName: 'ICU-1',
          icuStatus: 'ACTIVE',
        );
        const IcuPatientDetail detail = IcuPatientDetail(
          summary: summary,
          activeStay: IcuStaySummary(id: 'ICU-1'),
        );
        const IcuPatientDetail transferred = IcuPatientDetail(
          summary: IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            wardName: 'ICU-1',
            icuStatus: 'ACTIVE',
            transferStatus: 'REQUESTED',
          ),
          activeStay: IcuStaySummary(id: 'ICU-1'),
          transferRequests: <IcuTransferRequest>[
            IcuTransferRequest(
              id: 'TR-1',
              status: 'REQUESTED',
              toWardName: 'Ward B',
            ),
          ],
        );

        _stubInitialLoad(repository, board: const <IcuPatientSummary>[summary]);
        when(() => repository.loadIcuDetail(any())).thenAnswer(
          (_) async => const Result<IcuPatientDetail>.success(detail),
        );
        when(
          () => repository.requestTransfer(
            detail: any(named: 'detail'),
            toWardId: any(named: 'toWardId'),
            fromWardId: any(named: 'fromWardId'),
          ),
        ).thenAnswer(
          (_) async => const Result<IcuPatientDetail>.success(transferred),
        );

        final ProviderContainer container = _icuContainer(repository);
        addTearDown(container.dispose);
        await container.read(icuWorkspaceControllerProvider.future);

        final IcuWorkspaceController controller = container.read(
          icuWorkspaceControllerProvider.notifier,
        );
        await controller.selectPatient(summary);
        final AppFailure? failure = await controller.requestTransfer(
          toWardId: 'ward-b',
          fromWardId: 'ward-a',
        );

        expect(failure, isNull);
        // Allow the post-success board refresh to settle without requiring the
        // board stub to echo transferStatus on the summary row.
        await Future<void>.delayed(Duration.zero);
        final Result<IcuWorkspaceState> result = container
            .read(icuWorkspaceControllerProvider)
            .requireValue;
        final IcuWorkspaceState state = result.when(
          success: (IcuWorkspaceState value) => value,
          failure: (AppFailure f) => fail(f.code),
        );
        expect(state.selectedDetail?.transferRequests.single.id, 'TR-1');
        expect(state.selectedDetail?.transferRequests.single.status, 'REQUESTED');
        verify(
          () => repository.requestTransfer(
            detail: any(named: 'detail'),
            toWardId: 'ward-b',
            fromWardId: 'ward-a',
          ),
        ).called(1);
        verify(
          () => repository.listIcuBoard(any()),
        ).called(greaterThanOrEqualTo(2));
      },
    );

    test(
      'requestTransfer failure patches nothing and returns AppFailure',
      () async {
        final _MockIcuRepository repository = _MockIcuRepository();
        const IcuPatientSummary summary = IcuPatientSummary(
          id: 'ADM-1',
          admissionId: 'ADM-1',
          displayId: 'ADM0001',
          icuStatus: 'ACTIVE',
        );
        const IcuPatientDetail detail = IcuPatientDetail(
          summary: summary,
          activeStay: IcuStaySummary(id: 'ICU-1'),
        );

        _stubInitialLoad(repository, board: const <IcuPatientSummary>[summary]);
        when(() => repository.loadIcuDetail(any())).thenAnswer(
          (_) async => const Result<IcuPatientDetail>.success(detail),
        );
        when(
          () => repository.requestTransfer(
            detail: any(named: 'detail'),
            toWardId: any(named: 'toWardId'),
            fromWardId: any(named: 'fromWardId'),
          ),
        ).thenAnswer(
          (_) async => const Result<IcuPatientDetail>.failure(
            AppFailure.network(),
          ),
        );

        final ProviderContainer container = _icuContainer(repository);
        addTearDown(container.dispose);
        await container.read(icuWorkspaceControllerProvider.future);

        final IcuWorkspaceController controller = container.read(
          icuWorkspaceControllerProvider.notifier,
        );
        await controller.selectPatient(summary);
        final AppFailure? failure = await controller.requestTransfer(
          toWardId: 'ward-b',
        );

        expect(failure, isNotNull);
        final Result<IcuWorkspaceState> result = container
            .read(icuWorkspaceControllerProvider)
            .requireValue;
        final IcuWorkspaceState state = result.when(
          success: (IcuWorkspaceState value) => value,
          failure: (AppFailure f) => fail(f.code),
        );
        expect(state.selectedDetail?.transferRequests, isEmpty);
        expect(state.selectedDetail?.summary.transferStatus, isNull);
      },
    );
  });
}

void _stubInitialLoad(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[],
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer(
    (invocation) async => Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: board,
        request: (invocation.positionalArguments.single as IcuBoardQuery)
            .pageRequest,
        totalItemCount: board.length,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
}
