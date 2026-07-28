import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:hosspi_hms/features/profile/presentation/state/user_profile_state.dart';
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
    'Change password opens the dialog directly without an intermediate panel',
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
    'panel=change-password deep link opens the dialog and clears the panel',
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

  testWidgets('narrow viewport keeps Change password discoverable', (
    WidgetTester tester,
  ) async {
    await _pumpAccountSection(
      tester,
      permissions: <AppPermission>[AppPermissions.profileRead],
      size: const Size(390, 844),
    );

    // Labels collapse on narrow widths; tooltip / semantics remain.
    expect(find.byTooltip('Change password'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}

Future<void> _pumpAccountSection(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  String? initialPanel,
  ValueChanged<String>? onPanelChanged,
  Size size = const Size(1280, 1200),
}) async {
  final AuthSession session = _session(permissions);
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);
  final UserProfileState profileState = UserProfileState(
    view: UserProfileView(
      session: session,
      record: const UserProfileRecord(
        id: 'profile-1',
        userId: 'user-1',
        firstName: 'Alex',
        lastName: 'Demo',
        gender: 'UNKNOWN',
      ),
    ),
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
        userProfileControllerProvider.overrideWith(
          () => _FakeUserProfileController(profileState),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
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
  await tester.pumpAndSettle();
}

AuthSession _session(List<AppPermission> permissions) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    user: const AuthUserProfile(
      id: 'user-1',
      displayId: 'USR-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
      tenantId: 'tenant-1',
      tenantName: 'Acme Health',
      facilityId: 'facility-1',
      facilityName: 'Central Hospital',
      roles: <String>['doctor'],
      staffPosition: 'physician',
    ),
  );
}

final class _FakeUserProfileController extends UserProfileController {
  _FakeUserProfileController(this._profileState);

  final UserProfileState _profileState;

  @override
  Future<Result<UserProfileState>> build() async {
    return Result<UserProfileState>.success(_profileState);
  }

  @override
  Future<void> refresh() async {
    state = AsyncData<Result<UserProfileState>>(
      Result<UserProfileState>.success(_profileState),
    );
  }

  @override
  Future<bool> saveProfile(UserProfileDraft draft) async {
    return true;
  }
}
