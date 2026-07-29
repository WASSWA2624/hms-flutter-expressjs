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
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_account_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

void main() {
  group('Profile financial inventory (AC1)', () {
    test('every atom is explicitly not billable with audit reason', () {
      expect(profileTabHasNoBillableActions(), isTrue);
      expect(profileFinancialInventory, isNotEmpty);
      for (final ProfileFinancialAtom atom in profileFinancialInventory) {
        expect(
          atom.classification,
          ProfileFinancialClass.notBillable,
          reason: atom.id,
        );
        expect(atom.auditReason, isNotNull, reason: atom.id);
        expect(
          atom.auditReason,
          isIn(<String>['NOT_REQUIRED', 'NO_CHARGE', 'NOT_BILLED']),
        );
      }
    });

    test('mutation atoms carry NO_CHARGE audit without billable class', () {
      final ProfileFinancialAtom editSave = profileFinancialInventory
          .where((ProfileFinancialAtom atom) => atom.id == 'edit_profile_save')
          .single;
      expect(editSave.classification, ProfileFinancialClass.notBillable);
      expect(editSave.auditReason, 'NO_CHARGE');
    });
  });

  group('Profile billing bypass (AC2–AC5)', () {
    testWidgets('authorized surface has no payment or ledger affordances', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('edit profile dialog has no billing controls', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('Payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('change password dialog has no billing controls', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Amount'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('billing:write alone cannot collect or adjust on profile', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.billingWrite,
        ],
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('profile update without billing:write cannot collect', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      expect(find.text('Change password'), findsOneWidget);
      expect(find.textContaining('Adjust balance'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
    });
  });

  group('Profile section layout (AC5)', () {
    testWidgets('desktop authorized UI: flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        size: const Size(1280, 1200),
        themeMode: ThemeMode.light,
      );
      expectFlatTitledSectionLayout(tester);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Professional details'), findsOneWidget);
    });

    testWidgets('mobile authorized UI: flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        size: const Size(390, 844),
        themeMode: ThemeMode.light,
      );
      expectFlatTitledSectionLayout(tester);
      expect(find.byTooltip('Change password'), findsOneWidget);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('edit profile dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expectFlatTitledSectionLayout(tester);
    });
  });

  group('Profile sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized edit refreshes profile without billing gate', (
      WidgetTester tester,
    ) async {
      final _FakeUserProfileRepository repository = _FakeUserProfileRepository(
        _session(<AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ]),
      );
      await _pumpProfileSurface(
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
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('loading and retry remain for authorized readers', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _FakeUserProfileRepository repository = _FakeUserProfileRepository(
        _session(<AppPermission>[AppPermissions.profileRead]),
        loadGate: gate,
        failFirstLoad: true,
      );

      await _pumpProfileSurface(
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
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('read-only profile:read hides financial and update controls', (
      WidgetTester tester,
    ) async {
      await _pumpProfileSurface(
        tester,
        permissions: <AppPermission>[AppPermissions.profileRead],
      );

      expect(find.text('Alex Demo'), findsWidgets);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });
  });
}

Future<void> _pumpProfileSurface(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  AuthSession? session,
  UserProfileRepository? repository,
  Size size = const Size(1280, 1200),
  ThemeMode themeMode = ThemeMode.light,
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
            child: const SettingsAccountSection(),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

AuthSession _session(List<AppPermission> permissions) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions,
    isAuthorizationHydrated: true,
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
