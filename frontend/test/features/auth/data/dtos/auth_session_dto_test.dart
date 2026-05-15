import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_session_dto.dart';

void main() {
  test('maps user details from auth response payload', () {
    const payload = <String, Object?>{
      'access_token': 'header.payload.signature',
      'refresh_token': 'refresh-token',
      'user': <String, Object?>{
        'id': 'user-123',
        'human_friendly_id': 'USR-123',
        'email': 'admin@example.com',
        'phone': '+256700000000',
        'status': 'active',
        'position_title': 'tenant_admin',
        'permission_names': <String>['settings.read'],
        'module_subscriptions': <Object?>[
          <String, Object?>{
            'module_slug': 'clinical-care',
            'is_active': true,
            'evaluated_plan_fit_status': 'fit',
          },
          <String, Object?>{
            'module_slug': 'billing',
            'is_active': true,
            'entitlement_denied': true,
          },
        ],
        'profile': <String, Object?>{
          'first_name': 'Wilson',
          'middle_name': 'K',
          'last_name': 'Admin',
          'gender': 'male',
        },
        'tenant': <String, Object?>{'name': 'IHK Hospital'},
        'facility': <String, Object?>{
          'name': 'IHK Hospital',
          'facility_type': 'hospital',
        },
        'staff_profile': <String, Object?>{
          'staff_number': 'STF-001',
          'position': 'administrator',
          'practitioner_type': 'doctor',
        },
        'roles': <Object?>[
          <String, Object?>{
            'role': <String, Object?>{'name': 'tenant_admin'},
          },
        ],
      },
    };

    final session = AuthSessionDto.fromResponseData(payload).toEntity();
    final user = session.user;

    expect(user, isNotNull);
    expect(session.subject, 'admin@example.com');
    expect(session.permissions.map((permission) => permission.value), [
      'settings.read',
    ]);
    expect(session.moduleEntitlements['CLINICAL_CARE']?.isAvailable, isTrue);
    expect(session.moduleEntitlements['BILLING']?.isAvailable, isFalse);
    expect(user!.displayName, 'Wilson K Admin');
    expect(user.effectiveTitle, 'Administrator');
    expect(user.overallRole, 'Tenant Admin');
    expect(user.userType, 'Doctor');
    expect(user.tenantName, 'IHK Hospital');
    expect(user.facilityName, 'IHK Hospital');
    expect(user.staffNumber, 'STF-001');
  });
}
