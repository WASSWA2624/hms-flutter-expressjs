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
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_transfer_update_dialog.dart';
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
  stage: 'TRANSFER_REQUESTED',
  transferStatus: 'REQUESTED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
  openTransferRequestId: 'tr-1',
);

const IpdAdmissionDetail _admission = IpdAdmissionDetail(
  summary: _admissionSummary,
  openTransferRequest: IpdTransferRequest(
    id: 'tr-1',
    status: 'REQUESTED',
  ),
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

const List<IpdBedOption> _beds = <IpdBedOption>[
  IpdBedOption(
    id: 'bed-2',
    label: 'Bed 2',
    wardId: 'ward-b',
    wardName: 'Ward B',
  ),
  IpdBedOption(
    id: 'bed-3',
    label: 'Bed 3',
    wardId: 'ward-c',
    wardName: 'Ward C',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets(
    'uses AppTransferUpdateDialog with Cancel and Edit chrome',
    (WidgetTester tester) async {
      final _MockIpdRepository repository = _MockIpdRepository();
      _stubWorkspaceLoad(repository);

      await _pumpDialog(tester, repository: repository);

      expect(find.byType(AppTransferUpdateDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('MANAGE TRANSFER'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.transfer), findsWidgets);
      expect(find.byIcon(AppActionIcons.edit), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);

      final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
        find.byType(AppSelectField<String>).first,
      );
      expect(field.labelText, 'Transfer action');
      expect(field.value, AppTransferUpdateActions.approve);
    },
  );

  testWidgets('title never uses the patient display name', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(tester, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Manage transfer');
    expect(find.text('MANAGE TRANSFER'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('Cancel pops false without mutating transfer state', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    _stubWorkspaceLoad(repository);
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await _pumpDialogFrames(tester);

    expect(result, isFalse);
    verifyNever(() => repository.updateTransfer(any(), any()));
  });

  testWidgets('failure keeps the dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    _stubWorkspaceLoad(repository);
    when(() => repository.updateTransfer(any(), any())).thenAnswer(
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

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await _pumpDialogFrames(tester);

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    verify(() => repository.updateTransfer('adm-1', any())).called(1);
  });

  testWidgets('successful save pops true after persisted transfer update', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    Map<String, Object?>? payload;
    _stubWorkspaceLoad(repository);
    when(() => repository.updateTransfer(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments[1] as Map<String, Object?>;
      final IpdAdmissionSummary approved = IpdAdmissionSummary(
        id: 'adm-1',
        displayId: 'ADM-1',
        patientId: 'pat-1',
        patientDisplayName: 'Jane Doe',
        stage: 'TRANSFER_REQUESTED',
        transferStatus: 'APPROVED',
        admissionStatus: 'ADMITTED',
        hasActiveBed: true,
        openTransferRequestId: 'tr-1',
      );
      when(() => repository.listAdmissions(any())).thenAnswer(
        (Invocation listInvocation) async =>
            Result<AppPage<IpdAdmissionSummary>>.success(
              AppPage<IpdAdmissionSummary>(
                items: <IpdAdmissionSummary>[approved],
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
          summary: approved,
          openTransferRequest: const IpdTransferRequest(
            id: 'tr-1',
            status: 'APPROVED',
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

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await _pumpDialogFrames(tester);

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(payload?['action'], AppTransferUpdateActions.approve);
    expect(payload?['transfer_request_id'], 'tr-1');
    verify(() => repository.updateTransfer('adm-1', any())).called(1);
  });

  testWidgets('defaults to COMPLETE for in-progress transfer and requires bed', (
    WidgetTester tester,
  ) async {
    final _MockIpdRepository repository = _MockIpdRepository();
    Map<String, Object?>? payload;
    _stubWorkspaceLoad(repository);
    when(() => repository.updateTransfer(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments[1] as Map<String, Object?>;
      return const Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'adm-1',
            displayId: 'ADM-1',
            patientId: 'pat-1',
            patientDisplayName: 'Jane Doe',
            stage: 'ADMITTED_IN_BED',
            admissionStatus: 'ADMITTED',
            hasActiveBed: true,
          ),
        ),
      );
    });
    bool? result;

    await _pumpDialog(
      tester,
      repository: repository,
      admission: const IpdAdmissionDetail(
        summary: IpdAdmissionSummary(
          id: 'adm-1',
          displayId: 'ADM-1',
          patientId: 'pat-1',
          patientDisplayName: 'Jane Doe',
          stage: 'TRANSFER_IN_PROGRESS',
          transferStatus: 'IN_PROGRESS',
          admissionStatus: 'ADMITTED',
          hasActiveBed: true,
          openTransferRequestId: 'tr-1',
        ),
        openTransferRequest: IpdTransferRequest(
          id: 'tr-1',
          status: 'IN_PROGRESS',
        ),
      ),
      onResult: (bool? value) => result = value,
    );

    final Finder fields = find.byType(AppSelectField<String>);
    expect(fields, findsNWidgets(2));

    final AppSelectField<String> actionField =
        tester.widget<AppSelectField<String>>(fields.first);
    expect(actionField.value, AppTransferUpdateActions.complete);
    expect(actionField.labelText, 'Transfer action');

    final AppSelectField<String> bedField =
        tester.widget<AppSelectField<String>>(fields.at(1));
    expect(bedField.labelText, 'Destination bed');
    expect(bedField.hintText, 'Select a bed');
    bedField.onChanged?.call('bed-2');
    await tester.pump();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await _pumpDialogFrames(tester);

    expect(result, isTrue);
    expect(payload?['action'], AppTransferUpdateActions.complete);
    expect(payload?['to_bed_id'], 'bed-2');
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockIpdRepository repository = _MockIpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(
      tester,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppTransferUpdateDialog), findsOneWidget);
    expect(find.text('MANAGE TRANSFER'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });
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
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(_beds),
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

Future<void> _pumpDialog(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  IpdAdmissionDetail admission = _admission,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
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
                  label: 'Open transfer update',
                  leadingIcon: AppActionIcons.transfer,
                  onPressed: () async {
                    await ref.read(ipdWorkspaceControllerProvider.future);
                    if (!context.mounted) {
                      return;
                    }
                    final bool? value = await showAppDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => TransferUpdateDialog(
                        admission: admission,
                        beds: _beds,
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
  await tester.tap(find.widgetWithText(AppButton, 'Open transfer update'));
  await tester.pumpAndSettle();
}

Future<void> _pumpDialogFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}
