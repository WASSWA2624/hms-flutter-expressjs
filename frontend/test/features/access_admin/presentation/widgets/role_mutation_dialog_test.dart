import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('requests tenant options when tenant picker is required', (
    WidgetTester tester,
  ) async {
    int tenantLoadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                unawaited(
                  showRoleMutationDialog(
                    context: context,
                    mode: RoleMutationMode.create,
                    requireTenantPicker: true,
                    loadTenantOptions: () async {
                      tenantLoadCount += 1;
                      return const <AccessAdminLookupOption>[
                        AccessAdminLookupOption(
                          id: 'tenant-1',
                          label: 'DemoCare General Hospital',
                        ),
                      ];
                    },
                    loadPermissionsForTenant: (_) async =>
                        const <AccessAdminLookupOption>[],
                    onSubmit: (_) async => null,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    for (int attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tenantLoadCount > 0) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(tenantLoadCount, 1);
    expect(find.text('CREATE ROLE'), findsOneWidget);
  });
}
