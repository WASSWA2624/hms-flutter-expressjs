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
