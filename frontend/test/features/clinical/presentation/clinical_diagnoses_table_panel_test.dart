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
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

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
    required List<ClinicalRelatedRecord> diagnoses,
    ClinicalOrderAction? onRemove,
    ClinicalOrderBatchAction? onRemoveSelected,
    ClinicalOrderBatchAction? onEditSelected,
    VoidCallback? onAdd,
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
            body: ClinicalDiagnosesTablePanel(
              diagnoses: diagnoses,
              onRemove: onRemove ?? (_, __) async {},
              onRemoveSelected: onRemoveSelected,
              onEditSelected: onEditSelected,
              onAdd: onAdd ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows bordered section with Add and Edit in header',
    (WidgetTester tester) async {
      var addTapped = false;
      await pumpPanel(
        tester,
        onAdd: () => addTapped = true,
        onEditSelected: (_, __) async {},
        diagnoses: <ClinicalRelatedRecord>[
          ClinicalRelatedRecord(
            id: '11111111-1111-4111-8111-111111111111',
            kind: 'diagnosis',
            title: 'Malaria',
            diagnosisType: 'PRIMARY',
            code: 'B54',
            status: 'ACTIVE',
            occurredAt: DateTime(2026, 7, 28, 10),
          ),
          ClinicalRelatedRecord(
            id: '22222222-2222-4222-8222-222222222222',
            kind: 'diagnosis',
            title: 'Typhoid fever',
            diagnosisType: 'SECONDARY',
            code: 'A01.0',
          ),
        ],
      );

      expect(find.text('Patient diagnoses'), findsOneWidget);
      expect(find.text('Malaria - Primary | B54'), findsOneWidget);
      expect(find.text('Typhoid fever - Secondary | A01.0'), findsOneWidget);
      expect(find.text('Status'), findsNothing);
      expect(find.text('Arrival'), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(AppCollapsibleSection), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Remove'), findsNWidgets(2));
      expect(find.widgetWithText(AppButton, 'Add'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Remove selected'), findsNothing);

      final AppCollapsibleSection section = tester.widget(
        find.byType(AppCollapsibleSection),
      );
      expect(section.contentPadding, isNull);
      expect(section.headerActions, isNotEmpty);
      expect(section.actions, isEmpty);

      final AppButton addButton = tester.widget(
        find.widgetWithText(AppButton, 'Add'),
      );
      expect(addButton.leadingIcon, AppActionIcons.add);
      final AppButton editButton = tester.widget(
        find.widgetWithText(AppButton, 'Edit'),
      );
      expect(editButton.leadingIcon, AppActionIcons.edit);
      expect(editButton.onPressed, isNull);

      await tester.tap(find.widgetWithText(AppButton, 'Add'));
      await tester.pumpAndSettle();
      expect(addTapped, isTrue);
    },
  );

  testWidgets(
    'puts Remove selected in the header when rows are checked',
    (WidgetTester tester) async {
      List<ClinicalRelatedRecord>? removed;
      List<ClinicalRelatedRecord>? edited;

      await pumpPanel(
        tester,
        onEditSelected: (_, List<ClinicalRelatedRecord> selected) async {
          edited = selected;
        },
        onRemoveSelected: (_, List<ClinicalRelatedRecord> selected) async {
          removed = selected;
        },
        diagnoses: <ClinicalRelatedRecord>[
          ClinicalRelatedRecord(
            id: '33333333-3333-4333-8333-333333333333',
            kind: 'diagnosis',
            title: 'Pneumonia',
            diagnosisType: 'DIFFERENTIAL',
            code: 'J18.9',
          ),
        ],
      );

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Remove selected'), findsOneWidget);

      final AppButton removeSelected = tester.widget(
        find.widgetWithText(AppButton, 'Remove selected'),
      );
      expect(removeSelected.leadingIcon, AppActionIcons.delete);

      final AppButton editButton = tester.widget(
        find.widgetWithText(AppButton, 'Edit'),
      );
      expect(editButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(AppButton, 'Edit'));
      await tester.pumpAndSettle();
      expect(edited!.single.id, '33333333-3333-4333-8333-333333333333');

      await tester.tap(find.widgetWithText(AppButton, 'Remove selected'));
      await tester.pumpAndSettle();
      expect(removed!.single.id, '33333333-3333-4333-8333-333333333333');
    },
  );

  testWidgets('Remove action passes the diagnosis UUID', (
    WidgetTester tester,
  ) async {
    String? removedId;

    await pumpPanel(
      tester,
      diagnoses: <ClinicalRelatedRecord>[
        ClinicalRelatedRecord(
          id: '44444444-4444-4444-8444-444444444444',
          kind: 'diagnosis',
          title: 'Asthma',
          diagnosisType: 'PRIMARY',
          code: 'J45',
        ),
      ],
      onRemove: (_, ClinicalRelatedRecord diagnosis) async {
        removedId = diagnosis.id;
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(removedId, '44444444-4444-4444-8444-444444444444');
  });
}
