import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/data/dtos/tenant_facility_dtos.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  group('Tenant facility DTOs', () {
    test('parses workspace setup payload with subscription summary', () {
      final FacilitySetupSnapshot snapshot =
          FacilitySetupWorkspaceDto.fromResponse(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'tenant': <String, Object?>{
                'id': 'TEN0001',
                'name': 'Acme Hospital',
                'slug': 'acme',
                'is_active': true,
              },
              'facility': <String, Object?>{
                'id': 'FAC0001',
                'tenant_id': 'TEN0001',
                'name': 'Main Campus',
                'facility_type': 'HOSPITAL',
                'is_active': true,
                'extension_json': <String, Object?>{
                  'logo_url': 'https://example.com/logo.png',
                },
              },
              'facilities': <Object?>[
                <String, Object?>{
                  'id': 'FAC0001',
                  'tenant_id': 'TEN0001',
                  'name': 'Main Campus',
                  'facility_type': 'HOSPITAL',
                  'is_active': true,
                },
              ],
              'contact_address': <String, Object?>{
                'phone': '+256700000000',
                'email': 'info@acme.test',
                'address_line1': 'Plot 1 Hospital Road',
                'city': 'Kampala',
                'country': 'UG',
              },
                <String, Object?>{
                  'id': 'BRN0001',
                  'tenant_id': 'TEN0001',
                  'facility_id': 'FAC0001',
                  'name': 'North Wing',
                  'is_active': true,
                },
              ],
              'departments': <Object?>[
                <String, Object?>{
                  'id': 'DEP0001',
                  'tenant_id': 'TEN0001',
                  'facility_id': 'FAC0001',
                  'name': 'Internal Medicine',
                  'department_type': 'CLINICAL',
                  'is_active': true,
                },
              ],
              'units': <Object?>[
                <String, Object?>{
                  'id': 'UNT0001',
                  'tenant_id': 'TEN0001',
                  'facility_id': 'FAC0001',
                  'department_id': 'DEP0001',
                  'name': 'OPD Clinic',
                  'is_active': true,
                },
              ],
              'wards': <Object?>[
                <String, Object?>{
                  'id': 'WRD0001',
                  'tenant_id': 'TEN0001',
                  'facility_id': 'FAC0001',
                  'name': 'General Ward',
                  'ward_type': 'GENERAL',
                  'is_active': true,
                },
              ],
              'rooms': const <Object?>[],
              'beds': <Object?>[
                <String, Object?>{
                  'id': 'BED0001',
                  'tenant_id': 'TEN0001',
                  'facility_id': 'FAC0001',
                  'ward_id': 'WRD0001',
                  'label': 'A1',
                  'status': 'AVAILABLE',
                },
              ],
              'subscription_summary': <String, Object?>{
                'plan_label': 'Premium',
                'status': 'ACTIVE',
                'active_modules_count': 4,
                'subscription_id': 'SUB0001',
              },
              'permissions': <String, Object?>{
                'can_manage_tenant': true,
                'can_manage_facility': true,
                'can_view_subscriptions': true,
              },
            },
          }).toEntity();

      expect(snapshot.tenant?.name, 'Acme Hospital');
      expect(snapshot.facility?.name, 'Main Campus');
      expect(snapshot.branches, hasLength(1));
      expect(snapshot.departments, hasLength(1));
      expect(snapshot.units, hasLength(1));
      expect(snapshot.wards, hasLength(1));
      expect(snapshot.beds, hasLength(1));
      expect(snapshot.contactAddress.phone, '+256700000000');
      expect(snapshot.subscriptionSummary?.planLabel, 'Premium');
      expect(snapshot.subscriptionSummary?.activeModulesCount, 4);
      expect(snapshot.permissions.canManageTenant, isTrue);
      expect(snapshot.completedChecklistItems, 8);
    });
  });
}
