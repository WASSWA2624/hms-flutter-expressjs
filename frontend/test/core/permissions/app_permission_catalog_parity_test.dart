import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';

/// Canonical permission codes mirrored from `backend/src/config/permissions.js`.
const Set<String> _backendPermissionCodes = <String>{
  'profile:read',
  'profile:update',
  'patient:read',
  'patient:write',
  'patient:delete',
  'clinical:read',
  'clinical:write',
  'emergency:read',
  'emergency:write',
  'emergency:delete',
  'lab:read',
  'lab:write',
  'radiology:read',
  'radiology:write',
  'pharmacy:read',
  'pharmacy:write',
  'billing:read',
  'billing:write',
  'operations:read',
  'operations:write',
  'hr:read',
  'hr:write',
  'unit:read',
  'unit:manage',
  'roster:read',
  'roster:write',
  'roster:publish',
  'roster:approve',
  'biomed:read',
  'biomed:write',
  'mortuary:read',
  'mortuary:write',
  'mortuary:release',
  'mortuary:manage_storage',
  'mortuary:post_mortem_request',
  'mortuary:approve',
  'mortuary:billing_event',
  'mortuary:export',
  'mortuary:audit',
  'communications:read',
  'communications:write',
  'communications:delete',
  'integration:read',
  'integration:write',
  'integration:delete',
  'reports:read',
  'reports:write',
  'reports:delete',
  'subscriptions:read',
  'subscriptions:write',
  'subscriptions:delete',
  'last_office:read',
  'last_office:write',
  'last_office:approve',
  'compliance:read',
  'compliance:review',
  'break_glass:request',
  'break_glass:review',
  'break_glass:approve',
  'evidence:export',
  'financial:approve',
  'facility:admin',
  'tenant:admin',
  'system:admin',
};

void main() {
  group('AppPermissions catalog', () {
    test('matches backend PERMISSIONS codes exactly', () {
      final Set<String> frontendCodes = AppPermissions.all
          .map((AppPermission permission) => permission.value)
          .toSet();

      expect(frontendCodes, _backendPermissionCodes);
    });

    test('each catalog permission is an atomic domain:action key', () {
      for (final AppPermission permission in AppPermissions.all) {
        final List<String> parts = permission.value.split(':');
        expect(parts.length, 2, reason: permission.value);
        expect(parts[0], isNotEmpty, reason: permission.value);
        expect(parts[1], isNotEmpty, reason: permission.value);
      }
    });

    test('module-scoped domains remain mapped for attachable rights', () {
      const List<String> moduleScoped = <String>[
        'patient:read',
        'clinical:write',
        'lab:read',
        'radiology:write',
        'pharmacy:read',
        'billing:write',
        'hr:read',
        'roster:publish',
        'biomed:write',
        'mortuary:audit',
        'communications:delete',
        'integration:write',
        'reports:read',
        'subscriptions:write',
        'operations:read',
      ];

      for (final String code in moduleScoped) {
        expect(
          PermissionModuleMap.moduleForPermissionCode(code),
          isNotNull,
          reason: code,
        );
      }
    });
  });
}
