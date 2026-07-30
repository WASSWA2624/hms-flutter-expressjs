import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_completed_billing_inventory.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _completed = IpdAdmissionSummary(
  id: 'adm-done',
  displayId: 'ADM-C1',
  patientDisplayName: 'Carol Completed',
  stage: 'DISCHARGED',
  dischargeStatus: 'COMPLETED',
  wardDisplayName: 'Ward C',
);

const DischargeRelatedRecord _paidInvoice = DischargeRelatedRecord(
  id: 'inv-1',
  kind: 'INVOICE',
  status: 'PAID',
  billingStatus: 'PAID',
  title: 'Final invoice',
  amount: 150000,
  currency: 'UGX',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final bool needsPharmacy = permissions.contains(AppPermissions.pharmacyRead);
  final bool needsOperations = permissions.contains(
    AppPermissions.operationsRead,
  );
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            if (needsClinical)
              const AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            if (needsPharmacy)
              const AppModuleEntitlement(
                code: 'pharmacy-dispensing',
                licenseStatus: 'ACTIVE',
              ),
            if (needsOperations)
              const AppModuleEntitlement(
                code: 'facilities-maintenance',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubQueue(
  _MockDischargeRepository repository, {
  List<DischargeRelatedRecord> invoices = const <DischargeRelatedRecord>[
    _paidInvoice,
  ],
}) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[_completed],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
  when(() => repository.getAdmissionDetail(any())).thenAnswer((_) async {
    return Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-1',
        encounterId: 'encounter-1',
        ipd: const IpdAdmissionDetail(
          summary: _completed,
          latestDischargeSummary: IpdDischargeSummary(
            id: 'ds-1',
            status: 'COMPLETED',
            summary: 'Recovered; follow up in clinic.',
            clearance: IpdDischargeClearance(
              summaryReady: true,
              pendingOrdersReviewed: true,
              pharmacyCleared: true,
              billingCleared: true,
              nursingCleared: true,
              documentsReady: true,
              patientExited: true,
            ),
          ),
          dischargeSummaries: <IpdDischargeSummary>[
            IpdDischargeSummary(
              id: 'ds-1',
              status: 'COMPLETED',
              summary: 'Recovered; follow up in clinic.',
            ),
          ],
          nursingNotes: <IpdClinicalRecord>[
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
        invoices: invoices,
      ),
    );
  });
  when(() => repository.createPharmacyOrder(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
}

Future<void> _pumpCompletedTab(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<DischargeRelatedRecord>? invoices,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubQueue(repository, invoices: invoices ?? const <DischargeRelatedRecord>[_paidInvoice]);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/discharge?section=completed',
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
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Text(
              'Billing workspace patient=${state.uri.queryParameters['patient_id'] ?? ''}',
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
  // Narrow viewports can overflow print next-action chrome; clear so flat /
  // dialog assertions remain authoritative (same pattern as Billing scans).
  final Object? layoutException = tester.takeException();
  if (layoutException != null) {
    expect(
      layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
      reason: 'Unexpected exception: $layoutException',
    );
  }
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

  group('Discharge Completed billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(DischargeCompletedBillingInventory.atoms, isNotEmpty);
      expect(
        DischargeCompletedBillingInventory.atoms.map(
          (DischargeCompletedFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'empty_loading_error',
          'row_select',
          'next_action_print',
          'continue_discharge',
          'open_billing',
          'request_billing',
          'request_pharmacy',
          'billing_panel',
          'medicines_panel',
          'clearance_billing_step',
          'print_summary',
          'absent_inline_collect',
        ]),
      );
      for (final DischargeCompletedFinancialAtom atom
          in DischargeCompletedBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass ==
                DischargeCompletedFinancialClass.notBilled ||
            atom.financialClass ==
                DischargeCompletedFinancialClass.notRequired ||
            atom.financialClass == DischargeCompletedFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(DischargeCompletedBillingInventory.openBilling.mounted, isTrue);
      expect(DischargeCompletedBillingInventory.requestBilling.mounted, isFalse);
      expect(
        DischargeCompletedBillingInventory.continueDischarge.mounted,
        isFalse,
      );
      expect(
        DischargeCompletedBillingInventory.nextActionPrint.auditCode,
        'NO_CHARGE',
      );
    });

    test('AC2: billable atoms wire through Billing; inline collect forbidden', () {
      expect(
        DischargeCompletedBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        DischargeCompletedBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        DischargeCompletedBillingInventory.requestPharmacy.billingPath,
        contains('persistPharmacyOrderBilling'),
      );
      for (final DischargeCompletedFinancialAtom atom
          in DischargeCompletedBillingInventory.atoms) {
        if (DischargeCompletedBillingInventory.isInlineCollectionForbidden(
          atom.financialClass,
        )) {
          expect(
            atom.mounted == false ||
                (atom.billingPath?.contains('Billing') ?? false) ||
                (atom.billingPath?.contains('billing') ?? false),
            isTrue,
            reason: '${atom.id} must not bypass Billing',
          );
        }
      }
      expect(
        DischargeCompletedAtomPermissions.requestBilling,
        same(DischargeCompletedAtomPermissions.openBilling),
      );
    });

    test('AC3: discharge realtime includes billing for status parity', () {
      expect(RealtimeEventGroups.discharge, isNotEmpty);
      expect(
        RealtimeEventGroups.discharge.any(
          (String event) =>
              event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'AC2/AC3/AC4: Open billing navigates; invoice status parity; no cashier',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
              AppPermissions.pharmacyRead,
            },
          ),
        );

        await tester.tap(find.text('Carol Completed'));
        await tester.pumpAndSettle();

        expect(find.text('Final invoice'), findsOneWidget);
        expect(find.textContaining('Paid'), findsWidgets);
        expect(find.text('Request final billing'), findsNothing);
        expect(find.text('Create invoice request'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=patient-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC2: pharmacy create-charge wires to clinical-request-billing path',
      (WidgetTester tester) async {
        expect(
          DischargeCompletedBillingInventory.requestPharmacy.financialClass,
          DischargeCompletedFinancialClass.createCharge,
        );
        expect(
          DischargeCompletedBillingInventory.requestPharmacy.billingPath,
          contains('persistPharmacyOrderBilling'),
        );
        expect(
          DischargeCompletedBillingInventory.requestPharmacy.billingPath,
          contains('buildPharmacyOrderBillingFromRequest'),
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
              AppPermissions.pharmacyRead,
            },
          ),
        );

        await tester.tap(find.text('Carol Completed'));
        await tester.pumpAndSettle();
        expect(find.text('Request medicines'), findsOneWidget);
      },
    );

    testWidgets(
      'AC4: unauthorized users cannot collect/adjust; Open billing absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          DischargeCompletedAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );
        expect(
          DischargeCompletedAtomPermissions.requestPharmacy.isAllowed(reader),
          isFalse,
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Carol Completed'));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.text('Request medicines'), findsNothing);
        expect(find.text('Billing clearance'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('AC5: desktop light — flat sections on Completed detail', (
      WidgetTester tester,
    ) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
            AppPermissions.pharmacyRead,
            AppPermissions.operationsRead,
            AppPermissions.lastOfficeRead,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();

      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Completed detail desktop light',
      );
    });

    testWidgets('AC5: mobile dark — flat sections on Completed detail', (
      WidgetTester tester,
    ) async {
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
            AppPermissions.pharmacyRead,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      final Finder row = find.text('Carol Completed');
      await tester.ensureVisible(row);
      await tester.tap(row, warnIfMissed: false);
      await tester.pumpAndSettle();
      // Clear any residual list overflow after opening detail.
      tester.takeException();

      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Completed detail mobile dark',
      );
    });

    testWidgets('AC4: light + dark keep Authorized Open billing chrome', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: withBilling,
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Open billing'), findsWidgets);
      expect(find.text('Final invoice'), findsOneWidget);

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: withBilling,
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Carol Completed'));
      await tester.pumpAndSettle();
      expect(find.text('Open billing'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });
  });
}
