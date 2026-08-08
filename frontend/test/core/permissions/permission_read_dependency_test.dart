import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/permission_read_dependency.dart';

void main() {
  group('permission_read_dependency', () {
    test('requires matching read for non-read actions when catalog has it', () {
      expect(
        requiredReadPermissionFor(
          'billing:write',
          catalogCodes: const <String>['billing:read', 'billing:write'],
        ),
        'billing:read',
      );
      expect(
        requiredReadPermissionFor(
          'platform:admin',
          catalogCodes: const <String>['platform:admin'],
        ),
        isNull,
      );
      expect(requiredReadPermissionFor('billing:read'), isNull);
    });

    test('expand adds missing reads', () {
      expect(
        expandPermissionCodesWithRequiredReads(
          const <String>['billing:write'],
          catalogCodes: const <String>['billing:read', 'billing:write'],
        ),
        <String>{'billing:write', 'billing:read'},
      );
    });

    test('cannot deselect read while sibling actions remain', () {
      expect(
        canDeselectPermissionCode(
          'billing:read',
          selectedCodes: const <String>['billing:read', 'billing:write'],
          catalogCodes: const <String>['billing:read', 'billing:write'],
        ),
        isFalse,
      );
      expect(
        canDeselectPermissionCode(
          'billing:write',
          selectedCodes: const <String>['billing:read', 'billing:write'],
          catalogCodes: const <String>['billing:read', 'billing:write'],
        ),
        isTrue,
      );
    });
  });
}
