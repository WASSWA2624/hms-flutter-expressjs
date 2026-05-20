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
        () => repository.saveBed(
          id: any(named: 'id'),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
          wardId: any(named: 'wardId'),
          label: any(named: 'label'),
          status: any(named: 'status'),
          roomId: any(named: 'roomId'),
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
        () => repository.saveBed(
          id: 'BED-001',
          tenantId: 'TEN-001',
          facilityId: 'FAC-001',
          wardId: 'WRD-001',
          label: 'A1',
          status: BedSetupStatus.reserved,
          roomId: 'ROM-001',
        ),
      ).called(1);
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
