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
  AppAccessPolicy writePolicy() {
    return AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR']),
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      ),
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    required List<ClinicalRelatedRecord> orders,
    ClinicalOrderAction? onEdit,
    ClinicalOrderAction? onCancel,
    ClinicalOrderAction? onDelete,
    ClinicalLabOrderItemAction? onCancelItem,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appAccessPolicyProvider.overrideWithValue(writePolicy())],
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClinicalLabOrdersTablePanel(
                orders: orders,
                onEdit: onEdit ?? (_, __) async {},
                onCancel: onCancel ?? (_, __) async {},
                onDelete: onDelete ?? (_, __) async {},
                onCancelItem: onCancelItem,
                onCancelSelected: (_, __) async {},
                onDeleteSelected: (_, __) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows panel sections with Tests/Range/Result/Flag and no nested tables',
    (WidgetTester tester) async {
      await pumpPanel(
        tester,
        onCancelItem: (_, __, ___) async {},
        orders: <ClinicalRelatedRecord>[
          ClinicalRelatedRecord(
            id: 'LAB-1',
            kind: 'lab_order',
            status: 'ORDERED',
            title: 'Abdominal Pain Panel | ABDP',
            labOrderItems: <ClinicalLabOrderItem>[
              const ClinicalLabOrderItem(
                id: 'ITEM-1',
                status: 'ORDERED',
                testDisplayName: 'Amylase',
                testCode: 'AMY',
                panelDisplayName: 'Abdominal Pain Panel',
                panelCode: 'ABDP',
                panelId: 'PANEL-1',
                referenceRangeSummary: 'Adult | 25 - 125 U/L',
              ),
              const ClinicalLabOrderItem(
                id: 'ITEM-2',
                status: 'ORDERED',
                testDisplayName: 'Lipase',
                testCode: 'LIP',
                panelDisplayName: 'Abdominal Pain Panel',
                panelCode: 'ABDP',
                panelId: 'PANEL-1',
              ),
            ],
          ),
        ],
      );

      expect(find.text('Lab orders'), findsOneWidget);
      expect(find.text('Abdominal Pain Panel | ABDP'), findsOneWidget);
      expect(find.text('Tests'), findsOneWidget);
      expect(find.text('Range name'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Amylase | AMY'), findsOneWidget);
      expect(find.text('Lipase | LIP'), findsOneWidget);
      expect(find.text('Adult | 25 - 125 U/L'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Value'), findsNothing);
      expect(find.text('Arrival time'), findsNothing);
      expect(find.text('Unpaid'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.widgetWithText(AppButton, 'Cancel order'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Edit order'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel test'), findsNWidgets(2));
      expect(
        find.widgetWithText(AppButton, 'Cancel selected'),
        findsNothing,
      );
    },
  );

  testWidgets('hides cancel for completed orders and tests', (
    WidgetTester tester,
  ) async {
    await pumpPanel(
      tester,
      orders: <ClinicalRelatedRecord>[
        ClinicalRelatedRecord(
          id: 'LAB-2',
          kind: 'lab_order',
          status: 'COMPLETED',
          title: 'White Blood Cell Count | WBC',
          labOrderItems: <ClinicalLabOrderItem>[
            const ClinicalLabOrderItem(
              id: 'ITEM-3',
              status: 'COMPLETED',
              testDisplayName: 'White Blood Cell Count',
              testCode: 'WBC',
              resultValue: '14.8',
              resultUnit: 'x10^9/L',
              resultFlag: 'HIGH',
              referenceRangeSummary: 'Adult | 18 years+ | 4 - 11 x10^9/L',
            ),
          ],
        ),
      ],
    );

    expect(find.text('14.8 | x10^9/L'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel order'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Cancel test'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Edit order'), findsNothing);
  });
}
