import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/emergency/data/dtos/emergency_dtos.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_harness.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(_awaitingResponseDetail());
    registerFallbackValue(_awaitingResponseDetail().summary);
  });

  test('response DTOs prefer public identifiers over internal IDs', () {
    final EmergencyResponseRecord response =
        const EmergencyResponseRecordDto(<String, Object?>{
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'human_friendly_id': 'ERS000001',
          'emergency_case_id': 'EME000001',
          'notes': 'Airway secured',
          'response_at': '2026-07-16T12:00:00.000Z',
        }).toEntity();

    expect(response.id, 'ERS000001');
    expect(response.emergencyCaseId, 'EME000001');
    expect(response.notes, 'Airway secured');
  });

  group('EmergencyWorkspaceController markResponse', () {
    test(
      'patches detail responses and queue response status after persistence',
      () async {
        final _MockEmergencyRepository repository = _MockEmergencyRepository();
        _stubInitialLoad(repository);
        var persisted = false;
        when(() => repository.loadEmergencyDetail(any())).thenAnswer(
          (_) async => Result<EmergencyCaseDetail>.success(
            persisted ? _respondedDetail() : _awaitingResponseDetail(),
          ),
        );
        when(
          () => repository.markResponse(
            detail: any(named: 'detail'),
            notes: 'Airway secured',
          ),
        ).thenAnswer((_) async {
          persisted = true;
          return Result<EmergencyCaseDetail>.success(_respondedDetail());
        });
        final ProviderContainer container = _container(repository);
        await container.read(emergencyWorkspaceControllerProvider.future);
        await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .selectCase(_awaitingResponseDetail().summary);

        final AppFailure? failure = await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .markResponse(notes: 'Airway secured');

        final EmergencyWorkspaceState state = _state(container);
        expect(failure, isNull);
        expect(state.selectedDetail?.latestResponse?.id, 'ERS000002');
        expect(state.selectedDetail?.latestResponse?.notes, 'Airway secured');
        expect(state.board.items.single.latestResponse?.id, 'ERS000002');
        expect(state.board.items.single.responseStatus, 'RESPONDED');
        expect(state.isSaving, isFalse);
      },
    );

    test('keeps detail and queue unchanged when persistence fails', () async {
      final _MockEmergencyRepository repository = _MockEmergencyRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(
        () => repository.markResponse(
          detail: any(named: 'detail'),
          notes: 'Airway secured',
        ),
      ).thenAnswer(
        (_) async => const Result<EmergencyCaseDetail>.failure(expectedFailure),
      );
      final ProviderContainer container = _container(repository);
      await container.read(emergencyWorkspaceControllerProvider.future);
      await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .selectCase(_awaitingResponseDetail().summary);

      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .markResponse(notes: 'Airway secured');

      final EmergencyWorkspaceState state = _state(container);
      expect(failure, expectedFailure);
      expect(state.selectedDetail?.latestResponse, isNull);
      expect(state.board.items.single.latestResponse, isNull);
      expect(state.board.items.single.responseStatus, 'WAITING_RESPONSE');
      expect(state.lastFailure, expectedFailure);
      expect(state.isSaving, isFalse);
    });
  });

  testWidgets(
    'response dialog blocks dismissal and preserves notes after failure',
    (WidgetTester tester) async {
      final Completer<AppFailure?> completer = Completer<AppFailure?>();
      String? submitted;

      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              leadingIcon: Icons.medical_services_outlined,
              onPressed: () {
                unawaited(
                  showEmergencyResponseDialog(
                    context: context,
                    initialNotes: 'Draft note',
                    onSubmit: (String notes) {
                      submitted = notes;
                      return completer.future;
                    },
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

      expect(find.text('RESPONSE'), findsOneWidget);
      expect(find.text('Draft note'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Airway secured');
      await tester.tap(find.text('Mark response'));
      await tester.pump();

      expect(submitted, 'Airway secured');
      expect(_button(tester, 'Cancel').enabled, isFalse);
      expect(_button(tester, 'Mark response').isLoading, isTrue);
      expect(find.byType(AppTextActionDialog), findsOneWidget);

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(AppTextActionDialog), findsOneWidget);
      expect(find.text('Airway secured'), findsOneWidget);
      expect(_button(tester, 'Cancel').enabled, isTrue);
      expect(find.byType(AppFormInformationBanner), findsOneWidget);
    },
  );

  testWidgets('response dialog cancel leaves no persisted state', (
    WidgetTester tester,
  ) async {
    var submitted = false;

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            leadingIcon: Icons.medical_services_outlined,
            onPressed: () {
              unawaited(
                showEmergencyResponseDialog(
                  context: context,
                  onSubmit: (String notes) async {
                    submitted = true;
                    return null;
                  },
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
    await tester.enterText(find.byType(EditableText), 'Should not save');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
    expect(find.byType(AppTextActionDialog), findsNothing);
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
          items: <EmergencyCaseSummary>[_awaitingResponseDetail().summary],
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
    (_) async => Result<EmergencyCaseDetail>.success(_awaitingResponseDetail()),
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

EmergencyCaseDetail _awaitingResponseDetail() {
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
    triageAssessments: <EmergencyTriageAssessment>[
      EmergencyTriageAssessment(
        id: 'TRA000001',
        emergencyCaseId: 'EME000001',
        triageLevel: 'LEVEL_2',
      ),
    ],
  );
}

EmergencyCaseDetail _respondedDetail() {
  const EmergencyResponseRecord response = EmergencyResponseRecord(
    id: 'ERS000002',
    displayId: 'ERS000002',
    emergencyCaseId: 'EME000001',
    notes: 'Airway secured',
  );
  final EmergencyCaseDetail original = _awaitingResponseDetail();
  return original.copyWith(
    summary: original.summary.copyWith(latestResponse: response),
    responses: const <EmergencyResponseRecord>[response],
  );
}
