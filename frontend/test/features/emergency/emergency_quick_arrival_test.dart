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
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_harness.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(
      const EmergencyQuickArrivalInput(
        firstName: '',
        lastName: '',
        severity: 'CRITICAL',
      ),
    );
    registerFallbackValue(const EmergencyCaseSummary(id: 'EME000001'));
  });

  group('EmergencyQuickArrivalDto', () {
    test('maps the persisted aggregate using public identifiers', () {
      final EmergencyCaseDetail detail = EmergencyQuickArrivalDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'emergency_case': <String, Object?>{
              'human_friendly_id': 'EME000001',
              'patient_id': 'PAT000001',
              'patient_display_name': 'Jane Doe',
              'severity': 'CRITICAL',
              'status': 'OPEN',
            },
            'triage_assessment': <String, Object?>{
              'human_friendly_id': 'TRA000001',
              'emergency_case_id': 'EME000001',
              'triage_level': 'LEVEL_2',
            },
            'emergency_response': <String, Object?>{
              'human_friendly_id': 'ERS000001',
              'emergency_case_id': 'EME000001',
              'notes': 'Chest pain',
            },
          },
        },
      ).toEntity();

      expect(detail.summary.id, 'EME000001');
      expect(detail.summary.patientId, 'PAT000001');
      expect(detail.latestTriage?.id, 'TRA000001');
      expect(detail.latestResponse?.id, 'ERS000001');
    });
  });

  group('EmergencyWorkspaceController quick arrival', () {
    test(
      'patches board, selected detail, and derived badges on success',
      () async {
        final _MockEmergencyRepository repository = _MockEmergencyRepository();
        _stubInitialLoad(repository);
        final EmergencyCaseDetail created = _createdDetail();
        when(
          () => repository.createQuickArrival(any()),
        ).thenAnswer((_) async => Result<EmergencyCaseDetail>.success(created));
        final ProviderContainer container = _container(repository);

        await container.read(emergencyWorkspaceControllerProvider.future);
        final AppFailure? failure = await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .createQuickArrival(
              const EmergencyQuickArrivalInput(
                firstName: 'Jane',
                lastName: 'Doe',
                severity: 'CRITICAL',
                triageLevel: 'LEVEL_2',
              ),
            );

        final EmergencyWorkspaceState state = _state(container);
        expect(failure, isNull);
        expect(state.board.items.single.id, 'EME000001');
        expect(state.selectedDetail?.summary.id, 'EME000001');
        expect(state.activeCount, 1);
        expect(state.criticalCount, 1);
        expect(state.isSaving, isFalse);
      },
    );

    test('keeps all slices unchanged when persistence fails', () async {
      final _MockEmergencyRepository repository = _MockEmergencyRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(() => repository.createQuickArrival(any())).thenAnswer(
        (_) async => const Result<EmergencyCaseDetail>.failure(expectedFailure),
      );
      final ProviderContainer container = _container(repository);

      await container.read(emergencyWorkspaceControllerProvider.future);
      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .createQuickArrival(
            const EmergencyQuickArrivalInput(
              firstName: 'Jane',
              lastName: 'Doe',
              severity: 'CRITICAL',
            ),
          );

      final EmergencyWorkspaceState state = _state(container);
      expect(failure, expectedFailure);
      expect(state.board.items, isEmpty);
      expect(state.selectedDetail, isNull);
      expect(state.activeCount, 0);
      expect(state.lastFailure, expectedFailure);
      expect(state.isSaving, isFalse);
    });
  });

  testWidgets(
    'dialog preserves input and blocks dismissal while submission is pending',
    (WidgetTester tester) async {
      final Completer<AppFailure?> completer = Completer<AppFailure?>();
      EmergencyQuickArrivalInput? submitted;

      await pumpLocalizedWidget(
        tester,
        QuickArrivalDialog(
          onSubmit: (EmergencyQuickArrivalInput input) {
            submitted = input;
            return completer.future;
          },
        ),
        size: const Size(390, 700),
        padding: EdgeInsets.zero,
      );

      await tester.enterText(find.byType(TextFormField).first, 'Jane');
      await tester.enterText(find.byType(TextFormField).last, 'Chest pain');
      await tester.tap(find.text('Open case'));
      await tester.pump();

      expect(submitted?.firstName, 'Jane');
      expect(submitted?.notes, 'Chest pain');
      expect(
        tester
            .widget<AppButton>(
              find.byWidgetPredicate(
                (Widget widget) =>
                    widget is AppButton && widget.label == 'Cancel',
              ),
            )
            .enabled,
        isFalse,
      );

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(QuickArrivalDialog), findsOneWidget);
      expect(find.text('Jane'), findsOneWidget);
      expect(find.text('Chest pain'), findsOneWidget);
    },
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
          items: const <EmergencyCaseSummary>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(_createdDetail()),
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

EmergencyCaseDetail _createdDetail() {
  return const EmergencyCaseDetail(
    summary: EmergencyCaseSummary(
      id: 'EME000001',
      displayId: 'EME000001',
      patientId: 'PAT000001',
      patientDisplayId: 'PAT000001',
      patientDisplayName: 'Jane Doe',
      severity: 'CRITICAL',
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
