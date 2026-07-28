import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/widgets/rooms_beds_status_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  BedBoardItem bed(String id, BedSetupStatus status) {
    return BedBoardItem(
      bed: BedProfile(
        id: id,
        tenantId: 'TEN-001',
        facilityId: 'FAC-001',
        wardId: 'WRD-001',
        label: id,
        status: status,
      ),
    );
  }

  group('roomsBedsSectionMatchesStatus', () {
    test('all matches every status', () {
      for (final BedSetupStatus status in BedSetupStatus.values) {
        expect(
          roomsBedsSectionMatchesStatus(RoomsBedsSection.all, status),
          isTrue,
        );
      }
    });

    test('available matches only available beds', () {
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.available,
          BedSetupStatus.available,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.available,
          BedSetupStatus.occupied,
        ),
        isFalse,
      );
    });

    test('occupied matches only occupied beds', () {
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.occupied,
          BedSetupStatus.occupied,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.occupied,
          BedSetupStatus.available,
        ),
        isFalse,
      );
    });

    test('turnover matches reserved, cleaning, and maintenance', () {
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.turnover,
          BedSetupStatus.reserved,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.turnover,
          BedSetupStatus.cleaning,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.turnover,
          BedSetupStatus.maintenance,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.turnover,
          BedSetupStatus.available,
        ),
        isFalse,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.turnover,
          BedSetupStatus.blocked,
        ),
        isFalse,
      );
    });

    test('outOfService matches blocked and outOfService', () {
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.outOfService,
          BedSetupStatus.blocked,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.outOfService,
          BedSetupStatus.outOfService,
        ),
        isTrue,
      );
      expect(
        roomsBedsSectionMatchesStatus(
          RoomsBedsSection.outOfService,
          BedSetupStatus.maintenance,
        ),
        isFalse,
      );
    });
  });

  group('roomsBedsSectionFilteredPage', () {
    late AppPage<BedBoardItem> page;

    setUp(() {
      page = AppPage<BedBoardItem>(
        items: <BedBoardItem>[
          bed('A1', BedSetupStatus.available),
          bed('O1', BedSetupStatus.occupied),
          bed('R1', BedSetupStatus.reserved),
          bed('C1', BedSetupStatus.cleaning),
          bed('M1', BedSetupStatus.maintenance),
          bed('B1', BedSetupStatus.blocked),
          bed('X1', BedSetupStatus.outOfService),
        ],
        request: const AppPageRequest(),
        totalItemCount: 7,
      );
    });

    test('all returns the original page', () {
      final AppPage<BedBoardItem> filtered = roomsBedsSectionFilteredPage(
        page,
        RoomsBedsSection.all,
      );
      expect(identical(filtered, page), isTrue);
      expect(filtered.items, hasLength(7));
    });

    test('available filters to available beds only', () {
      final AppPage<BedBoardItem> filtered = roomsBedsSectionFilteredPage(
        page,
        RoomsBedsSection.available,
      );
      expect(filtered.items.map((BedBoardItem b) => b.id), <String>['A1']);
      expect(filtered.totalItemCount, 1);
    });

    test('occupied filters to occupied beds only', () {
      final AppPage<BedBoardItem> filtered = roomsBedsSectionFilteredPage(
        page,
        RoomsBedsSection.occupied,
      );
      expect(filtered.items.map((BedBoardItem b) => b.id), <String>['O1']);
    });

    test('turnover filters reserved, cleaning, and maintenance', () {
      final AppPage<BedBoardItem> filtered = roomsBedsSectionFilteredPage(
        page,
        RoomsBedsSection.turnover,
      );
      expect(filtered.items.map((BedBoardItem b) => b.id), <String>[
        'R1',
        'C1',
        'M1',
      ]);
      expect(filtered.totalItemCount, 3);
    });

    test('outOfService filters blocked and out-of-service beds', () {
      final AppPage<BedBoardItem> filtered = roomsBedsSectionFilteredPage(
        page,
        RoomsBedsSection.outOfService,
      );
      expect(filtered.items.map((BedBoardItem b) => b.id), <String>[
        'B1',
        'X1',
      ]);
      expect(filtered.totalItemCount, 2);
    });
  });

  group('roomsBedsSectionCount', () {
    test('badge counts match workspace status aggregates', () {
      const RoomsBedsWorkspaceState state = RoomsBedsWorkspaceState(
        query: RoomsBedsQuery(),
        beds: AppPage<BedBoardItem>(
          items: <BedBoardItem>[],
          request: AppPageRequest(),
        ),
        referenceData: RoomsBedsReferenceData(
          snapshot: FacilitySetupSnapshot(
            tenant: TenantProfile(id: 'TEN-001', name: 'Tenant'),
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
                name: 'Ward A',
                type: WardSetupType.general,
              ),
            ],
            beds: <BedProfile>[
              BedProfile(
                id: 'BED-1',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'A1',
                status: BedSetupStatus.available,
              ),
              BedProfile(
                id: 'BED-2',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'B1',
                status: BedSetupStatus.occupied,
              ),
              BedProfile(
                id: 'BED-3',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'C1',
                status: BedSetupStatus.reserved,
              ),
              BedProfile(
                id: 'BED-4',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'C2',
                status: BedSetupStatus.cleaning,
              ),
              BedProfile(
                id: 'BED-5',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'C3',
                status: BedSetupStatus.maintenance,
              ),
              BedProfile(
                id: 'BED-6',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'D1',
                status: BedSetupStatus.blocked,
              ),
            ],
          ),
        ),
      );

      expect(roomsBedsSectionCount(state, RoomsBedsSection.all), 6);
      expect(roomsBedsSectionCount(state, RoomsBedsSection.available), 1);
      expect(roomsBedsSectionCount(state, RoomsBedsSection.occupied), 1);
      expect(roomsBedsSectionCount(state, RoomsBedsSection.turnover), 3);
      expect(roomsBedsSectionCount(state, RoomsBedsSection.outOfService), 1);
    });
  });

  group('roomsBedsPrimaryNextActionKind', () {
    BedBoardItem bedWithStatus(
      BedSetupStatus status, {
      bool hasOpenTransfer = false,
    }) {
      return BedBoardItem(
        bed: BedProfile(
          id: 'BED-1',
          tenantId: 'TEN-001',
          facilityId: 'FAC-001',
          wardId: 'WRD-001',
          label: 'A1',
          status: status,
        ),
        admissionContext: hasOpenTransfer
            ? const BedAdmissionContext(
                admissionId: 'ADM-1',
                transferRequestId: 'TR-1',
                transferStatus: 'REQUESTED',
              )
            : null,
      );
    }

    test('available resolves to assign', () {
      expect(
        roomsBedsPrimaryNextActionKind(bedWithStatus(BedSetupStatus.available)),
        RoomsBedsNextActionKind.assign,
      );
    });

    test('occupied without transfer resolves to release', () {
      expect(
        roomsBedsPrimaryNextActionKind(bedWithStatus(BedSetupStatus.occupied)),
        RoomsBedsNextActionKind.release,
      );
    });

    test('occupied with open transfer resolves to completeTransfer', () {
      expect(
        roomsBedsPrimaryNextActionKind(
          bedWithStatus(BedSetupStatus.occupied, hasOpenTransfer: true),
        ),
        RoomsBedsNextActionKind.completeTransfer,
      );
    });

    test('reserved resolves to markAvailable', () {
      expect(
        roomsBedsPrimaryNextActionKind(bedWithStatus(BedSetupStatus.reserved)),
        RoomsBedsNextActionKind.markAvailable,
      );
    });

    test('cleaning resolves to markAvailable', () {
      expect(
        roomsBedsPrimaryNextActionKind(bedWithStatus(BedSetupStatus.cleaning)),
        RoomsBedsNextActionKind.markAvailable,
      );
    });

    test('maintenance resolves to openOperations', () {
      expect(
        roomsBedsPrimaryNextActionKind(
          bedWithStatus(BedSetupStatus.maintenance),
        ),
        RoomsBedsNextActionKind.openOperations,
      );
    });

    test('blocked resolves to markAvailable', () {
      expect(
        roomsBedsPrimaryNextActionKind(bedWithStatus(BedSetupStatus.blocked)),
        RoomsBedsNextActionKind.markAvailable,
      );
    });

    test('outOfService resolves to openOperations', () {
      expect(
        roomsBedsPrimaryNextActionKind(
          bedWithStatus(BedSetupStatus.outOfService),
        ),
        RoomsBedsNextActionKind.openOperations,
      );
    });
  });

  group('roomsBedsBedBoardSearchMatcher', () {
    late BedBoardItem item;
    late bool Function(BedBoardItem, String) matcher;

    setUp(() {
      item = BedBoardItem(
        bed: BedProfile(
          id: 'BED-SEARCH',
          tenantId: 'TEN-001',
          facilityId: 'FAC-001',
          wardId: 'WRD-001',
          label: 'ICU Bed 3',
          status: BedSetupStatus.available,
        ),
        facility: const FacilityProfile(
          id: 'FAC-001',
          tenantId: 'TEN-001',
          name: 'Central Hospital',
          type: FacilitySetupType.hospital,
        ),
        ward: const WardProfile(
          id: 'WRD-001',
          tenantId: 'TEN-001',
          facilityId: 'FAC-001',
          name: 'ICU Ward',
          type: WardSetupType.icu,
        ),
        room: const RoomProfile(
          id: 'RM-001',
          tenantId: 'TEN-001',
          facilityId: 'FAC-001',
          wardId: 'WRD-001',
          name: 'Room 12',
          floor: 'Level 4',
        ),
      );
      matcher = roomsBedsBedBoardSearchMatcher(_FakeL10n());
    });

    test('empty query matches all', () {
      expect(matcher(item, ''), isTrue);
      expect(matcher(item, '   '), isTrue);
    });

    test('matches bed label', () {
      expect(matcher(item, 'icu bed'), isTrue);
    });

    test('matches facility name', () {
      expect(matcher(item, 'central'), isTrue);
    });

    test('matches ward and room location', () {
      expect(matcher(item, 'icu ward'), isTrue);
      expect(matcher(item, 'room 12'), isTrue);
    });

    test('matches floor hidden column value', () {
      expect(matcher(item, 'level 4'), isTrue);
    });

    test('no match returns false', () {
      expect(matcher(item, 'pediatrics'), isFalse);
    });
  });
}

class _FakeL10n implements AppLocalizations {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String name = invocation.memberName.toString();
    if (name.contains('roomsBeds') ||
        name.contains('tenantFacility') ||
        name.contains('profileUnknown')) {
      return 'label';
    }
    return '';
  }
}
