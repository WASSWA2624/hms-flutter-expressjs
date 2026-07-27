import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

import '../../../helpers/test_harness.dart';

void main() {
  testWidgets('permission details dialog is read-only', (
    WidgetTester tester,
  ) async {
    const AccessAdminItem permission = AccessAdminItem(
      id: 'perm-1',
      resource: AccessAdminResource.permissions,
      displayId: 'PERM-001',
      title: 'Patient read',
      subtitle: 'View patient records',
      permissionName: 'patient:read',
      status: 'active',
    );

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return TextButton(
            onPressed: () {
              showAccessAdminPermissionDetailDialog(
                context,
                permission: permission,
              );
            },
            child: const Text('Open'),
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('PERMISSION DETAILS'), findsOneWidget);
    expect(find.text('PERM-001'), findsOneWidget);
    expect(find.text('Patient read'), findsOneWidget);
    expect(find.text('View patient records'), findsOneWidget);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.text('PERMISSION DETAILS')),
    )!;
    expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
    expect(find.text(l10n.tenantFacilityEditAction), findsNothing);
    expect(find.text(l10n.tenantFacilityDeleteAction), findsNothing);
    expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
  });
}
