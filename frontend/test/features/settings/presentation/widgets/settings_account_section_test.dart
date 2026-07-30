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
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_account_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  testWidgets(
    'profile surface has one Change password entry and no Profile tab shell',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      expect(find.text('Profile'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Assigned roles'), findsOneWidget);
      expect(find.text('1 role'), findsNothing);
      expect(find.text('1 direct permission'), findsNothing);
      expect(
        find.text('Update your password and restart the session.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'profile body is absent without profile:read (intersection denial)',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileUpdate],
      );

      expect(find.text('Alex Demo'), findsNothing);
      expect(find.text('Assigned roles'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'profile:read shows Change password and hides Edit profile',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Assigned roles'), findsOneWidget);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
    },
  );

  testWidgets(
    'Change password opens the dialog with profile:read only',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
      );

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('Current password'), findsOneWidget);
      expect(
        find.text('Update your password and restart the session.'),
        findsNothing,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
    },
  );

  testWidgets(
    'panel=change-password deep link opens the dialog when profile:read granted',
    (WidgetTester tester) async {
      String? clearedPanel;
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        initialPanel: SettingsAccountSection.changePasswordPanel,
        onPanelChanged: (String panel) => clearedPanel = panel,
      );
      await tester.pumpAndSettle();

      expect(clearedPanel, SettingsAccountSection.profilePanel);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('Current password'), findsOneWidget);
    },
  );

  testWidgets(
    'panel=change-password deep link without profile:read shows forbidden feedback',
    (WidgetTester tester) async {
      String? clearedPanel;
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileUpdate],
        initialPanel: SettingsAccountSection.changePasswordPanel,
        onPanelChanged: (String panel) => clearedPanel = panel,
      );
      await tester.pumpAndSettle();

      expect(clearedPanel, SettingsAccountSection.profilePanel);
      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.text('Access denied'), findsOneWidget);
    },
  );

  testWidgets('Edit profile is absent without profile:update', (
    WidgetTester tester,
  ) async {
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[AppPermissions.profileRead],
    );

    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('Edit profile opens the edit dialog when authorized', (
    WidgetTester tester,
  ) async {
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
      ],
    );

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('authorized edit saves, shows success, and refreshes detail', (
    WidgetTester tester,
  ) async {
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository(
      _session(<AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
      ]),
    );
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
      ],
      repository: repository,
    );

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    final Finder firstNameField = find.descendant(
      of: find.byType(AppDialog),
      matching: find.byType(TextFormField),
    ).first;
    await tester.enterText(firstNameField, 'Jordan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updateCount, 1);
    expect(repository.loadCount, greaterThan(1));
    expect(find.textContaining('Profile updated'), findsOneWidget);
    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Jordan Demo'), findsWidgets);
  });

  testWidgets('loading and retry states remain for authorized readers', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository(
      _session(<AppPermission>[AppPermissions.profileRead]),
      loadGate: gate,
      failFirstLoad: true,
    );

    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[AppPermissions.profileRead],
      repository: repository,
      settle: false,
    );
    await tester.pump();

    expect(find.textContaining('Loading'), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Demo'), findsWidgets);
  });

  testWidgets('narrow viewport keeps authorized Change password discoverable', (
    WidgetTester tester,
  ) async {
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
      ],
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );

    expect(find.byTooltip('Change password'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('desktop dark theme still shows authorized profile atoms', (
    WidgetTester tester,
  ) async {
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
      ],
      size: const Size(1280, 1200),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Alex Demo'), findsWidgets);
  });

  testWidgets(
    'authorized empty roles and permissions copy remain visible',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
        session: _session(
          const <AppPermission>[],
          roles: const <String>[],
        ),
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(
        find.text('No roles are assigned to this account.'),
        findsOneWidget,
      );
      expect(
        find.text('No direct permissions are assigned to this account.'),
        findsOneWidget,
      );
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized change-password validation remains observable',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
      );

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Change password'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsWidgets);
      expect(find.byType(AppDialog), findsOneWidget);
    },
  );

  testWidgets(
    'facility:admin alone does not mount create/delete or unlock update',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.textContaining('Create'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
      expect(find.textContaining('Void'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full read+update intersection mounts update atoms; create/delete stay absent',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
          AppPermissions.facilityAdmin,
        ],
      );

      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.textContaining('Delete'), findsNothing);
      expect(find.textContaining('Void'), findsNothing);
    },
  );

  testWidgets(
    'no nested cross-module write entry points on account tab',
    (WidgetTester tester) async {
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      // Matrix nested cross-module rows are _(n/a)_ — admin navigate tiles
      // from Administration must not appear on this surface.
      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Administrative setup workspace'), findsNothing);
    },
  );

  testWidgets(
    'empty subscription modules still show core profile atoms (no plan strip)',
    (WidgetTester tester) async {
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: <AppPermission>{
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        },
        isAuthorizationHydrated: true,
        user: const AuthUserProfile(
          id: 'user-1',
          displayId: 'USR-1',
          email: 'alex@example.com',
          firstName: 'Alex',
          lastName: 'Demo',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['doctor'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[],
      );
      await _pumpAccountSection(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        session: session,
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
    },
  );

  test('feature helpers match AccessRequirement matrix keys', () {
    expect(
      SettingsAccountAtomPermissions.tab,
      same(profileReadRequirement),
    );
    expect(
      SettingsAccountAtomPermissions.update,
      same(profileUpdateRequirement),
    );
    expect(
      SettingsAccountAtomPermissions.tab.allPermissions,
      <AppPermission>[AppPermissions.profileRead],
    );
    expect(SettingsAccountAtomPermissions.tab.anyPermissions, isEmpty);
    expect(
      SettingsAccountAtomPermissions.update.allPermissions,
      <AppPermission>[AppPermissions.profileUpdate],
    );
    expect(SettingsAccountAtomPermissions.update.anyPermissions, isEmpty);
    expect(
      SettingsAccountAtomPermissions.create.allPermissions,
      <AppPermission>[AppPermissions.facilityAdmin],
    );
    expect(
      SettingsAccountAtomPermissions.delete.allPermissions,
      <AppPermission>[AppPermissions.facilityAdmin],
    );
    // Matrix view ∪ / nested cross-module rows are _(n/a)_ for this tab.
    expect(SettingsAccountAtomPermissions.nestedRead.anyPermissions, isEmpty);
    expect(
      SettingsAccountAtomPermissions.nestedWrite,
      same(profileUpdateRequirement),
    );
  });
}

Future<void> _pumpAccountSection(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  AuthSession? session,
  String? initialPanel,
  ValueChanged<String>? onPanelChanged,
  Size size = const Size(1280, 1200),
  ThemeMode themeMode = ThemeMode.light,
  UserProfileRepository? repository,
  bool settle = true,
}) async {
  final AuthSession resolvedSession = session ?? _session(permissions);
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    resolvedSession,
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
          SessionState.authenticated(session: resolvedSession),
        ),
        secureSessionStorageProvider.overrideWithValue(
          _TestSecureSessionStorage(),
        ),
        userProfileRepositoryProvider.overrideWithValue(
          repository ?? _FakeUserProfileRepository(resolvedSession),
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
            padding: const EdgeInsets.all(24),
            child: SettingsAccountSection(
              initialPanel: initialPanel,
              onPanelChanged: onPanelChanged,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

AuthSession _session(
  List<AppPermission> permissions, {
  List<String> roles = const <String>['doctor'],
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      displayId: 'USR-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
      tenantId: 'tenant-1',
      tenantName: 'Acme Health',
      facilityId: 'facility-1',
      facilityName: 'Central Hospital',
      roles: roles,
      staffPosition: 'physician',
    ),
  );
}

final class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository(
    this.session, {
    this.loadGate,
    this.failFirstLoad = false,
  });

  AuthSession session;
  final Completer<void>? loadGate;
  final bool failFirstLoad;
  int loadCount = 0;
  int updateCount = 0;

  @override
  Future<Result<UserProfileView>> loadCurrentProfile(
    AuthSession session,
  ) async {
    loadCount += 1;
    if (loadGate != null && !loadGate!.isCompleted) {
      await loadGate!.future;
    }
    if (failFirstLoad && loadCount == 1) {
      return const Result<UserProfileView>.failure(AppFailure.network());
    }
    return Result<UserProfileView>.success(
      UserProfileView(
        session: this.session,
        record: UserProfileRecord(
          id: 'profile-1',
          userId: 'user-1',
          firstName: this.session.user?.firstName ?? 'Alex',
          lastName: this.session.user?.lastName ?? 'Demo',
          gender: 'UNKNOWN',
        ),
      ),
    );
  }

  @override
  Future<Result<UserProfileRecord>> updateProfile(
    String profileId,
    UserProfileDraft draft,
  ) async {
    updateCount += 1;
    final AuthUserProfile? user = session.user;
    if (user != null) {
      session = session.copyWith(
        user: AuthUserProfile(
          id: user.id,
          displayId: user.displayId,
          email: user.email,
          phone: user.phone,
          status: user.status,
          positionTitle: user.positionTitle,
          firstName: draft.firstName,
          middleName: draft.middleName,
          lastName: draft.lastName,
          gender: draft.gender,
          tenantId: user.tenantId,
          tenantName: user.tenantName,
          facilityId: user.facilityId,
          facilityName: user.facilityName,
          facilityType: user.facilityType,
          staffNumber: user.staffNumber,
          staffPosition: user.staffPosition,
          practitionerType: user.practitionerType,
          roles: user.roles,
        ),
      );
    }
    return Result<UserProfileRecord>.success(
      UserProfileRecord(
        id: profileId,
        userId: 'user-1',
        firstName: draft.firstName,
        middleName: draft.middleName,
        lastName: draft.lastName,
        gender: draft.gender,
      ),
    );
  }
}

final class _TestSecureSessionStorage implements SecureSessionStorage {
  @override
  Future<SessionTokens?> readTokens() async =>
      SessionTokens(accessToken: 'access-token');

  @override
  Future<void> writeTokens(SessionTokens tokens) async {}

  @override
  Future<void> clear() async {}
}
