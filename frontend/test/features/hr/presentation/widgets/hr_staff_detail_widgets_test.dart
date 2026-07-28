import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_actions.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_overview.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_info_sheet.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const HrStaffProfile _profile = HrStaffProfile(
  id: 'uuid-avery',
  displayId: 'STF-AVERY',
  staffNumber: 'EMP-AVERY',
  position: 'Registered Nurse',
  practitionerType: 'NURSE',
  departmentName: 'Emergency',
  userId: 'user-1',
  userDisplayId: 'USR-1',
  userFullName: 'Avery Demo',
  userEmail: 'avery@example.com',
);

final HrStaffProfile _profileWithHireDate = _profile.copyWith(
  hireDate: DateTime(2024, 3, 15),
);

AppAccessPolicy _hrWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['HR']),
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.rosterWrite,
        AppPermissions.financialApprove,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

HrWorkspaceState _workspaceState() {
  return const HrWorkspaceState(
    overview: HrWorkspaceOverview(),
    staffQuery: HrStaffQuery(),
    staff: AppPage<HrStaffProfile>(
      items: <HrStaffProfile>[_profile],
      request: AppPageRequest(),
    ),
    workItemsQuery: HrWorkItemsQuery(),
    workItems: AppPage<HrWorkItem>(
      items: <HrWorkItem>[],
      request: AppPageRequest(pageSize: 10),
    ),
    referenceData: HrReferenceData(),
  );
}

HrStaffDetail _staffDetail() {
  return const HrStaffDetail(profile: _profile);
}

Future<void> _pumpHrDetailWidgets(
  WidgetTester tester, {
  required Size viewport,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_hrWritePolicy()),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: viewport.width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('HrStaffDetailOverview shows sheet rows without staff name', (
    WidgetTester tester,
  ) async {
    await _pumpHrDetailWidgets(
      tester,
      viewport: const Size(800, 600),
      child: HrStaffDetailOverview(profile: _profileWithHireDate),
    );

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('EMP-AVERY'), findsOneWidget);
    expect(find.text('Registered Nurse'), findsOneWidget);
    expect(find.text('Linked user'), findsOneWidget);
    expect(find.text('USR-1'), findsOneWidget);
    expect(find.text('avery@example.com'), findsOneWidget);
    expect(find.text('Avery Demo'), findsNothing);
    expect(find.byType(AppInfoSheetGrid), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HrStaffDetailOverview stacks at narrow width', (
    WidgetTester tester,
  ) async {
    await _pumpHrDetailWidgets(
      tester,
      viewport: const Size(360, 600),
      child: HrStaffDetailOverview(profile: _profileWithHireDate),
    );

    expect(find.text('EMP-AVERY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HrStaffDetailActions uses single section without group titles', (
    WidgetTester tester,
  ) async {
    await _pumpHrDetailWidgets(
      tester,
      viewport: const Size(800, 600),
      child: HrStaffDetailActions(
        state: _workspaceState(),
        detail: _staffDetail(),
        onAssignDepartment: (_, _) {},
        onAssignPosition: (_, _, _) {},
        onRecordAvailability: (_, _) {},
        onAssignShift: (_, _) {},
        onSwapShift: (_, _) {},
        onRequestLeave: (_, _) {},
        onCompensation: (_, _, _) {},
        onRunPayroll: (_, _, _) {},
        onAssignRole: (_, _, _) {},
        onModuleAccess: (_, _) {},
        onOffboardStaff: (_, _, _) {},
      ),
    );

    expect(find.text('Staff actions'), findsOneWidget);
    expect(find.text('Placement'), findsNothing);
    expect(find.text('Scheduling'), findsNothing);
    expect(find.text('Payroll'), findsNothing);
    expect(find.text('Access'), findsNothing);
    expect(find.text('Assign department'), findsOneWidget);
    expect(find.text('Assign position'), findsOneWidget);
    expect(find.text('Record availability'), findsOneWidget);
    expect(find.text('Assign shift'), findsOneWidget);
    expect(find.text('Swap shift'), findsOneWidget);
    expect(find.text('Request leave'), findsOneWidget);
    expect(find.text('Compensation'), findsOneWidget);
    expect(find.text('Run payroll'), findsOneWidget);
    expect(find.text('End employment'), findsOneWidget);
    expect(find.text('Assign role'), findsOneWidget);
    expect(find.text('View module access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HrStaffDetailActions wraps buttons at narrow width', (
    WidgetTester tester,
  ) async {
    await _pumpHrDetailWidgets(
      tester,
      viewport: const Size(360, 800),
      child: HrStaffDetailActions(
        state: _workspaceState(),
        detail: _staffDetail(),
        onAssignDepartment: (_, _) {},
        onAssignPosition: (_, _, _) {},
        onRecordAvailability: (_, _) {},
        onAssignShift: (_, _) {},
        onSwapShift: (_, _) {},
        onRequestLeave: (_, _) {},
        onCompensation: (_, _, _) {},
        onRunPayroll: (_, _, _) {},
        onAssignRole: (_, _, _) {},
        onModuleAccess: (_, _) {},
        onOffboardStaff: (_, _, _) {},
      ),
    );

    expect(find.byType(Wrap), findsOneWidget);
    expect(find.textContaining('...'), findsNothing);
    expect(find.text('Assign department'), findsOneWidget);
    expect(find.text('View module access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
