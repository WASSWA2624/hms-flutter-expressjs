import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Staff account permanent delete wiring', () {
    late String repositoryInterfaceSource;
    late String repositoryImplSource;
    late String managementDialogsSource;
    late String facilityDialogsSource;

    setUpAll(() {
      repositoryInterfaceSource = File(
        'lib/features/access_admin/domain/repositories/access_admin_repository.dart',
      ).readAsStringSync();
      repositoryImplSource = File(
        'lib/features/access_admin/data/repositories/access_admin_repository_impl.dart',
      ).readAsStringSync();
      managementDialogsSource = File(
        'lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart',
      ).readAsStringSync();
      facilityDialogsSource = File(
        'lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart',
      ).readAsStringSync();
    });

    test('repository exposes soft delete, restore and permanent delete', () {
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<void>> deleteUser(String userId);',
        ),
        isTrue,
      );
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<void>> restoreUser(String userId);',
        ),
        isTrue,
      );
      expect(
        repositoryInterfaceSource.contains(
          'Future<Result<void>> permanentDeleteUser(String userId);',
        ),
        isTrue,
      );
    });

    test('permanent delete calls the users permanent endpoint', () {
      final int start = repositoryImplSource.indexOf(
        'Future<Result<void>> permanentDeleteUser(String userId)',
      );
      expect(start, greaterThanOrEqualTo(0));
      final String body = repositoryImplSource.substring(start, start + 400);

      expect(body.contains('_apiClient.delete<void>'), isTrue);
      expect(body.contains('HmsApiResource.users'), isTrue);
      expect(body.contains("'permanent'"), isTrue);
    });

    test('purge is gated on a soft-deleted, mutable account', () {
      final int start = managementDialogsSource.indexOf(
        'bool canPermanentDeleteAccessAdminUser(',
      );
      expect(start, greaterThanOrEqualTo(0));
      final int end = managementDialogsSource.indexOf(
        'Future<bool> confirmPermanentDeleteAccessAdminUser(',
      );
      expect(end, greaterThan(start));
      final String body = managementDialogsSource.substring(start, end);

      expect(body.contains('!user.isDeleted'), isTrue);
      expect(body.contains('canMutateAccessAdminDemoAccount(user)'), isTrue);
      expect(body.contains('canWriteAccessAdmin(policy)'), isTrue);
      expect(body.contains('!user.isSystemCritical'), isTrue);
    });

    test('purge asks the admin to type the account name first', () {
      final int start = managementDialogsSource.indexOf(
        'Future<bool> confirmPermanentDeleteAccessAdminUser(',
      );
      expect(start, greaterThanOrEqualTo(0));
      final String body = managementDialogsSource.substring(start, start + 3000);

      expect(body.contains('AppTextInputActionDialog'), isTrue);
      expect(body.contains('confirmMatches:'), isTrue);
      expect(
        body.contains('accessAdminPermanentDeleteUserWarningBody'),
        isTrue,
      );
      expect(
        body.contains('accessAdminPermanentDeleteUserConfirmationBody'),
        isTrue,
      );
      expect(body.contains('repository.permanentDeleteUser'), isTrue);
    });

    test('deleted rows offer restore and permanent delete', () {
      expect(
        managementDialogsSource.contains('_confirmPermanentDeleteUser(user)'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('Icons.delete_forever_outlined'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains(
          'l10n.tenantFacilityPermanentDeleteAction',
        ),
        isTrue,
      );
    });

    test('facility details users panel reuses the shared purge flow', () {
      expect(facilityDialogsSource.contains('onPermanentDelete:'), isTrue);
      expect(
        facilityDialogsSource.contains(
          'confirmPermanentDeleteAccessAdminUser(',
        ),
        isTrue,
      );
      expect(
        facilityDialogsSource.contains('canPermanentDeleteAccessAdminUser('),
        isTrue,
      );
    });
  });
}
