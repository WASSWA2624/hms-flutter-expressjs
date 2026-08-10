import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_currency.dart';

String hrPayrollRunId(HrWorkItem item) {
  final String runId = (item.payrollRunId ?? '').trim();
  if (runId.isNotEmpty) {
    return runId;
  }
  final String displayId = (item.displayId ?? '').trim();
  if (displayId.isNotEmpty) {
    return displayId;
  }
  return item.effectiveId;
}

String hrPayrollCurrencyCode(HrWorkItem item, {String? fallback}) {
  final String currency = (item.currency ?? '').trim().toUpperCase();
  if (currency.isNotEmpty) {
    return currency;
  }
  final String? resolved = fallback?.trim().toUpperCase();
  if (resolved != null && resolved.isNotEmpty) {
    return resolved;
  }
  return appDefaultCurrencyCode;
}

String? hrPayrollCurrencyFromItems(Iterable<HrWorkItem> items) {
  for (final HrWorkItem item in items) {
    final String currency = (item.currency ?? '').trim();
    if (currency.isNotEmpty) {
      return currency.toUpperCase();
    }
  }
  return null;
}

String hrPayrollTotalColumnLabel(
  AppLocalizations l10n, {
  String? currencyCode,
}) {
  final String code = (currencyCode ?? '').trim().toUpperCase();
  if (code.isEmpty) {
    return l10n.hrPayCompensationTotalColumnWithCurrency(
      appDefaultCurrencyCode,
    );
  }
  return l10n.hrPayCompensationTotalColumnWithCurrency(code);
}

String hrPayrollAmountLabel(
  num amount,
  Locale locale, {
  bool treatZeroAsEmpty = true,
}) {
  if (treatZeroAsEmpty && amount == 0) {
    return '—';
  }
  return AppFormatters.decimal(amount, locale);
}

String hrPayrollLaneLabel(AppLocalizations l10n, String? lane) {
  final String normalized = (lane ?? '').trim().toUpperCase();
  if (normalized == 'FINANCE_DIRECT') {
    return l10n.hrPayCompensationLaneFinanceDirect;
  }
  return l10n.hrPayCompensationLaneHrToFinance;
}

String hrPayrollStatusLabel(AppLocalizations l10n, String? status) {
  return switch ((status ?? '').trim().toUpperCase()) {
    'DRAFT' || 'PENDING' || 'PENDING_REVIEW' =>
      l10n.hrPayCompensationStatusPending,
    'PROCESSED' || 'APPROVED' => l10n.hrPayCompensationStatusApproved,
    'PAID' => l10n.hrPayCompensationStatusPaid,
    'CANCELLED' => l10n.hrPayCompensationStatusCancelled,
    _ => (status ?? '').trim().isEmpty
        ? l10n.profileUnknownValue
        : status!.trim(),
  };
}

String hrPayrollNextActionLabel(AppLocalizations l10n, HrWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  return switch (status) {
    'PROCESSED' || 'APPROVED' => l10n.hrPayCompensationMarkPaidAction,
    'PAID' || 'CANCELLED' => l10n.hrPreviewPayrollAction,
    _ => l10n.hrPayCompensationReviewApproveAction,
  };
}

bool hrPayrollStatusIs(HrWorkItem item, String status) {
  return (item.status ?? '').trim().toUpperCase() == status.toUpperCase();
}

bool hrPayrollIsPendingReview(HrWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  return status == 'DRAFT' ||
      status == 'PENDING' ||
      status == 'PENDING_REVIEW';
}

bool hrPayrollIsApproved(HrWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  return status == 'PROCESSED' || status == 'APPROVED';
}

String hrPayrollEscapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Prefer live preview totals, but keep the work-item snapshot when preview is empty.
num hrPayrollResolvedTotal(HrWorkItem item, HrPayrollPreview? preview) {
  final num previewTotal = preview?.totalAmount ?? 0;
  if (previewTotal != 0) {
    return previewTotal;
  }
  if (item.totalAmount != 0) {
    return item.totalAmount;
  }
  return previewTotal;
}

int hrPayrollResolvedStaffCount(HrWorkItem item, HrPayrollPreview? preview) {
  final int previewCount = preview?.staffCount ?? 0;
  if (previewCount > 0) {
    return previewCount;
  }
  if (item.staffCount > 0) {
    return item.staffCount;
  }
  final int itemLines = preview?.items.length ?? 0;
  if (itemLines > 0) {
    return itemLines;
  }
  return previewCount;
}

/// Flattens payroll preview staff lines into printable/table component rows.
List<HrPayrollBreakdownRow> hrPayrollBreakdownRows({
  required HrPayrollPreview? preview,
  required String paymentPath,
}) {
  final List<HrPayrollPreviewItem> items =
      preview?.items ?? const <HrPayrollPreviewItem>[];
  final List<HrPayrollBreakdownRow> rows = <HrPayrollBreakdownRow>[];
  for (final HrPayrollPreviewItem item in items) {
    final String staff =
        (item.staffName ?? item.staffNumber ?? item.staffProfileDisplayId ?? '')
            .trim();
    final List<HrPayrollCalculationComponent> components =
        item.calculation?.components ?? const <HrPayrollCalculationComponent>[];
    if (components.isEmpty) {
      rows.add(
        HrPayrollBreakdownRow(
          staffName: staff,
          payType: null,
          amount: item.amount,
          currency: item.currency,
          paymentPath: paymentPath,
        ),
      );
      continue;
    }
    for (final HrPayrollCalculationComponent component in components) {
      rows.add(
        HrPayrollBreakdownRow(
          staffName: staff,
          payType: component.payType,
          quantity: component.quantity,
          unit: component.unit,
          rate: component.rate,
          amount: component.amount,
          currency: component.currency ?? item.currency,
          paymentPath: paymentPath,
        ),
      );
    }
  }
  return rows;
}

@immutable
final class HrPayrollBreakdownRow {
  const HrPayrollBreakdownRow({
    required this.staffName,
    required this.paymentPath,
    this.payType,
    this.quantity = 0,
    this.unit,
    this.rate = 0,
    this.amount = 0,
    this.currency,
  });

  final String staffName;
  final String? payType;
  final num quantity;
  final String? unit;
  final num rate;
  final num amount;
  final String? currency;
  final String paymentPath;
}
