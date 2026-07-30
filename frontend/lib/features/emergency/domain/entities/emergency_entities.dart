import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum EmergencyBoardScope { active, critical, ambulance, handoff, closed, all }

enum EmergencyBoardTab { active, critical, ambulance, handoff, closed, all }

/// Panels the emergency workspace can focus via deep link
/// (`/emergency?id=&panel=triage|response|ambulance|handoff`).
enum EmergencyDetailPanelFocus { none, triage, response, ambulance, handoff }

/// Parsed deep-link parameters for the emergency workspace route
/// (`/emergency?id=&panel=`).
///
/// `caseId` deep-links to a specific emergency case (opens its detail).
/// `panel` pre-focuses an action panel (triage, response, ambulance, handoff).
/// `search` pre-fills the board search box.
@immutable
final class EmergencyWorkspaceQuery {
  const EmergencyWorkspaceQuery({
    this.caseId = '',
    this.panel = EmergencyDetailPanelFocus.none,
    this.search = '',
    this.scope = '',
  });

  factory EmergencyWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return EmergencyWorkspaceQuery(
      caseId: pick(<String>[
        'id',
        'case',
        'caseId',
        'emergencyCaseId',
        'encounterId',
        'encounter',
      ]),
      panel: _panelFromValue(pick(<String>['panel', 'focus', 'action'])),
      search: pick(<String>['search', 'q', 'patient']),
      scope: pick(<String>['scope', 'board', 'tab']),
    );
  }

  final String caseId;
  final EmergencyDetailPanelFocus panel;
  final String search;
  final String scope;

  bool get hasRouteTargeting =>
      caseId.isNotEmpty ||
      panel != EmergencyDetailPanelFocus.none ||
      search.isNotEmpty ||
      scope.isNotEmpty;

  String get signature => '$caseId|${panel.name}|$search|$scope';

  static EmergencyDetailPanelFocus _panelFromValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'triage' => EmergencyDetailPanelFocus.triage,
      'response' => EmergencyDetailPanelFocus.response,
      'ambulance' ||
      'dispatch' ||
      'trip' => EmergencyDetailPanelFocus.ambulance,
      'handoff' => EmergencyDetailPanelFocus.handoff,
      _ => EmergencyDetailPanelFocus.none,
    };
  }
}

/// Snapshot of the downstream workflow created when an emergency case is
/// handed off, persisted on the case so the detail panel can deep-link into
/// the receiving module without re-querying it.
@immutable
final class EmergencyHandoffOutcome {
  const EmergencyHandoffOutcome({
    required this.destination,
    this.route,
    this.receivingDisplayId,
    this.encounterDisplayId,
    this.admissionDisplayId,
    this.icuStayDisplayId,
    this.stage,
    this.billingDeferred = false,
    this.billingPaymentStatus,
    this.billingInvoiceId,
    this.terminal = false,
    this.notes,
    this.handoffAt,
  });

  final String destination;
  final String? route;
  final String? receivingDisplayId;
  final String? encounterDisplayId;
  final String? admissionDisplayId;
  final String? icuStayDisplayId;
  final String? stage;
  final bool billingDeferred;
  /// Billing SoR payment status when a deferred invoice was posted.
  final String? billingPaymentStatus;
  final String? billingInvoiceId;
  final bool terminal;
  final String? notes;
  final DateTime? handoffAt;

  /// True when a receiving workflow was created and can be opened.
  bool get hasReceivingWork =>
      !terminal && (receivingDisplayId ?? '').trim().isNotEmpty;

  /// Deep link into the receiving module, or null when terminal / unavailable.
  String? get receivingDeepLink {
    final String? routeKey = route?.trim();
    final String? id = receivingDisplayId?.trim();
    if (routeKey == null || routeKey.isEmpty) {
      return null;
    }
    if (id == null || id.isEmpty) {
      return '/$routeKey';
    }
    return '/$routeKey?id=${Uri.encodeQueryComponent(id)}';
  }
}

@immutable
final class EmergencyBoardQuery {
  const EmergencyBoardQuery({
    this.search = '',
    this.scope = EmergencyBoardScope.active,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final EmergencyBoardScope scope;
  final AppPageRequest pageRequest;

  EmergencyBoardQuery copyWith({
    String? search,
    EmergencyBoardScope? scope,
    AppPageRequest? pageRequest,
  }) {
    return EmergencyBoardQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class EmergencyCaseSummary {
  const EmergencyCaseSummary({
    required this.id,
    this.displayId,
    this.tenantId,
    this.tenantLabel,
    this.facilityId,
    this.facilityLabel,
    this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.severity,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.latestTriage,
    this.latestResponse,
    this.latestDispatch,
    this.activeTrip,
    this.handoff,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? tenantLabel;
  final String? facilityId;
  final String? facilityLabel;
  final String? patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? severity;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final EmergencyTriageAssessment? latestTriage;
  final EmergencyResponseRecord? latestResponse;
  final EmergencyAmbulanceDispatch? latestDispatch;
  final EmergencyAmbulanceTrip? activeTrip;
  final EmergencyHandoffOutcome? handoff;

  String get apiId => id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientDisplayId,
          displayId,
          id,
        ]) ??
        id;
  }

  String get caseLabel => _firstNonEmpty(<String?>[displayId, id]) ?? id;

  String get patientLabel {
    return _joinDisplay(<String?>[patientDisplayName, patientDisplayId]) ??
        patientDisplayName ??
        patientDisplayId ??
        '';
  }

  String get triageLevel => latestTriage?.triageLevel ?? '';

  String get responseStatus {
    if (latestResponse != null) {
      return 'RESPONDED';
    }
    return 'WAITING_RESPONSE';
  }

  String get currentLocation {
    if (activeTrip != null) {
      return 'Ambulance transporting';
    }
    final String dispatchStatus = latestDispatch?.status ?? '';
    if (dispatchStatus.isNotEmpty &&
        dispatchStatus.toUpperCase() != 'AVAILABLE') {
      return 'Ambulance ${_apiLabel(dispatchStatus)}';
    }
    return facilityLabel ?? 'Emergency reception';
  }

  String get nextAction {
    final String normalizedStatus = (status ?? '').toUpperCase();
    if (normalizedStatus == 'CLOSED' || normalizedStatus == 'COMPLETED') {
      return 'Review summary';
    }
    if (normalizedStatus == 'CANCELLED') {
      return 'Review cancellation';
    }
    if (latestTriage == null) {
      return 'Record triage';
    }
    if (latestResponse == null) {
      return 'Mark response';
    }
    if (activeTrip != null) {
      return 'Receive ambulance';
    }
    return 'Handoff';
  }

  bool get isOpen {
    return switch ((status ?? '').toUpperCase()) {
      'OPEN' || 'PENDING' || 'IN_PROGRESS' => true,
      _ => false,
    };
  }

  bool get isCritical {
    return switch ((severity ?? '').toUpperCase()) {
      'CRITICAL' || 'HIGH' => true,
      _ => false,
    };
  }

  bool get hasAmbulanceActivity => latestDispatch != null || activeTrip != null;

  bool get isReadyForHandoff {
    return isOpen && latestTriage != null && latestResponse != null;
  }

  bool matchesSearch(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    final EmergencyAmbulanceTrip? trip = activeTrip;
    return <String?>[
      id,
      displayId,
      caseLabel,
      patientDisplayId,
      patientDisplayName,
      displayTitle,
      severity,
      status,
      facilityLabel,
      currentLocation,
      triageLevel,
      responseStatus,
      nextAction,
      latestTriage?.triageLevel,
      latestDispatch?.ambulanceLabel,
      latestDispatch?.status,
      activeTrip?.ambulanceLabel,
      handoff?.destination,
      trip == null ? null : (trip.isActive ? 'IN_TRANSIT' : 'COMPLETE'),
      createdAt?.toIso8601String(),
      updatedAt?.toIso8601String(),
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  EmergencyCaseSummary copyWith({
    String? severity,
    String? status,
    EmergencyTriageAssessment? latestTriage,
    EmergencyResponseRecord? latestResponse,
    EmergencyAmbulanceDispatch? latestDispatch,
    EmergencyAmbulanceTrip? activeTrip,
    EmergencyHandoffOutcome? handoff,
  }) {
    return EmergencyCaseSummary(
      id: id,
      displayId: displayId,
      tenantId: tenantId,
      tenantLabel: tenantLabel,
      facilityId: facilityId,
      facilityLabel: facilityLabel,
      patientId: patientId,
      patientDisplayId: patientDisplayId,
      patientDisplayName: patientDisplayName,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latestTriage: latestTriage ?? this.latestTriage,
      latestResponse: latestResponse ?? this.latestResponse,
      latestDispatch: latestDispatch ?? this.latestDispatch,
      activeTrip: activeTrip ?? this.activeTrip,
      handoff: handoff ?? this.handoff,
    );
  }
}

@immutable
final class EmergencyTriageAssessment {
  const EmergencyTriageAssessment({
    required this.id,
    this.displayId,
    this.emergencyCaseId,
    this.emergencyCaseDisplayId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.triageLevel,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? emergencyCaseId;
  final String? emergencyCaseDisplayId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? triageLevel;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class EmergencyResponseRecord {
  const EmergencyResponseRecord({
    required this.id,
    this.displayId,
    this.emergencyCaseId,
    this.emergencyCaseDisplayId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.responseAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? emergencyCaseId;
  final String? emergencyCaseDisplayId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final DateTime? responseAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class EmergencyAmbulance {
  const EmergencyAmbulance({
    required this.id,
    this.displayId,
    this.identifier,
    this.status,
    this.facilityId,
    this.facilityLabel,
  });

  final String id;
  final String? displayId;
  final String? identifier;
  final String? status;
  final String? facilityId;
  final String? facilityLabel;

  String get displayTitle {
    return _joinDisplay(<String?>[identifier, displayId]) ?? id;
  }

  bool get isAvailable => (status ?? '').toUpperCase() == 'AVAILABLE';
}

@immutable
final class EmergencyAmbulanceDispatch {
  const EmergencyAmbulanceDispatch({
    required this.id,
    this.displayId,
    this.emergencyCaseId,
    this.emergencyCaseDisplayId,
    this.ambulanceId,
    this.ambulanceDisplayId,
    this.ambulanceLabel,
    this.patientDisplayId,
    this.patientDisplayName,
    this.status,
    this.dispatchedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? emergencyCaseId;
  final String? emergencyCaseDisplayId;
  final String? ambulanceId;
  final String? ambulanceDisplayId;
  final String? ambulanceLabel;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? status;
  final DateTime? dispatchedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive {
    return switch ((status ?? '').toUpperCase()) {
      'DISPATCHED' || 'EN_ROUTE' || 'ON_SCENE' || 'TRANSPORTING' => true,
      _ => false,
    };
  }
}

@immutable
final class EmergencyAmbulanceTrip {
  const EmergencyAmbulanceTrip({
    required this.id,
    this.displayId,
    this.emergencyCaseId,
    this.emergencyCaseDisplayId,
    this.ambulanceId,
    this.ambulanceDisplayId,
    this.ambulanceLabel,
    this.patientDisplayId,
    this.patientDisplayName,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
    this.billingDeferred = false,
    this.billingPaymentStatus,
    this.billingInvoiceId,
  });

  final String id;
  final String? displayId;
  final String? emergencyCaseId;
  final String? emergencyCaseDisplayId;
  final String? ambulanceId;
  final String? ambulanceDisplayId;
  final String? ambulanceLabel;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when trip mutation posted a deferred PENDING charge in Billing.
  final bool billingDeferred;

  /// Billing SoR payment status when a transport invoice was posted.
  final String? billingPaymentStatus;
  final String? billingInvoiceId;

  bool get isActive => endedAt == null;

  bool get hasBillingSnapshot =>
      billingDeferred ||
      (billingPaymentStatus ?? '').trim().isNotEmpty ||
      (billingInvoiceId ?? '').trim().isNotEmpty;
}

@immutable
final class EmergencyReferenceData {
  const EmergencyReferenceData({
    this.ambulances = const <EmergencyAmbulance>[],
  });

  final List<EmergencyAmbulance> ambulances;

  List<EmergencyAmbulance> get availableAmbulances {
    final List<EmergencyAmbulance> available = ambulances
        .where((EmergencyAmbulance ambulance) => ambulance.isAvailable)
        .toList(growable: false);
    return available.isEmpty ? ambulances : available;
  }
}

@immutable
final class EmergencyCaseDetail {
  const EmergencyCaseDetail({
    required this.summary,
    this.triageAssessments = const <EmergencyTriageAssessment>[],
    this.responses = const <EmergencyResponseRecord>[],
    this.dispatches = const <EmergencyAmbulanceDispatch>[],
    this.trips = const <EmergencyAmbulanceTrip>[],
  });

  final EmergencyCaseSummary summary;
  final List<EmergencyTriageAssessment> triageAssessments;
  final List<EmergencyResponseRecord> responses;
  final List<EmergencyAmbulanceDispatch> dispatches;
  final List<EmergencyAmbulanceTrip> trips;

  EmergencyTriageAssessment? get latestTriage {
    return triageAssessments.firstOrNull ?? summary.latestTriage;
  }

  EmergencyResponseRecord? get latestResponse {
    return responses.firstOrNull ?? summary.latestResponse;
  }

  EmergencyAmbulanceDispatch? get latestDispatch {
    return dispatches.firstOrNull ?? summary.latestDispatch;
  }

  EmergencyAmbulanceTrip? get activeTrip {
    return trips
            .where((EmergencyAmbulanceTrip trip) => trip.isActive)
            .firstOrNull ??
        summary.activeTrip;
  }

  EmergencyAmbulanceTrip? get latestTrip {
    return activeTrip ?? trips.firstOrNull;
  }

  EmergencyCaseDetail copyWith({
    EmergencyCaseSummary? summary,
    List<EmergencyTriageAssessment>? triageAssessments,
    List<EmergencyResponseRecord>? responses,
    List<EmergencyAmbulanceDispatch>? dispatches,
    List<EmergencyAmbulanceTrip>? trips,
  }) {
    return EmergencyCaseDetail(
      summary: summary ?? this.summary,
      triageAssessments: triageAssessments ?? this.triageAssessments,
      responses: responses ?? this.responses,
      dispatches: dispatches ?? this.dispatches,
      trips: trips ?? this.trips,
    );
  }
}

@immutable
final class EmergencyQuickArrivalInput {
  const EmergencyQuickArrivalInput({
    required this.firstName,
    required this.lastName,
    required this.severity,
    this.tenantId,
    this.facilityId,
    this.phone,
    this.triageLevel,
    this.notes,
  });

  final String firstName;
  final String lastName;
  final String severity;
  final String? tenantId;
  final String? facilityId;
  final String? phone;
  final String? triageLevel;
  final String? notes;

  EmergencyQuickArrivalInput copyWith({
    String? firstName,
    String? lastName,
    String? severity,
    String? tenantId,
    String? facilityId,
    String? phone,
    String? triageLevel,
    String? notes,
  }) {
    return EmergencyQuickArrivalInput(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      severity: severity ?? this.severity,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      phone: phone ?? this.phone,
      triageLevel: triageLevel ?? this.triageLevel,
      notes: notes ?? this.notes,
    );
  }
}

@immutable
final class EmergencyWorkspaceState {
  const EmergencyWorkspaceState({
    required this.query,
    required this.board,
    this.referenceData = const EmergencyReferenceData(),
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshingBoard = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final EmergencyBoardQuery query;
  final AppPage<EmergencyCaseSummary> board;
  final EmergencyReferenceData referenceData;
  final EmergencyCaseDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshingBoard;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get activeCount {
    return board.items.where((EmergencyCaseSummary item) => item.isOpen).length;
  }

  int get criticalCount {
    return board.items
        .where((EmergencyCaseSummary item) => item.isOpen && item.isCritical)
        .length;
  }

  int get ambulanceCount {
    return board.items
        .where((EmergencyCaseSummary item) => item.hasAmbulanceActivity)
        .length;
  }

  int get handoffCount {
    return board.items
        .where((EmergencyCaseSummary item) => item.isReadyForHandoff)
        .length;
  }

  int get closedCount {
    return board.items
        .where((EmergencyCaseSummary item) => !item.isOpen)
        .length;
  }

  int get allCount => board.totalItemCount ?? board.items.length;

  int get workloadCount {
    final Set<String> uniqueCases = <String>{};
    for (final EmergencyCaseSummary item in board.items) {
      if (item.isOpen || item.hasAmbulanceActivity) {
        uniqueCases.add(item.id);
      }
    }
    return uniqueCases.length;
  }

  EmergencyWorkspaceState copyWith({
    EmergencyBoardQuery? query,
    AppPage<EmergencyCaseSummary>? board,
    EmergencyReferenceData? referenceData,
    EmergencyCaseDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshingBoard,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return EmergencyWorkspaceState(
      query: query ?? this.query,
      board: board ?? this.board,
      referenceData: referenceData ?? this.referenceData,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshingBoard: isRefreshingBoard ?? this.isRefreshingBoard,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }
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
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
