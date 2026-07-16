import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/rooms_beds/data/repositories/rooms_beds_repository_impl.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/repositories/rooms_beds_repository.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:mocktail/mocktail.dart';

class _MockRoomsBedsRepository extends Mock implements RoomsBedsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(WardSetupType.general);
    registerFallbackValue(BedSetupStatus.available);
    registerFallbackValue(
      const BedProfile(
        id: 'BED-001',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        wardId: 'WRD-001',
        label: 'A1',
        status: BedSetupStatus.available,
      ),
    );
  });

  group('RoomsBedsWorkspaceController', () {
    test('loads beds with assignment context only where operational', () async {
      final _MockRoomsBedsRepository repository = _MockRoomsBedsRepository();
      _stubSetup(repository);
      _stubAssignments(repository);

      final ProviderContainer container = ProviderContainer(
        overrides: [roomsBedsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<RoomsBedsWorkspaceState> result = await container.read(
        roomsBedsWorkspaceControllerProvider.future,
      );

      final RoomsBedsWorkspaceState state = result.when(
        success: (RoomsBedsWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );

      expect(state.beds.items, hasLength(2));
      expect(state.beds.items.first.activeAssignment, isNull);
      expect(state.beds.items.last.currentAdmissionId, 'ADM-001');
      expect(state.beds.items.last.currentAdmissionDisplayId, 'Admission 001');
      verify(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(1);
      verify(() => repository.listBedAssignmentsForBed('BED-002')).called(1);
      verifyNever(() => repository.listBedAssignmentsForBed('BED-001'));
    });

    test('updates one bed row after a status mutation', () async {
      final _MockRoomsBedsRepository repository = _MockRoomsBedsRepository();
      _stubSetup(repository);
      _stubAssignments(repository);
      when(
        () => repository.updateBedStatus(
          bed: any(named: 'bed'),
          status: any(named: 'status'),
        ),
      ).thenAnswer(
        (_) async => const Result<BedProfile>.success(
          BedProfile(
            id: 'BED-001',
            tenantId: 'TEN-001',
            facilityId: 'FAC-001',
            wardId: 'WRD-001',
            label: 'A1',
            status: BedSetupStatus.reserved,
            roomId: 'ROM-001',
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [roomsBedsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(roomsBedsWorkspaceControllerProvider.future);

      final RoomsBedsWorkspaceState before = container
          .read(roomsBedsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (RoomsBedsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );

      final AppFailure? failure = await container
          .read(roomsBedsWorkspaceControllerProvider.notifier)
          .updateBedStatus(before.beds.items.first, BedSetupStatus.reserved);

      final RoomsBedsWorkspaceState after = container
          .read(roomsBedsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (RoomsBedsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );

      expect(failure, isNull);
      expect(after.beds.items.first.status, BedSetupStatus.reserved);
      expect(after.beds.items.last.status, BedSetupStatus.occupied);
      verify(
        () => repository.updateBedStatus(
          bed: before.beds.items.first.bed,
          status: BedSetupStatus.reserved,
        ),
      ).called(1);
      verify(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(1);
    });

    test('updateTransfer reloads bed board only after HTTP success', () async {
      final _MockRoomsBedsRepository repository = _MockRoomsBedsRepository();
      _stubSetup(repository);
      _stubAssignments(repository);
      when(
        () => repository.updateTransfer(
          admissionId: any(named: 'admissionId'),
          action: any(named: 'action'),
          transferRequestId: any(named: 'transferRequestId'),
          toBedId: any(named: 'toBedId'),
        ),
      ).thenAnswer((_) async => const Result<void>.success(null));

      final ProviderContainer container = ProviderContainer(
        overrides: [roomsBedsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(roomsBedsWorkspaceControllerProvider.future);

      final RoomsBedsWorkspaceState before = container
          .read(roomsBedsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (RoomsBedsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );
      final BedBoardItem occupied = before.beds.items.last;

      final AppFailure? failure = await container
          .read(roomsBedsWorkspaceControllerProvider.notifier)
          .updateTransfer(
            item: occupied,
            admissionId: 'ADM-001',
            action: 'APPROVE',
            transferRequestId: 'TR-1',
          );

      expect(failure, isNull);
      verify(
        () => repository.updateTransfer(
          admissionId: 'ADM-001',
          action: 'APPROVE',
          transferRequestId: 'TR-1',
          toBedId: null,
        ),
      ).called(1);
      // Initial load + post-success reload.
      verify(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(2);
    });

    test('updateTransfer failure does not reload bed board', () async {
      final _MockRoomsBedsRepository repository = _MockRoomsBedsRepository();
      _stubSetup(repository);
      _stubAssignments(repository);
      when(
        () => repository.updateTransfer(
          admissionId: any(named: 'admissionId'),
          action: any(named: 'action'),
          transferRequestId: any(named: 'transferRequestId'),
          toBedId: any(named: 'toBedId'),
        ),
      ).thenAnswer(
        (_) async => const Result<void>.failure(AppFailure.network()),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [roomsBedsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(roomsBedsWorkspaceControllerProvider.future);

      final RoomsBedsWorkspaceState before = container
          .read(roomsBedsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (RoomsBedsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );

      final AppFailure? failure = await container
          .read(roomsBedsWorkspaceControllerProvider.notifier)
          .updateTransfer(
            item: before.beds.items.last,
            admissionId: 'ADM-001',
            action: 'START',
          );

      expect(failure, isNotNull);
      final RoomsBedsWorkspaceState after = container
          .read(roomsBedsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (RoomsBedsWorkspaceState value) => value,
            failure: (AppFailure value) => fail(value.code),
          );
      expect(after.isSaving, isFalse);
      expect(after.lastFailure, isNotNull);
      verify(
        () => repository.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(1);
    });
  });
}

void _stubSetup(_MockRoomsBedsRepository repository) {
  when(
    () => repository.loadSetup(facilityId: any(named: 'facilityId')),
  ).thenAnswer((_) async => Result<FacilitySetupSnapshot>.success(_snapshot()));
}

void _stubAssignments(_MockRoomsBedsRepository repository) {
  when(() => repository.loadAdmissionContext(any())).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(
        admissionId: 'ADM-001',
        admissionDisplayId: 'Admission 001',
      ),
    ),
  );
  when(() => repository.listBedAssignmentsForBed(any())).thenAnswer((
    invocation,
  ) async {
    final String bedId = invocation.positionalArguments.single as String;
    if (bedId != 'BED-002') {
      return const Result<List<BedAssignmentRecord>>.success(
        <BedAssignmentRecord>[],
      );
    }

    return const Result<List<BedAssignmentRecord>>.success(
      <BedAssignmentRecord>[
        BedAssignmentRecord(
          id: 'BAS-001',
          admissionId: 'ADM-001',
          admissionDisplayId: 'Admission 001',
          bedId: 'BED-002',
        ),
      ],
    );
  });
}

FacilitySetupSnapshot _snapshot() {
  return const FacilitySetupSnapshot(
    tenant: TenantProfile(id: 'TEN-001', name: 'Tenant'),
    facility: FacilityProfile(
      id: 'FAC-001',
      tenantId: 'TEN-001',
      name: 'Main',
      type: FacilitySetupType.hospital,
    ),
    facilities: <FacilityProfile>[
      FacilityProfile(
        id: 'FAC-001',
        tenantId: 'TEN-001',
        name: 'Main',
        type: FacilitySetupType.hospital,
      ),
    ],
    wards: <WardProfile>[
      WardProfile(
        id: 'WRD-001',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        name: 'General',
        type: WardSetupType.general,
      ),
    ],
    rooms: <RoomProfile>[
      RoomProfile(
        id: 'ROM-001',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        name: 'Room A',
        wardId: 'WRD-001',
      ),
    ],
    beds: <BedProfile>[
      BedProfile(
        id: 'BED-001',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        wardId: 'WRD-001',
        label: 'A1',
        status: BedSetupStatus.available,
        roomId: 'ROM-001',
      ),
      BedProfile(
        id: 'BED-002',
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        wardId: 'WRD-001',
        label: 'A2',
        status: BedSetupStatus.occupied,
        roomId: 'ROM-001',
      ),
    ],
  );
}
