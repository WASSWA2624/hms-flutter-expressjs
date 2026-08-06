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
    registerFallbackValue(_openDetail());
    registerFallbackValue(_openDetail().summary);
  });

  group('EmergencyWorkspaceQuery.fromUri', () {
    test('parses id and panel deep-link parameters', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?id=EME000001&panel=handoff'),
      );

      expect(query.caseId, 'EME000001');
      expect(query.panel, EmergencyDetailPanelFocus.handoff);
      expect(query.search, isEmpty);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('maps dispatch and trip aliases to the ambulance panel', () {
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?panel=dispatch'),
        ).panel,
        EmergencyDetailPanelFocus.ambulance,
      );
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?focus=trip'),
        ).panel,
        EmergencyDetailPanelFocus.ambulance,
      );
    });

    test('accepts alternate aliases for case id and search', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?case=EME000002&q=Jane'),
      );

      expect(query.caseId, 'EME000002');
      expect(query.search, 'Jane');
      expect(query.panel, EmergencyDetailPanelFocus.none);
    });

    test('accepts workflow encounterId as the case deep-link', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?encounterId=EME000099&panel=triage'),
      );

      expect(query.caseId, 'EME000099');
      expect(query.panel, EmergencyDetailPanelFocus.triage);
    });

    test('treats blank values as absent and reports no targeting', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?id=%20%20&panel=%20%20'),
      );

      expect(query.caseId, isEmpty);
      expect(query.panel, EmergencyDetailPanelFocus.none);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('parses scope from the query string', () {
      final EmergencyWorkspaceQuery query = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?scope=critical'),
      );

      expect(query.scope, 'critical');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('accepts board and tab aliases for scope', () {
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?board=ambulance'),
        ).scope,
        'ambulance',
      );
      expect(
        EmergencyWorkspaceQuery.fromUri(
          Uri.parse('/emergency?tab=handoff'),
        ).scope,
        'handoff',
      );
    });

    test('includes scope in the route signature', () {
      final EmergencyWorkspaceQuery withScope = EmergencyWorkspaceQuery.fromUri(
        Uri.parse('/emergency?scope=closed&search=Jane'),
      );
      final EmergencyWorkspaceQuery withoutScope =
          EmergencyWorkspaceQuery.fromUri(Uri.parse('/emergency?search=Jane'));

      expect(withScope.signature, contains('closed'));
      expect(withScope.signature, isNot(withoutScope.signature));
    });
  });

  group('EmergencyHandoffOutcome', () {
    test('builds a deep link for a receiving workflow', () {
      const EmergencyHandoffOutcome outcome = EmergencyHandoffOutcome(
        destination: 'IPD',
        route: 'ipd',
        receivingDisplayId: 'ADM000001',
      );

      expect(outcome.hasReceivingWork, isTrue);
      expect(outcome.receivingDeepLink, '/ipd?id=ADM000001');
    });

    test('terminal handoffs expose no receiving work or deep link', () {
      const EmergencyHandoffOutcome outcome = EmergencyHandoffOutcome(
        destination: 'REFERRAL',
        terminal: true,
      );

      expect(outcome.hasReceivingWork, isFalse);
      expect(outcome.receivingDeepLink, isNull);
    });
  });

  group('EmergencyCaseDto handoff mapping', () {
    test('parses a top-level handoff snapshot with billing deferred', () {
      final EmergencyCaseSummary summary = const EmergencyCaseDto(
        <String, Object?>{
          'id': '11111111-1111-1111-1111-111111111111',
          'display_id': 'EME000001',
          'severity': 'CRITICAL',
          'status': 'CLOSED',
          'handoff': <String, Object?>{
            'destination': 'IPD',
            'route': 'ipd',
            'receiving_display_id': 'ADM000001',
            'admission_display_id': 'ADM000001',
            'stage': 'WARD',
            'billing_deferred': true,
            'terminal': false,
            'handoff_at': '2026-06-25T08:00:00Z',
            'notes': 'Admitted to medical ward.',
          },
        },
      ).toEntity();

      final EmergencyHandoffOutcome? handoff = summary.handoff;
      expect(handoff, isNotNull);
      expect(handoff!.destination, 'IPD');
      expect(handoff.route, 'ipd');
      expect(handoff.receivingDisplayId, 'ADM000001');
      expect(handoff.billingDeferred, isTrue);
      expect(handoff.terminal, isFalse);
      expect(handoff.hasReceivingWork, isTrue);
      expect(handoff.receivingDeepLink, '/ipd?id=ADM000001');
      expect(handoff.handoffAt, isNotNull);
    });

    test('falls back to extension_json.handoff when not at top level', () {
      final EmergencyCaseSummary summary = const EmergencyCaseDto(
        <String, Object?>{
          'id': '22222222-2222-2222-2222-222222222222',
          'display_id': 'EME000002',
          'status': 'CLOSED',
          'extension_json': <String, Object?>{
            'handoff': <String, Object?>{
              'destination': 'OPD',
              'route': 'opd',
              'receiving_display_id': 'ENC000001',
              'stage': 'WAITING_VITALS',
              'billing_deferred': false,
            },
          },
        },
      ).toEntity();

      expect(summary.handoff, isNotNull);
      expect(summary.handoff!.destination, 'OPD');
      expect(summary.handoff!.receivingDeepLink, '/opd?id=ENC000001');
      expect(summary.handoff!.billingDeferred, isFalse);
    });

    test('returns no handoff when the case was never handed off', () {
      final EmergencyCaseSummary summary =
          const EmergencyCaseDto(<String, Object?>{
            'id': '33333333-3333-3333-3333-333333333333',
            'display_id': 'EME000003',
            'status': 'OPEN',
          }).toEntity();

      expect(summary.handoff, isNull);
    });
  });

  group('EmergencyWorkspaceController handoff', () {
    test(
      'patches detail, board row, and handoff count after persistence',
      () async {
        final _MockEmergencyRepository repository = _MockEmergencyRepository();
        _stubInitialLoad(repository);
        var persisted = false;
        when(() => repository.loadEmergencyDetail(any())).thenAnswer(
          (_) async => Result<EmergencyCaseDetail>.success(
            persisted ? _handedOffDetail() : _openDetail(),
          ),
        );
        when(
          () => repository.recordHandoff(
            detail: any(named: 'detail'),
            destination: 'OPD',
            notes: 'Ready for clinic',
            closeCase: true,
          ),
        ).thenAnswer((_) async {
          persisted = true;
          return Result<EmergencyCaseDetail>.success(_handedOffDetail());
        });
        when(() => repository.listEmergencyBoard(any())).thenAnswer((
          invocation,
        ) {
          final EmergencyBoardQuery query =
              invocation.positionalArguments.single as EmergencyBoardQuery;
          final EmergencyCaseSummary item = persisted
              ? _handedOffDetail().summary
              : _openDetail().summary;
          return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
            Result<AppPage<EmergencyCaseSummary>>.success(
              AppPage<EmergencyCaseSummary>(
                items: <EmergencyCaseSummary>[item],
                request: query.pageRequest,
                totalItemCount: 1,
              ),
            ),
          );
        });

        final ProviderContainer container = _container(repository);
        await container.read(emergencyWorkspaceControllerProvider.future);
        await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .selectCase(_openDetail().summary);

        final AppFailure? failure = await container
            .read(emergencyWorkspaceControllerProvider.notifier)
            .handoff(destination: 'OPD', notes: 'Ready for clinic');

        final EmergencyWorkspaceState state = _state(container);
        expect(failure, isNull);
        expect(state.selectedDetail?.summary.handoff?.destination, 'OPD');
        expect(state.board.items.single.handoff?.destination, 'OPD');
        expect(state.board.items.single.status, 'CLOSED');
        expect(state.isSaving, isFalse);
      },
    );

    test('keeps detail and board unchanged when persistence fails', () async {
      final _MockEmergencyRepository repository = _MockEmergencyRepository();
      _stubInitialLoad(repository);
      const AppFailure expectedFailure = AppFailure.network();
      when(
        () => repository.recordHandoff(
          detail: any(named: 'detail'),
          destination: 'IPD',
          notes: any(named: 'notes'),
          closeCase: any(named: 'closeCase'),
        ),
      ).thenAnswer(
        (_) async => const Result<EmergencyCaseDetail>.failure(expectedFailure),
      );
      final ProviderContainer container = _container(repository);
      await container.read(emergencyWorkspaceControllerProvider.future);
      await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .selectCase(_openDetail().summary);

      final AppFailure? failure = await container
          .read(emergencyWorkspaceControllerProvider.notifier)
          .handoff(destination: 'IPD');

      final EmergencyWorkspaceState state = _state(container);
      expect(failure, expectedFailure);
      expect(state.selectedDetail?.summary.handoff, isNull);
      expect(state.board.items.single.handoff, isNull);
      expect(state.board.items.single.status, 'OPEN');
      expect(state.lastFailure, expectedFailure);
      expect(state.isSaving, isFalse);
    });
  });

  testWidgets(
    'handoff dialog uses AppDialog with Cancel then Handoff and blocks dismissal',
    (WidgetTester tester) async {
      final Completer<AppFailure?> completer = Completer<AppFailure?>();
      HandoffInput? submitted;

      await pumpLocalizedWidget(
        tester,
        HandoffDialog(
          onSubmit: (HandoffInput input) {
            submitted = input;
            return completer.future;
          },
        ),
        size: const Size(390, 700),
        padding: EdgeInsets.zero,
      );

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('HANDOFF'), findsOneWidget);
      expect(find.textContaining('Destination'), findsWidgets);
      expect(find.textContaining('Handoff notes'), findsWidgets);
      expect(find.text('Close emergency case'), findsOneWidget);
      expect(find.text('OPD'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.handoff), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.scrollable, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);

      await tester.enterText(find.byType(TextFormField).first, 'Ready for OPD');
      await tester.tap(find.text('Handoff'));
      await tester.pump();

      expect(submitted?.destination, 'OPD');
      expect(submitted?.notes, 'Ready for OPD');
      expect(submitted?.closeCase, isTrue);
      expect(_button(tester, 'Close').enabled, isFalse);
      expect(_button(tester, 'Handoff').isLoading, isTrue);
      expect(
        tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
        isFalse,
      );

      completer.complete(const AppFailure.network());
      await tester.pumpAndSettle();

      expect(find.byType(HandoffDialog), findsOneWidget);
      expect(find.text('Ready for OPD'), findsOneWidget);
      expect(_button(tester, 'Close').enabled, isTrue);
    },
  );

  testWidgets('title is role-based and never the patient display name', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      HandoffDialog(onSubmit: (_) async => null),
      size: const Size(800, 500),
      padding: EdgeInsets.zero,
    );

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, isA<Text>());
    expect((dialog.title! as Text).data, 'Handoff');
    expect(find.text('HANDOFF'), findsOneWidget);
    expect(find.text('JANE DOE'), findsNothing);
  });

  testWidgets('Cancel dismisses without submitting', (WidgetTester tester) async {
    var submitted = false;
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            leadingIcon: AppActionIcons.handoff,
            onPressed: () {
              unawaited(
                showEmergencyHandoffDialog(
                  context: context,
                  onSubmit: (_) async {
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

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(submitted, isFalse);
    expect(find.byType(HandoffDialog), findsNothing);
  });

  testWidgets('remains usable on a compact high-text-scale surface', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: HandoffDialog(onSubmit: (_) async => null),
      ),
      size: const Size(320, 568),
      padding: EdgeInsets.zero,
    );

    expect(find.byType(HandoffDialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Handoff'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
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
          items: <EmergencyCaseSummary>[_openDetail().summary],
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
    (_) async => Result<EmergencyCaseDetail>.success(_openDetail()),
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

EmergencyCaseDetail _openDetail() {
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
    responses: <EmergencyResponseRecord>[
      EmergencyResponseRecord(
        id: 'ERS000001',
        emergencyCaseId: 'EME000001',
        notes: 'Stabilized',
      ),
    ],
  );
}

EmergencyCaseDetail _handedOffDetail() {
  final EmergencyCaseDetail original = _openDetail();
  const EmergencyHandoffOutcome handoff = EmergencyHandoffOutcome(
    destination: 'OPD',
    route: 'opd',
    receivingDisplayId: 'ENC000001',
    encounterDisplayId: 'ENC000001',
    stage: 'WAITING_VITALS',
    notes: 'Ready for clinic',
  );
  return original.copyWith(
    summary: original.summary.copyWith(status: 'CLOSED', handoff: handoff),
  );
}
