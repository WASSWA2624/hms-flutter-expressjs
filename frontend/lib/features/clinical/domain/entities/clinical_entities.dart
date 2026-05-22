import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum ClinicalQueueScope {
  all,
  today,
  urgent,
  waitingReview,
  inConsultation,
  resultsReady,
  completed,
}

@immutable
final class ClinicalWorklistQuery {
  const ClinicalWorklistQuery({
    this.search = '',
    this.filters = const ClinicalWorklistFilters(),
    this.scope = ClinicalQueueScope.all,
    this.pageRequest = const AppPageRequest(pageSize: 25),
  });

  final String search;
  final ClinicalWorklistFilters filters;
  final ClinicalQueueScope scope;
  final AppPageRequest pageRequest;

  String get databaseSearch {
    return _joinedSearchTerms(<String?>[
      search,
      filters.patient,
      filters.patientIdentifier,
      filters.patientPhone,
      filters.encounter,
      filters.queue,
      filters.providerText,
      filters.statusText,
      filters.location,
    ]);
  }

  ClinicalWorklistQuery copyWith({
    String? search,
    ClinicalWorklistFilters? filters,
    ClinicalQueueScope? scope,
    AppPageRequest? pageRequest,
  }) {
    return ClinicalWorklistQuery(
      search: search ?? this.search,
      filters: filters ?? this.filters,
      scope: scope ?? this.scope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class ClinicalWorklistFilters {
  const ClinicalWorklistFilters({
    this.searchField,
    this.dateFrom,
    this.dateTo,
    this.patient,
    this.patientIdentifier,
    this.patientPhone,
    this.encounter,
    this.queue,
    this.providerText,
    this.statusText,
    this.location,
    this.sourceQueue,
    this.status,
    this.provider,
  });

  final String? searchField;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? patient;
  final String? patientIdentifier;
  final String? patientPhone;
  final String? encounter;
  final String? queue;
  final String? providerText;
  final String? statusText;
  final String? location;
  final String? sourceQueue;
  final String? status;
  final String? provider;

  bool get isActive {
    return _hasText(searchField) ||
        dateFrom != null ||
        dateTo != null ||
        _hasText(patient) ||
        _hasText(patientIdentifier) ||
        _hasText(patientPhone) ||
        _hasText(encounter) ||
        _hasText(queue) ||
        _hasText(providerText) ||
        _hasText(statusText) ||
        _hasText(location) ||
        _hasText(sourceQueue) ||
        _hasText(status) ||
        _hasText(provider);
  }
}

@immutable
final class ClinicalWorklistEntry {
  const ClinicalWorklistEntry({
    required this.id,
    required this.sourceQueue,
    required this.encounterId,
    this.encounterPublicId,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.patientPublicId,
    this.patientDisplayName,
    this.patientPhone,
    this.patientAgeSex,
    this.patientDateOfBirth,
    this.patientGender,
    this.encounterType,
    this.status,
    this.stage,
    this.nextStep,
    this.currentLocation,
    this.providerUserId,
    this.providerDisplayName,
    this.startedAt,
    this.updatedAt,
    this.admissionId,
    this.admissionPublicId,
    this.opdFlowApiId,
    this.isUrgent = false,
    this.resultsReady = false,
  });

  final String id;
  final String sourceQueue;
  final String encounterId;
  final String? encounterPublicId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? patientPublicId;
  final String? patientDisplayName;
  final String? patientPhone;
  final String? patientAgeSex;
  final DateTime? patientDateOfBirth;
  final String? patientGender;
  final String? encounterType;
  final String? status;
  final String? stage;
  final String? nextStep;
  final String? currentLocation;
  final String? providerUserId;
  final String? providerDisplayName;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final String? admissionId;
  final String? admissionPublicId;
  final String? opdFlowApiId;
  final bool isUrgent;
  final bool resultsReady;

  String get apiEncounterId => encounterPublicId ?? encounterId;
  String? get apiPatientId => patientPublicId ?? patientId;
  String? get apiAdmissionId => admissionPublicId ?? admissionId;
  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientPublicId,
          patientId,
          encounterPublicId,
          encounterId,
        ]) ??
        encounterId;
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

  bool get isTerminal {
    if (sourceQueue == 'IPD' && (status ?? '').toUpperCase() == 'ADMITTED') {
      return false;
    }
    return switch ((status ?? stage ?? '').toUpperCase()) {
      'CLOSED' ||
      'COMPLETED' ||
      'DISCHARGED' ||
      'ADMITTED' ||
      'CANCELLED' => true,
      _ => false,
    };
  }

  bool matchesSearch(String search, {ClinicalWorklistFilters? filters}) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    final String? field = filters?.searchField;
    return _searchValuesForField(field).whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesFilters(ClinicalWorklistFilters filters) {
    if (!_matchesAnyContains(filters.patient, <String?>[
      patientId,
      patientPublicId,
      patientDisplayName,
      patientPhone,
      patientAgeSex,
      patientGender,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.patientIdentifier, <String?>[
      patientId,
      patientPublicId,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.patientPhone, <String?>[patientPhone])) {
      return false;
    }
    if (!_matchesAnyContains(filters.encounter, <String?>[
      encounterId,
      encounterPublicId,
      encounterType,
      admissionId,
      admissionPublicId,
      opdFlowApiId,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.queue, <String?>[
      sourceQueue,
      stage,
      nextStep,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.providerText, <String?>[
      providerUserId,
      providerDisplayName,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.statusText, <String?>[
      status,
      stage,
      nextStep,
    ])) {
      return false;
    }
    if (!_matchesAnyContains(filters.location, <String?>[
      facilityId,
      currentLocation,
    ])) {
      return false;
    }
    if (!_matchesExact(sourceQueue, filters.sourceQueue)) {
      return false;
    }
    if (!_matchesAnyExact(filters.status, <String?>[status, stage, nextStep])) {
      return false;
    }
    if (!_matchesExact(providerDisplayName, filters.provider)) {
      return false;
    }
    return _matchesDateRange(
      updatedAt ?? startedAt,
      filters.dateFrom,
      filters.dateTo,
    );
  }

  List<String?> _searchValuesForField(String? field) {
    return switch (field) {
      'patient' => <String?>[
        patientId,
        patientPublicId,
        patientDisplayName,
        patientPhone,
        patientAgeSex,
        patientGender,
      ],
      'encounter' => <String?>[encounterId, encounterPublicId],
      'source' => <String?>[sourceQueue],
      'status' => <String?>[status, stage, nextStep],
      'provider' => <String?>[providerUserId, providerDisplayName],
      'location' => <String?>[facilityId, currentLocation],
      _ => <String?>[
        id,
        sourceQueue,
        encounterId,
        encounterPublicId,
        tenantId,
        facilityId,
        patientId,
        patientPublicId,
        patientDisplayName,
        patientPhone,
        patientAgeSex,
        patientGender,
        encounterType,
        status,
        stage,
        nextStep,
        currentLocation,
        providerUserId,
        providerDisplayName,
        admissionId,
        admissionPublicId,
      ],
    };
  }

  ClinicalWorklistEntry copyWith({
    String? status,
    String? stage,
    String? nextStep,
    DateTime? updatedAt,
    bool? resultsReady,
  }) {
    return ClinicalWorklistEntry(
      id: id,
      sourceQueue: sourceQueue,
      encounterId: encounterId,
      encounterPublicId: encounterPublicId,
      tenantId: tenantId,
      facilityId: facilityId,
      patientId: patientId,
      patientPublicId: patientPublicId,
      patientDisplayName: patientDisplayName,
      patientPhone: patientPhone,
      patientAgeSex: patientAgeSex,
      patientDateOfBirth: patientDateOfBirth,
      patientGender: patientGender,
      encounterType: encounterType,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      currentLocation: currentLocation,
      providerUserId: providerUserId,
      providerDisplayName: providerDisplayName,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      admissionId: admissionId,
      admissionPublicId: admissionPublicId,
      opdFlowApiId: opdFlowApiId,
      isUrgent: isUrgent,
      resultsReady: resultsReady ?? this.resultsReady,
    );
  }
}

@immutable
final class ClinicalRelatedRecord {
  const ClinicalRelatedRecord({
    required this.id,
    required this.kind,
    this.status,
    this.title,
    this.subtitle,
    this.occurredAt,
    this.labOrderItems = const <ClinicalLabOrderItem>[],
    this.radiologyOrderItems = const <ClinicalRadiologyOrderItem>[],
    this.pharmacyOrderItems = const <ClinicalPharmacyOrderItem>[],
    this.itemCount = 0,
    this.pendingItemCount = 0,
    this.inProcessItemCount = 0,
    this.completedItemCount = 0,
    this.sampleCount = 0,
  });

  final String id;
  final String kind;
  final String? status;
  final String? title;
  final String? subtitle;
  final DateTime? occurredAt;
  final List<ClinicalLabOrderItem> labOrderItems;
  final List<ClinicalRadiologyOrderItem> radiologyOrderItems;
  final List<ClinicalPharmacyOrderItem> pharmacyOrderItems;
  final int itemCount;
  final int pendingItemCount;
  final int inProcessItemCount;
  final int completedItemCount;
  final int sampleCount;
}

@immutable
final class ClinicalLabOrderItem {
  const ClinicalLabOrderItem({
    required this.id,
    this.status,
    this.resultStatus,
    this.labTestId,
    this.testDisplayName,
    this.testCode,
    this.category,
    this.specimenType,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? status;
  final String? resultStatus;
  final String? labTestId;
  final String? testDisplayName;
  final String? testCode;
  final String? category;
  final String? specimenType;
  final String? unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[category, specimenType, unit, status]);
  }
}

@immutable
final class ClinicalRadiologyOrderItem {
  const ClinicalRadiologyOrderItem({
    required this.id,
    this.testDisplayName,
    this.modality,
    this.bodyRegion,
    this.laterality,
    this.priority,
    this.clinicalNote,
  });

  final String id;
  final String? testDisplayName;
  final String? modality;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;
  final String? clinicalNote;

  String get displayTitle {
    return _firstNonEmpty(<String?>[testDisplayName, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[modality, bodyRegion, laterality, priority]);
  }
}

@immutable
final class ClinicalPharmacyOrderItem {
  const ClinicalPharmacyOrderItem({
    required this.id,
    this.status,
    this.drugId,
    this.drugDisplayName,
    this.customPrescription,
    this.dosage,
    this.doseAmount,
    this.doseUnit,
    this.route,
    this.frequency,
    this.durationValue,
    this.durationUnit,
    this.quantity,
    this.quantityUnit,
    this.instructions,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? status;
  final String? drugId;
  final String? drugDisplayName;
  final String? customPrescription;
  final String? dosage;
  final String? doseAmount;
  final String? doseUnit;
  final String? route;
  final String? frequency;
  final String? durationValue;
  final String? durationUnit;
  final String? quantity;
  final String? quantityUnit;
  final String? instructions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          drugDisplayName,
          customPrescription,
          drugId,
        ]) ??
        id;
  }

  String? get doseLabel {
    return _firstNonEmpty(<String?>[
      dosage,
      _joinTextParts(<String?>[doseAmount, doseUnit]),
    ]);
  }

  String? get durationLabel {
    return _joinTextParts(<String?>[durationValue, durationUnit]);
  }

  String? get quantityLabel {
    return _joinTextParts(<String?>[quantity, quantityUnit]);
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[
      doseLabel,
      route,
      frequency,
      durationLabel,
      quantityLabel,
    ]);
  }
}

@immutable
final class ClinicalVitalSummary {
  const ClinicalVitalSummary({
    required this.id,
    required this.vitalType,
    required this.displayValue,
    this.status = 'RECORDED',
    this.recordedAt,
  });

  final String id;
  final String vitalType;
  final String displayValue;
  final String status;
  final DateTime? recordedAt;
}

@immutable
final class ClinicalAlertSummary {
  const ClinicalAlertSummary({
    required this.id,
    this.severity,
    this.status,
    this.message,
    this.vitalSignId,
    this.createdAt,
  });

  final String id;
  final String? severity;
  final String? status;
  final String? message;
  final String? vitalSignId;
  final DateTime? createdAt;
}

@immutable
final class ClinicalTriageHandoff {
  const ClinicalTriageHandoff({
    this.triageLevel,
    this.routeTo,
    this.chiefComplaint,
    this.triageNotes,
    this.stage,
    this.nextStep,
    this.emergencyIndicator = false,
    this.queuedAt,
    this.vitalSigns = const <ClinicalVitalSummary>[],
    this.alerts = const <ClinicalAlertSummary>[],
  });

  final String? triageLevel;
  final String? routeTo;
  final String? chiefComplaint;
  final String? triageNotes;
  final String? stage;
  final String? nextStep;
  final bool emergencyIndicator;
  final DateTime? queuedAt;
  final List<ClinicalVitalSummary> vitalSigns;
  final List<ClinicalAlertSummary> alerts;

  bool get hasContent {
    return _firstNonEmpty(<String?>[
              triageLevel,
              routeTo,
              chiefComplaint,
              triageNotes,
              stage,
              nextStep,
            ]) !=
            null ||
        emergencyIndicator ||
        vitalSigns.isNotEmpty ||
        alerts.isNotEmpty;
  }
}

typedef ClinicalCatalogOption = ClinicalActionCatalogOption;

typedef ClinicalRadiologyRequest = ClinicalActionRadiologyRequest;

@immutable
final class ClinicalEncounterBundle {
  const ClinicalEncounterBundle({
    required this.entry,
    this.triageHandoff,
    this.clinicalNotes = const <ClinicalRelatedRecord>[],
    this.diagnoses = const <ClinicalRelatedRecord>[],
    this.procedures = const <ClinicalRelatedRecord>[],
    this.carePlans = const <ClinicalRelatedRecord>[],
    this.labOrders = const <ClinicalRelatedRecord>[],
    this.radiologyOrders = const <ClinicalRelatedRecord>[],
    this.pharmacyOrders = const <ClinicalRelatedRecord>[],
    this.referrals = const <ClinicalRelatedRecord>[],
    this.followUps = const <ClinicalRelatedRecord>[],
    this.admissions = const <ClinicalRelatedRecord>[],
  });

  final ClinicalWorklistEntry entry;
  final ClinicalTriageHandoff? triageHandoff;
  final List<ClinicalRelatedRecord> clinicalNotes;
  final List<ClinicalRelatedRecord> diagnoses;
  final List<ClinicalRelatedRecord> procedures;
  final List<ClinicalRelatedRecord> carePlans;
  final List<ClinicalRelatedRecord> labOrders;
  final List<ClinicalRelatedRecord> radiologyOrders;
  final List<ClinicalRelatedRecord> pharmacyOrders;
  final List<ClinicalRelatedRecord> referrals;
  final List<ClinicalRelatedRecord> followUps;
  final List<ClinicalRelatedRecord> admissions;

  bool get hasResultsReady {
    return <ClinicalRelatedRecord>[...labOrders, ...radiologyOrders].any(
      (ClinicalRelatedRecord record) =>
          (record.status ?? '').toUpperCase() == 'COMPLETED',
    );
  }

  int get openActionCount {
    return <ClinicalRelatedRecord>[
          ...labOrders,
          ...radiologyOrders,
          ...pharmacyOrders,
          ...referrals,
          ...followUps,
          ...admissions,
        ]
        .where((ClinicalRelatedRecord record) => !_isTerminal(record.status))
        .length;
  }

  ClinicalEncounterBundle copyWith({
    ClinicalWorklistEntry? entry,
    ClinicalTriageHandoff? triageHandoff,
    List<ClinicalRelatedRecord>? clinicalNotes,
    List<ClinicalRelatedRecord>? diagnoses,
    List<ClinicalRelatedRecord>? procedures,
    List<ClinicalRelatedRecord>? carePlans,
    List<ClinicalRelatedRecord>? labOrders,
    List<ClinicalRelatedRecord>? radiologyOrders,
    List<ClinicalRelatedRecord>? pharmacyOrders,
    List<ClinicalRelatedRecord>? referrals,
    List<ClinicalRelatedRecord>? followUps,
    List<ClinicalRelatedRecord>? admissions,
  }) {
    return ClinicalEncounterBundle(
      entry: entry ?? this.entry,
      triageHandoff: triageHandoff ?? this.triageHandoff,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      diagnoses: diagnoses ?? this.diagnoses,
      procedures: procedures ?? this.procedures,
      carePlans: carePlans ?? this.carePlans,
      labOrders: labOrders ?? this.labOrders,
      radiologyOrders: radiologyOrders ?? this.radiologyOrders,
      pharmacyOrders: pharmacyOrders ?? this.pharmacyOrders,
      referrals: referrals ?? this.referrals,
      followUps: followUps ?? this.followUps,
      admissions: admissions ?? this.admissions,
    );
  }
}

typedef ClinicalReferenceData = ClinicalActionReferenceData;

@immutable
final class ClinicalWorkspaceState {
  const ClinicalWorkspaceState({
    required this.query,
    required this.worklist,
    this.referenceData = const ClinicalReferenceData(),
    this.selectedBundle,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final ClinicalWorklistQuery query;
  final AppPage<ClinicalWorklistEntry> worklist;
  final ClinicalReferenceData referenceData;
  final ClinicalEncounterBundle? selectedBundle;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get waitingReviewCount {
    return worklist.items
        .where(
          (ClinicalWorklistEntry item) =>
              _matchesReviewState(item) && !item.isTerminal,
        )
        .length;
  }

  int get urgentCount {
    return worklist.items
        .where(
          (ClinicalWorklistEntry item) => item.isUrgent && !item.isTerminal,
        )
        .length;
  }

  int get resultsReadyCount {
    return worklist.items
        .where(
          (ClinicalWorklistEntry item) => item.resultsReady && !item.isTerminal,
        )
        .length;
  }

  int get inConsultationCount {
    return worklist.items
        .where(
          (ClinicalWorklistEntry item) =>
              _matchesConsultationState(item) && !item.isTerminal,
        )
        .length;
  }

  int get completedCount {
    return worklist.items
        .where((ClinicalWorklistEntry item) => item.isTerminal)
        .length;
  }

  ClinicalWorkspaceState copyWith({
    ClinicalWorklistQuery? query,
    AppPage<ClinicalWorklistEntry>? worklist,
    ClinicalReferenceData? referenceData,
    ClinicalEncounterBundle? selectedBundle,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedBundle = false,
    bool clearLastFailure = false,
  }) {
    return ClinicalWorkspaceState(
      query: query ?? this.query,
      worklist: worklist ?? this.worklist,
      referenceData: referenceData ?? this.referenceData,
      selectedBundle: clearSelectedBundle
          ? null
          : selectedBundle ?? this.selectedBundle,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

bool clinicalWorklistEntryMatchesScope(
  ClinicalWorklistEntry item,
  ClinicalQueueScope scope,
) {
  return switch (scope) {
    ClinicalQueueScope.all => true,
    ClinicalQueueScope.today => _isToday(item.updatedAt ?? item.startedAt),
    ClinicalQueueScope.urgent => item.isUrgent,
    ClinicalQueueScope.waitingReview => _matchesReviewState(item),
    ClinicalQueueScope.inConsultation => _matchesConsultationState(item),
    ClinicalQueueScope.resultsReady => item.resultsReady,
    ClinicalQueueScope.completed => item.isTerminal,
  };
}

List<ClinicalWorklistEntry> deduplicateClinicalWorklistEntries(
  Iterable<ClinicalWorklistEntry> entries,
) {
  final Map<String, ClinicalWorklistEntry> byEncounter =
      <String, ClinicalWorklistEntry>{};

  for (final ClinicalWorklistEntry entry in entries) {
    final String key = _worklistDeduplicationKey(entry);
    final ClinicalWorklistEntry? existing = byEncounter[key];
    byEncounter[key] = existing == null
        ? entry
        : _mergeClinicalWorklistEntries(existing, entry);
  }

  return byEncounter.values.toList(growable: false);
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

String _worklistDeduplicationKey(ClinicalWorklistEntry entry) {
  return (_firstNonEmpty(<String?>[
            entry.encounterId,
            entry.encounterPublicId,
            entry.id,
          ]) ??
          entry.hashCode.toString())
      .toUpperCase();
}

ClinicalWorklistEntry _mergeClinicalWorklistEntries(
  ClinicalWorklistEntry left,
  ClinicalWorklistEntry right,
) {
  final int leftPriority = _worklistSourcePriority(left);
  final int rightPriority = _worklistSourcePriority(right);
  final ClinicalWorklistEntry preferred =
      rightPriority > leftPriority ||
          (rightPriority == leftPriority &&
              _entryUpdatedAt(right).isAfter(_entryUpdatedAt(left)))
      ? right
      : left;
  final ClinicalWorklistEntry fallback = identical(preferred, left)
      ? right
      : left;

  return ClinicalWorklistEntry(
    id: preferred.id,
    sourceQueue: preferred.sourceQueue,
    encounterId:
        _firstNonEmpty(<String?>[
          preferred.encounterId,
          fallback.encounterId,
        ]) ??
        preferred.encounterId,
    encounterPublicId: _firstNonEmpty(<String?>[
      preferred.encounterPublicId,
      fallback.encounterPublicId,
    ]),
    tenantId: _firstNonEmpty(<String?>[preferred.tenantId, fallback.tenantId]),
    facilityId: _firstNonEmpty(<String?>[
      preferred.facilityId,
      fallback.facilityId,
    ]),
    patientId: _firstNonEmpty(<String?>[
      preferred.patientId,
      fallback.patientId,
    ]),
    patientPublicId: _firstNonEmpty(<String?>[
      preferred.patientPublicId,
      fallback.patientPublicId,
    ]),
    patientDisplayName: _firstNonEmpty(<String?>[
      preferred.patientDisplayName,
      fallback.patientDisplayName,
    ]),
    patientPhone: _firstNonEmpty(<String?>[
      preferred.patientPhone,
      fallback.patientPhone,
    ]),
    patientAgeSex: _firstNonEmpty(<String?>[
      preferred.patientAgeSex,
      fallback.patientAgeSex,
    ]),
    patientDateOfBirth:
        preferred.patientDateOfBirth ?? fallback.patientDateOfBirth,
    patientGender: _firstNonEmpty(<String?>[
      preferred.patientGender,
      fallback.patientGender,
    ]),
    encounterType: _firstNonEmpty(<String?>[
      preferred.encounterType,
      fallback.encounterType,
    ]),
    status: _firstNonEmpty(<String?>[preferred.status, fallback.status]),
    stage: _firstNonEmpty(<String?>[preferred.stage, fallback.stage]),
    nextStep: _firstNonEmpty(<String?>[preferred.nextStep, fallback.nextStep]),
    currentLocation: _firstNonEmpty(<String?>[
      preferred.currentLocation,
      fallback.currentLocation,
    ]),
    providerUserId: _firstNonEmpty(<String?>[
      preferred.providerUserId,
      fallback.providerUserId,
    ]),
    providerDisplayName: _firstNonEmpty(<String?>[
      preferred.providerDisplayName,
      fallback.providerDisplayName,
    ]),
    startedAt: preferred.startedAt ?? fallback.startedAt,
    updatedAt: _latestDateTime(preferred.updatedAt, fallback.updatedAt),
    admissionId: _firstNonEmpty(<String?>[
      preferred.admissionId,
      fallback.admissionId,
    ]),
    admissionPublicId: _firstNonEmpty(<String?>[
      preferred.admissionPublicId,
      fallback.admissionPublicId,
    ]),
    opdFlowApiId: _firstNonEmpty(<String?>[
      preferred.opdFlowApiId,
      fallback.opdFlowApiId,
    ]),
    isUrgent: preferred.isUrgent || fallback.isUrgent,
    resultsReady: preferred.resultsReady || fallback.resultsReady,
  );
}

int _worklistSourcePriority(ClinicalWorklistEntry entry) {
  final String source = entry.sourceQueue.toUpperCase();
  if (source == 'IPD') {
    return 500;
  }
  if (source == 'TRIAGE' && _isTriageQueueStage(entry.stage)) {
    return 450;
  }
  if (source == 'OPD') {
    return 400;
  }
  if (source == 'TRIAGE') {
    return 350;
  }
  if (_hasText(entry.opdFlowApiId)) {
    return 300;
  }
  if (source == 'ENCOUNTER') {
    return 100;
  }
  return 200;
}

bool _isTriageQueueStage(String? stage) {
  return switch ((stage ?? '').toUpperCase()) {
    'WAITING_VITALS' || 'WAITING_DOCTOR_ASSIGNMENT' => true,
    _ => false,
  };
}

DateTime _entryUpdatedAt(ClinicalWorklistEntry entry) {
  return entry.updatedAt ??
      entry.startedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _latestDateTime(DateTime? left, DateTime? right) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  return right.isAfter(left) ? right : left;
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

bool _matchesExact(String? value, String? expected) {
  final String? normalizedExpected = _nonEmpty(expected);
  if (normalizedExpected == null) {
    return true;
  }
  return (value ?? '').trim().toLowerCase() == normalizedExpected.toLowerCase();
}

bool _matchesAnyExact(String? expected, Iterable<String?> values) {
  final String? normalizedExpected = _nonEmpty(expected);
  if (normalizedExpected == null) {
    return true;
  }
  return values.any(
    (String? value) => _matchesExact(value, normalizedExpected),
  );
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

bool _matchesReviewState(ClinicalWorklistEntry item) {
  final String value = '${item.stage ?? ''} ${item.nextStep ?? ''}'
      .toUpperCase();
  return value.contains('REVIEW') || value.contains('DOCTOR');
}

bool _matchesConsultationState(ClinicalWorklistEntry item) {
  final String value = '${item.stage ?? ''} ${item.status ?? ''}'.toUpperCase();
  return value.contains('CONSULT') ||
      value.contains('IN_PROGRESS') ||
      value == 'OPEN';
}

bool _isTerminal(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'DISCHARGED' ||
    'CLOSED' ||
    'DISPENSED' => true,
    _ => false,
  };
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

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

bool _hasText(String? value) {
  return _nonEmpty(value) != null;
}

String _joinedSearchTerms(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .toSet()
      .join(' ');
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? _joinTextParts(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return joined.isEmpty ? null : joined;
}
