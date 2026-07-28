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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_board_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _pendingBed = IpdAdmissionSummary(
  id: 'adm-pending',
  displayId: 'ADM-PEND',
  patientId: 'pat-pending',
  patientDisplayName: 'Pat Pending',
  stage: 'ADMITTED_PENDING_BED',
  admissionStatus: 'ADMITTED',
  nextStep: 'ASSIGN_BED',
  encounterId: 'enc-pending',
);

const IpdAdmissionSummary _transferPending = IpdAdmissionSummary(
  id: 'adm-xfer',
  displayId: 'ADM-XFER',
  patientId: 'pat-xfer',
  patientDisplayName: 'Terry Transfer',
  stage: 'TRANSFER_REQUESTED',
  admissionStatus: 'ADMITTED',
  nextStep: 'APPROVE_TRANSFER',
  encounterId: 'enc-xfer',
  hasActiveBed: true,
);

const IpdAdmissionDetail _transferDetail = IpdAdmissionDetail(
  summary: _transferPending,
  openTransferRequest: IpdTransferRequest(id: 'tr-1', status: 'REQUESTED'),
  transferRequests: <IpdTransferRequest>[
    IpdTransferRequest(id: 'tr-1', status: 'REQUESTED'),
  ],
);

AppAccessPolicy _writePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['DOCTOR']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.operationsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _readOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTION']),
      permissions: <AppPermission>{AppPermissions.clinicalRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubRepository(
  _MockIpdRepository repository, {
  required List<IpdAdmissionSummary> items,
  IpdAdmissionDetail? detail,
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((_) async {
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: const AppPageRequest(),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
  );
  when(() => repository.getAdmission(any())).thenAnswer((_) async {
    return Result<IpdAdmissionDetail>.success(
      detail ?? IpdAdmissionDetail(summary: items.first),
    );
  });
}

Future<void> _pumpIpd(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  AppAccessPolicy? accessPolicy,
  String initialLocation = '/ipd',
  IpdAdmissionQuery? initialQuery,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery:
                  initialQuery ?? IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _writePolicy(),
        ),
      ],
      child: MaterialApp.router(
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
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  testWidgets('tab strip has no Refresh control', (WidgetTester tester) async {
    _stubRepository(repository, items: <IpdAdmissionSummary>[_pendingBed]);
    await _pumpIpd(tester, repository: repository);

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('assign-bed next-action opens assign dialog without detail', (
    WidgetTester tester,
  ) async {
    _stubRepository(repository, items: <IpdAdmissionSummary>[_pendingBed]);
    await _pumpIpd(tester, repository: repository);

    expect(find.byType(IpdBoardNextActionCell), findsOneWidget);
    await tester.tap(find.text('Assign bed'));
    await tester.pumpAndSettle();

    expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
    expect(find.text('ADMISSION DETAIL'), findsNothing);
  });

  testWidgets('detail omits assign-bed when it is the row next-action', (
    WidgetTester tester,
  ) async {
    _stubRepository(repository, items: <IpdAdmissionSummary>[_pendingBed]);
    await _pumpIpd(tester, repository: repository);

    await tester.tap(find.text('Pat Pending'));
    await tester.pumpAndSettle();

    expect(find.text('ADMISSION DETAIL'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text('Assign bed'),
      ),
      findsNothing,
    );
  });

  testWidgets('unauthorized user has no start admission or assign next-action', (
    WidgetTester tester,
  ) async {
    _stubRepository(repository, items: <IpdAdmissionSummary>[_pendingBed]);
    await _pumpIpd(
      tester,
      repository: repository,
      accessPolicy: _readOnlyPolicy(),
    );

    expect(find.byTooltip('Start admission'), findsNothing);
    expect(find.text('Assign bed'), findsNothing);
  });

  testWidgets('transfer panel deep link opens transfer dialog without detail', (
    WidgetTester tester,
  ) async {
    _stubRepository(
      repository,
      items: <IpdAdmissionSummary>[_transferPending],
      detail: _transferDetail,
    );
    await _pumpIpd(
      tester,
      repository: repository,
      initialLocation: '/ipd?id=adm-xfer&panel=transfers',
      initialQuery: IpdAdmissionQuery.fromUri(
        Uri.parse('/ipd?id=adm-xfer&panel=transfers'),
      ),
    );

    expect(find.text('Manage transfer'), findsOneWidget);
    expect(find.text('ADMISSION DETAIL'), findsNothing);
  });

  test('ipdBoardNextActionKind maps stage and nextStep', () {
    expect(
      ipdBoardNextActionKind(_pendingBed),
      IpdBoardNextActionKind.assignBed,
    );
    expect(
      ipdBoardNextActionKind(_transferPending),
      IpdBoardNextActionKind.manageTransfer,
    );
    expect(
      ipdBoardNextActionKind(
        const IpdAdmissionSummary(
          id: 'a',
          stage: 'ADMITTED_IN_BED',
          nextStep: 'CONTINUE_CARE',
        ),
      ),
      IpdBoardNextActionKind.continueCare,
    );
  });

  test('query parses focusAction and hasFocusedMutation', () {
    final IpdAdmissionQuery query = IpdAdmissionQuery.fromUri(
      Uri.parse('/ipd?admissionId=adm-1&action=approve'),
    );
    expect(query.focusAdmissionId, 'adm-1');
    expect(query.focusAction, 'approve');
    expect(query.hasFocusedMutation, isTrue);
  });
}
