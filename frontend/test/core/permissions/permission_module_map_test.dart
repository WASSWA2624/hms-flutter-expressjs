import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';

void main() {
  group('PermissionModuleMap', () {
    test('maps module-scoped permission domains', () {
      expect(
        PermissionModuleMap.moduleForPermission(
          const AppPermission('lab:read'),
        ),
        'lab-workflows',
      );
      expect(
        PermissionModuleMap.moduleForPermissionCode('patient:write'),
        'patient-registry',
      );
      expect(
        PermissionModuleMap.moduleForPermissionCode('billing:read'),
        'billing-payments',
      );
    });

    test('leaves core and platform permissions unmapped', () {
      expect(
        PermissionModuleMap.moduleForPermissionCode('profile:read'),
        isNull,
      );
      expect(
        PermissionModuleMap.moduleForPermissionCode('tenant:admin'),
        isNull,
      );
      expect(
        PermissionModuleMap.moduleForPermissionCode('system:admin'),
        isNull,
      );
    });
  });
}
