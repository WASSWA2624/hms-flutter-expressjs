import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
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
                    loadPermissionsForTenant:
                        ({
                          required String tenantId,
                          String? facilityId,
                        }) async =>
                            const Result<List<AccessAdminLookupOption>>.success(
                              <AccessAdminLookupOption>[],
                            ),
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
    expect(find.text('Entire organization'), findsOneWidget);
    expect(find.text('One facility'), findsOneWidget);
  });

  testWidgets('forces facility scope when tenant-wide is not allowed', (
    WidgetTester tester,
  ) async {
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
                    tenantId: 'tenant-1',
                    allowTenantWideScope: false,
                    forceFacilityScope: true,
                    loadFacilityOptions: (_) async =>
                        const <AccessAdminLookupOption>[
                          AccessAdminLookupOption(
                            id: 'facility-1',
                            label: 'Main Campus',
                          ),
                        ],
                    loadPermissionsForTenant:
                        ({
                          required String tenantId,
                          String? facilityId,
                        }) async =>
                            const Result<List<AccessAdminLookupOption>>.success(
                              <AccessAdminLookupOption>[
                                AccessAdminLookupOption(
                                  id: 'perm-1',
                                  label: 'patient:read',
                                ),
                              ],
                            ),
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
    await tester.pumpAndSettle();

    expect(find.text('One facility'), findsOneWidget);
    expect(find.text('Main Campus'), findsOneWidget);
  });

  testWidgets(
    'edit mode keeps attached permissions selected after lookup load',
    (WidgetTester tester) async {
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
                      mode: RoleMutationMode.edit,
                      tenantId: 'tenant-1',
                      initialName: 'All rights',
                      initialDescription: 'Full access',
                      initialPermissionIds: const <String>{
                        'PRM0001',
                        'PRM0002',
                      },
                      permissionLookups: const <AccessAdminLookupOption>[
                        AccessAdminLookupOption(
                          id: 'PRM0001',
                          label: 'patient:read',
                        ),
                        AccessAdminLookupOption(
                          id: 'PRM0002',
                          label: 'patient:write',
                        ),
                        AccessAdminLookupOption(
                          id: 'PRM0003',
                          label: 'billing:read',
                        ),
                      ],
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
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('2 of 3 selected'), findsWidgets);
    },
  );
}
