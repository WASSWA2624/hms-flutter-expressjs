import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/home/data/dtos/home_dashboard_lookups_dtos.dart';

void main() {
  group('HomeDashboardLookupsDto', () {
    test('parses tenants, facilities, branches, and filter lookups', () {
      final lookups = HomeDashboardLookupsDto.fromResponse(<String, Object?>{
        'data': <String, Object?>{
          'tenants': <Object?>[
            <String, Object?>{'id': 'TEN-1', 'label': 'Demo tenant'},
          ],
          'facilities': <Object?>[
            <String, Object?>{
              'id': 'FAC-1',
              'label': 'Main hospital',
              'meta': <String, Object?>{'facility_type': 'hospital'},
            },
          ],
            <String, Object?>{
              'id': 'BR-1',
              'label': 'Outpatient wing',
              'meta': <String, Object?>{'facility_id': 'FAC-1'},
            },
          ],
          'queue_types': <Object?>[
            <String, Object?>{'id': 'appointments', 'label': 'Appointments'},
          ],
          'date_presets': <Object?>[
            <String, Object?>{'id': 'today', 'label': 'Today'},
          ],
        },
      }).toEntity();

      expect(lookups.tenants.single.label, 'Demo tenant');
      expect(lookups.facilities.single.metaFacilityType, 'hospital');
      expect(
        lookups.branchesForFacility('FAC-1').single.label,
        'Outpatient wing',
      );
      expect(lookups.queueTypes.single.id, 'appointments');
      expect(lookups.datePresets.single.id, 'today');
    });
  });
}
