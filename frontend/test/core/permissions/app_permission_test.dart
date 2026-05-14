import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

void main() {
  group('AppPermissionGrant', () {
    const usersReadPermission = AppPermission('users.read');
    const reportsReadPermission = AppPermission('reports.read');

    test('centralizes all and any permission checks', () {
      final grant = AppPermissionGrant(<AppPermission>{usersReadPermission});

      expect(grant.grants(usersReadPermission), isTrue);
      expect(grant.grants(reportsReadPermission), isFalse);
      expect(grant.grantsAll(<AppPermission>{usersReadPermission}), isTrue);
      expect(
        grant.grantsAll(<AppPermission>{
          usersReadPermission,
          reportsReadPermission,
        }),
        isFalse,
      );
      expect(
        grant.grantsAny(<AppPermission>{
          usersReadPermission,
          reportsReadPermission,
        }),
        isTrue,
      );
    });

    test('compares grants by permission values', () {
      final firstGrant = AppPermissionGrant(<AppPermission>{
        usersReadPermission,
        reportsReadPermission,
      });
      final secondGrant = AppPermissionGrant(<AppPermission>{
        reportsReadPermission,
        usersReadPermission,
      });

      expect(firstGrant, secondGrant);
      expect(firstGrant.hashCode, secondGrant.hashCode);
    });
  });
}
