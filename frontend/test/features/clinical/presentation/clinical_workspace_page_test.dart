import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _fullClinicalPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.evidenceExport,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'patient-registry',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'scheduling-queue',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'encounter-fallback',
        sourceQueue: 'OPD',
        encounterId: 'encounter-fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
  });

  testWidgets('renders tab strip with section counts and worklist', (
    tester,
  ) async {
    final _Harness harness = await _pumpClinicalWorkspace(tester);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Pending'), findsOneWidget);
    expect(_tab('Assigned to me'), findsOneWidget);
    expect(_tab('Urgent'), findsOneWidget);
    expect(_tab('Results ready'), findsOneWidget);
    expect(_tab('Completed'), findsOneWidget);
    expect(_tab('Waiting review'), findsNothing);
    expect(_tab('In consultation'), findsNothing);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Next action'), findsWidgets);
    expect(find.text('Current step'), findsNothing);
    expect(find.text('Queue scope'), findsNothing);
    expect(find.text('Sarah Clinical'), findsOneWidget);
    expect(find.text('John Other'), findsOneWidget);
    expect(find.text('No encounter selected'), findsNothing);
    expect(tester.takeException(), isNull);

    clearInteractions(harness.clinicalRepository);
    await tester.enterText(find.byType(TextFormField).first, 'Other');
    await tester.pump();

    expect(find.text('Sarah Clinical'), findsNothing);
    expect(find.text('John Other'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final List<Object?> capturedQueries = verify(
      () => harness.clinicalRepository.listEncounters(captureAny()),
    ).captured;
    expect(capturedQueries, isNotEmpty);
    expect(
      capturedQueries.every(
        (Object? query) =>
            (query as ClinicalWorklistQuery).databaseSearch == 'Other',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await _pumpUntilFound(tester, find.text('Sarah Clinical'));

    expect(find.byType(AppListTableGrid), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Sarah Clinical'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs calls applyScope with matching queue scope', (
    tester,
  ) async {
    final _Harness harness = await _pumpClinicalWorkspace(tester);

    clearInteractions(harness.clinicalRepository);
    await tester.tap(_tab('Urgent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final List<Object?> captured = verify(
      () => harness.clinicalRepository.listEncounters(captureAny()),
    ).captured;
    expect(captured, isNotEmpty);
    expect(
      captured.map((Object? query) => (query as ClinicalWorklistQuery).scope),
      contains(ClinicalQueueScope.urgent),
    );
    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'urgent'),
    );
  });

  testWidgets('switching to Assigned to me updates URL section query', (
    tester,
  ) async {
    final _Harness harness = await _pumpClinicalWorkspace(tester);

    await tester.tap(_tab('Assigned to me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'assigned-to-me'),
    );

    final List<Object?> captured = verify(
      () => harness.clinicalRepository.listEncounters(captureAny()),
    ).captured;
    expect(
      captured.map((Object? query) => (query as ClinicalWorklistQuery).scope),
      contains(ClinicalQueueScope.assignedToMe),
    );
  });

  testWidgets('deep link section=urgent selects Urgent tab and scopes fetch', (
    tester,
  ) async {
    final _Harness harness = await _pumpClinicalWorkspace(
      tester,
      initialLocation: '/clinical?section=urgent',
      initialQuery: ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=urgent'),
      ),
    );

    expect(_tab('Urgent'), findsOneWidget);

    final List<Object?> captured = verify(
      () => harness.clinicalRepository.listEncounters(captureAny()),
    ).captured;
    expect(
      captured.any(
        (Object? query) =>
            (query as ClinicalWorklistQuery).scope == ClinicalQueueScope.urgent,
      ),
      isTrue,
    );
  });

  testWidgets('results-ready tab shows encounter type column by default', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      encounters: <ClinicalWorklistEntry>[
        ClinicalWorklistEntry(
          id: 'encounter-results',
          sourceQueue: 'OPD',
          encounterId: 'encounter-results',
          encounterPublicId: 'ENC000099',
          patientDisplayName: 'Results Patient',
          patientPublicId: 'PAT000099',
          providerDisplayName: 'Dr Results',
          encounterType: 'OUTPATIENT',
          currentLocation: 'Clinic R',
          status: 'OPEN',
          stage: 'LAB_RESULTS_READY',
          resultsReady: true,
          updatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.tap(_tab('Results ready'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Results Patient'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Encounter type'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Doctor'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'Results ready shows Export Print and info count tone when allowed',
    (tester) async {
      await _pumpClinicalWorkspace(
        tester,
        encounters: <ClinicalWorklistEntry>[
          ClinicalWorklistEntry(
            id: 'encounter-results-chrome',
            sourceQueue: 'OPD',
            encounterId: 'encounter-results-chrome',
            encounterPublicId: 'ENC000098',
            patientDisplayName: 'Results Chrome Patient',
            patientPublicId: 'PAT000098',
            providerDisplayName: 'Dr Results',
            encounterType: 'OUTPATIENT',
            currentLocation: 'Clinic R',
            status: 'OPEN',
            stage: 'LAB_RESULTS_READY',
            resultsReady: true,
            updatedAt: DateTime.now(),
          ),
        ],
      );

      await tester.tap(_tab('Results ready'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem resultsReady = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == 'Results ready',
      );
      expect(resultsReady.countTone, AppTabCountTone.info);
      expect(find.text('Results Chrome Patient'), findsOneWidget);
    },
  );

  testWidgets('Results ready omits Export Print without evidence:export', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
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
          isAuthorizationHydrated: true,
        ),
      ),
    );

    await tester.tap(_tab('Results ready'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets('deep link section=results opens Results ready', (tester) async {
    final _Harness harness = await _pumpClinicalWorkspace(
      tester,
      initialLocation: '/clinical?section=results',
      initialQuery: ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=results'),
      ),
    );

    expect(_tab('Results ready'), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'results-ready'),
    );
  });

  testWidgets('Completed tab shows encounter type column by default', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      encounters: <ClinicalWorklistEntry>[
        ClinicalWorklistEntry(
          id: 'encounter-completed',
          sourceQueue: 'OPD',
          encounterId: 'encounter-completed',
          encounterPublicId: 'ENC000077',
          patientDisplayName: 'Completed Patient',
          patientPublicId: 'PAT000077',
          providerDisplayName: 'Dr Done',
          encounterType: 'OUTPATIENT',
          currentLocation: 'Clinic C',
          status: 'COMPLETED',
          stage: 'COMPLETED',
          updatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.tap(_tab('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Completed Patient'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Encounter type'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Doctor'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'Completed shows Export Print and info count tone when allowed',
    (tester) async {
      await _pumpClinicalWorkspace(
        tester,
        encounters: <ClinicalWorklistEntry>[
          ClinicalWorklistEntry(
            id: 'encounter-completed-chrome',
            sourceQueue: 'OPD',
            encounterId: 'encounter-completed-chrome',
            encounterPublicId: 'ENC000076',
            patientDisplayName: 'Completed Chrome Patient',
            patientPublicId: 'PAT000076',
            providerDisplayName: 'Dr Done',
            encounterType: 'OUTPATIENT',
            currentLocation: 'Clinic C',
            status: 'COMPLETED',
            stage: 'COMPLETED',
            updatedAt: DateTime.now(),
          ),
        ],
      );

      await tester.tap(_tab('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem completed = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == 'Completed',
      );
      expect(completed.countTone, AppTabCountTone.info);
      expect(find.text('Completed Chrome Patient'), findsOneWidget);
    },
  );

  testWidgets('Completed omits Export Print without evidence:export', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
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
          isAuthorizationHydrated: true,
        ),
      ),
    );

    await tester.tap(_tab('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets('deep link section=done opens Completed', (tester) async {
    final _Harness harness = await _pumpClinicalWorkspace(
      tester,
      initialLocation: '/clinical?section=done',
      initialQuery: ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=done'),
      ),
    );

    expect(_tab('Completed'), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'completed'),
    );
  });

  testWidgets('Assigned to me tab keeps standard worklist columns', (
    tester,
  ) async {
    final _Harness harness = await _pumpClinicalWorkspace(tester);

    await tester.tap(_tab('Assigned to me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'assigned-to-me'),
    );
    expect(_tab('Assigned to me'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
    'Assigned to me shows Export Print and warning count tone when allowed',
    (tester) async {
      await _pumpClinicalWorkspace(tester);

      await tester.tap(_tab('Assigned to me'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem assigned = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == 'Assigned to me',
      );
      expect(assigned.countTone, AppTabCountTone.warning);
    },
  );

  testWidgets('Assigned to me omits Export Print without evidence:export', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
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
          isAuthorizationHydrated: true,
        ),
      ),
    );

    await tester.tap(_tab('Assigned to me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets('deep link section=mine opens Assigned to me', (tester) async {
    final _Harness harness = await _pumpClinicalWorkspace(
      tester,
      initialLocation: '/clinical?section=mine',
      initialQuery: ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=mine'),
      ),
    );

    expect(_tab('Assigned to me'), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.queryParameters,
      containsPair('section', 'assigned-to-me'),
    );
  });

  testWidgets(
    'Urgent shows Export Print and danger count tone when allowed',
    (tester) async {
      await _pumpClinicalWorkspace(
        tester,
        encounters: <ClinicalWorklistEntry>[
          ClinicalWorklistEntry(
            id: 'encounter-urgent',
            sourceQueue: 'OPD',
            encounterId: 'encounter-urgent',
            encounterPublicId: 'ENC000091',
            patientDisplayName: 'Urgent Patient',
            patientPublicId: 'PAT000091',
            providerDisplayName: 'Dr Urgent',
            encounterType: 'OUTPATIENT',
            currentLocation: 'Clinic A',
            status: 'OPEN',
            stage: 'WAITING_DOCTOR_REVIEW',
            isUrgent: true,
            updatedAt: DateTime.now(),
          ),
        ],
      );

      await tester.tap(_tab('Urgent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem urgent = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == 'Urgent',
      );
      expect(urgent.countTone, AppTabCountTone.danger);
      expect(find.text('Urgent Patient'), findsOneWidget);
    },
  );

  testWidgets('Urgent omits Export Print without evidence:export', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
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
          isAuthorizationHydrated: true,
        ),
      ),
    );

    await tester.tap(_tab('Urgent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets(
    'worklist toolbar order is Filters Settings Export Print when export allowed',
    (tester) async {
      await _pumpClinicalWorkspace(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);

      final List<String> labels = <String>[
        for (final String label in <String>[
          'Filters',
          'Settings',
          'Export',
          'Print',
        ])
          label,
      ];
      final List<double> xs = <double>[
        for (final String label in labels)
          tester.getTopLeft(find.text(label).first).dx,
      ];
      for (int i = 1; i < xs.length; i++) {
        expect(xs[i] >= xs[i - 1], isTrue, reason: '${labels[i]} after ${labels[i - 1]}');
      }
    },
  );

  testWidgets('worklist Export and Print omit without evidence:export', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(
      tester,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
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
          isAuthorizationHydrated: true,
        ),
      ),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Print'), findsNothing);
  });

  testWidgets(
    'assigned provider without display name does not show Not assigned',
    (tester) async {
      await _pumpClinicalWorkspace(
        tester,
        encounters: <ClinicalWorklistEntry>[
          ClinicalWorklistEntry(
            id: 'encounter-assigned',
            sourceQueue: 'ENCOUNTER',
            encounterId: 'encounter-assigned',
            encounterPublicId: 'ENC000055',
            patientDisplayName: 'Chloe Okello',
            patientPublicId: 'PAT000055',
            providerUserId: 'user-doctor-1',
            encounterType: 'OUTPATIENT',
            status: 'OPEN',
            stage: 'WAITING_DOCTOR_REVIEW',
            updatedAt: DateTime.now(),
          ),
        ],
      );

      expect(find.text('Assigned'), findsWidgets);
      expect(find.text('Not assigned'), findsNothing);
    },
  );

  testWidgets('row tap opens encounter detail dialog with action bar', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Sarah Clinical'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsWidgets);
    expect(find.textContaining('Sarah Clinical'), findsWidgets);
  });

  testWidgets('mobile layout renders list items via mobile item builder', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(tester, physicalSize: const Size(390, 844));

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTableGrid), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('advanced filter dialog has no Queue scope dropdown', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(tester);

    await tester.tap(find.text('Filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Queue scope'), findsNothing);
  });

  testWidgets('Pending advanced filters footer includes Close', (tester) async {
    await _pumpClinicalWorkspace(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ADVANCED FILTERS'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
    expect(find.text('Apply filters'), findsOneWidget);
    expect(find.text('Close'), findsWidgets);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
  });

  testWidgets('Pending default visible columns are five', (tester) async {
    await _pumpClinicalWorkspace(tester);

    expect(find.text('Sarah Clinical'), findsOneWidget);
    expect(find.text('Patient name'), findsWidgets);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Doctor'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Next action'), findsWidgets);
    expect(find.text('Encounter type'), findsNothing);
  });

  testWidgets(
    'legacy waiting-review deep link opens Pending without writing section',
    (tester) async {
      final _Harness harness = await _pumpClinicalWorkspace(
        tester,
        initialLocation: '/clinical?section=waiting-review',
        initialQuery: ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=waiting-review'),
        ),
      );

      expect(_tab('Pending'), findsOneWidget);
      expect(
        harness.router.routeInformationProvider.value.uri.queryParameters,
        isNot(contains('section')),
      );
    },
  );

  testWidgets(
    'deep link encounterId+panel opens encounter with panel anchor',
    (tester) async {
      await _pumpClinicalWorkspace(
        tester,
        initialLocation: '/clinical?encounterId=encounter-1&panel=notes',
        initialQuery: ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?encounterId=encounter-1&panel=notes'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Clinical'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('clinical_panel_notes')),
        findsOneWidget,
      );
    },
  );

  testWidgets('clinical tabs omit Refresh and cross-module toolbar actions', (
    tester,
  ) async {
    await _pumpClinicalWorkspace(tester);

    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppTabStrip), matching: find.text('OPD')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppTabStrip), matching: find.text('Lab')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Discharge'),
      ),
      findsNothing,
    );
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    final AppListTable<ClinicalWorklistEntry> table = tester.widget(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppListTable<ClinicalWorklistEntry>,
      ),
    );
    expect(table.columnVisibilityTitle, 'Table Settings');
    expect(table.search?.advancedFilterTitle, 'Advanced filters');
    expect(find.text('Clinical workspace'), findsNothing);
    expect(find.text('Provider worklist'), findsNothing);
  });

  testWidgets(
    'Assigned to me, Urgent, and Results ready omit OPD toolbar action',
    (tester) async {
      await _pumpClinicalWorkspace(tester);

      for (final String tabLabel in <String>[
        'Assigned to me',
        'Urgent',
        'Results ready',
      ]) {
        await tester.tap(_tab(tabLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Refresh'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppTabStrip),
            matching: find.text('OPD'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppTabStrip),
            matching: find.text('Lab'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppTabStrip),
            matching: find.text('Discharge'),
          ),
          findsNothing,
        );
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      }
    },
  );

  testWidgets('Results ready tab omits Lab toolbar action', (tester) async {
    await _pumpClinicalWorkspace(tester);

    await tester.tap(_tab('Results ready'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Refresh'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppTabStrip), matching: find.text('Lab')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppTabStrip), matching: find.text('OPD')),
      findsNothing,
    );
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Completed today tab omits Discharge toolbar action', (tester) async {
    await _pumpClinicalWorkspace(tester);

    await tester.tap(_tab('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Refresh'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Discharge'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppTabStrip), matching: find.text('OPD')),
      findsNothing,
    );
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

class _Harness {
  const _Harness({required this.clinicalRepository, required this.router});

  final _MockClinicalRepository clinicalRepository;
  final GoRouter router;
}

Future<_Harness> _pumpClinicalWorkspace(
  WidgetTester tester, {
  ClinicalWorkspaceQuery? initialQuery,
  String initialLocation = '/clinical',
  Size physicalSize = const Size(1440, 900),
  List<ClinicalWorklistEntry>? encounters,
  AppAccessPolicy? accessPolicy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockClinicalRepository clinicalRepository = _MockClinicalRepository();
  final _MockOpdRepository opdRepository = _MockOpdRepository();
  final _MockIpdRepository ipdRepository = _MockIpdRepository();
  final List<ClinicalWorklistEntry> worklist =
      encounters ??
      <ClinicalWorklistEntry>[
        ClinicalWorklistEntry(
          id: 'encounter-1',
          sourceQueue: 'OPD',
          encounterId: 'encounter-1',
          encounterPublicId: 'ENC000001',
          patientDisplayName: 'Sarah Clinical',
          patientPublicId: 'PAT000001',
          providerDisplayName: 'Dr Kizza',
          encounterType: 'OUTPATIENT',
          currentLocation: 'Clinic A',
          status: 'OPEN',
          stage: 'WAITING_DOCTOR_REVIEW',
          updatedAt: DateTime.now(),
        ),
        ClinicalWorklistEntry(
          id: 'encounter-2',
          sourceQueue: 'OPD',
          encounterId: 'encounter-2',
          encounterPublicId: 'ENC000002',
          patientDisplayName: 'John Other',
          patientPublicId: 'PAT000002',
          providerDisplayName: 'Dr Mugerwa',
          encounterType: 'OUTPATIENT',
          currentLocation: 'Clinic B',
          status: 'OPEN',
          stage: 'IN_PROGRESS',
          updatedAt: DateTime.now(),
        ),
      ];
  _stubClinicalInitialLoad(clinicalRepository, encounters: worklist);
  _stubOpdInitialLoad(opdRepository);
  _stubIpdInitialLoad(ipdRepository);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = physicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final AppAccessPolicy resolvedAccessPolicy =
      accessPolicy ??
      AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.evidenceExport,
          },
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/clinical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClinicalWorkspacePage(
              initialQuery:
                  initialQuery ?? ClinicalWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
        ipdRepositoryProvider.overrideWithValue(ipdRepository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(resolvedAccessPolicy),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await _pumpUntilFound(tester, _tab('Pending'));
  await tester.pumpAndSettle();

  return _Harness(clinicalRepository: clinicalRepository, router: router);
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 100,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

void _stubClinicalInitialLoad(
  _MockClinicalRepository repository, {
  List<ClinicalWorklistEntry> encounters = const <ClinicalWorklistEntry>[],
}) {
  when(() => repository.listEncounters(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: encounters,
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: encounters.length,
      ),
    ),
  );
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
  when(() => repository.loadEncounterBundle(any())).thenAnswer((invocation) {
    final ClinicalWorklistEntry entry =
        invocation.positionalArguments.single as ClinicalWorklistEntry;
    return Future<Result<ClinicalEncounterBundle>>.value(
      Result<ClinicalEncounterBundle>.success(
        ClinicalEncounterBundle(entry: entry),
      ),
    );
  });
}

void _stubOpdInitialLoad(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.getOpdFlow(any())).thenAnswer(
    (_) async => const Result<OpdFlowDetail>.success(
      OpdFlowDetail(summary: OpdFlowSummary(id: 'flow-1', publicId: 'OPD000001')),
    ),
  );
}

void _stubIpdInitialLoad(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}
