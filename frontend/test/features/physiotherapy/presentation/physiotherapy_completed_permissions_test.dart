import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/physiotherapy_access.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

const TherapyWorkItem _completedItem = TherapyWorkItem(
  id: 'TH-DONE',
  encounterId: 'ENC-DONE',
  patientId: 'PAT-DONE',
  patientDisplayName: 'Cora Completed',
  status: 'COMPLETED',
  plan: 'Stretch protocol',
  billingStatus: 'UNAVAILABLE',
);

const TherapyWorkItem _completedAfterUpdate = TherapyWorkItem(
  id: 'TH-DONE',
  encounterId: 'ENC-DONE',
  patientId: 'PAT-DONE',
  patientDisplayName: 'Cora Completed',
  status: 'COMPLETED',
  plan: 'Updated stretch protocol',
  billingStatus: 'UNAVAILABLE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: physiotherapyModule, licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['PHYSIOTHERAPIST'],
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

void _stubWorkItems(
  _MockPhysiotherapyRepository repository, {
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_completedItem],
  PhysiotherapyDetail? detailOverride,
}) {
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PhysiotherapyWorklistQuery query =
        invocation.positionalArguments.single as PhysiotherapyWorklistQuery;
    final List<TherapyWorkItem> filtered = items
        .where(
          (TherapyWorkItem item) =>
              physiotherapyItemMatchesScope(item, query.scope),
        )
        .toList(growable: false);
    return Result<AppPage<TherapyWorkItem>>.success(
      AppPage<TherapyWorkItem>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(() => repository.loadDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<PhysiotherapyDetail>.success(detailOverride);
    }
    final TherapyWorkItem item =
        invocation.positionalArguments.single as TherapyWorkItem;
    return Result<PhysiotherapyDetail>.success(PhysiotherapyDetail(item: item));
  });
  when(
    () => repository.updatePlan(
      item: any(named: 'item'),
      plan: any(named: 'plan'),
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
    ),
  ).thenAnswer(
    (_) async => Result<PhysiotherapyDetail>.success(
      const PhysiotherapyDetail(item: _completedAfterUpdate),
    ),
  );
}

AppListTable<TherapyWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<TherapyWorkItem>>(
    find.byType(AppListTable<TherapyWorkItem>),
  );
}

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpCompletedTab(
  WidgetTester tester, {
  required _MockPhysiotherapyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_completedItem],
  String initialLocation = '/physiotherapy?section=completed',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkItems(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/physiotherapy',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PhysiotherapyWorkspacePage(
              initialQuery: PhysiotherapyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        physiotherapyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
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
  await _pumpFrames(tester);
}

void main() {
  late _MockPhysiotherapyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PhysiotherapyWorklistQuery());
    registerFallbackValue(
      const TherapyWorkItem(id: 'fallback', encounterId: 'ENC-FALLBACK'),
    );
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = _MockPhysiotherapyRepository();
  });

  group('PhysiotherapyCompletedAtomPermissions helpers (reuse / AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.tab,
          physiotherapyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.write,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.printInstructions,
          physiotherapyNextActionReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.nextAction,
          physiotherapyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.billingColumn,
          physiotherapyBillingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.billingChip,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.routeEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyCompletedAtomPermissions.catalogEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
    });

    test('atom map covers inventory verbs (AC1)', () {
      expect(PhysiotherapyCompletedAtomPermissions.tab, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.listChrome, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.search, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.filters, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.settings, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.pagination, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.empty, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.loading, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.retry, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.success, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.validation, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.rowSelect, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.detail, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.create, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.update, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.delete, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.write, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.nextAction, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.nextActionWrite, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.printInstructions, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.updatePlan, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.addProgressNote, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.closeEpisode, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.billingColumn, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.billingChip, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.nestedWrite, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.nestedRead, isNotNull);
      expect(PhysiotherapyCompletedAtomPermissions.routeEntry, isNotNull);
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        ]),
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.write.allPermissions,
        contains(AppPermissions.clinicalWrite),
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.billingColumn.allPermissions,
        contains(AppPermissions.billingRead),
      );
      expect(
        identical(
          therapyNextActionRequirementForKind(
            TherapyNextActionKind.printInstructions,
          ),
          PhysiotherapyCompletedAtomPermissions.printInstructions,
        ),
        isTrue,
      );
    });

    test('section tab gate uses Completed atom map', () {
      expect(
        identical(
          physiotherapySectionTabRequirement(PhysiotherapyQueueScope.completed),
          PhysiotherapyCompletedAtomPermissions.tab,
        ),
        isTrue,
      );
    });
  });

  group('authorization matrix (∩ / ∪ / subscription)', () {
    test('∪ allowance: clinical:read alone unlocks Completed tab chrome', () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.isAllowed(clinicalReader),
        isTrue,
      );
      expect(canViewPhysiotherapyCompleted(clinicalReader), isTrue);
      expect(
        PhysiotherapyCompletedAtomPermissions.printInstructions.isAllowed(
          clinicalReader,
        ),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.write.isAllowed(clinicalReader),
        isFalse,
      );
    });

    test('∪ allowance: patient:read alone unlocks Completed tab chrome', () {
      final AppAccessPolicy patientReader = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: physiotherapyModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.isAllowed(patientReader),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.nextAction.isAllowed(
          patientReader,
        ),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.write.isAllowed(patientReader),
        isFalse,
      );
    });

    test('∩ denial: clinical:write alone does not unlock tab read chrome', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.loading.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewPhysiotherapyCompleted(writeOnly), isFalse);
      expect(
        physiotherapyAllowedScopes(writeOnly),
        isEmpty,
      );
    });

    test('∩ denial: missing clinical:write hides mutations', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(PhysiotherapyCompletedAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        PhysiotherapyCompletedAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.updatePlan.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.closeEpisode.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
    });

    test('full ∩ write set unlocks mutations and success feedback', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(PhysiotherapyCompletedAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(
        PhysiotherapyCompletedAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.updatePlan.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.success.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.printInstructions.isAllowed(
          writer,
        ),
        isTrue,
      );
    });

    test('billing:read alone enters route but not Completed tab / billing chip', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: physiotherapyModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: billingPaymentsModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.routeEntry.isAllowed(billingOnly),
        isTrue,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.isAllowed(billingOnly),
        isFalse,
      );
      // Nested billing column still needs clinical/patient read for tab; column
      // requirement alone would pass with billing module — strip via tab gate.
      expect(
        PhysiotherapyCompletedAtomPermissions.billingColumn.isAllowed(
          billingOnly,
        ),
        isTrue,
      );
    });

    test('nested billing column absent without billing:read ∩ billing-payments', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.billingColumn.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(canViewPhysiotherapyBilling(clinicalOnly), isFalse);

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: physiotherapyModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: billingPaymentsModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.billingColumn.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });

    test('subscription strips Completed without physiotherapy module', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(
        PhysiotherapyCompletedAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPhysiotherapyCompleted(noModule), isFalse);
    });
  });

  group('Completed UI permission enforcement', () {
    testWidgets(
      '∩ denial: read-only Completed shows print; write controls absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          PhysiotherapyCompletedAtomPermissions.write.isAllowed(reader),
          isFalse,
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Completed'), findsOneWidget);
        expect(find.text('Cora Completed'), findsOneWidget);
        expect(find.text('Print instructions'), findsWidgets);
        expect(find.text('Update plan'), findsNothing);
        expect(find.text('Close episode'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Cora Completed'));
        await _pumpFrames(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        // Print is the row next-action, so detail omits it; write actions gone
        // (AppQuickActions may still mount but collapse to empty).
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Update plan'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Close episode'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Add progress note'),
          ),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance + ∩ presence: writer sees print and complementary writes',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.text('Print instructions'), findsWidgets);
        expect(find.text('Cora Completed'), findsOneWidget);

        await tester.tap(find.text('Cora Completed'));
        await _pumpFrames(tester);

        expect(find.byType(AppQuickActions), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Update plan'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Close episode'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Print instructions'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'nested billing column absent without billing rights; present with ∩',
      (WidgetTester tester) async {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: clinicalOnly,
        );

        final List<AppListTableColumn<TherapyWorkItem>> withoutBilling =
            _table(tester).columnChoices ??
            const <AppListTableColumn<TherapyWorkItem>>[];
        expect(
          withoutBilling.any(
            (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
          ),
          isFalse,
        );
        expect(find.text('Billing'), findsNothing);

        final AppAccessPolicy withBilling = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: physiotherapyModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: billingPaymentsModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: withBilling,
        );

        final List<AppListTableColumn<TherapyWorkItem>> withBillingCols =
            _table(tester).columnChoices ??
            const <AppListTableColumn<TherapyWorkItem>>[];
        expect(
          withBillingCols.any(
            (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'billing-only route entry collapses Completed strip (no routine banner)',
      (WidgetTester tester) async {
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: physiotherapyModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: billingPaymentsModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: billingOnly,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.byType(AppListTable<TherapyWorkItem>), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('authorized empty / loading chrome remain on Completed', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        items: const <TherapyWorkItem>[],
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      expect(find.text(l10n.physiotherapyNoWorkTitle), findsOneWidget);
      expect(_table(tester).search, isNotNull);
      expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
      expect(_table(tester).columnVisibilityLabel, 'Settings');
      expect(
        _table(tester).columnVisibilityStorageKey,
        'physiotherapy_completed',
      );
    });

    testWidgets(
      'post-mutation sync: Update plan refreshes detail after save',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Cora Completed'));
        await _pumpFrames(tester);

        await tester.tap(find.text('Update plan'));
        await _pumpFrames(tester);

        expect(find.byType(AppDialog), findsAtLeastNWidgets(2));
        await tester.enterText(find.byType(TextFormField).first, 'Updated stretch protocol');
        await tester.tap(find.text('Save'));
        await _pumpFrames(tester);

        verify(
          () => repository.updatePlan(
            item: any(named: 'item'),
            plan: any(named: 'plan'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).called(1);
        expect(find.text('Physiotherapy record saved.'), findsOneWidget);
      },
    );

    testWidgets('mobile viewport: Completed tab + print next-action', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: physiotherapyModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tabLabel('Completed'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsOneWidget);
      expect(find.text('Print instructions'), findsWidgets);
      expect(find.text('Update plan'), findsNothing);
    });

    testWidgets('desktop dark theme: Completed authorized chrome renders', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
        physicalSize: const Size(1440, 900),
      );

      expect(_tabLabel('Completed'), findsOneWidget);
      expect(find.text('Cora Completed'), findsOneWidget);
      expect(find.text('Print instructions'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('light theme: Completed read ∪ patient:read shows worklist', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy patientReader = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: physiotherapyModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: patientReader,
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Completed'), findsOneWidget);
      expect(find.text('Cora Completed'), findsOneWidget);
      expect(find.text('Print instructions'), findsWidgets);
    });
  });
}
