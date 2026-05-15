import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

@immutable
final class PatientListQuery {
  const PatientListQuery({
    this.search = '',
    this.patientId = '',
    this.gender,
    this.isActive,
    this.consentState,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String patientId;
  final String? gender;
  final bool? isActive;
  final String? consentState;
  final AppPageRequest pageRequest;

  PatientListQuery copyWith({
    String? search,
    String? patientId,
    String? gender,
    bool? isActive,
    String? consentState,
    AppPageRequest? pageRequest,
    bool clearGender = false,
    bool clearIsActive = false,
    bool clearConsentState = false,
  }) {
    return PatientListQuery(
      search: search ?? this.search,
      patientId: patientId ?? this.patientId,
      gender: clearGender ? null : gender ?? this.gender,
      isActive: clearIsActive ? null : isActive ?? this.isActive,
      consentState: clearConsentState
          ? null
          : consentState ?? this.consentState,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class Patient {
  const Patient({
    required this.id,
    this.publicId,
    this.displayName,
    this.tenantId,
    this.facilityId,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.isActive = true,
    this.primaryPhone,
    this.primaryEmail,
    this.primaryIdentifierType,
    this.primaryIdentifierValue,
    this.tenantLabel,
    this.facilityLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String? displayName;
  final String? tenantId;
  final String? facilityId;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final bool isActive;
  final String? primaryPhone;
  final String? primaryEmail;
  final String? primaryIdentifierType;
  final String? primaryIdentifierValue;
  final String? tenantLabel;
  final String? facilityLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveDisplayName {
    final String first = firstName?.trim() ?? '';
    final String last = lastName?.trim() ?? '';
    final String joined = <String>[
      first,
      last,
    ].where((String value) => value.isNotEmpty).join(' ');
    return _firstNonEmpty(<String?>[displayName, joined, publicId, id]) ?? id;
  }

  String? get effectiveIdentifier {
    final String? typedIdentifier = _joinNonEmpty(<String?>[
      primaryIdentifierType,
      primaryIdentifierValue,
    ]);
    return _firstNonEmpty(<String?>[typedIdentifier, publicId, id]);
  }

  Patient copyWith({
    String? id,
    String? publicId,
    String? displayName,
    String? tenantId,
    String? facilityId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    bool? isActive,
    String? primaryPhone,
    String? primaryEmail,
    String? primaryIdentifierType,
    String? primaryIdentifierValue,
    String? tenantLabel,
    String? facilityLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDateOfBirth = false,
    bool clearGender = false,
    bool clearFacilityId = false,
    bool clearPrimaryPhone = false,
    bool clearPrimaryEmail = false,
    bool clearPrimaryIdentifierType = false,
    bool clearPrimaryIdentifierValue = false,
  }) {
    return Patient(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      tenantId: tenantId ?? this.tenantId,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      gender: clearGender ? null : gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      primaryPhone: clearPrimaryPhone
          ? null
          : primaryPhone ?? this.primaryPhone,
      primaryEmail: clearPrimaryEmail
          ? null
          : primaryEmail ?? this.primaryEmail,
      primaryIdentifierType: clearPrimaryIdentifierType
          ? null
          : primaryIdentifierType ?? this.primaryIdentifierType,
      primaryIdentifierValue: clearPrimaryIdentifierValue
          ? null
          : primaryIdentifierValue ?? this.primaryIdentifierValue,
      tenantLabel: tenantLabel ?? this.tenantLabel,
      facilityLabel: facilityLabel ?? this.facilityLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
final class PatientIdentifier {
  const PatientIdentifier({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.type,
    required this.value,
    this.publicId,
    this.isPrimary = false,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String type;
  final String value;
  final bool isPrimary;
  final DateTime? updatedAt;
}

@immutable
final class PatientContact {
  const PatientContact({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.type,
    required this.value,
    this.publicId,
    this.isPrimary = false,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String type;
  final String value;
  final bool isPrimary;
  final DateTime? updatedAt;
}

@immutable
final class PatientGuardian {
  const PatientGuardian({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.name,
    this.publicId,
    this.relationship,
    this.phone,
    this.email,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String name;
  final String? relationship;
  final String? phone;
  final String? email;
  final DateTime? updatedAt;
}

@immutable
final class PatientAllergy {
  const PatientAllergy({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.allergen,
    required this.severity,
    this.publicId,
    this.reaction,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String allergen;
  final String severity;
  final String? reaction;
  final String? notes;
  final DateTime? updatedAt;
}

@immutable
final class PatientMedicalHistory {
  const PatientMedicalHistory({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.condition,
    this.publicId,
    this.diagnosisDate,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String condition;
  final DateTime? diagnosisDate;
  final String? notes;
  final DateTime? updatedAt;
}

@immutable
final class PatientDocument {
  const PatientDocument({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.documentType,
    required this.storageKey,
    this.publicId,
    this.fileName,
    this.contentType,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String documentType;
  final String storageKey;
  final String? fileName;
  final String? contentType;
  final DateTime? updatedAt;
}

@immutable
final class PatientConsent {
  const PatientConsent({
    required this.id,
    required this.tenantId,
    required this.patientId,
    required this.consentType,
    required this.status,
    this.publicId,
    this.grantedAt,
    this.revokedAt,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String tenantId;
  final String patientId;
  final String consentType;
  final String status;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final DateTime? updatedAt;
}

@immutable
final class PatientTimelineItem {
  const PatientTimelineItem({
    required this.id,
    required this.resource,
    this.occurredAt,
    this.title,
    this.subtitle,
  });

  final String id;
  final String resource;
  final DateTime? occurredAt;
  final String? title;
  final String? subtitle;
}

@immutable
final class PatientWorkspaceSnapshot {
  const PatientWorkspaceSnapshot({
    this.appointments = const <PatientSummaryRecord>[],
    this.queueEntries = const <PatientSummaryRecord>[],
    this.encounters = const <PatientSummaryRecord>[],
    this.admissions = const <PatientSummaryRecord>[],
    this.invoices = const <PatientSummaryRecord>[],
    this.payments = const <PatientSummaryRecord>[],
    this.duplicateCandidates = const <PatientDuplicateCandidate>[],
    this.summaryCounts = const <String, int>{},
  });

  final List<PatientSummaryRecord> appointments;
  final List<PatientSummaryRecord> queueEntries;
  final List<PatientSummaryRecord> encounters;
  final List<PatientSummaryRecord> admissions;
  final List<PatientSummaryRecord> invoices;
  final List<PatientSummaryRecord> payments;
  final List<PatientDuplicateCandidate> duplicateCandidates;
  final Map<String, int> summaryCounts;
}

@immutable
final class PatientSummaryRecord {
  const PatientSummaryRecord({
    required this.id,
    required this.kind,
    this.status,
    this.title,
    this.subtitle,
    this.amount,
    this.currency,
    this.occurredAt,
  });

  final String id;
  final String kind;
  final String? status;
  final String? title;
  final String? subtitle;
  final num? amount;
  final String? currency;
  final DateTime? occurredAt;
}

@immutable
final class PatientDuplicateCandidate {
  const PatientDuplicateCandidate({
    required this.reviewId,
    required this.confidenceScore,
    required this.classification,
    this.primaryPatient,
    this.secondaryPatient,
    this.candidatePatient,
  });

  final String reviewId;
  final int confidenceScore;
  final String classification;
  final Patient? primaryPatient;
  final Patient? secondaryPatient;
  final Patient? candidatePatient;
}

@immutable
final class PatientDetail {
  const PatientDetail({
    required this.patient,
    required this.workspace,
    this.identifiers = const <PatientIdentifier>[],
    this.contacts = const <PatientContact>[],
    this.guardians = const <PatientGuardian>[],
    this.allergies = const <PatientAllergy>[],
    this.medicalHistories = const <PatientMedicalHistory>[],
    this.documents = const <PatientDocument>[],
    this.consents = const <PatientConsent>[],
    this.timeline = const <PatientTimelineItem>[],
  });

  final Patient patient;
  final PatientWorkspaceSnapshot workspace;
  final List<PatientIdentifier> identifiers;
  final List<PatientContact> contacts;
  final List<PatientGuardian> guardians;
  final List<PatientAllergy> allergies;
  final List<PatientMedicalHistory> medicalHistories;
  final List<PatientDocument> documents;
  final List<PatientConsent> consents;
  final List<PatientTimelineItem> timeline;

  PatientDetail copyWith({
    Patient? patient,
    PatientWorkspaceSnapshot? workspace,
    List<PatientIdentifier>? identifiers,
    List<PatientContact>? contacts,
    List<PatientGuardian>? guardians,
    List<PatientAllergy>? allergies,
    List<PatientMedicalHistory>? medicalHistories,
    List<PatientDocument>? documents,
    List<PatientConsent>? consents,
    List<PatientTimelineItem>? timeline,
  }) {
    return PatientDetail(
      patient: patient ?? this.patient,
      workspace: workspace ?? this.workspace,
      identifiers: identifiers ?? this.identifiers,
      contacts: contacts ?? this.contacts,
      guardians: guardians ?? this.guardians,
      allergies: allergies ?? this.allergies,
      medicalHistories: medicalHistories ?? this.medicalHistories,
      documents: documents ?? this.documents,
      consents: consents ?? this.consents,
      timeline: timeline ?? this.timeline,
    );
  }
}

@immutable
final class PatientRegistryOverview {
  const PatientRegistryOverview({
    this.totalPatients = 0,
    this.activePatients = 0,
    this.waitingQueue = 0,
    this.activeAdmissions = 0,
    this.unpaidInvoices = 0,
    this.dueFollowUps = 0,
    this.duplicates = const <PatientDuplicateCandidate>[],
    this.recentPatients = const <Patient>[],
    this.waitingQueuePatients = const <Patient>[],
    this.consentExceptions = 0,
    this.missingDocuments = 0,
  });

  final int totalPatients;
  final int activePatients;
  final int waitingQueue;
  final int activeAdmissions;
  final int unpaidInvoices;
  final int dueFollowUps;
  final List<PatientDuplicateCandidate> duplicates;
  final List<Patient> recentPatients;
  final List<Patient> waitingQueuePatients;
  final int consentExceptions;
  final int missingDocuments;

  PatientRegistryOverview copyWith({
    int? totalPatients,
    int? activePatients,
    int? waitingQueue,
    int? activeAdmissions,
    int? unpaidInvoices,
    int? dueFollowUps,
    List<PatientDuplicateCandidate>? duplicates,
    List<Patient>? recentPatients,
    List<Patient>? waitingQueuePatients,
    int? consentExceptions,
    int? missingDocuments,
  }) {
    return PatientRegistryOverview(
      totalPatients: totalPatients ?? this.totalPatients,
      activePatients: activePatients ?? this.activePatients,
      waitingQueue: waitingQueue ?? this.waitingQueue,
      activeAdmissions: activeAdmissions ?? this.activeAdmissions,
      unpaidInvoices: unpaidInvoices ?? this.unpaidInvoices,
      dueFollowUps: dueFollowUps ?? this.dueFollowUps,
      duplicates: duplicates ?? this.duplicates,
      recentPatients: recentPatients ?? this.recentPatients,
      waitingQueuePatients: waitingQueuePatients ?? this.waitingQueuePatients,
      consentExceptions: consentExceptions ?? this.consentExceptions,
      missingDocuments: missingDocuments ?? this.missingDocuments,
    );
  }
}

@immutable
final class PatientReferenceData {
  const PatientReferenceData({
    this.facilities = const <PatientReferenceOption>[],
    this.documentTypes = const <String>[],
    this.consentTypes = const <String>[],
    this.consentStatuses = const <String>[],
    this.appointmentStatuses = const <String>[],
  });

  final List<PatientReferenceOption> facilities;
  final List<String> documentTypes;
  final List<String> consentTypes;
  final List<String> consentStatuses;
  final List<String> appointmentStatuses;
}

@immutable
final class PatientReferenceOption {
  const PatientReferenceOption({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
final class PatientRegistryState {
  const PatientRegistryState({
    required this.query,
    required this.page,
    required this.overview,
    required this.referenceData,
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshingList = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  factory PatientRegistryState.empty() {
    return const PatientRegistryState(
      query: PatientListQuery(),
      page: AppPage<Patient>(items: <Patient>[], request: AppPageRequest()),
      overview: PatientRegistryOverview(),
      referenceData: PatientReferenceData(),
    );
  }

  final PatientListQuery query;
  final AppPage<Patient> page;
  final PatientRegistryOverview overview;
  final PatientReferenceData referenceData;
  final PatientDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshingList;
  final bool isRefreshingDetail;
  final bool isSaving;

  PatientRegistryState copyWith({
    PatientListQuery? query,
    AppPage<Patient>? page,
    PatientRegistryOverview? overview,
    PatientReferenceData? referenceData,
    PatientDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshingList,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return PatientRegistryState(
      query: query ?? this.query,
      page: page ?? this.page,
      overview: overview ?? this.overview,
      referenceData: referenceData ?? this.referenceData,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshingList: isRefreshingList ?? this.isRefreshingList,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

enum PatientRelatedResource {
  identifier,
  contact,
  guardian,
  allergy,
  medicalHistory,
  document,
  consent,
}

@immutable
final class PatientMutationResult {
  const PatientMutationResult({required this.patientId});

  final String patientId;
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

String? _joinNonEmpty(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return joined.isEmpty ? null : joined;
}
