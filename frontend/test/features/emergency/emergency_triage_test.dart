import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/emergency/data/dtos/emergency_dtos.dart';
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/app_triage_components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_harness.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(_untreatedDetail());
    registerFallbackValue(_untreatedDetail().summary);
  });

  test('triage DTOs prefer public identifiers over internal IDs', () {
    final EmergencyTriageAssessment triage =
        const EmergencyTriageAssessmentDto(<String, Object?>{
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'human_friendly_id': 'TRA000001',
          'emergency_case_id': 'EME000001',
          'triage_level': 'LEVEL_1',
          'notes': 'Airway risk',
        }).toEntity();

    expect(triage.id, 'TRA000001');
    expect(triage.emergencyCaseId, 'EME000001');
    expect(triage.triageLevel, 'LEVEL_1');
    expect(triage.notes, 'Airway risk');
  });

  group('EmergencyWorkspaceController recordTriage', () {
    test(
      'patches detail triage and board summary after persistence',
      () async {
        final _MockEmergencyRepository repository = _MockEmergencyRepository();
        _stubInitialLoad(repository);
        var persisted = false;
        when(() => repository.loadEmergencyDetail(any())).thenAnswer(
          (_) async => Result<EmergencyCaseDetail>.success(
            persisted ? _triagedDetail() : _untreatedDetail(),
          ),
        );
        when(
          () => repository.recordTriage(
            detail: any(named: 'detail'),
            triageLevel: 'LEVEL_1',
            notes: 'Airway risk',
          ),
        ).thenAnswer((_) async {
          persisted = true;
          return Result<EmergencyCaseDetail>.success(_triagedDetail());
        });
        final ProviderContainer container = _container(repository);
        await container.read(emergencyWorkspaceControllerProvider.future);
        await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .selectCase(_untreatedDetail().summary);

        final AppFailure? failure = await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .recordTriage(triageLevel: 'LEVEL_1', notes: 'Airway risk');

        final EmergencyWorkspaceState state = _state(container);
        expect(failure, isNull);
        expect(state.selectedDetail?.latestTriage?.id, 'TRA000002');
        expect(state.selectedDetail?.latestTriage?.triageLevel, 'LEVEL_1');
        expect(state.selectedDetail?.latestTriage?.notes, 'Airway risk');
        expect(state.board.items.single.latestTriage?.id, 'TRA000002');
        expect(state.board.items.single.triageLevel, 'LEVEL_1');
        expect(state.isSaving, isFalse);
      },
    );

    test('keeps detail and queue unchanged when persistence fails', () async {
      final _MockEmergencyRepository repository = _MockEmergencyRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(
        () => repository.recordTriage(
          detail: any(named: 'detail'),
          triageLevel: 'LEVEL_1',
          notes: 'Airway risk',
        ),
      ).thenAnswer(
        (_) async => const Result<EmergencyCaseDetail>.failure(expectedFailure),
      );
      final ProviderContainer container = _container(repository);
      await container.read(emergencyWorkspaceControllerProvider.future);
      await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .selectCase(_untreatedDetail().summary);

      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .recordTriage(triageLevel: 'LEVEL_1', notes: 'Airway risk');

      final EmergencyWorkspaceState state = _state(container);
      expect(failure, expectedFailure);
      expect(state.selectedDetail?.latestTriage, isNull);
      expect(state.board.items.single.latestTriage, isNull);
      expect(state.lastFailure, expectedFailure);
      expect(state.isSaving, isFalse);
    });
  });

  testWidgets(
    'triage dialog blocks dismissal and preserves notes after failure',
    (WidgetTester tester) async {
      final Completer<AppFailure?> completer = Completer<AppFailure?>();
      AppTriageActionInput? submitted;

      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: Icons.monitor_heart_outlined,
              onPressed: () {
                unawaited(
                  showAppTriageActionDialog<bool>(
                    context: context,
                    builder: (_) => AppTriageActionDialog(
                      title: 'Record triage',
                      semanticLabel: 'Record emergency triage assessment',
                      submitLabel: 'Save triage',
                      requiredMessage: 'Required',
                      triageLevelLabel: 'Triage level',
                      triageLevelOptions: const <AppTriageOption>[
                        AppTriageOption(value: 'LEVEL_1', label: 'Level 1'),
                        AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                      ],
                      initialTriageLevel: 'LEVEL_2',
                      notesLabel: 'Triage notes',
                      initialNotes: 'Draft note',
                      onSubmit: (AppTriageActionInput input) {
                        submitted = input;
                        return completer.future;
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(390, 700),
        padding: EdgeInsets.zero,
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('RECORD TRIAGE'), findsOneWidget);
      expect(find.text('Draft note'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.save), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final Finder notesField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppTextField && widget.labelText == 'Triage notes',
      );
      await tester.enterText(notesField, 'Airway risk');
      await tester.tap(find.text('Save triage'));
      await tester.pump();

      expect(submitted?.notes, 'Airway risk');
      expect(_button(tester, 'Cancel').enabled, isFalse);
      expect(_button(tester, 'Save triage').isLoading, isTrue);
      expect(find.byType(AppTriageActionDialog), findsOneWidget);

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(AppTriageActionDialog), findsOneWidget);
      expect(find.text('Airway risk'), findsOneWidget);
      expect(_button(tester, 'Cancel').enabled, isTrue);
      expect(find.byType(AppFormInformationBanner), findsOneWidget);
    },
  );

  testWidgets('triage dialog cancel leaves no persisted state', (
    WidgetTester tester,
  ) async {
    var submitted = false;

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            leadingIcon: Icons.monitor_heart_outlined,
            onPressed: () {
              unawaited(
                showAppTriageActionDialog<bool>(
                  context: context,
                  builder: (_) => AppTriageActionDialog(
                    title: 'Record triage',
                    submitLabel: 'Save triage',
                    requiredMessage: 'Required',
                    triageLevelLabel: 'Triage level',
                    triageLevelOptions: const <AppTriageOption>[
                      AppTriageOption(value: 'LEVEL_2', label: 'Level 2'),
                    ],
                    notesLabel: 'Triage notes',
                    onSubmit: (_) async {
                      submitted = true;
                      return null;
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      size: const Size(800, 500),
      padding: EdgeInsets.zero,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final Finder notesField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppTextField && widget.labelText == 'Triage notes',
    );
    await tester.enterText(notesField, 'Should not save');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
    expect(find.byType(AppTriageActionDialog), findsNothing);
  });
}

AppButton _button(WidgetTester tester, String label) {
  return tester.widget<AppButton>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AppButton && widget.label == label,
    ),
  );
}

ProviderContainer _container(_MockEmergencyRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Object?>[
      emergencyRepositoryProvider.overrideWithValue(repository),
    ].cast(),
  );
  addTearDown(container.dispose);
  return container;
}

void _stubInitialLoad(_MockEmergencyRepository repository) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
      Result<AppPage<EmergencyCaseSummary>>.success(
        AppPage<EmergencyCaseSummary>(
          items: <EmergencyCaseSummary>[_untreatedDetail().summary],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(_untreatedDetail()),
  );
}

EmergencyWorkspaceState _state(ProviderContainer container) {
  return container
      .read(emergencyWorkspaceControllerProvider)
      .requireValue
      .when(
        success: (EmergencyWorkspaceState state) => state,
        failure: (AppFailure failure) => throw StateError(failure.code),
      );
}

EmergencyCaseDetail _untreatedDetail() {
  return const EmergencyCaseDetail(
    summary: EmergencyCaseSummary(
      id: 'EME000001',
      displayId: 'EME000001',
      patientId: 'PAT000001',
      patientDisplayId: 'PAT000001',
      patientDisplayName: 'Jane Doe',
      severity: 'HIGH',
      status: 'OPEN',
    ),
  );
}

EmergencyCaseDetail _triagedDetail() {
  const EmergencyTriageAssessment triage = EmergencyTriageAssessment(
    id: 'TRA000002',
    displayId: 'TRA000002',
    emergencyCaseId: 'EME000001',
    triageLevel: 'LEVEL_1',
    notes: 'Airway risk',
  );
  final EmergencyCaseDetail original = _untreatedDetail();
  return original.copyWith(
    summary: original.summary.copyWith(latestTriage: triage),
    triageAssessments: const <EmergencyTriageAssessment>[triage],
  );
}
