import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTenantFacilityRepository extends Mock
    implements TenantFacilityRepository {}

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const FacilityProfile _facility = FacilityProfile(
  id: 'facility-1',
  tenantId: 'tenant-1',
  name: 'DemoCare General Hospital',
  type: FacilitySetupType.hospital,
  displayId: 'FAC-DEMO',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const AccessAdminWorkspaceQuery());
  });

  testWidgets('facility row details dialog renders above its modal barrier', (
    WidgetTester tester,
  ) async {
    final _MockTenantFacilityRepository tenantRepository =
        _MockTenantFacilityRepository();
    final _MockAccessAdminRepository accessRepository =
        _MockAccessAdminRepository();
    when(
      () => tenantRepository.getFacility(any()),
    ).thenAnswer((_) async => const Result<FacilityProfile>.success(_facility));
    when(
      () => tenantRepository.loadSetup(
        facilityId: any(named: 'facilityId'),
        tenantId: any(named: 'tenantId'),
        includeDeleted: any(named: 'includeDeleted'),
        includeStructure: any(named: 'includeStructure'),
      ),
    ).thenAnswer(
      (_) async => const Result<FacilitySetupSnapshot>.success(
        FacilitySetupSnapshot(facility: _facility),
      ),
    );
    when(() => accessRepository.getWorkspace(any())).thenAnswer(
      (_) async => const Result<AccessAdminWorkspaceData>.success(
        AccessAdminWorkspaceData(
          items: <AccessAdminItem>[],
          page: AppPage<AccessAdminItem>(
            items: <AccessAdminItem>[],
            request: AppPageRequest(pageSize: 12),
            totalItemCount: 0,
          ),
          query: AccessAdminWorkspaceQuery(),
        ),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['PLATFORM_ADMIN'],
        ),
        isAuthorizationHydrated: true,
      ),
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantFacilityRepositoryProvider.overrideWithValue(tenantRepository),
          accessAdminRepositoryProvider.overrideWithValue(accessRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(policy),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return TextButton(
                  onPressed: () => showFacilityDetailsDialog(
                    context,
                    facility: _facility,
                    tenantName: 'DemoCare Tenant',
                  ),
                  child: const Text('Open facility'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open facility'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('FACILITY DETAILS'), findsOneWidget);
    expect(find.text('DemoCare General Hospital'), findsOneWidget);
    expect(find.text('Users'), findsWidgets);
  });
}
