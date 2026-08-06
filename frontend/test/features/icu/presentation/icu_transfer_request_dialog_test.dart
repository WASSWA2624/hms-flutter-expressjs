import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _summary = IcuPatientSummary(
  id: 'ADM-1',
  admissionId: 'ADM-1',
  displayId: 'ADM0001',
  patientDisplayName: 'Patient Example',
  wardName: 'ICU A',
  icuStatus: 'ACTIVE',
  hasActiveBed: true,
);

const IcuPatientDetail _detail = IcuPatientDetail(
  summary: _summary,
  activeStay: IcuStaySummary(id: 'ICU-1'),
);

const IcuReferenceData _referenceData = IcuReferenceData(
  wards: <IcuWardOption>[
    IcuWardOption(id: 'ward-icu', name: 'ICU A', wardType: 'ICU'),
    IcuWardOption(id: 'ward-b', name: 'Ward B', wardType: 'GENERAL'),
    IcuWardOption(id: 'ward-c', name: 'Ward C', wardType: 'SURGICAL'),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(_summary);
    registerFallbackValue(_detail);
  });

  testWidgets(
    'openIcuTransferDialog uses shared transfer chrome and excludes current ward',
    (WidgetTester tester) async {
      final _MockIcuRepository repository = _MockIcuRepository();
      await _pumpOpenTransfer(tester, repository: repository);

      expect(find.byType(AppTransferRequestDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('REQUEST TRANSFER'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Request transfer'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.text('PATIENT EXAMPLE'), findsNothing);
      expect(find.text('Patient Example'), findsNothing);

      final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
        find.byType(AppSelectField<String>),
      );
      expect(
        field.options.map((AppSelectOption<String> option) => option.value),
        <String>['ward-b', 'ward-c'],
      );
    },
  );

  testWidgets('Close pops without requesting transfer', (
    WidgetTester tester,
  ) async {
    final _MockIcuRepository repository = _MockIcuRepository();
    await _pumpOpenTransfer(tester, repository: repository);

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repository.requestTransfer(
        detail: any(named: 'detail'),
        toWardId: any(named: 'toWardId'),
        fromWardId: any(named: 'fromWardId'),
      ),
    );
  });

  testWidgets('failure keeps dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockIcuRepository repository = _MockIcuRepository();
    when(
      () => repository.requestTransfer(
        detail: any(named: 'detail'),
        toWardId: any(named: 'toWardId'),
        fromWardId: any(named: 'fromWardId'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result<IcuPatientDetail>.failure(AppFailure.network()),
    );

    await _pumpOpenTransfer(tester, repository: repository);

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-b');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    verify(
      () => repository.requestTransfer(
        detail: any(named: 'detail'),
        toWardId: 'ward-b',
        fromWardId: 'ward-icu',
      ),
    ).called(1);

    final Result<IcuWorkspaceState> result = ProviderScope.containerOf(
      tester.element(find.byType(AppDialog)),
    ).read(icuWorkspaceControllerProvider).requireValue;
    final IcuWorkspaceState state = result.when(
      success: (IcuWorkspaceState value) => value,
      failure: (AppFailure failure) => fail(failure.code),
    );
    expect(state.selectedDetail?.transferRequests, isEmpty);
  });

  testWidgets('success requests transfer and dismisses dialog', (
    WidgetTester tester,
  ) async {
    final _MockIcuRepository repository = _MockIcuRepository();
    when(
      () => repository.requestTransfer(
        detail: any(named: 'detail'),
        toWardId: any(named: 'toWardId'),
        fromWardId: any(named: 'fromWardId'),
      ),
    ).thenAnswer(
      (_) async => const Result<IcuPatientDetail>.success(
        IcuPatientDetail(
          summary: IcuPatientSummary(
            id: 'ADM-1',
            admissionId: 'ADM-1',
            displayId: 'ADM0001',
            patientDisplayName: 'Patient Example',
            wardName: 'ICU A',
            icuStatus: 'ACTIVE',
            transferStatus: 'REQUESTED',
            hasActiveBed: true,
          ),
          activeStay: IcuStaySummary(id: 'ICU-1'),
          transferRequests: <IcuTransferRequest>[
            IcuTransferRequest(
              id: 'TR-1',
              status: 'REQUESTED',
              fromWardName: 'ICU A',
              toWardName: 'Ward B',
            ),
          ],
        ),
      ),
    );

    await _pumpOpenTransfer(tester, repository: repository);

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-b');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    verify(
      () => repository.requestTransfer(
        detail: any(named: 'detail'),
        toWardId: 'ward-b',
        fromWardId: 'ward-icu',
      ),
    ).called(1);
  });
}

Future<void> _pumpOpenTransfer(
  WidgetTester tester, {
  required _MockIcuRepository repository,
}) async {
  _stubInitialLoad(repository);
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => const Result<IcuPatientDetail>.success(_detail),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        icuRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return Center(
                child: AppButton.primary(
                  label: 'Open transfer',
                  leadingIcon: AppActionIcons.transfer,
                  onPressed: () async {
                    final IcuWorkspaceController controller = ref.read(
                      icuWorkspaceControllerProvider.notifier,
                    );
                    await ref.read(icuWorkspaceControllerProvider.future);
                    await controller.selectPatient(_summary);
                    if (!context.mounted) {
                      return;
                    }
                    await openIcuTransferDialog(context, _referenceData);
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AppButton, 'Open transfer'));
  await tester.pumpAndSettle();
}

void _stubInitialLoad(_MockIcuRepository repository) {
  when(() => repository.listIcuBoard(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: const <IcuPatientSummary>[_summary],
        request: (invocation.positionalArguments.single as IcuBoardQuery)
            .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(_referenceData),
  );
}
