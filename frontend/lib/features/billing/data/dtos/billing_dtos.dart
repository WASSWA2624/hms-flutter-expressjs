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
      patientId: _string(json['patient_id']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      invoiceDisplayId: _string(json['invoice_display_id']),
      coveragePlanDisplayId: _string(json['coverage_plan_display_id']),
      status: _string(json['status']),
      billingStatus: _string(json['billing_status']),
      amount: _num(json['total_amount']) ?? _num(json['amount']) ?? 0,
      currency: _string(json['currency']),
      timelineAt: _date(json['timeline_at']) ?? _date(json['issued_at']),
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
  if (type == 'CLAIM' || json.containsKey('coverage_plan_id')) {
    return BillingWorkItemKind.claim;
  }
  if (type == 'ADJUSTMENT') {
    return BillingWorkItemKind.adjustment;
  }
  if (type == 'APPROVAL' ||
      fallbackQueue == BillingQueueType.approvalRequired) {
    return BillingWorkItemKind.approval;
  }
  if (type == 'PRE_AUTH') {
    return BillingWorkItemKind.preAuthorization;
  }
  return BillingWorkItemKind.other;
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
