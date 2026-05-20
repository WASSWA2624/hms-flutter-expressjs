import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/physiotherapy/data/dtos/physiotherapy_dtos.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final physiotherapyRepositoryProvider = Provider<PhysiotherapyRepository>((
  ref,
) {
  return PhysiotherapyRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class PhysiotherapyRepositoryImpl implements PhysiotherapyRepository {
  const PhysiotherapyRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _maxEncounterHydration = 30;
  static const AppPageRequest _appointmentFetchRequest = AppPageRequest(
    pageSize: 100,
  );
  static const List<String> _backendGapCodes = <String>[
    'PHYSIOTHERAPY_STATUS_ENDPOINT',
    'BILLING_AUTHORIZATION_ENDPOINT',
    'PHYSIOTHERAPY_REPORT_ENDPOINT',
  ];

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<TherapyWorkItem>>> listWorkItems(
    PhysiotherapyWorklistQuery query,
  ) async {
    final Result<AppPage<PhysiotherapyEncounterSummary>> encountersResult =
        await _fetchEncounterSummaries(query);
    final AppFailure? encountersFailure = _failureOrNull(encountersResult);
    if (encountersFailure != null) {
      return Result<AppPage<TherapyWorkItem>>.failure(encountersFailure);
    }

    final Result<AppPage<PhysiotherapyRecord>> appointmentsResult =
        await _fetchAppointmentRecords(query);
    final AppFailure? appointmentsFailure = _failureOrNull(appointmentsResult);
    if (appointmentsFailure != null) {
      return Result<AppPage<TherapyWorkItem>>.failure(appointmentsFailure);
    }

    final List<PhysiotherapyEncounterSummary> encounters = _successValue(
      encountersResult,
    ).items;
    final List<PhysiotherapyRecord> therapyAppointments = _successValue(
      appointmentsResult,
    ).items.where(_isTherapyRecord).toList(growable: false);

    final List<Result<_PhysiotherapyEncounterBundle>> bundleResults =
        await Future.wait(
          encounters
              .take(_maxEncounterHydration)
              .map(
                (PhysiotherapyEncounterSummary encounter) =>
                    _loadEncounterBundle(encounter),
              ),
        );
    final AppFailure? bundleFailure = _firstFailure(bundleResults);
    if (bundleFailure != null) {
      return Result<AppPage<TherapyWorkItem>>.failure(bundleFailure);
    }

    final Set<String> matchedAppointmentIds = <String>{};
    final List<TherapyWorkItem> items = <TherapyWorkItem>[];
    for (final Result<_PhysiotherapyEncounterBundle> result in bundleResults) {
      final _PhysiotherapyEncounterBundle bundle = _successValue(result);
      final TherapyWorkItem base = bundle.summary.toBaseWorkItem();
      final List<PhysiotherapyRecord> matchingAppointments = therapyAppointments
          .where(
            (PhysiotherapyRecord appointment) =>
                _appointmentMatchesWorkItem(appointment, base),
          )
          .toList(growable: false);
      if (!bundle.hasTherapyContent && matchingAppointments.isEmpty) {
        continue;
      }
      matchedAppointmentIds.addAll(
        matchingAppointments.map((PhysiotherapyRecord record) => record.apiId),
      );
      items.add(_workItemFromBundle(bundle, matchingAppointments));
    }

    for (final PhysiotherapyRecord appointment in therapyAppointments) {
      if (matchedAppointmentIds.contains(appointment.apiId)) {
        continue;
      }
      items.add(_workItemFromAppointment(appointment));
    }

    final List<TherapyWorkItem> filteredItems =
        items
            .where(
              (TherapyWorkItem item) =>
                  item.matchesSearch(
                    query.search,
                    field: query.filters.searchField,
                  ) &&
                  item.matchesFilters(query.filters) &&
                  physiotherapyItemMatchesScope(item, query.scope),
            )
            .toList(growable: false)
          ..sort(_workItemSort);

    return Result<AppPage<TherapyWorkItem>>.success(
      _pageSlice(filteredItems, query.pageRequest),
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> loadDetail(TherapyWorkItem item) async {
    final Result<List<PhysiotherapyRecord>> appointmentsResult =
        await _fetchAppointmentsForItem(item);
    final AppFailure? appointmentsFailure = _failureOrNull(appointmentsResult);
    if (appointmentsFailure != null) {
      return Result<PhysiotherapyDetail>.failure(appointmentsFailure);
    }

    if (!item.hasEncounter) {
      return Result<PhysiotherapyDetail>.success(
        PhysiotherapyDetail(
          item: item,
          appointments: _successValue(appointmentsResult),
          backendGaps: _backendGapCodes,
        ),
      );
    }

    final Result<_PhysiotherapyEncounterBundle> bundleResult =
        await _loadEncounterBundle(_summaryFromItem(item));
    final AppFailure? bundleFailure = _failureOrNull(bundleResult);
    if (bundleFailure != null) {
      return Result<PhysiotherapyDetail>.failure(bundleFailure);
    }

    final _PhysiotherapyEncounterBundle bundle = _successValue(bundleResult);
    final List<PhysiotherapyRecord> appointments = _successValue(
      appointmentsResult,
    );
    return Result<PhysiotherapyDetail>.success(
      _detailFromBundle(bundle, appointments),
    );
  }

  @override
  Future<Result<PhysiotherapyDetail>> acceptReferral({
    required TherapyWorkItem item,
    required String note,
  }) async {
    final Result<void> result = await _createProcedure(item, <String, Object?>{
      'code': 'PHYSIO_REFERRAL_ACCEPTED',
      'description': _joinLines(<String>[
        'Physiotherapy referral accepted.',
        if (note.trim().isNotEmpty) note.trim(),
      ]),
      'performed_at': DateTime.now().toUtc().toIso8601String(),
    });
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> scheduleSession({
    required TherapyWorkItem item,
    required DateTime startAt,
    required DateTime endAt,
    String? providerUserId,
    String? reason,
  }) async {
    final String? patientId = item.apiPatientId;
    if (patientId == null || !item.hasEncounter) {
      return Result<PhysiotherapyDetail>.failure(AppFailure.validation());
    }

    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.appointments),
      data: _withoutEmpty(<String, Object?>{
        'patient_id': patientId,
        'provider_user_id': providerUserId,
        'status': 'SCHEDULED',
        'scheduled_start': startAt.toUtc().toIso8601String(),
        'scheduled_end': endAt.toUtc().toIso8601String(),
        'reason': _appointmentReason(item, reason),
      }),
      decoder: (_) {},
    );
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> recordAssessment({
    required TherapyWorkItem item,
    required String assessment,
    required String goals,
    required String plan,
    String? instructions,
  }) async {
    final Result<void> procedureResult = await _createProcedure(
      item,
      <String, Object?>{
        'code': 'PHYSIO_ASSESSMENT',
        'description': _joinLines(<String>[
          'Assessment:',
          assessment.trim(),
          'Goals:',
          goals.trim(),
          'Plan:',
          plan.trim(),
          if ((instructions ?? '').trim().isNotEmpty) 'Instructions:',
          if ((instructions ?? '').trim().isNotEmpty) instructions!.trim(),
        ]),
        'performed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final AppFailure? procedureFailure = _failureOrNull(procedureResult);
    if (procedureFailure != null) {
      return Result<PhysiotherapyDetail>.failure(procedureFailure);
    }

    if (plan.trim().isEmpty && goals.trim().isEmpty) {
      return loadDetail(item);
    }

    final Result<void> carePlanResult = await _createCarePlan(
      item,
      _joinLines(<String>[
        if (goals.trim().isNotEmpty) 'Goals:',
        if (goals.trim().isNotEmpty) goals.trim(),
        if (plan.trim().isNotEmpty) 'Plan:',
        if (plan.trim().isNotEmpty) plan.trim(),
        if ((instructions ?? '').trim().isNotEmpty) 'Instructions:',
        if ((instructions ?? '').trim().isNotEmpty) instructions!.trim(),
      ]),
    );
    return _reloadAfterMutation(item, carePlanResult);
  }

  @override
  Future<Result<PhysiotherapyDetail>> recordSession({
    required TherapyWorkItem item,
    required String note,
    String? attendanceStatus,
  }) async {
    final Result<void> result = await _createProcedure(item, <String, Object?>{
      'code': 'PHYSIO_SESSION',
      'description': _joinLines(<String>[
        if ((attendanceStatus ?? '').trim().isNotEmpty)
          'Attendance: ${attendanceStatus!.trim()}',
        note.trim(),
      ]),
      'performed_at': DateTime.now().toUtc().toIso8601String(),
    });
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> markAttendance({
    required TherapyWorkItem item,
    required String status,
    String? note,
  }) async {
    final String? appointmentId = item.appointmentApiId;
    if (appointmentId == null || appointmentId.trim().isEmpty) {
      return Result<PhysiotherapyDetail>.failure(AppFailure.validation());
    }

    final Result<void> result = await _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.appointments, appointmentId),
      data: _withoutEmpty(<String, Object?>{
        'status': status.trim().toUpperCase(),
        'reason': _appointmentReason(item, note),
      }),
      decoder: (_) {},
    );
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> updatePlan({
    required TherapyWorkItem item,
    required String plan,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Result<void> result = await _createCarePlan(
      item,
      plan.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> addProgressNote({
    required TherapyWorkItem item,
    required String authorUserId,
    required String note,
  }) async {
    if (!item.hasEncounter) {
      return Result<PhysiotherapyDetail>.failure(AppFailure.validation());
    }

    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.clinicalNotes),
      data: _withoutEmpty(<String, Object?>{
        'encounter_id': item.apiEncounterId,
        'author_user_id': authorUserId,
        'note': _joinLines(<String>[
          'Physiotherapy progress note:',
          note.trim(),
        ]),
      }),
      decoder: (_) {},
    );
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> scheduleFollowUp({
    required TherapyWorkItem item,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    if (!item.hasEncounter) {
      return Result<PhysiotherapyDetail>.failure(AppFailure.validation());
    }

    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.followUps),
      data: _withoutEmpty(<String, Object?>{
        'encounter_id': item.apiEncounterId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': _joinLines(<String>[
          'Physiotherapy follow-up.',
          if ((notes ?? '').trim().isNotEmpty) notes!.trim(),
        ]),
      }),
      decoder: (_) {},
    );
    return _reloadAfterMutation(item, result);
  }

  @override
  Future<Result<PhysiotherapyDetail>> closeEpisode({
    required TherapyWorkItem item,
    required String summary,
  }) async {
    final Result<void> result = await _createProcedure(item, <String, Object?>{
      'code': 'PHYSIO_EPISODE_CLOSED',
      'description': _joinLines(<String>[
        'Physiotherapy episode closed.',
        summary.trim(),
      ]),
      'performed_at': DateTime.now().toUtc().toIso8601String(),
    });
    return _reloadAfterMutation(item, result);
  }

  Future<Result<AppPage<PhysiotherapyEncounterSummary>>>
  _fetchEncounterSummaries(PhysiotherapyWorklistQuery query) {
    const AppPageRequest request = AppPageRequest(
      pageSize: _maxEncounterHydration,
    );
    return _apiClient.get<AppPage<PhysiotherapyEncounterSummary>>(
      ApiEndpoints.collection(HmsApiResource.encounters),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': request.pageSize,
        'status': query.scope == PhysiotherapyQueueScope.completed
            ? 'CLOSED'
            : 'OPEN',
        'search': query.databaseSearch,
        'sort_by': 'updated_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          PhysiotherapyEncounterPageDto.fromResponse(data, request).page,
    );
  }

  Future<Result<AppPage<PhysiotherapyRecord>>> _fetchAppointmentRecords(
    PhysiotherapyWorklistQuery query,
  ) {
    final String search = query.databaseSearch.trim().isEmpty
        ? 'physio'
        : query.databaseSearch;
    return _apiClient.get<AppPage<PhysiotherapyRecord>>(
      ApiEndpoints.collection(HmsApiResource.appointments),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': _appointmentFetchRequest.pageSize,
        'search': search,
        'sort_by': 'scheduled_start',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          decodeAppointmentPage(data, _appointmentFetchRequest),
    );
  }

  Future<Result<List<PhysiotherapyRecord>>> _fetchAppointmentsForItem(
    TherapyWorkItem item,
  ) {
    final String? patientId = item.patientId;
    return _apiClient
        .get<AppPage<PhysiotherapyRecord>>(
          ApiEndpoints.collection(HmsApiResource.appointments),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 50,
            'patient_id': patientId,
            'search': patientId == null ? _appointmentSearchText(item) : null,
            'sort_by': 'scheduled_start',
            'order': 'desc',
          }),
          decoder: (Object? data) =>
              decodeAppointmentPage(data, const AppPageRequest(pageSize: 50)),
        )
        .then((Result<AppPage<PhysiotherapyRecord>> result) {
          return result.map((AppPage<PhysiotherapyRecord> page) {
            return page.items
                .where(
                  (PhysiotherapyRecord appointment) =>
                      _isTherapyRecord(appointment) &&
                      _appointmentMatchesWorkItem(appointment, item),
                )
                .toList(growable: false);
          });
        });
  }

  Future<Result<_PhysiotherapyEncounterBundle>> _loadEncounterBundle(
    PhysiotherapyEncounterSummary summary,
  ) async {
    final List<Result<List<PhysiotherapyRecord>>> results =
        await Future.wait(<Future<Result<List<PhysiotherapyRecord>>>>[
          _fetchRelatedList(
            HmsApiResource.procedures,
            summary.encounterId,
            PhysiotherapyRecordKind.procedure,
          ),
          _fetchRelatedList(
            HmsApiResource.carePlans,
            summary.encounterId,
            PhysiotherapyRecordKind.carePlan,
          ),
          _fetchRelatedList(
            HmsApiResource.clinicalNotes,
            summary.encounterId,
            PhysiotherapyRecordKind.clinicalNote,
          ),
          _fetchRelatedList(
            HmsApiResource.followUps,
            summary.encounterId,
            PhysiotherapyRecordKind.followUp,
          ),
        ]);

    final AppFailure? failure = _firstFailure(results);
    if (failure != null) {
      return Result<_PhysiotherapyEncounterBundle>.failure(failure);
    }

    return Result<_PhysiotherapyEncounterBundle>.success(
      _PhysiotherapyEncounterBundle(
        summary: summary,
        procedures: _successValue(results[0]),
        carePlans: _successValue(results[1]),
        progressNotes: _successValue(results[2]),
        followUps: _successValue(results[3]),
      ),
    );
  }

  Future<Result<List<PhysiotherapyRecord>>> _fetchRelatedList(
    HmsApiResource resource,
    String encounterId,
    PhysiotherapyRecordKind kind,
  ) {
    return _apiClient.get<List<PhysiotherapyRecord>>(
      ApiEndpoints.collection(resource),
      queryParameters: <String, Object?>{
        'encounter_id': encounterId,
        'page': 1,
        'limit': 50,
        'sort_by': 'updated_at',
        'order': 'desc',
      },
      decoder: (Object? data) => decodePhysiotherapyRecords(data, kind),
    );
  }

  Future<Result<void>> _createProcedure(
    TherapyWorkItem item,
    Map<String, Object?> payload,
  ) {
    if (!item.hasEncounter) {
      return Future<Result<void>>.value(
        Result<void>.failure(AppFailure.validation()),
      );
    }
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.procedures),
      data: _withoutEmpty(<String, Object?>{
        'encounter_id': item.apiEncounterId,
        ...payload,
      }),
      decoder: (_) {},
    );
  }

  Future<Result<void>> _createCarePlan(
    TherapyWorkItem item,
    String plan, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (!item.hasEncounter || plan.trim().isEmpty) {
      return Future<Result<void>>.value(
        Result<void>.failure(AppFailure.validation()),
      );
    }
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.carePlans),
      data: _withoutEmpty(<String, Object?>{
        'encounter_id': item.apiEncounterId,
        'plan': plan.trim(),
        'start_date': (startDate ?? DateTime.now()).toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
      }),
      decoder: (_) {},
    );
  }

  Future<Result<PhysiotherapyDetail>> _reloadAfterMutation(
    TherapyWorkItem item,
    Result<void> mutationResult,
  ) {
    final AppFailure? failure = _failureOrNull(mutationResult);
    if (failure != null) {
      return Future<Result<PhysiotherapyDetail>>.value(
        Result<PhysiotherapyDetail>.failure(failure),
      );
    }
    return loadDetail(item);
  }

  PhysiotherapyDetail _detailFromBundle(
    _PhysiotherapyEncounterBundle bundle,
    List<PhysiotherapyRecord> appointments,
  ) {
    final TherapyWorkItem item = _workItemFromBundle(bundle, appointments);
    return PhysiotherapyDetail(
      item: item,
      appointments: appointments,
      procedures: _therapyOrAll(bundle.procedures),
      carePlans: _therapyOrAll(bundle.carePlans),
      progressNotes: _therapyOrAll(bundle.progressNotes),
      followUps: _therapyOrAll(bundle.followUps),
      backendGaps: _backendGapCodes,
    );
  }

  TherapyWorkItem _workItemFromBundle(
    _PhysiotherapyEncounterBundle bundle,
    List<PhysiotherapyRecord> appointments,
  ) {
    final TherapyWorkItem base = bundle.summary.toBaseWorkItem();
    final List<PhysiotherapyRecord> procedures = _therapyOrAll(
      bundle.procedures,
    );
    final List<PhysiotherapyRecord> carePlans = _therapyOrAll(bundle.carePlans);
    final List<PhysiotherapyRecord> progressNotes = _therapyOrAll(
      bundle.progressNotes,
    );
    final List<PhysiotherapyRecord> followUps = _therapyOrAll(bundle.followUps);
    final PhysiotherapyRecord? nextAppointment = _nextAppointment(appointments);
    final PhysiotherapyRecord? latestProcedure = _latestRecord(procedures);
    final PhysiotherapyRecord? latestPlan = _latestRecord(carePlans);
    final PhysiotherapyRecord? latestFollowUp = _latestRecord(followUps);
    final PhysiotherapyRecord? latestNote = _latestRecord(progressNotes);
    final String? plan = latestPlan?.description;
    final String? assessment = _latestAssessment(procedures)?.description;

    return TherapyWorkItem(
      id: base.id,
      encounterId: base.encounterId,
      encounterPublicId: base.encounterPublicId,
      patientId: base.patientId,
      patientPublicId: base.patientPublicId,
      patientDisplayName: base.patientDisplayName,
      patientPhone: base.patientPhone,
      patientGender: base.patientGender,
      encounterType: base.encounterType,
      source: _sourceFor(
        procedures: procedures,
        carePlans: carePlans,
        appointments: appointments,
      ),
      sourceId:
          latestProcedure?.id ??
          latestPlan?.id ??
          nextAppointment?.id ??
          base.id,
      sourceTitle:
          latestProcedure?.displayTitle ??
          latestPlan?.displayTitle ??
          nextAppointment?.displayTitle,
      referralReason:
          latestProcedure?.description ??
          nextAppointment?.description ??
          latestNote?.description,
      status: _statusFor(
        procedures: procedures,
        carePlans: carePlans,
        followUps: followUps,
        appointments: appointments,
      ),
      attendanceStatus: nextAppointment?.status,
      therapistUserId: nextAppointment?.providerUserId ?? base.therapistUserId,
      therapistName: nextAppointment?.providerName ?? base.therapistName,
      appointmentId: nextAppointment?.id,
      appointmentApiId: nextAppointment?.apiId,
      procedureId: latestProcedure?.id,
      carePlanId: latestPlan?.id,
      followUpId: latestFollowUp?.id,
      sessionAt: nextAppointment?.startAt ?? latestFollowUp?.startAt,
      lastActivityAt: _latestDate(<DateTime?>[
        nextAppointment?.activityAt,
        latestProcedure?.activityAt,
        latestPlan?.activityAt,
        latestFollowUp?.activityAt,
        latestNote?.activityAt,
        base.lastActivityAt,
      ]),
      plan: _extractSection(plan, 'Plan') ?? plan,
      goals:
          _extractSection(plan, 'Goals') ??
          _extractSection(assessment, 'Goals'),
      instructions:
          _extractSection(plan, 'Instructions') ??
          _extractSection(assessment, 'Instructions'),
    );
  }

  TherapyWorkItem _workItemFromAppointment(PhysiotherapyRecord appointment) {
    return TherapyWorkItem(
      id: appointment.id,
      encounterId: '',
      patientId: appointment.patientId,
      patientPublicId: appointment.patientPublicId,
      patientDisplayName: appointment.patientDisplayName,
      source: 'APPOINTMENT',
      sourceId: appointment.id,
      sourceTitle: appointment.displayTitle,
      referralReason: appointment.description,
      status: _statusForAppointment(appointment),
      attendanceStatus: appointment.status,
      therapistUserId: appointment.providerUserId,
      therapistName: appointment.providerName,
      appointmentId: appointment.id,
      appointmentApiId: appointment.apiId,
      sessionAt: appointment.startAt,
      lastActivityAt: appointment.activityAt,
    );
  }

  PhysiotherapyEncounterSummary _summaryFromItem(TherapyWorkItem item) {
    return PhysiotherapyEncounterSummary(
      id: item.id,
      encounterId: item.encounterId,
      encounterPublicId: item.encounterPublicId,
      patientId: item.patientId,
      patientPublicId: item.patientPublicId,
      patientDisplayName: item.patientDisplayName,
      patientPhone: item.patientPhone,
      patientGender: item.patientGender,
      encounterType: item.encounterType,
      providerUserId: item.therapistUserId,
      providerName: item.therapistName,
      updatedAt: item.lastActivityAt,
    );
  }

  List<PhysiotherapyRecord> _therapyOrAll(List<PhysiotherapyRecord> records) {
    final List<PhysiotherapyRecord> therapyRecords = records
        .where(_isTherapyRecord)
        .toList(growable: false);
    return therapyRecords.isEmpty ? records : therapyRecords;
  }

  PhysiotherapyRecord? _latestRecord(List<PhysiotherapyRecord> records) {
    if (records.isEmpty) {
      return null;
    }
    final List<PhysiotherapyRecord> sorted = records.toList(growable: false)
      ..sort((PhysiotherapyRecord left, PhysiotherapyRecord right) {
        final DateTime? leftDate = left.activityAt;
        final DateTime? rightDate = right.activityAt;
        if (leftDate == null && rightDate == null) {
          return 0;
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }
        return rightDate.compareTo(leftDate);
      });
    return sorted.first;
  }

  PhysiotherapyRecord? _nextAppointment(List<PhysiotherapyRecord> records) {
    final DateTime now = DateTime.now();
    final List<PhysiotherapyRecord> future =
        records
            .where(
              (PhysiotherapyRecord record) =>
                  record.startAt != null &&
                  !record.startAt!.toLocal().isBefore(now) &&
                  !_isTerminalAppointment(record.status),
            )
            .toList(growable: false)
          ..sort((PhysiotherapyRecord left, PhysiotherapyRecord right) {
            return left.startAt!.compareTo(right.startAt!);
          });
    if (future.isNotEmpty) {
      return future.first;
    }
    return _latestRecord(records);
  }

  PhysiotherapyRecord? _latestAssessment(List<PhysiotherapyRecord> records) {
    return _latestRecord(
      records
          .where(
            (PhysiotherapyRecord record) =>
                (record.code ?? '').toUpperCase() == 'PHYSIO_ASSESSMENT',
          )
          .toList(growable: false),
    );
  }

  String _sourceFor({
    required List<PhysiotherapyRecord> procedures,
    required List<PhysiotherapyRecord> carePlans,
    required List<PhysiotherapyRecord> appointments,
  }) {
    if (procedures.any(
      (PhysiotherapyRecord record) =>
          (record.code ?? '').toUpperCase().contains('REFERRAL'),
    )) {
      return 'REFERRAL';
    }
    if (appointments.isNotEmpty) {
      return 'APPOINTMENT';
    }
    if (carePlans.isNotEmpty) {
      return 'CARE_PLAN';
    }
    return 'PROCEDURE';
  }

  String _statusFor({
    required List<PhysiotherapyRecord> procedures,
    required List<PhysiotherapyRecord> carePlans,
    required List<PhysiotherapyRecord> followUps,
    required List<PhysiotherapyRecord> appointments,
  }) {
    if (procedures.any(
      (PhysiotherapyRecord record) =>
          (record.code ?? '').toUpperCase() == 'PHYSIO_EPISODE_CLOSED',
    )) {
      return 'COMPLETED';
    }
    if (appointments.any(_isMissedAppointment)) {
      return 'MISSED';
    }
    if (followUps.any(_isDueFollowUp)) {
      return 'FOLLOW_UP_DUE';
    }
    if (appointments.any(
      (PhysiotherapyRecord record) => _isToday(record.startAt),
    )) {
      return 'TODAY';
    }
    if (carePlans.isNotEmpty) {
      return 'ACTIVE_PLAN';
    }
    if (procedures.any(
      (PhysiotherapyRecord record) =>
          (record.code ?? '').toUpperCase() == 'PHYSIO_SESSION',
    )) {
      return 'IN_TREATMENT';
    }
    if (procedures.any(
      (PhysiotherapyRecord record) =>
          (record.code ?? '').toUpperCase() == 'PHYSIO_ASSESSMENT',
    )) {
      return 'ASSESSMENT';
    }
    if (procedures.any(
      (PhysiotherapyRecord record) =>
          (record.code ?? '').toUpperCase() == 'PHYSIO_REFERRAL_ACCEPTED',
    )) {
      return 'ACCEPTED';
    }
    return 'REFERRAL';
  }

  String _statusForAppointment(PhysiotherapyRecord appointment) {
    if (_isMissedAppointment(appointment)) {
      return 'MISSED';
    }
    if (_isToday(appointment.startAt)) {
      return 'TODAY';
    }
    if (_isTerminalAppointment(appointment.status)) {
      return 'COMPLETED';
    }
    return 'REFERRAL';
  }

  bool _isTherapyRecord(PhysiotherapyRecord record) {
    return record.isTherapyRelated ||
        _containsTherapyMarker(record.description) ||
        _containsTherapyMarker(record.title) ||
        _containsTherapyMarker(record.subtitle);
  }

  bool _appointmentMatchesWorkItem(
    PhysiotherapyRecord appointment,
    TherapyWorkItem item,
  ) {
    final String haystack = <String?>[
      appointment.title,
      appointment.description,
      appointment.patientId,
      appointment.patientPublicId,
      appointment.patientDisplayName,
    ].whereType<String>().join(' ').toLowerCase();
    final List<String?> needles = <String?>[
      item.encounterId,
      item.encounterPublicId,
      item.patientId,
      item.patientPublicId,
      item.patientDisplayName,
    ];
    return needles
        .map((String? value) => value?.trim().toLowerCase() ?? '')
        .where((String value) => value.isNotEmpty)
        .any(haystack.contains);
  }

  bool _containsTherapyMarker(String? value) {
    final String normalized = value?.toLowerCase() ?? '';
    return normalized.contains('physio') ||
        normalized.contains('physical therapy') ||
        normalized.contains('rehab') ||
        normalized.contains('mobility') ||
        normalized.contains('exercise');
  }

  bool _isMissedAppointment(PhysiotherapyRecord record) {
    final String status = (record.status ?? '').toUpperCase();
    if (status == 'NO_SHOW') {
      return true;
    }
    final DateTime? endAt = record.endAt ?? record.startAt;
    if (endAt == null || _isTerminalAppointment(status)) {
      return false;
    }
    return endAt.toLocal().isBefore(DateTime.now()) &&
        (status == 'SCHEDULED' || status == 'CONFIRMED');
  }

  bool _isDueFollowUp(PhysiotherapyRecord record) {
    final String status = (record.status ?? '').toUpperCase();
    final DateTime? scheduledAt = record.startAt ?? record.occurredAt;
    return scheduledAt != null &&
        scheduledAt.toLocal().isBefore(DateTime.now()) &&
        status == 'SCHEDULED';
  }

  bool _isTerminalAppointment(String? status) {
    return switch ((status ?? '').toUpperCase()) {
      'COMPLETED' || 'CANCELLED' || 'NO_SHOW' => true,
      _ => false,
    };
  }

  bool _isToday(DateTime? value) {
    if (value == null) {
      return false;
    }
    final DateTime localValue = value.toLocal();
    final DateTime now = DateTime.now();
    return localValue.year == now.year &&
        localValue.month == now.month &&
        localValue.day == now.day;
  }

  DateTime? _latestDate(Iterable<DateTime?> values) {
    DateTime? latest;
    for (final DateTime? value in values) {
      if (value == null) {
        continue;
      }
      if (latest == null || value.isAfter(latest)) {
        latest = value;
      }
    }
    return latest;
  }

  int _workItemSort(TherapyWorkItem left, TherapyWorkItem right) {
    final DateTime? leftDate = left.sessionAt ?? left.lastActivityAt;
    final DateTime? rightDate = right.sessionAt ?? right.lastActivityAt;
    if (leftDate == null && rightDate == null) {
      return left.displayTitle.compareTo(right.displayTitle);
    }
    if (leftDate == null) {
      return 1;
    }
    if (rightDate == null) {
      return -1;
    }
    return leftDate.compareTo(rightDate);
  }

  AppPage<TherapyWorkItem> _pageSlice(
    List<TherapyWorkItem> items,
    AppPageRequest request,
  ) {
    final int start = request.offset.clamp(0, items.length);
    final int end = (start + request.pageSize).clamp(start, items.length);
    return AppPage<TherapyWorkItem>(
      items: items.sublist(start, end),
      request: request,
      totalItemCount: items.length,
    );
  }

  String _appointmentSearchText(TherapyWorkItem item) {
    return <String?>[
          'physio',
          item.encounterPublicId,
          item.encounterId,
          item.patientPublicId,
          item.patientDisplayName,
        ]
        .whereType<String>()
        .where((String value) => value.trim().isNotEmpty)
        .join(' ');
  }

  String _appointmentReason(TherapyWorkItem item, String? note) {
    return _joinLines(<String>[
      'Physiotherapy session.',
      if (item.encounterId.trim().isNotEmpty) 'Encounter: ${item.encounterId}',
      if ((item.encounterPublicId ?? '').trim().isNotEmpty)
        'Encounter reference: ${item.encounterPublicId!.trim()}',
      if ((note ?? '').trim().isNotEmpty) note!.trim(),
    ]);
  }

  String? _extractSection(String? text, String heading) {
    final String source = text?.trim() ?? '';
    if (source.isEmpty) {
      return null;
    }
    final RegExp pattern = RegExp(
      '$heading:\\s*([\\s\\S]*?)(?:\\n[A-Z][A-Za-z ]+:|\\z)',
      caseSensitive: false,
    );
    final RegExpMatch? match = pattern.firstMatch(source);
    return match?.group(1)?.trim();
  }

  String _joinLines(Iterable<String> lines) {
    return lines
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join('\n');
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }

  AppFailure? _firstFailure<T>(List<Result<T>> results) {
    for (final Result<T> result in results) {
      final AppFailure? failure = _failureOrNull(result);
      if (failure != null) {
        return failure;
      }
    }
    return null;
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  T _successValue<T>(Result<T> result) {
    return result.when(
      success: (T value) => value,
      failure: (_) => throw StateError('Expected successful result.'),
    );
  }
}

final class _PhysiotherapyEncounterBundle {
  const _PhysiotherapyEncounterBundle({
    required this.summary,
    this.procedures = const <PhysiotherapyRecord>[],
    this.carePlans = const <PhysiotherapyRecord>[],
    this.progressNotes = const <PhysiotherapyRecord>[],
    this.followUps = const <PhysiotherapyRecord>[],
  });

  final PhysiotherapyEncounterSummary summary;
  final List<PhysiotherapyRecord> procedures;
  final List<PhysiotherapyRecord> carePlans;
  final List<PhysiotherapyRecord> progressNotes;
  final List<PhysiotherapyRecord> followUps;

  bool get hasTherapyContent {
    return <PhysiotherapyRecord>[
      ...procedures,
      ...carePlans,
      ...progressNotes,
      ...followUps,
    ].any(
      (PhysiotherapyRecord record) =>
          record.isTherapyRelated ||
          (record.description ?? '').toLowerCase().contains('physiotherapy'),
    );
  }
}
