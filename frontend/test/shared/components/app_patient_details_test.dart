import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_patient_details.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';
import 'component_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('uses detail panel section chrome with chevron collapse', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        persistExpandPreference: false,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Encounter',
            value: 'ENC-9',
          ),
        ],
      ),
    );

    expect(find.byType(AppWorkspaceDetailPanel), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('MRN-100'), findsOneWidget);
    expect(find.text('·'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('ENC-9'), findsNothing);
  });

  testWidgets('expanded body is an overflow row with Icon Label: Value |', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        persistExpandPreference: false,
        initiallyExpanded: true,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Encounter',
            value: 'ENC-9',
            icon: Icons.badge_outlined,
          ),
          AppWorkspacePatientContextField(
            label: 'Orders included',
            value: '1 active order',
            icon: Icons.science_outlined,
          ),
        ],
      ),
      size: const Size(360, 800),
    );

    expect(find.textContaining('Encounter:'), findsOneWidget);
    expect(find.text('ENC-9'), findsOneWidget);
    expect(find.textContaining('Orders included:'), findsOneWidget);
    expect(find.text('1 active order'), findsOneWidget);
    expect(find.text('|'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);

    final double encounterY = tester
        .getTopLeft(find.textContaining('Encounter:'))
        .dy;
    final double ordersY = tester
        .getTopLeft(find.textContaining('Orders included:'))
        .dy;
    expect(ordersY, closeTo(encounterY, 1));
  });

  testWidgets('defaults to collapsed with only the header visible', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        ageLabel: '37y',
        genderLabel: 'Female',
        persistExpandPreference: false,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Encounter',
            value: 'ENC-9',
          ),
        ],
      ),
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('MRN-100'), findsOneWidget);
    expect(find.text('37y'), findsNothing);
    expect(find.text('Female'), findsNothing);
    expect(find.text('ENC-9'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('expanding reveals age, gender, and workflow fields in the row', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        patientNumberLabel: 'MRN',
        ageLabel: '37y',
        genderLabel: 'Female',
        persistExpandPreference: false,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Phone',
            value: '+256700000000',
          ),
        ],
      ),
    );

    expect(find.textContaining('Phone'), findsNothing);
    expect(find.text('+256700000000'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.textContaining('Age:'), findsOneWidget);
    expect(find.text('37y'), findsOneWidget);
    expect(find.textContaining('Gender:'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.textContaining('Phone:'), findsOneWidget);
    expect(find.text('+256700000000'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('chevron collapses expanded workflow fields', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        persistExpandPreference: false,
        initiallyExpanded: true,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(label: 'Encounter', value: 'ENC-9'),
        ],
      ),
    );

    expect(find.text('ENC-9'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.text('ENC-9'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('unauthorized expanded fields never appear', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        persistExpandPreference: false,
        initiallyExpanded: true,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Phone',
            value: '+256700000000',
            authorized: false,
          ),
          AppWorkspacePatientContextField(label: 'Ward', value: 'Ward A'),
        ],
      ),
    );

    expect(find.text('+256700000000'), findsNothing);
    expect(find.textContaining('Phone'), findsNothing);
    expect(find.text('Ward A'), findsOneWidget);
  });

  testWidgets('persists expand preference without storing PHI', (
    WidgetTester tester,
  ) async {
    final _MemoryPreferencesStore store = _MemoryPreferencesStore();
    final AuthSession session = _testSession(
      userId: 'user-1',
      tenantId: 'tenant-a',
      facilityId: 'facility-a',
    );
    final String preferenceKey =
        AppPatientDetailsExpandedController.preferenceKeyForSession(session);

    await pumpLocalizedWidget(
      tester,
      ProviderScope(
        overrides: [
          appPreferencesStoreProvider.overrideWithValue(store),
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: session),
          ),
        ],
        child: const AppPatientDetails(
          patientName: 'Ada Lovelace',
          patientNumber: 'MRN-100',
          ageLabel: '37y',
          genderLabel: 'Female',
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Phone',
              value: '+256700000000',
            ),
          ],
        ),
      ),
    );

    expect(find.text('+256700000000'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(store.getBool(preferenceKey), isTrue);
    expect(store.storedValues.keys, <String>[preferenceKey]);
    expect(
      store.storedValues.values.every((Object? value) => value is bool),
      isTrue,
    );
    expect(
      store.storedValues.values.any(
        (Object? value) =>
            value is String &&
            (value.contains('Ada') ||
                value.contains('MRN') ||
                value.contains('+256')),
      ),
      isFalse,
    );

    // Simulate restart with the same preference store.
    await pumpLocalizedWidget(
      tester,
      ProviderScope(
        overrides: [
          appPreferencesStoreProvider.overrideWithValue(store),
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: session),
          ),
        ],
        child: const AppPatientDetails(
          patientName: 'Ada Lovelace',
          patientNumber: 'MRN-100',
          ageLabel: '37y',
          genderLabel: 'Female',
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Phone',
              value: '+256700000000',
            ),
          ],
        ),
      ),
    );

    expect(find.text('+256700000000'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  test('preference key is partitioned by user/tenant/facility', () {
    final AuthSession sessionA = _testSession(
      userId: 'user-a',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    );
    final AuthSession sessionB = _testSession(
      userId: 'user-b',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    );

    final String keyA =
        AppPatientDetailsExpandedController.preferenceKeyForSession(sessionA);
    final String keyB =
        AppPatientDetailsExpandedController.preferenceKeyForSession(sessionB);

    expect(keyA, isNot(equals(keyB)));
    expect(keyA, startsWith(AppPreferenceKeys.patientDetailsExpanded));
    expect(keyA, contains('tenant-1'));
    expect(keyA, contains('facility-1'));
    expect(keyA, contains('user-a'));
  });

  testWidgets('adapts action layout on compact mobile width', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppPatientDetails(
        patientName: 'Ada Lovelace',
        patientNumber: 'MRN-100',
        ageLabel: '37y',
        genderLabel: 'Female',
        persistExpandPreference: false,
        expandedFields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Phone',
            value: '+256700000000',
          ),
        ],
      ),
      size: const Size(360, 800),
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('MRN-100'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('+256700000000'), findsOneWidget);
  });

  testWidgets('supports enlarged text scale without losing header identity', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: AppPatientDetails(
                  patientName: 'Ada Lovelace',
                  patientNumber: 'MRN-100',
                  ageLabel: '37y',
                  genderLabel: 'Female',
                  persistExpandPreference: false,
                  expandedFields: <AppWorkspacePatientContextField>[
                    AppWorkspacePatientContextField(
                      label: 'Phone',
                      value: '+256700000000',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('MRN-100'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });
}

AuthSession _testSession({
  required String userId,
  required String tenantId,
  required String facilityId,
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'test-token-$userId'),
    subject: '$userId@example.com',
    user: AuthUserProfile(
      id: userId,
      displayId: 'USR-$userId',
      email: '$userId@example.com',
      firstName: 'Test',
      lastName: 'User',
      tenantId: tenantId,
      tenantName: 'Tenant',
      facilityId: facilityId,
      facilityName: 'Facility',
      facilityType: 'hospital',
      positionTitle: 'clinician',
      staffNumber: 'STF-$userId',
      staffPosition: 'doctor',
      roles: const <String>['doctor'],
    ),
  );
}

final class _MemoryPreferencesStore implements AppPreferencesStore {
  final Map<String, Object?> storedValues = <String, Object?>{};

  @override
  String? getString(String key) => storedValues[key] as String?;

  @override
  bool? getBool(String key) => storedValues[key] as bool?;

  @override
  int? getInt(String key) => storedValues[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    storedValues[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    storedValues[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    storedValues[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    storedValues.remove(key);
    return true;
  }
}
