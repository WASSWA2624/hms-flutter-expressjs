import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/app_startup_state.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_preferences_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'preferences strip is absent without profile:read (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: const <AppPermission>[],
        tab: 'preferences',
      );

      expect(find.text('Preferences'), findsNothing);
      expect(find.text('App theme'), findsNothing);
      expect(find.text('System'), findsNothing);
      expect(find.text('Light'), findsNothing);
      expect(find.text('Dark'), findsNothing);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Access denied'), findsNothing);
    },
  );

  testWidgets(
    'profile:update alone does not reveal preferences (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileUpdate],
        tab: 'preferences',
      );

      expect(find.text('Preferences'), findsNothing);
      expect(find.text('App theme'), findsNothing);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsNothing);
    },
  );

  testWidgets(
    'profile:read mounts theme update controls',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'preferences',
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Preferences'), findsWidgets);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
      expect(find.text('App theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'profile:read mounts theme update controls without profile:update',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'preferences',
      );

      expect(find.text('Preferences'), findsWidgets);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
      expect(find.text('App theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    },
  );

  testWidgets(
    'facility:admin alone does not unlock preferences create/delete UI',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.facilityAdmin],
        tab: 'preferences',
      );

      // Create/delete matrix keys map to facility:admin but this tab has no
      // create/delete atoms; without profile:read the section stays collapsed.
      expect(find.text('Preferences'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets(
    'no nested cross-module write entry points on preferences',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'preferences',
      );

      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
    },
  );

  testWidgets(
    'authorized theme change syncs provider and preference store',
    (WidgetTester tester) async {
      final _MemoryPreferencesStore store = _MemoryPreferencesStore();
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'preferences',
        store: store,
        themeMode: ThemeMode.system,
      );

      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(store.getString(AppPreferenceKeys.themeMode), 'dark');
    },
  );

  testWidgets(
    'authorized save failure shows visible error feedback',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'preferences',
        store: _MemoryPreferencesStore(failPersist: true),
        themeMode: ThemeMode.system,
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(
        find.text('The preference could not be saved.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile light theme shows authorized preferences update atoms',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'preferences',
        size: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
      expect(find.text('App theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop dark theme shows authorized preferences update atoms',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'preferences',
        size: const Size(1280, 1200),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('App theme'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsPage strip hides Preferences without profile:read',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: const <AppPermission>[],
        tab: 'preferences',
      );

      expect(find.text('Preferences'), findsNothing);
      expect(find.text('Accessibility'), findsNothing);
    },
  );

  test('feature helpers match AccessRequirement matrix keys', () {
    expect(
      SettingsPreferencesAtomPermissions.tab,
      same(profileReadRequirement),
    );
    expect(
      SettingsPreferencesAtomPermissions.update,
      same(profileReadRequirement),
    );
    expect(
      SettingsPreferencesAtomPermissions.tab.allPermissions,
      <AppPermission>[AppPermissions.profileRead],
    );
    expect(SettingsPreferencesAtomPermissions.tab.anyPermissions, isEmpty);
    expect(
      SettingsPreferencesAtomPermissions.update.allPermissions,
      <AppPermission>[AppPermissions.profileRead],
    );
    expect(SettingsPreferencesAtomPermissions.update.anyPermissions, isEmpty);
    expect(
      SettingsPreferencesAtomPermissions.create.allPermissions,
      <AppPermission>[AppPermissions.facilityAdmin],
    );
    expect(
      SettingsPreferencesAtomPermissions.delete.allPermissions,
      <AppPermission>[AppPermissions.facilityAdmin],
    );
    // Matrix has no union / nested cross-module rows for this tab.
    expect(
      SettingsPreferencesAtomPermissions.nestedRead.anyPermissions,
      isEmpty,
    );
    expect(
      SettingsPreferencesAtomPermissions.nestedWrite,
      same(profileReadRequirement),
    );
    // profile:* keys are core/platform (not plan-module mapped).
  });

  testWidgets(
    'SettingsPreferencesSection integrates AppAccessGate helpers',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      expect(find.byType(SettingsPreferencesSection), findsOneWidget);
      expect(find.byType(AppRadioGroup<ThemeMode>), findsOneWidget);
    },
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  String tab = 'preferences',
  Size size = const Size(900, 1000),
  ThemeMode themeMode = ThemeMode.light,
  _MemoryPreferencesStore? store,
}) async {
  final AuthSession session = _session(permissions);
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);
  final _MemoryPreferencesStore resolvedStore =
      store ?? _MemoryPreferencesStore();

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
        appPreferencesStoreProvider.overrideWithValue(resolvedStore),
        appStartupStateProvider.overrideWithValue(
          AppStartupState(
            themeMode: themeMode,
            locale: const Locale('en'),
            accessibility: const AppAccessibilityPreferences(),
            storageReadiness: const StorageReadiness.ready(),
            sessionReadiness: SessionState.authenticated(session: session),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsPage(
              initialQuery: SettingsPageQuery(tab: tab),
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
}) async {
  final AuthSession session = _session(permissions);
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(session: session),
        ),
        appPreferencesStoreProvider.overrideWithValue(
          _MemoryPreferencesStore(),
        ),
        appStartupStateProvider.overrideWithValue(
          AppStartupState(
            themeMode: ThemeMode.light,
            locale: const Locale('en'),
            accessibility: const AppAccessibilityPreferences(),
            storageReadiness: const StorageReadiness.ready(),
            sessionReadiness: SessionState.authenticated(session: session),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: SettingsPreferencesSection(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _session(List<AppPermission> permissions) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    isAuthorizationHydrated: true,
    user: const AuthUserProfile(
      id: 'user-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      roles: <String>['doctor'],
    ),
  );
}

final class _MemoryPreferencesStore implements AppPreferencesStore {
  _MemoryPreferencesStore({this.failPersist = false});

  final bool failPersist;
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    if (failPersist) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    if (failPersist) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    if (failPersist) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}
