import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

String billingMoney(BuildContext context, num value, String? currencyCode) {
  return AppFormatters.currency(
    value,
    Localizations.localeOf(context),
    currencyCode: currencyCode ?? appDefaultCurrencyCode,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}

String billingDateTime(BuildContext context, DateTime? value) {
  final AppLocalizations l10n = context.l10n;
  return value == null
      ? l10n.billingNotRecorded
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String billingApiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return context.l10n.billingUnknownValue;
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

String billingClearanceLabel(
  BuildContext context,
  BillingClearanceState state,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (state) {
    BillingClearanceState.cleared => l10n.billingClearanceCleared,
    BillingClearanceState.partiallyPaid => l10n.billingClearancePartiallyPaid,
    BillingClearanceState.deferred => l10n.billingClearanceDeferred,
    BillingClearanceState.insured => l10n.billingClearanceInsured,
    BillingClearanceState.pendingAuthorization =>
      l10n.billingClearancePendingAuth,
    BillingClearanceState.blocked => l10n.billingClearanceBlocked,
  };
}

AppWorkspaceStatusTone billingClearanceTone(BillingClearanceState state) {
  return switch (state) {
    BillingClearanceState.cleared => AppWorkspaceStatusTone.success,
    BillingClearanceState.partiallyPaid => AppWorkspaceStatusTone.info,
    BillingClearanceState.deferred => AppWorkspaceStatusTone.neutral,
    BillingClearanceState.insured => AppWorkspaceStatusTone.info,
    BillingClearanceState.pendingAuthorization =>
      AppWorkspaceStatusTone.warning,
    BillingClearanceState.blocked => AppWorkspaceStatusTone.error,
  };
}

IconData billingClearanceIcon(BillingClearanceState state) {
  return switch (state) {
    BillingClearanceState.cleared => Icons.verified_outlined,
    BillingClearanceState.partiallyPaid => Icons.pie_chart_outline,
    BillingClearanceState.deferred => Icons.schedule_outlined,
    BillingClearanceState.insured => Icons.health_and_safety_outlined,
    BillingClearanceState.pendingAuthorization => Icons.rule_outlined,
    BillingClearanceState.blocked => Icons.lock_outline,
  };
}

String billingQueueLabel(BuildContext context, BillingQueueType queue) {
  final AppLocalizations l10n = context.l10n;
  return switch (queue) {
    BillingQueueType.all => l10n.billingAllWorkItems,
    BillingQueueType.needsIssue => l10n.billingNeedsIssue,
    BillingQueueType.pendingPayment => l10n.billingAwaitingPayment,
    BillingQueueType.claimsPending => l10n.billingClaimsPending,
    BillingQueueType.approvalRequired => l10n.billingApprovalRequired,
    BillingQueueType.overdue => l10n.billingOverdue,
  };
}

IconData billingQueueIcon(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.all => Icons.inventory_2_outlined,
    BillingQueueType.needsIssue => Icons.receipt_long_outlined,
    BillingQueueType.pendingPayment => Icons.payments_outlined,
    BillingQueueType.claimsPending => Icons.health_and_safety_outlined,
    BillingQueueType.approvalRequired => Icons.rule_outlined,
    BillingQueueType.overdue => Icons.warning_amber_outlined,
  };
}

String billingPatientName(BuildContext context, BillingWorkItem item) {
  final String name = item.patientDisplayName?.trim() ?? '';
  return name.isEmpty ? context.l10n.billingUnknownPatient : name;
}

String billingDetailTitle(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  if (item.isInvoice) {
    return l10n.billingInvoiceDetailTitle;
  }
  if (item.isClaim) {
    return l10n.billingClaimDetailTitle;
  }
  if (item.isApproval) {
    return l10n.billingApprovalDetailTitle;
  }
  if (item.isPreAuthorization) {
    return l10n.billingPreAuthDetailTitle;
  }
  return l10n.billingItemDetailTitle;
}

String billingJoinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
}

String? billingEmptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
