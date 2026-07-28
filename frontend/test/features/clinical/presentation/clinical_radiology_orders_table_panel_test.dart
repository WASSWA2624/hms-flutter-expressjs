import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'radiology orders panel fills width, shows labeled actions, and supports batch select in header',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      List<ClinicalRelatedRecord>? cancelledBatch;

      final List<ClinicalRelatedRecord> orders = <ClinicalRelatedRecord>[
        ClinicalRelatedRecord(
          id: 'rad-1',
          kind: 'RADIOLOGY_ORDER',
          status: 'ORDERED',
          occurredAt: DateTime(2026, 7, 28, 15, 25),
          title: 'Abdomen ultrasound',
          radiologyOrderItems: const <ClinicalRadiologyOrderItem>[
            ClinicalRadiologyOrderItem(
              id: 'item-1',
              testDisplayName: 'Abdomen ultrasound',
              modality: 'ULTRASOUND',
              bodyRegion: 'Abdomen',
            ),
          ],
        ),
        ClinicalRelatedRecord(
          id: 'rad-2',
          kind: 'RADIOLOGY_ORDER',
          status: 'CANCELLED',
          occurredAt: DateTime(2026, 7, 23, 21, 26),
          title: 'Pelvis ultrasound',
          radiologyOrderItems: const <ClinicalRadiologyOrderItem>[
            ClinicalRadiologyOrderItem(
              id: 'item-2',
              testDisplayName: 'Pelvis ultrasound',
              modality: 'ULTRASOUND',
              bodyRegion: 'Pelvis',
            ),
          ],
        ),
      ];

      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appAccessPolicyProvider.overrideWithValue(policy)],
          child: MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ClinicalRadiologyOrdersTablePanel(
                orders: orders,
                onCancel: (_, __) async {},
                onDelete: (_, __) async {},
                onCancelSelected:
                    (_, List<ClinicalRelatedRecord> selected) async {
                      cancelledBatch = selected;
                    },
                onDeleteSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abdomen ultrasound'), findsOneWidget);
      expect(find.text('Pelvis ultrasound'), findsOneWidget);
      expect(find.text('Radiology orders'), findsOneWidget);

      // Ordered rows expose labeled cancel; cancelled rows expose labeled delete.
      expect(find.widgetWithText(AppButton, 'Cancel order'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Delete order'), findsOneWidget);

      final double tableWidth = tester.getSize(find.byType(DataTable)).width;
      expect(tableWidth, greaterThan(900));

      // Header checkbox + 2 row checkboxes.
      expect(find.byType(Checkbox), findsNWidgets(3));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Cancel selected'));
      await tester.pumpAndSettle();
      expect(cancelledBatch?.map((e) => e.id), <String>['rad-1']);
    },
  );
}
