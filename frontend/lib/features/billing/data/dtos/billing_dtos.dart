import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef BillingJsonMap = Map<String, Object?>;

final class BillingWorkspaceOverviewDto {
  const BillingWorkspaceOverviewDto(this.json);

  final BillingJsonMap json;

  factory BillingWorkspaceOverviewDto.fromResponse(Object? responseData) {
    return BillingWorkspaceOverviewDto(_dataMap(responseData));
  }

  BillingWorkspaceOverview toEntity() {
    return BillingWorkspaceOverview(
      summary: BillingSummaryDto(_map(json['summary'])).toEntity(),
      queues: _list(json['queues'])
          .map(BillingQueueSummaryDto.new)
          .map((BillingQueueSummaryDto dto) => dto.toEntity())
          .toList(growable: false),
      timeline: _list(_map(json['timeline'])['items'])
          .map(BillingTimelineItemDto.new)
          .map((BillingTimelineItemDto dto) => dto.toEntity())
          .where((BillingTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      generatedAt: _date(json['generated_at']),
    );
  }
}

final class BillingWorkItemPageDto {
  const BillingWorkItemPageDto({required this.page});

  final AppPage<BillingWorkItem> page;

  factory BillingWorkItemPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final BillingJsonMap data = _dataMap(responseData);
    final List<BillingJsonMap> queueEntries = _list(data['queues']);
    if (queueEntries.isNotEmpty) {
      final List<BillingWorkItem> items = <BillingWorkItem>[];
      int total = 0;
      for (final BillingJsonMap queueEntry in queueEntries) {
        final BillingQueueType queue = BillingQueueType.fromServer(
          _string(queueEntry['queue']),
        );
        final List<BillingJsonMap> queueItems = _list(queueEntry['items']);
        total += _int(queueEntry['total']) ?? queueItems.length;
        items.addAll(
          queueItems
              .map((BillingJsonMap item) {
                return BillingWorkItemDto(
                  item,
                  fallbackQueue: queue,
                ).toEntity();
              })
              .where((BillingWorkItem item) => item.id.isNotEmpty),
        );
      }

      return BillingWorkItemPageDto(
        page: AppPage<BillingWorkItem>(
          items: items,
          request: request,
          totalItemCount: total,
        ),
      );
    }

    final BillingQueueType queue = BillingQueueType.fromServer(
      _string(data['queue']),
    );
    final List<BillingWorkItem> items = _list(data['items'])
        .map((BillingJsonMap item) {
          return BillingWorkItemDto(item, fallbackQueue: queue).toEntity();
        })
        .where((BillingWorkItem item) => item.id.isNotEmpty)
        .toList(growable: false);

    return BillingWorkItemPageDto(
      page: AppPage<BillingWorkItem>(
        items: items,
        request: request,
        totalItemCount: _int(_map(data['pagination'])['total']),
      ),
    );
  }
}

final class BillingSummaryDto {
  const BillingSummaryDto(this.json);

  final BillingJsonMap json;

  BillingSummary toEntity() {
    return BillingSummary(
      needsIssue: _int(json['needs_issue']) ?? 0,
      pendingPayment: _int(json['pending_payment']) ?? 0,
      claimsPending: _int(json['claims_pending']) ?? 0,
      approvalRequired: _int(json['approval_required']) ?? 0,
      overdue: _int(json['overdue']) ?? 0,
      paymentsTodayTotal: _num(json['payments_today_total']) ?? 0,
      refundsTodayTotal: _num(json['refunds_today_total']) ?? 0,
    );
  }
}

final class BillingQueueSummaryDto {
  const BillingQueueSummaryDto(this.json);

  final BillingJsonMap json;

  BillingQueueSummary toEntity() {
    final BillingQueueType queue = BillingQueueType.fromServer(
      _string(json['queue']),
    );
    return BillingQueueSummary(
      queue: queue,
      label: _string(json['label']) ?? _queueDefaultLabel(queue),
      count: _int(json['count']) ?? 0,
    );
  }
}

final class BillingWorkItemDto {
  const BillingWorkItemDto(this.json, {required this.fallbackQueue});

  final BillingJsonMap json;
  final BillingQueueType fallbackQueue;

  BillingWorkItem toEntity() {
    final BillingWorkItemKind kind = _kind(json, fallbackQueue);
    final BillingFinancials financials = BillingFinancialsDto(
      _map(json['financials']),
      fallbackTotal: _num(json['total_amount']) ?? _num(json['amount']) ?? 0,
      payments: _list(json['payments']),
      adjustments: _list(json['billing_adjustments']),
    ).toEntity();

    return BillingWorkItem(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      kind: kind,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      patientId:
          _string(json['patient_id']) ??
          _string(_map(json['invoice'])['patient_id']) ??
          _string(_map(_map(json['invoice'])['patient'])['id']),
      patientDisplayId:
          _string(json['patient_display_id']) ??
          _string(_map(_map(json['invoice'])['patient'])['human_friendly_id']),
      patientDisplayName:
          _string(json['patient_display_name']) ??
          _patientName(_map(_map(json['invoice'])['patient'])),
      patientGender: _patientGender(json),
      patientDateOfBirth: _patientDateOfBirth(json),
      invoiceDisplayId:
          _string(json['invoice_display_id']) ??
          _string(_map(json['invoice'])['display_id']) ??
          _string(_map(json['invoice'])['human_friendly_id']),
      coveragePlanDisplayId:
          _string(json['coverage_plan_display_id']) ??
          _string(_map(json['coverage_plan'])['human_friendly_id']),
      status: _string(json['status']),
      billingStatus: _string(json['billing_status']),
      amount: _num(json['total_amount']) ?? _num(json['amount']) ?? 0,
      currency:
          _string(json['currency']) ??
          _string(_map(json['invoice'])['currency']),
      timelineAt:
          _date(json['timeline_at']) ??
          _date(json['issued_at']) ??
          _date(json['submitted_at']) ??
          _date(json['requested_at']),
      items: _list(json['items'])
          .map(BillingInvoiceItemDto.new)
          .map((BillingInvoiceItemDto dto) => dto.toEntity())
          .where((BillingInvoiceItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      payments: _list(json['payments'])
          .map(BillingPaymentDto.new)
          .map((BillingPaymentDto dto) => dto.toEntity())
          .where((BillingPayment item) => item.id.isNotEmpty)
          .toList(growable: false),
      adjustments: _list(json['billing_adjustments'])
          .map(BillingAdjustmentDto.new)
          .map((BillingAdjustmentDto dto) => dto.toEntity())
          .where((BillingAdjustment item) => item.id.isNotEmpty)
          .toList(growable: false),
      financials: financials,
      approvalType: _string(json['approval_type']),
      requestReason: _string(json['reason']),
      requestedByDisplayId:
          _string(json['requested_by_user_display_id']) ??
          _string(_map(json['requested_by_user'])['human_friendly_id']),
      requestedAt: _date(json['requested_at']),
      decidedAt: _date(json['decided_at']),
      targetDisplayId: _string(json['target_display_id']),
      linkedInvoiceId:
          _string(json['invoice_id']) ??
          _string(_map(json['invoice'])['id']) ??
          _string(_map(json['payload_json'])['invoice_id']),
      submittedAt: _date(json['submitted_at']),
      approvedAt: _date(json['approved_at']),
      encounterId: _string(json['encounter_id']),
      encounterDisplayId: _string(json['encounter_display_id']),
      sourceModule: _string(json['source_module']),
      sourceModules: _strings(json['source_modules']),
      settlementAmount: _num(json['settlement_amount']),
      decisionNotes: _string(json['decision_notes']),
    );
  }
}

final class BillingFinancialsDto {
  const BillingFinancialsDto(
    this.json, {
    required this.fallbackTotal,
    required this.payments,
    required this.adjustments,
  });

  final BillingJsonMap json;
  final num fallbackTotal;
  final List<BillingJsonMap> payments;
  final List<BillingJsonMap> adjustments;

  BillingFinancials toEntity() {
    if (json.isNotEmpty) {
      return BillingFinancials(
        invoiceTotal: _num(json['invoice_total']) ?? fallbackTotal,
        adjustmentTotal: _num(json['adjustment_total']) ?? 0,
        effectiveTotal: _num(json['effective_total']) ?? fallbackTotal,
        grossPaidTotal: _num(json['gross_paid_total']) ?? 0,
        refundedTotal: _num(json['refunded_total']) ?? 0,
        netPaidTotal: _num(json['net_paid_total']) ?? 0,
        balanceDue: _num(json['balance_due']) ?? fallbackTotal,
      );
    }

    final num paid = payments.fold<num>(0, (num total, BillingJsonMap payment) {
      final String status = (_string(payment['status']) ?? '').toUpperCase();
      if (status != 'COMPLETED' && status != 'REFUNDED') {
        return total;
      }
      return total + (_num(payment['amount']) ?? 0);
    });
    final num adjustmentTotal = adjustments.fold<num>(0, (
      num total,
      BillingJsonMap adjustment,
    ) {
      final String status = (_string(adjustment['status']) ?? '').toUpperCase();
      if (!<String>{'ISSUED', 'PAID', 'PARTIAL'}.contains(status)) {
        return total;
      }
      return total + (_num(adjustment['amount']) ?? 0);
    });
    final num effectiveTotal = fallbackTotal + adjustmentTotal;

    return BillingFinancials(
      invoiceTotal: fallbackTotal,
      adjustmentTotal: adjustmentTotal,
      effectiveTotal: effectiveTotal,
      grossPaidTotal: paid,
      netPaidTotal: paid,
      balanceDue: effectiveTotal - paid,
    );
  }
}

final class BillingInvoiceItemDto {
  const BillingInvoiceItemDto(this.json);

  final BillingJsonMap json;

  BillingInvoiceItem toEntity() {
    final BillingJsonMap metadata = _map(json['metadata_json']);
    return BillingInvoiceItem(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
        json['description'],
      ]),
      description: _string(json['description']) ?? 'Invoice item',
      quantity: _int(json['quantity']) ?? 1,
      unitPrice: _num(json['unit_price']) ?? 0,
      totalPrice: _num(json['total_price']) ?? 0,
      sourceModule:
          _string(metadata['source_module']) ?? _string(json['source_module']),
      sourceOrderDisplayId:
          _string(metadata['order_display_id']) ??
          _string(json['order_display_id']),
      encounterDisplayId:
          _string(metadata['encounter_display_id']) ??
          _string(json['encounter_display_id']),
      patientShare:
          _num(json['patient_share']) ?? _num(metadata['patient_share']),
      insurerShare:
          _num(json['insurer_share']) ?? _num(metadata['insurer_share']),
      coveragePlanName:
          _string(json['coverage_plan_name']) ??
          _string(metadata['coverage_plan_name']) ??
          _string(_map(json['coverage_plan'])['name']),
      insuranceCompanyName:
          _string(json['insurance_company_name']) ??
          _string(metadata['insurance_company_name']) ??
          _string(_map(json['insurance_company'])['name']),
    );
  }
}

final class BillingPaymentDto {
  const BillingPaymentDto(this.json);

  final BillingJsonMap json;

  BillingPayment toEntity() {
    return BillingPayment(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      status: _string(json['status']),
      method: _string(json['method']),
      amount: _num(json['amount']) ?? 0,
      transactionRef: _string(json['transaction_ref']),
      paidAt: _date(json['paid_at']),
    );
  }
}

final class BillingAdjustmentDto {
  const BillingAdjustmentDto(this.json);

  final BillingJsonMap json;

  BillingAdjustment toEntity() {
    return BillingAdjustment(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      status: _string(json['status']),
      amount: _num(json['amount']) ?? 0,
      reason: _string(json['reason']),
      adjustedAt: _date(json['adjusted_at']),
    );
  }
}

final class BillingMutationResultDto {
  const BillingMutationResultDto(
    this.json, {
    this.fallbackQueue = BillingQueueType.pendingPayment,
  });

  final BillingJsonMap json;
  final BillingQueueType fallbackQueue;

  factory BillingMutationResultDto.fromResponse(
    Object? responseData, {
    BillingQueueType fallbackQueue = BillingQueueType.pendingPayment,
  }) {
    return BillingMutationResultDto(
      _dataMap(responseData),
      fallbackQueue: fallbackQueue,
    );
  }

  BillingMutationResult toEntity() {
    BillingJsonMap invoiceJson = _map(json['invoice']);
    if (invoiceJson.isEmpty && _looksLikeInvoice(json)) {
      invoiceJson = json;
    }

    BillingJsonMap paymentJson = _map(json['payment']);
    if (paymentJson.isEmpty && _looksLikePayment(json)) {
      paymentJson = json;
    }

    BillingJsonMap approvalJson = _map(json['approval']);
    if (approvalJson.isEmpty && _looksLikeApproval(json)) {
      approvalJson = json;
    }

    BillingJsonMap claimJson = _map(json['claim']);
    if (claimJson.isEmpty && _looksLikeClaim(json)) {
      claimJson = json;
    }

    final BillingWorkItem? invoice = invoiceJson.isEmpty
        ? null
        : BillingWorkItemDto(
            invoiceJson,
            fallbackQueue: fallbackQueue,
          ).toEntity();
    final BillingPayment? payment = paymentJson.isEmpty
        ? null
        : BillingPaymentDto(paymentJson).toEntity();
    final BillingWorkItem? approval = approvalJson.isEmpty
        ? null
        : BillingWorkItemDto(
            approvalJson,
            fallbackQueue: BillingQueueType.approvalRequired,
          ).toEntity();
    final BillingWorkItem? claim = claimJson.isEmpty
        ? null
        : BillingWorkItemDto(
            claimJson,
            fallbackQueue: BillingQueueType.claimsPending,
          ).toEntity();

    return BillingMutationResult(
      invoice: invoice?.id.isEmpty == true ? null : invoice,
      payment: payment?.id.isEmpty == true ? null : payment,
      approval: approval?.id.isEmpty == true ? null : approval,
      claim: claim?.id.isEmpty == true ? null : claim,
      approvalRequired:
          json['approval_required'] == true ||
          _map(json['approval']).isNotEmpty,
    );
  }
}

final class BillingPatientLedgerDto {
  const BillingPatientLedgerDto(this.json, {required this.request});

  final BillingJsonMap json;
  final AppPageRequest request;

  factory BillingPatientLedgerDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    return BillingPatientLedgerDto(_dataMap(responseData), request: request);
  }

  BillingPatientLedger toEntity() {
    final BillingJsonMap patient = _map(json['patient']);
    final BillingJsonMap summary = _map(json['summary']);
    final BillingJsonMap ledger = _map(json['ledger']);
    final List<BillingLedgerEntry> entries = _list(ledger['items'])
        .map(BillingLedgerEntryDto.new)
        .map((BillingLedgerEntryDto dto) => dto.toEntity())
        .where((BillingLedgerEntry entry) => entry.id.isNotEmpty)
        .toList(growable: false);

    return BillingPatientLedger(
      patientId: _firstString(<Object?>[patient['id'], patient['display_id']]),
      patientDisplayId: _string(patient['display_id']),
      patientDisplayName: _string(patient['display_name']),
      summary: BillingLedgerSummary(
        totalInvoiced: _num(summary['total_invoiced']) ?? 0,
        totalAdjustments: _num(summary['total_adjustments']) ?? 0,
        totalPaid: _num(summary['total_paid']) ?? 0,
        totalRefunded: _num(summary['total_refunded']) ?? 0,
        netPaid: _num(summary['net_paid']) ?? 0,
        balanceDue: _num(summary['balance_due']) ?? 0,
      ),
      entries: entries,
      totalEntryCount:
          _int(_map(ledger['pagination'])['total']) ?? entries.length,
    );
  }
}

final class BillingLedgerEntryDto {
  const BillingLedgerEntryDto(this.json);

  final BillingJsonMap json;

  BillingLedgerEntry toEntity() {
    return BillingLedgerEntry(
      id: _firstString(<Object?>[
        json['display_id'],
        json['invoice_display_id'],
        json['payment_display_id'],
        json['id'],
      ]),
      kind: _kind(json, BillingQueueType.pendingPayment),
      action: _string(json['action']),
      status: _string(json['status']),
      displayId: _string(json['display_id']),
      invoiceDisplayId: _string(json['invoice_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      amount: _num(json['amount']) ?? 0,
      currency: _string(json['currency']),
      timelineAt: _date(json['timeline_at']),
    );
  }
}

final class BillingTimelineItemDto {
  const BillingTimelineItemDto(this.json);

  final BillingJsonMap json;

  BillingTimelineItem toEntity() {
    return BillingTimelineItem(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['invoice_display_id'],
        json['payment_display_id'],
      ]),
      kind: _kind(json, BillingQueueType.pendingPayment),
      action: _string(json['action']),
      status: _string(json['status']),
      displayId: _string(json['display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      amount: _num(json['amount']) ?? 0,
      currency: _string(json['currency']),
      timelineAt: _date(json['timeline_at']),
    );
  }
}

String decodeBillingRecordId(Object? responseData) {
  final BillingJsonMap data = _dataMap(responseData);
  return _firstString(<Object?>[
    data['id'],
    data['display_id'],
    data['human_friendly_id'],
  ]);
}

String _queueDefaultLabel(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.all => 'All billing work items',
    BillingQueueType.needsIssue => 'Needs issue',
    BillingQueueType.pendingPayment => 'Pending payment',
    BillingQueueType.claimsPending => 'Claims pending',
    BillingQueueType.approvalRequired => 'Approval required',
    BillingQueueType.overdue => 'Overdue',
  };
}

bool _looksLikeInvoice(BillingJsonMap json) {
  return json.containsKey('billing_status') ||
      json.containsKey('total_amount') ||
      json.containsKey('items');
}

bool _looksLikePayment(BillingJsonMap json) {
  return json.containsKey('method') &&
      json.containsKey('amount') &&
      (json.containsKey('paid_at') || json.containsKey('transaction_ref'));
}

bool _looksLikeApproval(BillingJsonMap json) {
  return json.containsKey('approval_type') || json.containsKey('target_entity');
}

bool _looksLikeClaim(BillingJsonMap json) {
  return json.containsKey('coverage_plan_id') &&
      json.containsKey('invoice_id') &&
      !json.containsKey('billing_status');
}

BillingWorkItemKind _kind(BillingJsonMap json, BillingQueueType fallbackQueue) {
  final String type = (_string(json['type']) ?? '').trim().toUpperCase();
  if (type == 'INVOICE' || json.containsKey('billing_status')) {
    return BillingWorkItemKind.invoice;
  }
  if (type == 'PAYMENT') {
    return BillingWorkItemKind.payment;
  }
  if (type == 'REFUND') {
    return BillingWorkItemKind.refund;
  }
  if (type == 'CLAIM' ||
      json.containsKey('coverage_plan_id') && json.containsKey('invoice_id')) {
    return BillingWorkItemKind.claim;
  }
  if (type == 'ADJUSTMENT') {
    return BillingWorkItemKind.adjustment;
  }
  if (type == 'APPROVAL' ||
      json.containsKey('approval_type') ||
      fallbackQueue == BillingQueueType.approvalRequired) {
    return BillingWorkItemKind.approval;
  }
  if (type == 'PRE_AUTH' ||
      json.containsKey('requested_at') &&
          json.containsKey('coverage_plan_id') &&
          !json.containsKey('invoice_id')) {
    return BillingWorkItemKind.preAuthorization;
  }
  return BillingWorkItemKind.other;
}

String? _patientName(BillingJsonMap patient) {
  final String first = _string(patient['first_name']) ?? '';
  final String last = _string(patient['last_name']) ?? '';
  final String combined = '$first $last'.trim();
  return combined.isEmpty ? null : combined;
}

String? _patientGender(BillingJsonMap json) {
  return _string(json['patient_gender']) ??
      _string(_map(_map(json['invoice'])['patient'])['gender']);
}

DateTime? _patientDateOfBirth(BillingJsonMap json) {
  return _date(json['patient_date_of_birth']) ??
      _date(_map(_map(json['invoice'])['patient'])['date_of_birth']);
}

BillingJsonMap _dataMap(Object? responseData) {
  final BillingJsonMap response = _map(responseData);
  final BillingJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

BillingJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<BillingJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <BillingJsonMap>[];
  }
  return value
      .map(_map)
      .where((BillingJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List<Object?>) {
    return const <String>[];
  }
  return value.map(_string).whereType<String>().toList(growable: false);
}

String _firstString(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String? normalized = _string(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}
