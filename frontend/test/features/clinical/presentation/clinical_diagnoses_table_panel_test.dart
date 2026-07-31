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
    required List<ClinicalRelatedRecord> diagnoses,
    ClinicalOrderAction? onRemove,
    ClinicalOrderBatchAction? onEditSelected,
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
              onEditSelected: onEditSelected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows flat humanized diagnosis rows without Status or Arrival columns',
    (WidgetTester tester) async {
      await pumpPanel(
        tester,
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
      expect(find.widgetWithText(AppButton, 'Remove'), findsNWidgets(2));
      expect(find.widgetWithText(AppButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Delete'), findsNothing);
    },
  );

  testWidgets('Edit is enabled after selecting a diagnosis row', (
    WidgetTester tester,
  ) async {
    List<ClinicalRelatedRecord>? edited;

    await pumpPanel(
      tester,
      diagnoses: <ClinicalRelatedRecord>[
        ClinicalRelatedRecord(
          id: '33333333-3333-4333-8333-333333333333',
          kind: 'diagnosis',
          title: 'Pneumonia',
          diagnosisType: 'DIFFERENTIAL',
          code: 'J18.9',
        ),
      ],
      onEditSelected: (_, List<ClinicalRelatedRecord> selected) async {
        edited = selected;
      },
    );

    final AppButton editButton = tester.widget(
      find.widgetWithText(AppButton, 'Edit'),
    );
    expect(editButton.onPressed, isNull);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.single.id, '33333333-3333-4333-8333-333333333333');
    expect(edited!.single.diagnosisType, 'DIFFERENTIAL');
  });

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
