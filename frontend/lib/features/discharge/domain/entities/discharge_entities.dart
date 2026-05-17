import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum DischargeStatusFilter {
  all,
  planned,
  summaryPending,
  pharmacyPending,
  nursingPending,
  billingPending,
  insurancePending,
  documentsReady,
  completed,
}

enum DischargeClearanceCode {
  doctor,
  nursing,
  pharmacy,
  billing,
  insurance,
  documents,
  bedRelease,
  housekeeping,
}

enum DischargeClearanceState { complete, pending, backendGap, unavailable }

@immutable
final class DischargeWorklistQuery {
  const DischargeWorklistQuery({
    this.search = '',
    this.status = DischargeStatusFilter.all,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final DischargeStatusFilter status;
  final AppPageRequest pageRequest;

  DischargeWorklistQuery copyWith({
    String? search,
    DischargeStatusFilter? status,
    AppPageRequest? pageRequest,
  }) {
    return DischargeWorklistQuery(
      search: search ?? this.search,
      status: status ?? this.status,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class DischargeRelatedRecord {
  const DischargeRelatedRecord({
    required this.id,
    required this.kind,
    this.status,
    this.billingStatus,
    this.title,
    this.subtitle,
    this.amount,
    this.currency,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String kind;
  final String? status;
  final String? billingStatus;
  final String? title;
  final String? subtitle;
  final num? amount;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpenPharmacyOrder {
    return switch ((status ?? '').toUpperCase()) {
      'ORDERED' || 'PARTIALLY_DISPENSED' => true,
      _ => false,
    };
  }

  bool get isOpenInvoice {
    return switch ((billingStatus ?? status ?? '').toUpperCase()) {
      'DRAFT' || 'ISSUED' || 'SENT' || 'PARTIAL' || 'OVERDUE' => true,
      _ => false,
    };
  }
}

@immutable
final class DischargeDrugOption {
  const DischargeDrugOption({
    required this.id,
    this.name,
    this.form,
    this.strength,
  });

  final String id;
  final String? name;
  final String? form;
  final String? strength;

  String get displayTitle => _firstNonEmpty(<String?>[name, id]) ?? id;

  String? get displaySubtitle => _joinDisplay(<String?>[form, strength]);
}

@immutable
final class DischargeClearanceItem {
  const DischargeClearanceItem({
    required this.code,
    required this.state,
    this.reference,
    this.updatedAt,
  });

  final DischargeClearanceCode code;
  final DischargeClearanceState state;
  final String? reference;
  final DateTime? updatedAt;
}

@immutable
final class DischargeAdmissionDetail {
  const DischargeAdmissionDetail({
    required this.ipd,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.encounterId,
    this.roomId,
    this.roomName,
    this.pharmacyOrders = const <DischargeRelatedRecord>[],
    this.invoices = const <DischargeRelatedRecord>[],
    this.billingDataUnavailable = false,
    this.pharmacyDataUnavailable = false,
  });

  final IpdAdmissionDetail ipd;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? encounterId;
  final String? roomId;
  final String? roomName;
  final List<DischargeRelatedRecord> pharmacyOrders;
  final List<DischargeRelatedRecord> invoices;
  final bool billingDataUnavailable;
  final bool pharmacyDataUnavailable;

  IpdAdmissionSummary get summary => ipd.summary;

  IpdDischargeSummary? get latestDischargeSummary {
    return ipd.latestDischargeSummary;
  }

  String? get summaryText {
    final String? value = latestDischargeSummary?.summary?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasSummary => summaryText != null;

  bool get isCompleted {
    return isCompletedDischarge(summary);
  }

  bool get hasOpenPharmacyOrders {
    return pharmacyOrders.any((DischargeRelatedRecord item) {
      return item.isOpenPharmacyOrder;
    });
  }

  bool get hasOpenInvoices {
    return invoices.any((DischargeRelatedRecord item) => item.isOpenInvoice);
  }

  bool get hasBillingClearance {
    return invoices.isNotEmpty && !hasOpenInvoices;
  }

  bool get hasNursingClearance {
    return isCompleted || ipd.nursingNotes.isNotEmpty;
  }

  bool get hasPharmacyClearance {
    return !pharmacyDataUnavailable && !hasOpenPharmacyOrders;
  }

  bool get hasDocumentOutput {
    return hasSummary;
  }

  bool get hasBedReleased {
    final IpdBedAssignment? assignment = ipd.activeBedAssignment;
    return isCompleted || assignment == null || assignment.releasedAt != null;
  }

  List<DischargeClearanceItem> get clearanceItems {
    return <DischargeClearanceItem>[
      DischargeClearanceItem(
        code: DischargeClearanceCode.doctor,
        state: hasSummary
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: latestDischargeSummary?.id,
        updatedAt: latestDischargeSummary?.updatedAt,
      ),
      DischargeClearanceItem(
        code: DischargeClearanceCode.nursing,
        state: hasNursingClearance
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: ipd.nursingNotes.isEmpty ? null : ipd.nursingNotes.first.id,
        updatedAt: ipd.nursingNotes.isEmpty
            ? null
            : ipd.nursingNotes.first.occurredAt,
      ),
      DischargeClearanceItem(
        code: DischargeClearanceCode.pharmacy,
        state: pharmacyDataUnavailable
            ? DischargeClearanceState.unavailable
            : hasPharmacyClearance
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: pharmacyOrders.isEmpty ? null : pharmacyOrders.first.id,
        updatedAt: pharmacyOrders.isEmpty
            ? null
            : pharmacyOrders.first.updatedAt ?? pharmacyOrders.first.createdAt,
      ),
      DischargeClearanceItem(
        code: DischargeClearanceCode.billing,
        state: billingDataUnavailable
            ? DischargeClearanceState.unavailable
            : hasBillingClearance
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: invoices.isEmpty ? null : invoices.first.id,
        updatedAt: invoices.isEmpty
            ? null
            : invoices.first.updatedAt ?? invoices.first.createdAt,
      ),
      const DischargeClearanceItem(
        code: DischargeClearanceCode.insurance,
        state: DischargeClearanceState.backendGap,
      ),
      DischargeClearanceItem(
        code: DischargeClearanceCode.documents,
        state: hasDocumentOutput
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: latestDischargeSummary?.id,
        updatedAt: latestDischargeSummary?.updatedAt,
      ),
      DischargeClearanceItem(
        code: DischargeClearanceCode.bedRelease,
        state: hasBedReleased
            ? DischargeClearanceState.complete
            : DischargeClearanceState.pending,
        reference: ipd.activeBedAssignment?.id,
        updatedAt: ipd.activeBedAssignment?.releasedAt,
      ),
      const DischargeClearanceItem(
        code: DischargeClearanceCode.housekeeping,
        state: DischargeClearanceState.backendGap,
      ),
    ];
  }

  List<DischargeClearanceItem> get blockingItems {
    return clearanceItems
        .where((DischargeClearanceItem item) {
          if (item.code == DischargeClearanceCode.bedRelease) {
            return false;
          }
          return item.state == DischargeClearanceState.pending ||
              item.state == DischargeClearanceState.unavailable;
        })
        .toList(growable: false);
  }

  DischargeAdmissionDetail copyWith({
    IpdAdmissionDetail? ipd,
    List<DischargeRelatedRecord>? pharmacyOrders,
    List<DischargeRelatedRecord>? invoices,
    bool? billingDataUnavailable,
    bool? pharmacyDataUnavailable,
  }) {
    return DischargeAdmissionDetail(
      ipd: ipd ?? this.ipd,
      tenantId: tenantId,
      facilityId: facilityId,
      patientId: patientId,
      encounterId: encounterId,
      roomId: roomId,
      roomName: roomName,
      pharmacyOrders: pharmacyOrders ?? this.pharmacyOrders,
      invoices: invoices ?? this.invoices,
      billingDataUnavailable:
          billingDataUnavailable ?? this.billingDataUnavailable,
      pharmacyDataUnavailable:
          pharmacyDataUnavailable ?? this.pharmacyDataUnavailable,
    );
  }
}

@immutable
final class DischargeReferenceData {
  const DischargeReferenceData({this.drugs = const <DischargeDrugOption>[]});

  final List<DischargeDrugOption> drugs;
}

@immutable
final class DischargeWorkspaceState {
  const DischargeWorkspaceState({
    required this.query,
    required this.queue,
    this.referenceData = const DischargeReferenceData(),
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final DischargeWorklistQuery query;
  final AppPage<IpdAdmissionSummary> queue;
  final DischargeReferenceData referenceData;
  final DischargeAdmissionDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get plannedCount {
    return queue.items.where(isPlannedDischarge).length;
  }

  int get summaryPendingCount {
    return queue.items.where((IpdAdmissionSummary item) {
      return !isCompletedDischarge(item) && !isPlannedDischarge(item);
    }).length;
  }

  int get documentsReadyCount {
    return queue.items.where((IpdAdmissionSummary item) {
      return isPlannedDischarge(item) || isCompletedDischarge(item);
    }).length;
  }

  int get completedCount {
    return queue.items.where(isCompletedDischarge).length;
  }

  int get workloadCount {
    return queue.items.where((IpdAdmissionSummary item) {
      return !isCompletedDischarge(item);
    }).length;
  }

  DischargeWorkspaceState copyWith({
    DischargeWorklistQuery? query,
    AppPage<IpdAdmissionSummary>? queue,
    DischargeReferenceData? referenceData,
    DischargeAdmissionDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return DischargeWorkspaceState(
      query: query ?? this.query,
      queue: queue ?? this.queue,
      referenceData: referenceData ?? this.referenceData,
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

bool isCompletedDischarge(IpdAdmissionSummary item) {
  return switch ((item.stage ??
          item.admissionStatus ??
          item.dischargeStatus ??
          '')
      .toUpperCase()) {
    'DISCHARGED' || 'COMPLETED' => true,
    _ => (item.dischargeStatus ?? '').toUpperCase() == 'COMPLETED',
  };
}

bool isPlannedDischarge(IpdAdmissionSummary item) {
  return !isCompletedDischarge(item) &&
      ((item.stage ?? '').toUpperCase() == 'DISCHARGE_PLANNED' ||
          (item.dischargeStatus ?? '').toUpperCase() == 'PLANNED');
}

bool matchesDischargeStatus(
  IpdAdmissionSummary item,
  DischargeStatusFilter status,
) {
  return switch (status) {
    DischargeStatusFilter.all => true,
    DischargeStatusFilter.completed => isCompletedDischarge(item),
    DischargeStatusFilter.planned ||
    DischargeStatusFilter.pharmacyPending ||
    DischargeStatusFilter.nursingPending ||
    DischargeStatusFilter.billingPending ||
    DischargeStatusFilter.insurancePending ||
    DischargeStatusFilter.documentsReady => isPlannedDischarge(item),
    DischargeStatusFilter.summaryPending =>
      !isCompletedDischarge(item) && !isPlannedDischarge(item),
  };
}

String? serverStageForDischargeStatus(DischargeStatusFilter status) {
  return switch (status) {
    DischargeStatusFilter.completed => 'DISCHARGED',
    DischargeStatusFilter.planned ||
    DischargeStatusFilter.pharmacyPending ||
    DischargeStatusFilter.nursingPending ||
    DischargeStatusFilter.billingPending ||
    DischargeStatusFilter.insurancePending ||
    DischargeStatusFilter.documentsReady => 'DISCHARGE_PLANNED',
    DischargeStatusFilter.all || DischargeStatusFilter.summaryPending => null,
  };
}

String? firstPendingBlocker(DischargeAdmissionDetail detail) {
  final List<DischargeClearanceItem> blockers = detail.blockingItems;
  if (blockers.isEmpty) {
    return null;
  }

  return blockers.first.code.name;
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
