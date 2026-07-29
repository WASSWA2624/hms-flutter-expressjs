import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _completed = IpdAdmissionSummary(
  id: 'adm-done',
  displayId: 'ADM-C1',
  patientDisplayName: 'Carol Completed',
  stage: 'DISCHARGED',
  dischargeStatus: 'COMPLETED',
  wardDisplayName: 'Ward C',
);

const IpdAdmissionSummary _planned = IpdAdmissionSummary(
  id: 'adm-planned',
  displayId: 'ADM-P1',
  patientDisplayName: 'Alice Planned',
  stage: 'DISCHARGE_PLANNED',
  dischargeStatus: 'PLANNED',
  wardDisplayName: 'Ward A',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: 'inpatient-bed-management',
      licenseStatus: 'ACTIVE',
    ),
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['DOCTOR'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubQueue(
  _MockDischargeRepository repository, {
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_completed],
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  DischargeAdmissionDetail? detail,
}) {
  when(() => repository.listQueue(any())).thenAnswer((invocation) async {
    if (listOverride != null) {
      return listOverride;
    }
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
  when(() => repository.getAdmissionDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detail != null) {
      return Result<DischargeAdmissionDetail>.success(detail);
    }
    final String id = invocation.positionalArguments.first as String;
    final IpdAdmissionSummary summary = items.firstWhere(
      (IpdAdmissionSummary item) =>
          item.id == id || item.displayId == id || item.apiId == id,
      orElse: () => items.first,
    );
    return Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'encounter-1',
        ipd: IpdAdmissionDetail(
          summary: summary,
          latestDischargeSummary: IpdDischargeSummary(
            id: 'ds-1',
            status: 'COMPLETED',
            summary: 'Recovered; follow up in clinic.',
          ),
          dischargeSummaries: <IpdDischargeSummary>[
            IpdDischargeSummary(
              id: 'ds-1',
              status: 'COMPLETED',
              summary: 'Recovered; follow up in clinic.',
            ),
          ],
          nursingNotes: const <IpdClinicalRecord>[
            IpdClinicalRecord(id: 'note-1', kind: 'NURSING_NOTE'),
          ],
        ),
        pharmacyOrders: const <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'rx-1',
            kind: 'PHARMACY_ORDER',
            status: 'DISPENSED',
            title: 'Amoxicillin',
          ),
        ],
        invoices: const <DischargeRelatedRecord>[
          DischargeRelatedRecord(
            id: 'inv-1',
            kind: 'INVOICE',
            status: 'PAID',
            billingStatus: 'PAID',
            title: 'Final invoice',
          ),
        ],
      ),
    );
  });
  when(
    () => repository.createFinalInvoice(any()),
  ).thenAnswer((_) async => const Result<void>.success(null));
}

Future<void> _pumpCompletedTab(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary>? items,
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  DischargeAdmissionDetail? detail,
  String initialLocation = '/discharge?section=completed',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubQueue(
    repository,
    items: items ?? <IpdAdmissionSummary>[_completed],
    listOverride: listOverride,
    detail: detail,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: DischargeWorkspacePage(
              initialQuery: DischargeWorklistQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dischargeRepositoryProvider.overrideWithValue(repository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockDischargeRepository repository;

  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockDischargeRepository();
  });

  group('DischargeCompletedAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        DischargeCompletedAtomPermissions.tab,
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.write,
        same(dischargeClinicalWriteRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.medicinesPanel,
        same(dischargePharmacyClearanceReadRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.billingPanel,
        same(dischargeBillingClearanceReadRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.roomTurnover,
        same(dischargeOperationsClearanceReadRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.routeEntry,
        same(dischargeWorkspaceEntryRequirement),
      );
      expect(
        dischargeSectionTabRequirement(DischargeDeskSection.completed),
        same(dischargeWorkspaceReadRequirement),
      );
      expect(
        DischargeCompletedAtomPermissions.medicinesPanel,
        same(DischargeAllPatientsAtomPermissions.medicinesPanel),
      );
      expect(
        DischargeCompletedAtomPermissions.write,
        same(DischargeAllPatientsAtomPermissions.write),
      );
    });

    test('∩ denial: missing clinical:write fails write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargeCompletedAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(DischargeCompletedAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        DischargeCompletedAtomPermissions.requestBilling.isAllowed(reader),
        isFalse,
      );
      expect(
        DischargeCompletedAtomPermissions.requestPharmacy.isAllowed(reader),
        isFalse,
      );
      expect(canWriteDischarge(reader), isFalse);
    });

    test('∪ allowance: last_office:read alone satisfies Completed read', () {
      final AppAccessPolicy lastOffice = _policy(
        permissions: <AppPermission>{AppPermissions.lastOfficeRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        DischargeCompletedAtomPermissions.tab.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        DischargeCompletedAtomPermissions.printSummary.isAllowed(lastOffice),
        isTrue,
      );
      expect(
        DischargeCompletedAtomPermissions.write.isAllowed(lastOffice),
        isFalse,
      );
      expect(canViewDischargeCompleted(lastOffice), isTrue);
    });

    test('∪ allowance: clinical:read alone satisfies Completed read', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(DischargeCompletedAtomPermissions.tab.isAllowed(clinical), isTrue);
      expect(canViewDischargeSection(clinical, DischargeDeskSection.completed),
          isTrue);
    });

    test(
      'route entry ∪: pharmacy:read alone satisfies entry, not Completed tab',
      () {
        final AppAccessPolicy pharmacyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          DischargeCompletedAtomPermissions.routeEntry.isAllowed(pharmacyOnly),
          isTrue,
        );
        expect(
          DischargeCompletedAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
      },
    );

    test('subscription strips Completed without inpatient-bed-management', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.lastOfficeRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(DischargeCompletedAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewDischargeCompleted(noModule), isFalse);
    });

    test('nested clearance ∩: pharmacy / billing / operations strip steps', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final List<DischargeClearanceItem> all = const <DischargeClearanceItem>[
        DischargeClearanceItem(
          code: DischargeClearanceCode.doctor,
          state: DischargeClearanceState.complete,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.pharmacy,
          state: DischargeClearanceState.complete,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.billing,
          state: DischargeClearanceState.complete,
        ),
        DischargeClearanceItem(
          code: DischargeClearanceCode.bedRelease,
          state: DischargeClearanceState.complete,
        ),
      ];
      final List<DischargeClearanceItem> visible =
          dischargeVisibleClearanceItems(clinicalOnly, all);
      expect(
        visible.map((DischargeClearanceItem item) => item.code),
        <DischargeClearanceCode>[DischargeClearanceCode.doctor],
      );

      final AppAccessPolicy withNested = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        dischargeVisibleClearanceItems(withNested, all).length,
        all.length,
      );
    });
  });

  testWidgets(
    'read-only Completed: list + print present; write atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Carol Completed'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Completed'), findsWidgets);
      expect(find.byTooltip('Print discharge summary'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Request final billing'), findsNothing);
      expect(find.text('Request medicines'), findsNothing);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Print discharge summary'), findsWidgets);
      expect(find.text('Discharge medicines'), findsNothing);
      expect(find.text('Billing clearance'), findsNothing);
      expect(find.text('Open pharmacy'), findsNothing);
      expect(find.text('Open billing'), findsNothing);
      expect(find.text('Open housekeeping'), findsNothing);
      expect(find.text('Pharmacy medicines'), findsNothing);
      expect(find.text('Final billing'), findsNothing);
      expect(find.text('Bed release'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ + nested reads: Completed mutations and nested panels mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
          AppPermissions.operationsRead,
          AppPermissions.lastOfficeRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'inpatient-bed-management',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(DischargeCompletedAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        DischargeCompletedAtomPermissions.medicinesPanel.isAllowed(writer),
        isTrue,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Carol Completed'), findsOneWidget);
      expect(find.byTooltip('Print discharge summary'), findsOneWidget);

      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Request final billing'), findsOneWidget);
      expect(find.text('Request medicines'), findsOneWidget);
      expect(find.text('Start discharge plan'), findsNothing);
      expect(find.text('Discharge medicines'), findsOneWidget);
      expect(find.text('Billing clearance'), findsOneWidget);
      expect(find.text('Open pharmacy'), findsOneWidget);
      expect(find.text('Open billing'), findsOneWidget);
      expect(find.text('Open housekeeping'), findsOneWidget);
      expect(find.text('Pharmacy medicines'), findsOneWidget);
      expect(find.text('Final billing'), findsOneWidget);
      expect(find.text('Bed release'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ last_office:read shows Completed chrome without clinical:read',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.lastOfficeRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.text('Carol Completed'), findsOneWidget);
      expect(find.byTooltip('Print discharge summary'), findsOneWidget);
      expect(find.byTooltip('Start discharge plan'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪ without tab read omits Completed chrome',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
        items: <IpdAdmissionSummary>[_completed, _planned],
      );

      expect(find.text('Carol Completed'), findsNothing);
      expect(find.textContaining('Completed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: inpatient-bed-management missing omits Completed',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
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
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Carol Completed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty Completed queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      items: const <IpdAdmissionSummary>[],
    );

    expect(find.text('No discharges in this view'), findsOneWidget);
    expect(find.text('Adjust filters to find discharge work.'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('authorized load error + Try again remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      ),
      listOverride: const Result<AppPage<IpdAdmissionSummary>>.failure(
        NetworkFailure(),
      ),
    );

    expect(find.text('Try again'), findsOneWidget);

    when(() => repository.listQueue(any())).thenAnswer(
      (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[_completed],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Carol Completed'), findsOneWidget);
  });

  testWidgets(
    'post-mutation sync: request billing shows success snackbar on Completed',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request final billing'));
      await tester.pumpAndSettle();

      expect(find.text('Create invoice request'), findsOneWidget);
      final Finder amountField = find.descendant(
        of: find.byType(AppFormShell),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField.first, '1000');
      await tester.tap(find.text('Create invoice request'));
      await tester.pumpAndSettle();

      expect(find.text('Discharge workflow updated.'), findsOneWidget);
      verify(() => repository.createFinalInvoice(any())).called(1);
    },
  );

  testWidgets('Completed desktop + mobile viewports keep print reachable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(1440, 900),
    );
    expect(find.byTooltip('Print discharge summary'), findsOneWidget);
    expect(find.text('Carol Completed'), findsOneWidget);

    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
    );
    expect(find.textContaining('Carol'), findsWidgets);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
  });

  testWidgets('Completed light + dark themes keep authorized chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.light,
    );
    expect(find.text('Carol Completed'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);

    await _pumpCompletedTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Carol Completed'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });
}
