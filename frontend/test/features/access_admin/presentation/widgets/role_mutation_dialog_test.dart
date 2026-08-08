import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows Platform / Tenant(s) / Facility(ies) radios for cross-tenant create',
    (WidgetTester tester) async {
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
                      allowPlatformScope: true,
                      allowTenantScope: true,
                      allowFacilityScope: true,
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
                      onSubmit: (List<AccessAdminRoleDraft> drafts) async =>
                          null,
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
        if (find.text('Platform').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('CREATE ROLE'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Tenant(s)'), findsOneWidget);
      expect(find.text('Facility(ies)'), findsOneWidget);
      expect(find.text('Entire organization'), findsNothing);
      expect(find.text('One facility'), findsNothing);
      expect(tenantLoadCount, 0);

      await tester.tap(find.text('Tenant(s)'));
      await tester.pump();
      for (int attempt = 0; attempt < 20; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
        if (tenantLoadCount > 0) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(tenantLoadCount, 1);
    },
  );

  testWidgets(
    'facility-only actor shows facility targets without Facility(ies) label',
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
                      mode: RoleMutationMode.create,
                      tenantId: 'tenant-1',
                      allowPlatformScope: false,
                      allowTenantScope: false,
                      allowFacilityScope: true,
                      allowTenantWideScope: false,
                      forceFacilityScope: true,
                      loadFacilityOptions: (_) async =>
                          const <AccessAdminLookupOption>[
                            AccessAdminLookupOption(
                              id: 'facility-1',
                              label: 'Main Campus',
                            ),
                          ],
                      onSubmit: (List<AccessAdminRoleDraft> drafts) async =>
                          null,
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

      expect(find.text('Facility(ies)'), findsNothing);
      expect(find.text('Platform'), findsNothing);
      expect(find.text('Tenant(s)'), findsNothing);
      expect(find.text('Main Campus'), findsOneWidget);
      expect(find.text('Entire organization'), findsNothing);
      expect(find.text('One facility'), findsNothing);
    },
  );

  testWidgets(
    'shows tenant guidance when create identity is blocked',
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
                      mode: RoleMutationMode.create,
                      allowPlatformScope: true,
                      allowTenantScope: true,
                      allowFacilityScope: true,
                      loadTenantOptions: () async =>
                          const <AccessAdminLookupOption>[
                            AccessAdminLookupOption(
                              id: 'tenant-1',
                              label: 'DemoCare General Hospital',
                            ),
                            AccessAdminLookupOption(
                              id: 'tenant-2',
                              label: 'Second Care',
                            ),
                          ],
                      onSubmit: (List<AccessAdminRoleDraft> drafts) async =>
                          null,
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

      await tester.tap(find.text('Tenant(s)'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Select at least one tenant before entering role details.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'edit mode uses Platform/Tenant/Facility scope radios and omits permissions',
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
                      allowPlatformScope: true,
                      allowTenantScope: true,
                      allowFacilityScope: true,
                      tenantId: 'tenant-1',
                      initialName: 'JOKING',
                      initialDisplayName: 'Joking',
                      initialDescription: 'Joking',
                      loadTenantOptions: () async {
                        return const <AccessAdminLookupOption>[
                          AccessAdminLookupOption(
                            id: 'tenant-1',
                            label: 'DemoCare General Hospital',
                          ),
                        ];
                      },
                      onSubmit: (List<AccessAdminRoleDraft> drafts) async =>
                          null,
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

      expect(find.text('EDIT ROLE'), findsOneWidget);
      expect(find.text('Permissions'), findsNothing);
      expect(find.text('Entire organization'), findsNothing);
      expect(find.text('One facility'), findsNothing);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Tenant(s)'), findsOneWidget);
      expect(find.text('Facility(ies)'), findsOneWidget);
      expect(find.text('JOKING'), findsWidgets);
      expect(find.text('Joking'), findsWidgets);
      expect(find.textContaining('Role name'), findsWidgets);
      expect(find.textContaining('Display name'), findsWidgets);
    },
  );

  testWidgets('create mode omits permissions and marks display name required', (
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
                    includePermissions: false,
                    allowPlatformScope: false,
                    allowTenantScope: true,
                    allowFacilityScope: true,
                    onSubmit: (List<AccessAdminRoleDraft> drafts) async => null,
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

    expect(find.text('CREATE ROLE'), findsOneWidget);
    expect(find.text('Permissions'), findsNothing);
    expect(find.textContaining('Display name'), findsWidgets);
    expect(find.textContaining('Role name'), findsWidgets);
  });
}
