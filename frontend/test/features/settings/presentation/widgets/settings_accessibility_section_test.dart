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
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_accessibility_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'accessibility strip is absent without profile:read (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: const <AppPermission>[],
        tab: 'accessibility',
      );

      expect(find.text('Accessibility'), findsNothing);
      expect(find.text('Reduce motion'), findsNothing);
      expect(find.text('Bold text'), findsNothing);
      expect(find.text('Text size'), findsNothing);
      expect(find.byType(AppCheckboxField), findsNothing);
      expect(find.byType(AppSelectField<AppTextScaleLevel>), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Access denied'), findsNothing);
    },
  );

  testWidgets(
    'profile:update alone does not reveal accessibility (intersection denial)',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileUpdate],
        tab: 'accessibility',
      );

      expect(find.text('Accessibility'), findsNothing);
      expect(find.text('Reduce motion'), findsNothing);
      expect(find.byType(AppCheckboxField), findsNothing);
    },
  );

  testWidgets(
    'profile:read mounts accessibility update controls',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'accessibility',
        accessibility: const AppAccessibilityPreferences(
          reduceMotion: true,
          boldText: false,
          textScaleLevel: AppTextScaleLevel.large,
        ),
      );

      expect(find.text('Accessibility'), findsWidgets);
      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      expect(find.byType(AppSelectField<AppTextScaleLevel>), findsOneWidget);
      expect(find.text('Reduce motion'), findsOneWidget);
      expect(find.text('Bold text'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'profile:read mounts update controls without profile:update',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'accessibility',
      );

      expect(find.text('Accessibility'), findsWidgets);
      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      expect(find.byType(AppSelectField<AppTextScaleLevel>), findsOneWidget);
      expect(find.text('Reduce motion'), findsOneWidget);
      expect(find.text('Bold text'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      // Read-only Yes/No summary is not used on the update path.
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
    },
  );

  testWidgets(
    'facility:admin alone does not unlock accessibility create/delete UI',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.facilityAdmin],
        tab: 'accessibility',
      );

      // Create/delete matrix keys map to facility:admin but this tab has no
      // create/delete atoms; without profile:read the section stays collapsed.
      expect(find.text('Accessibility'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets(
    'no nested cross-module write entry points on accessibility',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'accessibility',
      );

      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
    },
  );

  testWidgets(
    'authorized update toggles reduce motion and syncs provider state',
    (WidgetTester tester) async {
      final _MemoryPreferencesStore store = _MemoryPreferencesStore();
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'accessibility',
        store: store,
      );

      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      final Finder reduceMotionTile = find.widgetWithText(
        CheckboxListTile,
        'Reduce motion',
      );
      expect(reduceMotionTile, findsOneWidget);

      await tester.tap(reduceMotionTile);
      await tester.pumpAndSettle();

      final CheckboxListTile tile = tester.widget(reduceMotionTile);
      expect(tile.value, isTrue);
      expect(store.getBool(AppPreferenceKeys.reduceMotion), isTrue);
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
        tab: 'accessibility',
        store: _MemoryPreferencesStore(failPersist: true),
      );

      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Reduce motion'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The preference could not be saved.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile light theme shows authorized accessibility update atoms',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'accessibility',
        size: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      expect(find.text('Reduce motion'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop dark theme shows authorized accessibility update atoms',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        tab: 'accessibility',
        size: const Size(1280, 1200),
        themeMode: ThemeMode.dark,
        accessibility: const AppAccessibilityPreferences(
          reduceMotion: false,
          boldText: true,
          textScaleLevel: AppTextScaleLevel.extraLarge,
        ),
      );

      expect(find.text('Reduce motion'), findsOneWidget);
      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      expect(find.byType(AppSelectField<AppTextScaleLevel>), findsOneWidget);
      expect(find.text('Yes'), findsNothing);
      expect(find.text('No'), findsNothing);
    },
  );

  testWidgets(
    'SettingsPage strip hides Accessibility without profile:read',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: const <AppPermission>[],
        tab: 'preferences',
      );

      // Preferences shares profile:read ∩ — both tabs collapse together.
      expect(find.text('Preferences'), findsNothing);
      expect(find.text('Accessibility'), findsNothing);
    },
  );

  testWidgets(
    'empty subscription modules still show core accessibility atoms',
    (WidgetTester tester) async {
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'accessibility',
      );

      expect(find.text('Accessibility'), findsWidgets);
      expect(find.byType(AppCheckboxField), findsNWidgets(2));
      expect(find.byType(AppSelectField<AppTextScaleLevel>), findsOneWidget);
    },
  );

  testWidgets(
    'authorized bold text toggle syncs provider state',
    (WidgetTester tester) async {
      final _MemoryPreferencesStore store = _MemoryPreferencesStore();
      await _pumpSettings(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        tab: 'accessibility',
        store: store,
      );

      final Finder boldTextTile = find.widgetWithText(
        CheckboxListTile,
        'Bold text',
      );
      expect(boldTextTile, findsOneWidget);

      await tester.tap(boldTextTile);
      await tester.pumpAndSettle();

      final CheckboxListTile tile = tester.widget(boldTextTile);
      expect(tile.value, isTrue);
      expect(store.getBool(AppPreferenceKeys.boldText), isTrue);
    },
  );

  testWidgets(
    'SettingsAccessibilitySection integrates AppAccessGate helpers',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      expect(find.byType(SettingsAccessibilitySection), findsOneWidget);
      expect(find.byType(AppCheckboxField), findsNWidgets(2));
    },
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  String tab = 'accessibility',
  Size size = const Size(900, 1000),
  ThemeMode themeMode = ThemeMode.light,
  AppAccessibilityPreferences accessibility =
      const AppAccessibilityPreferences(),
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
            accessibility: accessibility,
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
            child: SettingsAccessibilitySection(),
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
    // Explicit empty list documents AC4: profile:* is not plan-module mapped.
    moduleEntitlements: const <AppModuleEntitlement>[],
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
