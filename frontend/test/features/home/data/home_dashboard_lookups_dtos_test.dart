import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/home/data/dtos/home_dashboard_lookups_dtos.dart';

void main() {
  group('HomeDashboardLookupsDto', () {
    test('parses tenants, facilities, and filter lookups', () {
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
      expect(lookups.queueTypes.single.id, 'appointments');
      expect(lookups.datePresets.single.id, 'today');
    });
  });
}
