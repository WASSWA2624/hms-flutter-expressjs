import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_configuration_section.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

void main() {
  test(
    'feature helpers match Configuration matrix ∩ / ∪ and source panel gates',
    () {
      expect(
        settingsConfigurationReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileRead],
      );
      expect(
        settingsConfigurationReadRequirement.anyPermissions,
        settingsAdminAnyPermissions,
      );
      expect(
        settingsConfigurationCreateRequirement.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        settingsConfigurationUpdateRequirement.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        settingsConfigurationDeleteRequirement.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      // Source panel gates (documented mapping vs matrix update ∩).
      expect(
        settingsConfigurationTenantRequirement.anyPermissions,
        <AppPermission>[
          AppPermissions.tenantAdmin,
          AppPermissions.platformAdmin,
        ],
      );
      expect(
        settingsConfigurationFacilityRequirement.anyPermissions,
        contains(AppPermissions.facilityAdmin),
      );
      expect(
        SettingsConfigurationAtomPermissions.tab,
        same(settingsConfigurationReadRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.tenantSave,
        same(settingsConfigurationTenantRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.facilitySave,
        same(settingsConfigurationFacilityRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.create,
        same(settingsFacilityAdminRequirement),
      );
    },
  );

  test(
    'settingsConfigurationSectionVisible requires read ∩ and a panel',
    () {
      final AppAccessPolicy missingRead = _policy(
        permissions: <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(settingsConfigurationSectionVisible(missingRead), isFalse);

      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>[AppPermissions.profileRead],
      );
      expect(settingsConfigurationSectionVisible(readOnly), isFalse);

      final AppAccessPolicy facilityUnion = _policy(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
      );
      expect(settingsConfigurationSectionVisible(facilityUnion), isTrue);

      final AppAccessPolicy noFacilityContext = _policy(
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        facilityId: null,
      );
      expect(settingsConfigurationSectionVisible(noFacilityContext), isFalse);
    },
  );

  testWidgets(
    'configuration strip absent without profile:read (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.facilityAdmin,
          AppPermissions.tenantAdmin,
        ],
      );

      expect(find.text('Configuration'), findsNothing);
      expect(find.text('Tenant defaults'), findsNothing);
      expect(find.text('Facility defaults'), findsNothing);
      expect(find.text('Save configuration'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Access denied'), findsNothing);
    },
  );

  testWidgets(
    'configuration strip absent with profile:read but no admin ∪ key',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
      );

      expect(find.text('Configuration'), findsNothing);
      expect(find.text('Tenant defaults'), findsNothing);
      expect(find.text('Facility defaults'), findsNothing);
    },
  );

  testWidgets(
    'facility:admin ∪ allowance mounts facility panel without tenant panel',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
      );

      expect(find.text('Configuration'), findsWidgets);
      expect(find.text('Facility defaults'), findsOneWidget);
      expect(find.text('Tenant defaults'), findsNothing);
      expect(find.text('Save configuration'), findsOneWidget);
      expect(find.text('Reset to default'), findsOneWidget);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'tenant:admin ∪ mounts tenant and facility panels',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
        ],
      );

      expect(find.text('Configuration'), findsWidgets);
      expect(find.text('Tenant defaults'), findsOneWidget);
      expect(find.text('Facility defaults'), findsOneWidget);
      expect(find.text('Save configuration'), findsNWidgets(2));
    },
  );

  testWidgets(
    'ABAC without facility context strips facility panel and collapses tab',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        facilityId: null,
      );

      expect(find.text('Configuration'), findsNothing);
      expect(find.text('Facility defaults'), findsNothing);
    },
  );

  testWidgets(
    'no nested cross-module write chrome on configuration tab',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.profileUpdate,
          AppPermissions.setupRead,
          AppPermissions.accessAdminRead,
        ],
      );

      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
    },
  );

  testWidgets(
    'mobile light theme shows authorized facility configuration atoms',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        size: const Size(390, 844),
      );

      expect(find.text('Configuration'), findsWidgets);
      expect(find.text('Facility defaults'), findsOneWidget);
      expect(find.text('Save configuration'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop dark theme shows authorized tenant configuration atoms',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
        ],
        size: const Size(1280, 1200),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Configuration'), findsWidgets);
      expect(find.text('Tenant defaults'), findsOneWidget);
      expect(find.text('Facility defaults'), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsConfigurationSection integrates AppAccessGate helpers',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.platformAdmin,
        ],
      );

      expect(find.byType(SettingsConfigurationSection), findsOneWidget);
      expect(find.text('Tenant defaults'), findsOneWidget);
      expect(find.text('Facility defaults'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized loading and error/retry states remain observable',
    (WidgetTester tester) async {
      final Completer<Result<FacilitySetupSnapshot>> pending =
          Completer<Result<FacilitySetupSnapshot>>();
      final _FakeTenantFacilityRepository repository =
          _FakeTenantFacilityRepository(pendingLoad: pending);

      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        repository: repository,
        settle: false,
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(
        const Result<FacilitySetupSnapshot>.failure(AppFailure.unexpected()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not save configuration.'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      repository.nextLoad = Result<FacilitySetupSnapshot>.success(_snapshot());
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(find.text('Facility defaults'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized save shows success feedback and syncs fee field',
    (WidgetTester tester) async {
      final _FakeTenantFacilityRepository repository =
          _FakeTenantFacilityRepository(
            nextLoad: Result<FacilitySetupSnapshot>.success(_snapshot()),
          );

      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        repository: repository,
      );

      expect(find.text('5000'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), '7500');
      await tester.pump();
      await tester.tap(find.text('Save configuration'));
      await tester.pumpAndSettle();

      expect(repository.saveFacilityCalls, 1);
      expect(
        find.text('Configuration saved successfully.'),
        findsOneWidget,
      );
      final TextEditingController amountController =
          tester.widget<EditableText>(find.byType(EditableText)).controller;
      expect(
        amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        '7500',
      );
      expect(
        repository.nextLoad,
        isA<ResultSuccess<FacilitySetupSnapshot>>().having(
          (ResultSuccess<FacilitySetupSnapshot> result) =>
              result.value.facility?.standardConsultationFee,
          'synced fee',
          '7500',
        ),
      );
    },
  );

  testWidgets(
    'empty tenant context state remains visible for authorized users',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
        ],
        repository: _FakeTenantFacilityRepository(
          nextLoad: const Result<FacilitySetupSnapshot>.success(
            FacilitySetupSnapshot(),
          ),
        ),
      );

      expect(
        find.text('Select a tenant and facility to configure defaults.'),
        findsOneWidget,
      );
      expect(find.text('Save configuration'), findsNothing);
    },
  );

  testWidgets(
    'authorized reset confirm dialog mounts and syncs cleared fee',
    (WidgetTester tester) async {
      final _FakeTenantFacilityRepository repository =
          _FakeTenantFacilityRepository(
            nextLoad: Result<FacilitySetupSnapshot>.success(_snapshot()),
          );

      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        repository: repository,
      );

      await tester.ensureVisible(find.text('Reset to default'));
      await tester.tap(find.text('Reset to default'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('RESET CONFIGURATION?'), findsOneWidget);
      expect(
        find.text(
          'This will clear the configured values and revert to defaults.',
        ),
        findsOneWidget,
      );

      // Confirm in the dialog (second "Reset to default" = dialog primary).
      await tester.tap(find.text('Reset to default').last);
      await tester.pumpAndSettle();

      expect(repository.saveFacilityCalls, 1);
      expect(
        find.text('Configuration saved successfully.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  String? facilityId = 'facility-1',
  Size size = const Size(900, 1000),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final AuthSession session = _session(
    permissions: permissions,
    facilityId: facilityId,
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
        tenantFacilityRepositoryProvider.overrideWithValue(
          _FakeTenantFacilityRepository(
            nextLoad: Result<FacilitySetupSnapshot>.success(_snapshot()),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SettingsPage(
              initialQuery: SettingsPageQuery(tab: 'configuration'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  String? facilityId = 'facility-1',
  TenantFacilityRepository? repository,
  Size size = const Size(900, 1000),
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  final AuthSession session = _session(
    permissions: permissions,
    facilityId: facilityId,
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);
  final TenantFacilityRepository resolvedRepository =
      repository ??
      _FakeTenantFacilityRepository(
        nextLoad: Result<FacilitySetupSnapshot>.success(_snapshot()),
      );

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
        tenantFacilityRepositoryProvider.overrideWithValue(resolvedRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: SettingsConfigurationSection(),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

AppAccessPolicy _policy({
  required List<AppPermission> permissions,
  String? facilityId = 'facility-1',
}) {
  final AuthSession session = _session(
    permissions: permissions,
    facilityId: facilityId,
  );
  return AppAccessPolicy.fromSession(session).copyWithPermissions(permissions);
}

AuthSession _session({
  required List<AppPermission> permissions,
  String? facilityId = 'facility-1',
  List<String> roles = const <String>['doctor'],
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
      tenantId: 'tenant-1',
      facilityId: facilityId,
      roles: roles,
    ),
  );
}

FacilitySetupSnapshot _snapshot() {
  const TenantProfile tenant = TenantProfile(
    id: 'tenant-1',
    name: 'Demo Tenant',
    currency: 'UGX',
    standardConsultationFee: '4000',
  );
  const FacilityProfile facility = FacilityProfile(
    id: 'facility-1',
    tenantId: 'tenant-1',
    name: 'Demo Facility',
    type: FacilitySetupType.hospital,
    currency: 'UGX',
    standardConsultationFee: '5000',
  );
  return const FacilitySetupSnapshot(
    tenant: tenant,
    facility: facility,
    facilities: <FacilityProfile>[facility],
  );
}

final class _FakeTenantFacilityRepository implements TenantFacilityRepository {
  _FakeTenantFacilityRepository({
    this.nextLoad,
    this.pendingLoad,
  });

  Result<FacilitySetupSnapshot>? nextLoad;
  Completer<Result<FacilitySetupSnapshot>>? pendingLoad;
  int saveFacilityCalls = 0;
  int saveTenantCalls = 0;

  @override
  Future<Result<FacilitySetupSnapshot>> loadSetup({
    String? facilityId,
    String? tenantId,
    bool includeDeleted = false,
    bool includeStructure = false,
  }) async {
    if (pendingLoad != null && !pendingLoad!.isCompleted) {
      return pendingLoad!.future;
    }
    return nextLoad ??
        const Result<FacilitySetupSnapshot>.failure(AppFailure.unexpected());
  }

  @override
  Future<Result<FacilityProfile>> saveFacility({
    String? id,
    required String tenantId,
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    String? logoUrl,
    bool removeLogo = false,
    String? currency,
    String? standardConsultationFee,
    bool clearStandardConsultationFee = false,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
    bool confirmSimilar = false,
  }) async {
    saveFacilityCalls += 1;
    final FacilityProfile facility = FacilityProfile(
      id: id ?? 'facility-1',
      tenantId: tenantId,
      name: name,
      type: type,
      isActive: isActive,
      currency: currency,
      standardConsultationFee: clearStandardConsultationFee
          ? null
          : standardConsultationFee,
    );
    nextLoad = Result<FacilitySetupSnapshot>.success(
      FacilitySetupSnapshot(
        tenant: _snapshot().tenant,
        facility: facility,
        facilities: <FacilityProfile>[facility],
      ),
    );
    return Result<FacilityProfile>.success(facility);
  }

  @override
  Future<Result<TenantProfile>> saveTenant({
    String? id,
    required String name,
    String? slug,
    required bool isActive,
    String? currency,
    String? standardConsultationFee,
    bool clearStandardConsultationFee = false,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    bool confirmSimilar = false,
  }) async {
    saveTenantCalls += 1;
    final TenantProfile tenant = TenantProfile(
      id: id ?? 'tenant-1',
      name: name,
      slug: slug,
      isActive: isActive,
      currency: currency,
      standardConsultationFee: clearStandardConsultationFee
          ? null
          : standardConsultationFee,
    );
    return Result<TenantProfile>.success(tenant);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(invocation.memberName.toString());
  }
}
