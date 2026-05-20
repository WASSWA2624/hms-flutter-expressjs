import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum PhysiotherapyQueueScope {
  referrals,
  today,
  missed,
  activePlans,
  followUpDue,
  completed,
  all,
}

enum PhysiotherapyRecordKind {
  appointment,
  procedure,
  carePlan,
  clinicalNote,
  followUp,
}

@immutable
final class PhysiotherapyWorklistFilters {
  const PhysiotherapyWorklistFilters({
    this.searchField,
    this.source,
    this.status,
    this.attendance,
    this.therapist,
    this.dateFrom,
    this.dateTo,
  });

  final String? searchField;
  final String? source;
  final String? status;
  final String? attendance;
  final String? therapist;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get isActive {
    return _hasText(searchField) ||
        _hasText(source) ||
        _hasText(status) ||
        _hasText(attendance) ||
        _hasText(therapist) ||
        dateFrom != null ||
        dateTo != null;
  }

  PhysiotherapyWorklistFilters copyWith({
    String? searchField,
    String? source,
    String? status,
    String? attendance,
    String? therapist,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearSearchField = false,
    bool clearSource = false,
    bool clearStatus = false,
    bool clearAttendance = false,
    bool clearTherapist = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return PhysiotherapyWorklistFilters(
      searchField: clearSearchField ? null : searchField ?? this.searchField,
      source: clearSource ? null : source ?? this.source,
      status: clearStatus ? null : status ?? this.status,
      attendance: clearAttendance ? null : attendance ?? this.attendance,
      therapist: clearTherapist ? null : therapist ?? this.therapist,
      dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
    );
  }
}

@immutable
final class PhysiotherapyWorklistQuery {
  const PhysiotherapyWorklistQuery({
    this.search = '',
    this.scope = PhysiotherapyQueueScope.referrals,
    this.filters = const PhysiotherapyWorklistFilters(),
    this.pageRequest = const AppPageRequest(pageSize: 25),
  });

  final String search;
  final PhysiotherapyQueueScope scope;
  final PhysiotherapyWorklistFilters filters;
  final AppPageRequest pageRequest;

  String get databaseSearch {
    return _joinDisplay(<String?>[search, filters.therapist]) ?? '';
  }

  bool get hasActiveFilters {
    return search.trim().isNotEmpty ||
        scope != PhysiotherapyQueueScope.referrals ||
        filters.isActive;
  }

  PhysiotherapyWorklistQuery copyWith({
    String? search,
    PhysiotherapyQueueScope? scope,
    PhysiotherapyWorklistFilters? filters,
    AppPageRequest? pageRequest,
  }) {
    return PhysiotherapyWorklistQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      filters: filters ?? this.filters,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

typedef TherapyWorkItem = PhysiotherapyWorkItem;

@immutable
final class PhysiotherapyWorkItem {
  const PhysiotherapyWorkItem({
    required this.id,
    required this.encounterId,
    this.encounterPublicId,
    this.patientId,
    this.patientPublicId,
    this.patientDisplayName,
    this.patientPhone,
    this.patientGender,
    this.encounterType,
    this.source = 'REFERRAL',
    this.sourceId,
    this.sourceTitle,
    this.referralReason,
    this.status = 'REFERRAL',
    this.attendanceStatus,
    this.billingStatus = 'BACKEND_GAP',
    this.therapistUserId,
    this.therapistName,
    this.appointmentId,
    this.appointmentApiId,
    this.procedureId,
    this.carePlanId,
    this.followUpId,
    this.sessionAt,
    this.lastActivityAt,
    this.plan,
    this.goals,
    this.instructions,
  });

  final String id;
  final String encounterId;
  final String? encounterPublicId;
  final String? patientId;
  final String? patientPublicId;
  final String? patientDisplayName;
  final String? patientPhone;
  final String? patientGender;
  final String? encounterType;
  final String source;
  final String? sourceId;
  final String? sourceTitle;
  final String? referralReason;
  final String status;
  final String? attendanceStatus;
  final String billingStatus;
  final String? therapistUserId;
  final String? therapistName;
  final String? appointmentId;
  final String? appointmentApiId;
  final String? procedureId;
  final String? carePlanId;
  final String? followUpId;
  final DateTime? sessionAt;
  final DateTime? lastActivityAt;
  final String? plan;
  final String? goals;
  final String? instructions;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientPublicId,
          patientId,
          encounterPublicId,
          encounterId,
        ]) ??
        id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[
      patientPublicId,
      patientPhone,
      patientGender,
      encounterPublicId,
      encounterType,
    ]);
  }

  String? get apiPatientId =>
      _firstNonEmpty(<String?>[patientId, patientPublicId]);

  String get apiEncounterId => encounterId;

  bool get hasEncounter => encounterId.trim().isNotEmpty;

  bool get hasAppointment => _hasText(appointmentApiId);

  bool get isCompleted {
    final String normalized = status.toUpperCase();
    return normalized == 'COMPLETED' || normalized == 'CLOSED';
  }

  bool matchesSearch(String search, {String? field}) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return _searchValuesForField(field).whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesFilters(PhysiotherapyWorklistFilters filters) {
    if (!_matchesExact(source, filters.source)) {
      return false;
    }
    if (!_matchesExact(status, filters.status)) {
      return false;
    }
    if (!_matchesExact(attendanceStatus, filters.attendance)) {
      return false;
    }
    if (!_matchesAnyContains(filters.therapist, <String?>[
      therapistUserId,
      therapistName,
    ])) {
      return false;
    }
    return _matchesDateRange(
      sessionAt ?? lastActivityAt,
      filters.dateFrom,
      filters.dateTo,
    );
  }

  List<String?> _searchValuesForField(String? field) {
    return switch (field) {
      'patient' => <String?>[
        patientDisplayName,
        patientPublicId,
        patientId,
        patientPhone,
        patientGender,
      ],
      'encounter' => <String?>[encounterId, encounterPublicId, encounterType],
      'source' => <String?>[source, sourceId, sourceTitle, referralReason],
      'status' => <String?>[status, attendanceStatus, billingStatus],
      'therapist' => <String?>[therapistUserId, therapistName],
      _ => <String?>[
        id,
        encounterId,
        encounterPublicId,
        patientId,
        patientPublicId,
        patientDisplayName,
        patientPhone,
        patientGender,
        encounterType,
        source,
        sourceId,
        sourceTitle,
        referralReason,
        status,
        attendanceStatus,
        billingStatus,
        therapistUserId,
        therapistName,
        appointmentId,
        procedureId,
        carePlanId,
        followUpId,
        plan,
        goals,
        instructions,
      ],
    };
  }

  PhysiotherapyWorkItem copyWith({
    String? status,
    String? attendanceStatus,
    String? billingStatus,
    String? therapistUserId,
    String? therapistName,
    String? appointmentId,
    String? appointmentApiId,
    String? procedureId,
    String? carePlanId,
    String? followUpId,
    DateTime? sessionAt,
    DateTime? lastActivityAt,
    String? plan,
    String? goals,
    String? instructions,
  }) {
    return PhysiotherapyWorkItem(
      id: id,
      encounterId: encounterId,
      encounterPublicId: encounterPublicId,
      patientId: patientId,
      patientPublicId: patientPublicId,
      patientDisplayName: patientDisplayName,
      patientPhone: patientPhone,
      patientGender: patientGender,
      encounterType: encounterType,
      source: source,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      referralReason: referralReason,
      status: status ?? this.status,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      billingStatus: billingStatus ?? this.billingStatus,
      therapistUserId: therapistUserId ?? this.therapistUserId,
      therapistName: therapistName ?? this.therapistName,
      appointmentId: appointmentId ?? this.appointmentId,
      appointmentApiId: appointmentApiId ?? this.appointmentApiId,
      procedureId: procedureId ?? this.procedureId,
      carePlanId: carePlanId ?? this.carePlanId,
      followUpId: followUpId ?? this.followUpId,
      sessionAt: sessionAt ?? this.sessionAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      plan: plan ?? this.plan,
      goals: goals ?? this.goals,
      instructions: instructions ?? this.instructions,
    );
  }
}

@immutable
final class PhysiotherapyRecord {
  const PhysiotherapyRecord({
    required this.id,
    required this.apiId,
    required this.kind,
    this.status,
    this.code,
    this.title,
    this.subtitle,
    this.description,
    this.patientId,
    this.patientPublicId,
    this.patientDisplayName,
    this.providerUserId,
    this.providerName,
    this.startAt,
    this.endAt,
    this.occurredAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String apiId;
  final PhysiotherapyRecordKind kind;
  final String? status;
  final String? code;
  final String? title;
  final String? subtitle;
  final String? description;
  final String? patientId;
  final String? patientPublicId;
  final String? patientDisplayName;
  final String? providerUserId;
  final String? providerName;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return _firstNonEmpty(<String?>[title, description, code, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[subtitle, status, providerName]);
  }

  DateTime? get activityAt => occurredAt ?? startAt ?? updatedAt ?? createdAt;

  bool get isTherapyRelated {
    final String haystack = <String?>[
      code,
      title,
      subtitle,
      description,
      status,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains('physio') ||
        haystack.contains('physical therapy') ||
        haystack.contains('rehab') ||
        haystack.contains('mobility') ||
        haystack.contains('exercise') ||
        (code ?? '').toUpperCase().startsWith('PT');
  }
}

@immutable
final class PhysiotherapyDetail {
  const PhysiotherapyDetail({
    required this.item,
    this.appointments = const <PhysiotherapyRecord>[],
    this.procedures = const <PhysiotherapyRecord>[],
    this.carePlans = const <PhysiotherapyRecord>[],
    this.progressNotes = const <PhysiotherapyRecord>[],
    this.followUps = const <PhysiotherapyRecord>[],
    this.backendGaps = const <String>[],
  });

  final PhysiotherapyWorkItem item;
  final List<PhysiotherapyRecord> appointments;
  final List<PhysiotherapyRecord> procedures;
  final List<PhysiotherapyRecord> carePlans;
  final List<PhysiotherapyRecord> progressNotes;
  final List<PhysiotherapyRecord> followUps;
  final List<String> backendGaps;

  List<PhysiotherapyRecord> get sessionHistory {
    return <PhysiotherapyRecord>[...appointments, ...procedures]
      ..sort(_newestFirst);
  }

  bool get hasBackendGaps => backendGaps.isNotEmpty;

  PhysiotherapyDetail copyWith({
    PhysiotherapyWorkItem? item,
    List<PhysiotherapyRecord>? appointments,
    List<PhysiotherapyRecord>? procedures,
    List<PhysiotherapyRecord>? carePlans,
    List<PhysiotherapyRecord>? progressNotes,
    List<PhysiotherapyRecord>? followUps,
    List<String>? backendGaps,
  }) {
    return PhysiotherapyDetail(
      item: item ?? this.item,
      appointments: appointments ?? this.appointments,
      procedures: procedures ?? this.procedures,
      carePlans: carePlans ?? this.carePlans,
      progressNotes: progressNotes ?? this.progressNotes,
      followUps: followUps ?? this.followUps,
      backendGaps: backendGaps ?? this.backendGaps,
    );
  }
}

@immutable
final class PhysiotherapyWorkspaceState {
  const PhysiotherapyWorkspaceState({
    required this.query,
    required this.worklist,
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final PhysiotherapyWorklistQuery query;
  final AppPage<TherapyWorkItem> worklist;
  final PhysiotherapyDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get workloadCount {
    return worklist.items
        .where((TherapyWorkItem item) => !item.isCompleted)
        .length;
  }

  int get referralsCount {
    return _countScope(PhysiotherapyQueueScope.referrals);
  }

  int get todayCount {
    return _countScope(PhysiotherapyQueueScope.today);
  }

  int get missedCount {
    return _countScope(PhysiotherapyQueueScope.missed);
  }

  int get activePlansCount {
    return _countScope(PhysiotherapyQueueScope.activePlans);
  }

  int get followUpDueCount {
    return _countScope(PhysiotherapyQueueScope.followUpDue);
  }

  int get completedCount {
    return _countScope(PhysiotherapyQueueScope.completed);
  }

  int _countScope(PhysiotherapyQueueScope scope) {
    return worklist.items
        .where(
          (TherapyWorkItem item) => physiotherapyItemMatchesScope(item, scope),
        )
        .length;
  }

  PhysiotherapyWorkspaceState copyWith({
    PhysiotherapyWorklistQuery? query,
    AppPage<TherapyWorkItem>? worklist,
    PhysiotherapyDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return PhysiotherapyWorkspaceState(
      query: query ?? this.query,
      worklist: worklist ?? this.worklist,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

bool physiotherapyItemMatchesScope(
  TherapyWorkItem item,
  PhysiotherapyQueueScope scope,
) {
  final String status = item.status.toUpperCase();
  return switch (scope) {
    PhysiotherapyQueueScope.all => true,
    PhysiotherapyQueueScope.referrals =>
      status == 'REFERRAL' || status == 'ACCEPTED' || status == 'ASSESSMENT',
    PhysiotherapyQueueScope.today => _isToday(item.sessionAt),
    PhysiotherapyQueueScope.missed =>
      status == 'MISSED' ||
          (item.attendanceStatus ?? '').toUpperCase() == 'NO_SHOW',
    PhysiotherapyQueueScope.activePlans => status == 'ACTIVE_PLAN',
    PhysiotherapyQueueScope.followUpDue => status == 'FOLLOW_UP_DUE',
    PhysiotherapyQueueScope.completed =>
      status == 'COMPLETED' || status == 'CLOSED',
  };
}

int _newestFirst(PhysiotherapyRecord left, PhysiotherapyRecord right) {
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
}

bool _matchesDateRange(DateTime? value, DateTime? from, DateTime? to) {
  if (from == null && to == null) {
    return true;
  }
  if (value == null) {
    return false;
  }

  final DateTime localValue = _dateOnly(value.toLocal());
  if (from != null && localValue.isBefore(_dateOnly(from))) {
    return false;
  }
  if (to != null && localValue.isAfter(_dateOnly(to))) {
    return false;
  }
  return true;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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

bool _matchesExact(String? value, String? expected) {
  final String? normalizedExpected = _nonEmpty(expected);
  if (normalizedExpected == null) {
    return true;
  }
  return (value ?? '').trim().toLowerCase() == normalizedExpected.toLowerCase();
}

bool _matchesAnyContains(String? expected, Iterable<String?> values) {
  final String? normalizedExpected = _nonEmpty(expected)?.toLowerCase();
  if (normalizedExpected == null) {
    return true;
  }
  return values.whereType<String>().any(
    (String value) => value.toLowerCase().contains(normalizedExpected),
  );
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' • ');
  return joined.isEmpty ? null : joined;
}

bool _hasText(String? value) {
  return value?.trim().isNotEmpty ?? false;
}

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
