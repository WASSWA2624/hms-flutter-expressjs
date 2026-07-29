import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_columns.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _transferPatient = NursingPatientSummary(
  id: 'adm-transfer',
  admissionId: 'adm-transfer',
  displayId: 'ADM-TRANSFER',
  patientDisplayId: 'PT-TRANSFER',
  patientDisplayName: 'Transfer Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
  hasActiveBed: true,
  transferStatus: 'REQUESTED',
  openTransferRequestId: 'xfer-1',
);

const NursingTransferRequest _activeTransfer = NursingTransferRequest(
  id: 'xfer-1',
  status: 'REQUESTED',
  fromWardName: 'Ward A',
  toWardName: 'Ward B',
);

const List<AppModuleEntitlement> _nursingModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: nursingInpatientBedModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['NURSE'],
  List<AppModuleEntitlement> modules = _nursingModules,
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy({AppPermission readKey = AppPermissions.clinicalRead}) {
  return _policy(permissions: <AppPermission>{readKey});
}

AppAccessPolicy _readWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _clinicalWriteOnlyPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    },
  );
}

AppAccessPolicy _patientWriteWithoutClinicalWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _lastOfficeReadOnlyPolicy() {
  return _policy(
    roles: const <String>['RECEPTION'],
    permissions: <AppPermission>{
      AppPermissions.lastOfficeRead,
      AppPermissions.clinicalRead,
    },
  );
}

AppAccessPolicy _shiftContextPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.rosterRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _medicationsPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.pharmacyRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(
        code: 'pharmacy-dispensing',
        licenseStatus: 'ACTIVE',
      ),
    ],
  );
}

List<NursingPatientSummary> _itemsForQuery(NursingWorklistQuery query) {
  return <NursingPatientSummary>[_transferPatient]
      .where((NursingPatientSummary item) => item.matchesScope(query.scope))
      .toList(growable: false);
}

void _stubNursingRepository(_MockNursingRepository repository) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    final List<NursingPatientSummary> items = _itemsForQuery(query);
    return Result<AppPage<NursingPatientSummary>>.success(
      AppPage<NursingPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listPendingHandovers()).thenAnswer(
    (_) async =>
        const Result<List<NursingHandover>>.success(<NursingHandover>[]),
  );
  when(() => repository.listCurrentRosters()).thenAnswer(
    (_) async => const Result<List<NursingRosterAssignment>>.success(
      <NursingRosterAssignment>[],
    ),
  );
  when(() => repository.loadPatientDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary,
        activeTransfer: _activeTransfer,
        medicationReminders: const <MedicationReminder>[
          MedicationReminder(
            id: 'med-1',
            medicationLabel: 'Paracetamol',
            status: 'DUE',
          ),
        ],
      ),
    );
  });
  when(() => repository.updateTransfer(any(), any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.first as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: summary.copyWith(transferStatus: 'COMPLETED'),
      ),
    );
  });
}

Future<void> _pumpTransferPending(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/nursing?scope=transfer-pending',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubNursingRepository(repository);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/nursing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: NursingWorkspacePage(
              initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nursingRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _readWritePolicy()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_transferPatient);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('NursingTransferPendingAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement vocabulary (no second map)', () {
      expect(
        identical(
          NursingTransferPendingAtomPermissions.tab,
          nursingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.write,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.nextAction,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.nextActionTransfer,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.acknowledgeTransfer,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.create,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.update,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.delete,
          nursingClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.complementaryWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.checklistWrite,
          nursingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.medicationsPanel,
          nursingMedicationsPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.administerMedication,
          nursingMedicationAdministerRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.shiftContext,
          nursingShiftContextRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.routeEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingTransferPendingAtomPermissions.catalogEntry,
          RouteAccessCatalog.nursingEntry,
        ),
        isTrue,
      );
      expect(
        nursingNextActionRequirement(NursingNextActionKind.transfer),
        NursingTransferPendingAtomPermissions.nextActionTransfer,
      );
      expect(
        nursingNextActionRequirement(
          NursingNextActionKind.transfer,
          scope: NursingQueueScope.transferPending,
        ),
        NursingTransferPendingAtomPermissions.nextActionTransfer,
      );
      expect(
        nursingBoardTabRequirement(NursingQueueScope.transferPending),
        NursingTransferPendingAtomPermissions.tab,
      );
      expect(
        nursingWriteRequirementForScope(NursingQueueScope.transferPending),
        NursingTransferPendingAtomPermissions.write,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _readPolicy(),
          NursingQueueScope.transferPending,
        ),
        isFalse,
      );
      expect(
        nursingBoardShowsNextActionColumn(
          _clinicalWriteOnlyPolicy(),
          NursingQueueScope.transferPending,
        ),
        isTrue,
      );
    });

    test('intersection denial: clinical:write required for transfer write', () {
      final AppAccessPolicy patientWriteOnly =
          _patientWriteWithoutClinicalWritePolicy();
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(
          _readPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.write.isAllowed(patientWriteOnly),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.nextActionTransfer.isAllowed(
          patientWriteOnly,
        ),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.write.isAllowed(
          _clinicalWriteOnlyPolicy(),
        ),
        isTrue,
      );
    });

    test('union allowance: clinical:read OR patient:read for tab read', () {
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(
          _readPolicy(readKey: AppPermissions.clinicalRead),
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(
          _readPolicy(readKey: AppPermissions.patientRead),
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.listChrome.isAllowed(
          _readPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.search.isAllowed(_readPolicy()),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.rowSelect.isAllowed(_readPolicy()),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.create.isAllowed(_readPolicy()),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.success.isAllowed(_readPolicy()),
        isFalse,
      );
    });

    test('last_office:read alone does not unlock transfer writes', () {
      final AppAccessPolicy lastOfficeWithClinical = _lastOfficeReadOnlyPolicy();
      expect(
        NursingTransferPendingAtomPermissions.routeEntry.isAllowed(
          lastOfficeWithClinical,
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(
          lastOfficeWithClinical,
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.write.isAllowed(
          lastOfficeWithClinical,
        ),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.nextActionTransfer.isAllowed(
          lastOfficeWithClinical,
        ),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.complementaryWrite.isAllowed(
          lastOfficeWithClinical,
        ),
        isFalse,
      );
      expect(canWriteNursing(lastOfficeWithClinical), isFalse);

      final AppAccessPolicy lastOfficeOnly = _policy(
        roles: const <String>['RECEPTION'],
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
      );
      expect(
        NursingTransferPendingAtomPermissions.routeEntry.isAllowed(
          lastOfficeOnly,
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(lastOfficeOnly),
        isFalse,
      );
      expect(canViewNursingTransferPending(lastOfficeOnly), isFalse);
    });

    test(
      'source ∪ complementaryWrite allows patient:write without clinical:write',
      () {
        final AppAccessPolicy patientWriter =
            _patientWriteWithoutClinicalWritePolicy();
        expect(
          NursingTransferPendingAtomPermissions.write.isAllowed(patientWriter),
          isFalse,
        );
        expect(
          NursingTransferPendingAtomPermissions.complementaryWrite.isAllowed(
            patientWriter,
          ),
          isTrue,
        );
        expect(
          NursingTransferPendingAtomPermissions.addNote.isAllowed(patientWriter),
          isTrue,
        );
      },
    );

    test('subscription / module strip without inpatient-bed-management', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested medications panel requires pharmacy:read ∩', () {
      expect(
        NursingTransferPendingAtomPermissions.medicationsPanel.isAllowed(
          _readPolicy(),
        ),
        isFalse,
      );
      expect(
        NursingTransferPendingAtomPermissions.medicationsPanel.isAllowed(
          _medicationsPanelPolicy(),
        ),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.administerMedication.isAllowed(
          _readWritePolicy(),
        ),
        isFalse,
      );
    });

    test('ABAC facility context strip', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        facilityId: null,
      );
      // Tab read does not require facility on the requirement itself; write
      // still needs clinical:write + roles + module.
      expect(
        NursingTransferPendingAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        NursingTransferPendingAtomPermissions.write.isAllowed(noFacility),
        isTrue,
      );
    });
  });

  group('Transfer pending UI authorization (AC2-AC5)', () {
    testWidgets('authorized writer sees acknowledge-transfer next-action', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readWritePolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.textContaining(l10n.nursingScopeTransferPendingLabel), findsWidgets);
      expect(find.text('Transfer Patient'), findsOneWidget);
      expect(find.text(l10n.nursingNextActionColumnLabel), findsWidgets);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsWidgets,
      );
      expect(find.byTooltip(l10n.nursingShiftContextTitle), findsNothing);
    });

    testWidgets('read-only user: next-action column and writes absent', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.text('Transfer Patient'), findsOneWidget);
      expect(find.text(l10n.nursingNextActionColumnLabel), findsNothing);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      '∩ denial: patient:write without clinical:write hides transfer CTA',
      (WidgetTester tester) async {
        await _pumpTransferPending(
          tester,
          repository: repository,
          policy: _patientWriteWithoutClinicalWritePolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.text('Transfer Patient'), findsOneWidget);
        expect(
          find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
          findsNothing,
        );
        expect(find.text(l10n.nursingNextActionColumnLabel), findsNothing);

        await tester.tap(find.text('Transfer Patient'));
        await _pumpAfterAction(tester);

        // Source ∪ complementary writes still mount without clinical:write.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAddNote),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAcknowledgeTransfer),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'authorized writer detail: complementary writes; transfer omitted as next-action',
      (WidgetTester tester) async {
        await _pumpTransferPending(
          tester,
          repository: repository,
          policy: _readWritePolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        await tester.tap(find.text('Transfer Patient'));
        await _pumpAfterAction(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        // Row next-action Acknowledge transfer omitted from detail Quick Actions.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAcknowledgeTransfer),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionAddNote),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.nursingActionRecordVitals),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.nursingMedicationsTitle), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('light theme: read-only chrome without write affordances', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readPolicy(),
        themeMode: ThemeMode.light,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.text('Transfer Patient'), findsOneWidget);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('error / retry state remains for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.listWardPatients(any())).thenAnswer(
        (_) async => const Result<AppPage<NursingPatientSummary>>.failure(
          AppFailure.network(),
        ),
      );
      when(() => repository.listPendingHandovers()).thenAnswer(
        (_) async =>
            const Result<List<NursingHandover>>.success(<NursingHandover>[]),
      );
      when(() => repository.listCurrentRosters()).thenAnswer(
        (_) async => const Result<List<NursingRosterAssignment>>.success(
          <NursingRosterAssignment>[],
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/nursing?scope=transfer-pending',
        routes: <RouteBase>[
          GoRoute(
            path: '/nursing',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: NursingWorkspacePage(
                  initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nursingRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_readPolicy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('∪ allowance: patient:read alone shows transfer-pending tab', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readPolicy(readKey: AppPermissions.patientRead),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(
        find.textContaining(l10n.nursingScopeTransferPendingLabel),
        findsWidgets,
      );
      expect(find.text('Transfer Patient'), findsOneWidget);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsNothing,
      );
    });

    testWidgets('shift context mounts only with roster/ops + hr-rosters', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _shiftContextPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.byTooltip(l10n.nursingShiftContextTitle), findsOneWidget);
    });

    testWidgets('detail: transfer write absent for read-only; Open ICU ok', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.text('Transfer Patient'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text(l10n.nursingActionAcknowledgeTransfer),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text(l10n.nursingActionAddNote),
        ),
        findsNothing,
      );
      expect(find.text(l10n.nursingMedicationsTitle), findsNothing);
    });

    testWidgets('detail: medications panel requires pharmacy:read', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _medicationsPanelPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.text('Transfer Patient'));
      await _pumpAfterAction(tester);

      expect(find.text(l10n.nursingMedicationsTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text(l10n.nursingActionAcknowledgeTransfer),
        ),
        findsNothing,
      );
    });

    testWidgets('authorized transfer next-action opens dialog and syncs', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readWritePolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.byTooltip(l10n.nursingActionAcknowledgeTransfer).first);
      await _pumpAfterAction(tester);

      expect(find.byType(NursingTransferDialog), findsOneWidget);
      expect(find.text(l10n.nursingConfirmTransferLabel), findsOneWidget);

      // Validation state: submit without confirm stays on dialog.
      await tester.tap(find.text(l10n.nursingActionAcknowledgeTransfer).last);
      await _pumpAfterAction(tester);
      expect(find.byType(NursingTransferDialog), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await _pumpAfterAction(tester);
      await tester.tap(find.text(l10n.nursingActionAcknowledgeTransfer).last);
      await _pumpAfterAction(tester);

      expect(find.byType(NursingTransferDialog), findsNothing);
      verify(() => repository.updateTransfer(any(), any())).called(1);
      verify(() => repository.listWardPatients(any())).called(
        greaterThanOrEqualTo(2),
      );
    });

    testWidgets('empty state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.listWardPatients(any())).thenAnswer(
        (_) async => Result<AppPage<NursingPatientSummary>>.success(
          AppPage<NursingPatientSummary>(
            items: const <NursingPatientSummary>[],
            request: const AppPageRequest(),
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.listPendingHandovers()).thenAnswer(
        (_) async =>
            const Result<List<NursingHandover>>.success(<NursingHandover>[]),
      );
      when(() => repository.listCurrentRosters()).thenAnswer(
        (_) async => const Result<List<NursingRosterAssignment>>.success(
          <NursingRosterAssignment>[],
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/nursing?scope=transfer-pending',
        routes: <RouteBase>[
          GoRoute(
            path: '/nursing',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: NursingWorkspacePage(
                  initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nursingRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_readPolicy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.nursingNoWorklistTitle), findsOneWidget);
    });

    testWidgets('mobile viewport: next-action trailing when write allowed', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readWritePolicy(),
        viewport: const Size(390, 844),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsWidgets,
      );
    });

    testWidgets('desktop dark theme: authorized chrome remains available', (
      WidgetTester tester,
    ) async {
      await _pumpTransferPending(
        tester,
        repository: repository,
        policy: _readWritePolicy(),
        themeMode: ThemeMode.dark,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Transfer Patient'), findsOneWidget);
      expect(
        find.byTooltip(l10n.nursingActionAcknowledgeTransfer),
        findsWidgets,
      );
    });

    test('columns omit next_action when policy denies transfer write', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final List<AppListTableColumn<NursingWorkItem>> denied =
          nursingColumnsForScope(
            l10n,
            NursingQueueScope.transferPending,
            policy: _readPolicy(),
          );
      final List<AppListTableColumn<NursingWorkItem>> allowed =
          nursingColumnsForScope(
            l10n,
            NursingQueueScope.transferPending,
            policy: _readWritePolicy(),
          );

      expect(
        denied.map((AppListTableColumn<NursingWorkItem> c) => c.label),
        isNot(contains(l10n.nursingNextActionColumnLabel)),
      );
      expect(
        allowed.map((AppListTableColumn<NursingWorkItem> c) => c.label),
        contains(l10n.nursingNextActionColumnLabel),
      );
      expect(
        denied.map((AppListTableColumn<NursingWorkItem> c) => c.label),
        contains(l10n.nursingTransferPendingSummaryLabel),
      );
    });

    test('tab strip helpers collapse transfer when read denied by module', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        modules: const <AppModuleEntitlement>[],
      );
      expect(canViewNursingTab(noModule, NursingQueueScope.transferPending), isFalse);
      expect(nursingAllowedScopes(noModule), isEmpty);
    });
  });
}
