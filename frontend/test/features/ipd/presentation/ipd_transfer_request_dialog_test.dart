import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_transfer_request_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _admissionSummary = IpdAdmissionSummary(
  id: 'adm-1',
  displayId: 'ADM-1',
  patientId: 'pat-1',
  patientDisplayName: 'Jane Doe',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
);

const IpdAdmissionDetail _admission = IpdAdmissionDetail(
  summary: _admissionSummary,
  activeBedAssignment: IpdBedAssignment(
    id: 'ba-1',
    bed: IpdBedOption(
      id: 'bed-1',
      label: 'Bed 1',
      wardId: 'ward-a',
      wardName: 'Ward A',
    ),
  ),
);

const List<IpdWardOption> _wards = <IpdWardOption>[
  IpdWardOption(id: 'ward-a', name: 'Ward A', wardType: 'GENERAL'),
  IpdWardOption(id: 'ward-b', name: 'Ward B', wardType: 'SURGICAL'),
  IpdWardOption(id: 'ward-c', name: 'Ward C', wardType: 'ICU'),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets(
    'uses AppTransferRequestDialog with Cancel and Request transfer chrome',
    (WidgetTester tester) async {
      final _MockIpdRepository repository = _MockIpdRepository();
      await _pumpDialog(tester, repository: repository);

      expect(find.byType(AppTransferRequestDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('REQUEST TRANSFER'), findsOneWidget);
      expect(find.text('Request transfer'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);

      final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
        find.byType(AppSelectField<String>),
      );
      expect(field.labelText, 'Target ward');
      expect(field.hintText, 'Select a ward');
      expect(
        field.options.map((AppSelectOption<String> option) => option.value),
        <String>['ward-b', 'ward-c'],
      );
      expect(field.options.map((AppSelectOption<String> o) => o.label), [
        'Ward B | Surgical',
        'Ward C | Icu',
      ]);
    },
  );

  testWidgets('title never uses the patient display name', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    await _pumpDialog(tester, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Request transfer');
    expect(find.text('REQUEST TRANSFER'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Cancel pops false without mutating transfer state', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.requestTransfer(any(), any()));
  });

  testWidgets('failure keeps the dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    when(() => repository.requestTransfer(any(), any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.failure(
        AppFailure.network(),
      ),
    );
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-b');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Request transfer'), findsOneWidget);
    verify(() => repository.requestTransfer('adm-1', any())).called(1);
  });

  testWidgets('successful save pops true after persisted transfer request', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    Map<String, Object?>? payload;
    when(() => repository.requestTransfer(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments[1] as Map<String, Object?>;
      final IpdAdmissionSummary transferred = IpdAdmissionSummary(
        id: 'adm-1',
        displayId: 'ADM-1',
        patientId: 'pat-1',
        patientDisplayName: 'Jane Doe',
        stage: 'TRANSFER_REQUESTED',
        transferStatus: 'REQUESTED',
        admissionStatus: 'ADMITTED',
        hasActiveBed: true,
        openTransferRequestId: 'tr-1',
      );
      when(() => repository.listAdmissions(any())).thenAnswer(
        (Invocation listInvocation) async =>
            Result<AppPage<IpdAdmissionSummary>>.success(
              AppPage<IpdAdmissionSummary>(
                items: <IpdAdmissionSummary>[transferred],
                request:
                    (listInvocation.positionalArguments.single
                            as IpdAdmissionQuery)
                        .pageRequest,
                totalItemCount: 1,
              ),
            ),
      );
      when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
      return Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: transferred,
          openTransferRequest: const IpdTransferRequest(
            id: 'tr-1',
            status: 'REQUESTED',
          ),
        ),
      );
    });
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('ward-b');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Request transfer'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(payload?['from_ward_id'], 'ward-a');
    expect(payload?['to_ward_id'], 'ward-b');
    expect(payload?['requested_at'], isA<String>());
    verify(() => repository.requestTransfer('adm-1', any())).called(1);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockIpdRepository repository = _MockIpdRepository();
    await _pumpDialog(
      tester,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppTransferRequestDialog), findsOneWidget);
    expect(find.text('REQUEST TRANSFER'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Request transfer'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required IpdRepository repository,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  _stubWorkspaceLoad(repository as _MockIpdRepository);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        ipdRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return Center(
                child: AppButton.primary(
                  label: 'Open transfer',
                  leadingIcon: AppActionIcons.transfer,
                  onPressed: () async {
                    await ref.read(ipdWorkspaceControllerProvider.future);
                    if (!context.mounted) {
                      return;
                    }
                    final bool? value = await showAppDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const TransferRequestDialog(
                        admission: _admission,
                        wards: _wards,
                      ),
                    );
                    onResult?.call(value);
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

void _stubWorkspaceLoad(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[_admissionSummary],
        request:
            (invocation.positionalArguments.single as IpdAdmissionQuery)
                .pageRequest,
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(_wards),
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
    (_) async => const Result<List<IpdBedBoardEntry>>.success(
      <IpdBedBoardEntry>[],
    ),
  );
}
