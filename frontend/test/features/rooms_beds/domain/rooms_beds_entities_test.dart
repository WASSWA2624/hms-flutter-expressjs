import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('RoomsBedsSection', () {
    test('exposes five bed board sections', () {
      expect(RoomsBedsSection.values, hasLength(5));
      expect(
        RoomsBedsSection.values,
        containsAll(<RoomsBedsSection>[
          RoomsBedsSection.all,
          RoomsBedsSection.available,
          RoomsBedsSection.occupied,
          RoomsBedsSection.turnover,
          RoomsBedsSection.outOfService,
        ]),
      );
    });
  });

  group('RoomsBedsQuery.fromUri', () {
    test('parses section=available', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?section=available'),
      );

      expect(query.section, RoomsBedsSection.available);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section=occupied', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?section=occupied'),
      );

      expect(query.section, RoomsBedsSection.occupied);
    });

    test('parses section=turnover', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?section=turnover'),
      );

      expect(query.section, RoomsBedsSection.turnover);
    });

    test('parses turnover aliases reserved, cleaning, and maintenance', () {
      expect(
        RoomsBedsQuery.fromUri(
          Uri.parse('/rooms-beds?section=reserved'),
        ).section,
        RoomsBedsSection.turnover,
      );
      expect(
        RoomsBedsQuery.fromUri(
          Uri.parse('/rooms-beds?section=cleaning'),
        ).section,
        RoomsBedsSection.turnover,
      );
      expect(
        RoomsBedsQuery.fromUri(
          Uri.parse('/rooms-beds?section=maintenance'),
        ).section,
        RoomsBedsSection.turnover,
      );
    });

    test('parses section=out-of-service', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?section=out-of-service'),
      );

      expect(query.section, RoomsBedsSection.outOfService);
    });

    test('parses out-of-service aliases', () {
      expect(
        RoomsBedsQuery.fromUri(
          Uri.parse('/rooms-beds?section=out_of_service'),
        ).section,
        RoomsBedsSection.outOfService,
      );
      expect(
        RoomsBedsQuery.fromUri(
          Uri.parse('/rooms-beds?section=blocked'),
        ).section,
        RoomsBedsSection.outOfService,
      );
      expect(
        RoomsBedsQuery.fromUri(Uri.parse('/rooms-beds?section=oos')).section,
        RoomsBedsSection.outOfService,
      );
    });

    test('accepts tab alias for section', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?tab=available'),
      );

      expect(query.section, RoomsBedsSection.available);
    });

    test('defaults to all when section is missing', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds'),
      );

      expect(query.section, RoomsBedsSection.all);
      expect(query.status, isNull);
      expect(query.hasRouteTargeting, isFalse);
      expect(query.hasFilters, isFalse);
    });

    test('still parses status and ward deep links', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?status=OCCUPIED&ward=WRD-001'),
      );

      expect(query.status, BedSetupStatus.occupied);
      expect(query.wardId, 'WRD-001');
      expect(query.section, RoomsBedsSection.all);
      expect(query.hasRouteTargeting, isTrue);
      expect(query.hasFilters, isTrue);
    });

    test('copyWith preserves and overrides section', () {
      const RoomsBedsQuery original = RoomsBedsQuery(
        section: RoomsBedsSection.available,
      );
      expect(
        original.copyWith(search: 'A1').section,
        RoomsBedsSection.available,
      );
      expect(
        original.copyWith(section: RoomsBedsSection.turnover).section,
        RoomsBedsSection.turnover,
      );
    });
  });

  group('RoomsBedsWorkspaceState section counts', () {
    test('tab badge counts match status groups', () {
      final RoomsBedsWorkspaceState state = RoomsBedsWorkspaceState(
        query: const RoomsBedsQuery(),
        beds: const AppPage<BedBoardItem>(
          items: <BedBoardItem>[],
          request: AppPageRequest(),
        ),
        referenceData: RoomsBedsReferenceData(
          snapshot: FacilitySetupSnapshot(
            tenant: const TenantProfile(id: 'TEN-001', name: 'Tenant'),
            facilities: const <FacilityProfile>[
              FacilityProfile(
                id: 'FAC-001',
                tenantId: 'TEN-001',
                name: 'Main',
                type: FacilitySetupType.hospital,
              ),
            ],
            wards: const <WardProfile>[
              WardProfile(
                id: 'WRD-001',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                name: 'Ward A',
                type: WardSetupType.general,
              ),
            ],
            rooms: const <RoomProfile>[],
            beds: const <BedProfile>[
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
                label: 'A2',
                status: BedSetupStatus.available,
              ),
              BedProfile(
                id: 'BED-3',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'B1',
                status: BedSetupStatus.occupied,
              ),
              BedProfile(
                id: 'BED-4',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'B2',
                status: BedSetupStatus.reserved,
              ),
              BedProfile(
                id: 'BED-5',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'C1',
                status: BedSetupStatus.cleaning,
              ),
              BedProfile(
                id: 'BED-6',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'C2',
                status: BedSetupStatus.maintenance,
              ),
              BedProfile(
                id: 'BED-7',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'D1',
                status: BedSetupStatus.blocked,
              ),
              BedProfile(
                id: 'BED-8',
                tenantId: 'TEN-001',
                facilityId: 'FAC-001',
                wardId: 'WRD-001',
                label: 'D2',
                status: BedSetupStatus.outOfService,
              ),
            ],
          ),
        ),
      );

      expect(state.totalBedCount, 8);
      expect(state.availableCount, 2);
      expect(state.occupiedCount, 1);
      expect(
        state.reservedCount + state.cleaningCount + state.maintenanceCount,
        3,
      );
      expect(state.blockedCount, 2);
    });
  });
}
