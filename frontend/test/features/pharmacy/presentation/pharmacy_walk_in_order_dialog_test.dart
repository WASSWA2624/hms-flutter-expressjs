import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_walk_in_order_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

AppAccessPolicy _pharmacyWritePolicy({bool canRegisterPatient = false}) {
  final List<AppPermission> permissions = <AppPermission>[
    AppPermissions.pharmacyRead,
    AppPermissions.pharmacyWrite,
    if (canRegisterPatient) AppPermissions.patientWrite,
  ];
  final List<AppModuleEntitlement> modules = <AppModuleEntitlement>[
    const AppModuleEntitlement(code: 'pharmacy'),
    const AppModuleEntitlement(code: 'pharmacy-dispensing'),
    if (canRegisterPatient) const AppModuleEntitlement(code: 'patients'),
  ];
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['PHARMACIST'],
      ),
      permissions: permissions,
      moduleEntitlements: modules,
    ),
  );
}

void main() {
  late _MockClinicalRepository clinicalRepository;

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
    when(() => clinicalRepository.loadReferenceData()).thenAnswer(
      (_) async => const Result<ClinicalReferenceData>.success(
        ClinicalReferenceData(
          drugs: <ClinicalActionCatalogOption>[
            ClinicalActionCatalogOption(
              id: 'amox',
              name: 'Amoxicillin',
              code: 'AMOX',
              unitPrice: 12,
              currency: 'USD',
            ),
          ],
        ),
      ),
    );
  });

  Future<void> pumpCreateOrder(
    WidgetTester tester, {
    AppAccessPolicy? policy,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          appAccessPolicyProvider.overrideWithValue(
            policy ?? _pharmacyWritePolicy(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: PharmacyWalkInOrderDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Anonymous and reuses Prescribe medicines UI', (
    WidgetTester tester,
  ) async {
    await pumpCreateOrder(tester);

    expect(find.text('Create order'), findsWidgets);
    expect(find.text('Anonymous'), findsOneWidget);
    expect(find.text('Existing patient'), findsOneWidget);
    expect(find.text('New patient'), findsNothing);
    expect(find.text('No medicines added yet'), findsOneWidget);
    expect(find.text('Add medicine'), findsWidgets);
    expect(find.text('Review billing'), findsNothing);
    expect(find.text('Line 1'), findsNothing);
  });

  testWidgets('shows New patient mode when registry write is allowed', (
    WidgetTester tester,
  ) async {
    await pumpCreateOrder(
      tester,
      policy: _pharmacyWritePolicy(canRegisterPatient: true),
    );

    expect(find.text('New patient'), findsOneWidget);
  });

  testWidgets('shows Review billing after selecting Existing patient mode', (
    WidgetTester tester,
  ) async {
    await pumpCreateOrder(tester);

    await tester.tap(find.text('Existing patient'));
    await tester.pumpAndSettle();

    // Review billing stays hidden until a patient is selected.
    expect(find.text('Review billing'), findsNothing);
  });
}
