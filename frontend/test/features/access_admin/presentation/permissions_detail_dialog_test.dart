import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../../helpers/test_harness.dart';

void main() {
  testWidgets('permission details show machine code and catalog description', (
    WidgetTester tester,
  ) async {
    const AccessAdminItem permission = AccessAdminItem(
      id: 'perm-1',
      resource: AccessAdminResource.permissions,
      displayId: 'PERM-001',
      title: 'Patient — Read',
      permissionName: 'patient:read',
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
    expect(find.text('Patient — Read'), findsOneWidget);
    expect(find.text('patient:read'), findsAtLeastNWidgets(1));
    expect(find.text('Allows read access within patient.'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.text('PERMISSION DETAILS')),
    )!;
    expect(find.text(l10n.accessAdminStatusLabel), findsNothing);
    expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
    expect(find.text(l10n.tenantFacilityEditAction), findsNothing);
    expect(find.text(l10n.tenantFacilityDeleteAction), findsNothing);
  });

  testWidgets('permission details prefer API description over catalog', (
    WidgetTester tester,
  ) async {
    const AccessAdminItem permission = AccessAdminItem(
      id: 'perm-2',
      resource: AccessAdminResource.permissions,
      displayId: 'PERM-002',
      title: 'Patient — Read',
      subtitle: 'View patient records from the registry.',
      permissionName: 'patient:read',
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

    expect(find.text('View patient records from the registry.'), findsOneWidget);
    expect(find.text('Allows read access within patient.'), findsNothing);
    expect(find.text('patient:read'), findsAtLeastNWidgets(1));
  });
}
