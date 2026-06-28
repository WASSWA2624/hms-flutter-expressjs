import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHrRepository extends Mock implements HrRepository {}

ProviderContainer _createContainer(_MockHrRepository repository) {
  return ProviderContainer(
    overrides: [
      hrRepositoryProvider.overrideWithValue(repository),
      initialSessionStateProvider.overrideWithValue(
        const SessionState.authenticated(),
      ),
    ],
  );
}

const HrStaffProfile _staff = HrStaffProfile(
  id: 'uuid-1',
  displayId: 'STF-1',
  staffNumber: 'EMP-1',
  userFullName: 'Jane Doe',
);

const HrWorkItem _leaveItem = HrWorkItem(
  id: 'LV-1',
  queue: HrQueue.leaveRequests,
  displayId: 'LV-1',
  status: 'REQUESTED',
);

void _stubInitialLoad(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(summary: HrWorkspaceSummary(totalStaff: 1)),
    ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[_staff],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[_leaveItem],
        request: AppPageRequest(pageSize: 10),
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.loadStaffAccessSummary(any())).thenAnswer(
    (_) async => const Result<HrStaffAccessSummary>.success(
      HrStaffAccessSummary(),
    ),
  );
  when(
    () => repository.assignUserRole(
      userId: any(named: 'userId'),
      roleId: any(named: 'roleId'),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer((_) async => const Result<void>.success(null));
  when(() => repository.revokeUserRole(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
  when(() => repository.createUserAccount(any())).thenAnswer(
    (_) async => const Result<Object?>.success(null),
  );
  when(() => repository.updateStaffAssignment(any(), any())).thenAnswer(
    (_) async => const Result<Object?>.success(null),
  );
  when(() => repository.createShiftTemplate(any())).thenAnswer(
    (_) async => const Result<Object?>.success(null),
  );
  when(() => repository.updateShiftTemplate(any(), any())).thenAnswer(
    (_) async => const Result<Object?>.success(null),
  );
  when(() => repository.deleteShiftTemplate(any())).thenAnswer(
    (_) async => const Result<Object?>.success(null),
  );
  when(() => repository.previewPayrollRun(any())).thenAnswer(
    (_) async => const Result<HrPayrollPreview>.success(HrPayrollPreview()),
  );
  when(() => repository.generateRosterPreview(any())).thenAnswer(
    (_) async => const Result<HrRosterGenerateResult>.success(
      HrRosterGenerateResult(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
  });

  group('HrWorkspaceController', () {
    test('selectStaffByDisplayId loads detail for a known staff row', () async {
      final _MockHrRepository repository = _MockHrRepository();
      _stubInitialLoad(repository);
      when(() => repository.loadStaffDetail(any())).thenAnswer(
        (_) async =>
            const Result<HrStaffDetail>.success(HrStaffDetail(profile: _staff)),
      );

      final ProviderContainer container = _createContainer(repository);
      addTearDown(container.dispose);
      await container.read(hrWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(hrWorkspaceControllerProvider.notifier)
          .selectStaffByDisplayId('STF-1');

      expect(failure, isNull);
      final HrWorkspaceState state = _readState(container);
      expect(state.selectedStaff, isNotNull);
      expect(state.selectedStaff!.profile.effectiveId, 'STF-1');
      verify(() => repository.loadStaffDetail(any())).called(1);
    });

    test('approveLeave refreshes work items and overview', () async {
      final _MockHrRepository repository = _MockHrRepository();
      _stubInitialLoad(repository);
      when(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => const Result<Object?>.success(null));

      final ProviderContainer container = _createContainer(repository);
      addTearDown(container.dispose);
      await container.read(hrWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(hrWorkspaceControllerProvider.notifier)
          .approveLeave(_leaveItem, reason: 'Approved');

      expect(failure, isNull);
      verify(
        () => repository.approveLeave('LV-1', reason: 'Approved'),
      ).called(1);
      verify(() => repository.listWorkItems(any())).called(greaterThan(1));
      verify(() => repository.loadOverview()).called(greaterThan(1));
    });

    test('createStaffProfile failure is surfaced without crashing', () async {
      final _MockHrRepository repository = _MockHrRepository();
      _stubInitialLoad(repository);
      when(() => repository.createStaffProfile(any())).thenAnswer(
        (_) async => Result<HrStaffProfile>.failure(AppFailure.validation()),
      );

      final ProviderContainer container = _createContainer(repository);
      addTearDown(container.dispose);
      await container.read(hrWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(hrWorkspaceControllerProvider.notifier)
          .createStaffProfile(<String, Object?>{'staff_number': 'EMP-2'});

      expect(failure, isNotNull);
      final HrWorkspaceState state = _readState(container);
      expect(state.isMutating, isFalse);
      expect(state.lastFailure, isNotNull);
    });
  });
}

HrWorkspaceState _readState(ProviderContainer container) {
  final Result<HrWorkspaceState> result = container
      .read(hrWorkspaceControllerProvider)
      .requireValue;
  return result.when(
    success: (HrWorkspaceState state) => state,
    failure: (AppFailure failure) =>
        throw StateError('Expected success state, got failure: $failure'),
  );
}
