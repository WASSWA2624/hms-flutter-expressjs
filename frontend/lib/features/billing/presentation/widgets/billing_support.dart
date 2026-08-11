import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
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
    BillingClearanceState.awaitingPayment => l10n.billingAwaitingPayment,
    BillingClearanceState.overdue => l10n.billingOverdue,
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
    BillingClearanceState.awaitingPayment => AppWorkspaceStatusTone.warning,
    BillingClearanceState.overdue => AppWorkspaceStatusTone.error,
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
    BillingClearanceState.awaitingPayment => Icons.payments_outlined,
    BillingClearanceState.overdue => Icons.warning_amber_outlined,
    BillingClearanceState.blocked => Icons.lock_outline,
  };
}

String billingInvoiceSourceLabel(BuildContext context, BillingWorkItem item) {
  final String? summary = item.invoiceSourceSummary;
  if (summary == null || summary.trim().isEmpty) {
    return context.l10n.profileUnknownValue;
  }
  return billingApiLabel(context, summary);
}

String billingQueueLabel(BuildContext context, BillingQueueType queue) {
  final AppLocalizations l10n = context.l10n;
  return switch (queue) {
    BillingQueueType.all => l10n.billingOpenWork,
    BillingQueueType.needsIssue => l10n.billingNeedsIssue,
    BillingQueueType.pendingPayment => l10n.billingCollectDue,
    BillingQueueType.claimsPending => l10n.billingClaimsPending,
    BillingQueueType.approvalRequired => l10n.billingApprovalRequired,
    BillingQueueType.overdue => l10n.billingOverdue,
  };
}

/// Full sentence for tab strip hover/focus (billing.md §2).
String? billingQueueTooltip(BuildContext context, BillingQueueType queue) {
  final AppLocalizations l10n = context.l10n;
  return switch (queue) {
    BillingQueueType.all => l10n.billingOpenWorkTooltip,
    BillingQueueType.needsIssue => l10n.billingNeedsIssueTooltip,
    BillingQueueType.pendingPayment => l10n.billingCollectDueTooltip,
    BillingQueueType.claimsPending => l10n.billingClaimsPendingTooltip,
    BillingQueueType.approvalRequired => l10n.billingApprovalRequiredTooltip,
    _ => null,
  };
}

/// Persisted table-settings key (`billing_<section>_v1`).
String billingTableSettingsKey(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.all => 'billing_work_v1',
    BillingQueueType.needsIssue => 'billing_issue_v1',
    BillingQueueType.pendingPayment => 'billing_collect_v1',
    BillingQueueType.claimsPending => 'billing_claims_v1',
    BillingQueueType.approvalRequired => 'billing_approvals_v1',
    BillingQueueType.overdue => 'billing_collect_v1',
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

AppTabCountTone billingQueueCountTone(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.overdue => AppTabCountTone.danger,
    BillingQueueType.needsIssue ||
    BillingQueueType.pendingPayment ||
    BillingQueueType.claimsPending ||
    BillingQueueType.approvalRequired => AppTabCountTone.warning,
    BillingQueueType.all => AppTabCountTone.info,
  };
}

String billingPatientName(BuildContext context, BillingWorkItem item) {
  final String name = item.patientDisplayName?.trim() ?? '';
  return name.isEmpty ? context.l10n.billingUnknownPatient : name;
}

/// Billing-oriented status for worklist rows (not accounts clearance).
String billingWorkItemStatusLabel(BuildContext context, BillingWorkItem item) {
  final AppLocalizations l10n = context.l10n;
  final String status = (item.status ?? '').trim().toUpperCase();
  final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();

  if (item.isApproval) {
    return switch (status) {
      'PENDING' => l10n.billingStatusPendingApprovalOption,
      'APPROVED' => l10n.billingStatusApprovedOption,
      'REJECTED' || 'DENIED' => l10n.billingStatusRejectedOption,
      _ => billingApiLabel(context, item.status),
    };
  }
  if (item.isClaim) {
    return switch (status) {
      'SUBMITTED' => l10n.billingStatusClaimSubmittedOption,
      'REJECTED' => l10n.billingStatusRejectedOption,
      'APPROVED' || 'PAID' || 'SETTLED' => l10n.billingStatusApprovedOption,
      _ => billingApiLabel(context, item.status),
    };
  }
  if (item.isPreAuthorization) {
    return switch (status) {
      'PENDING' => l10n.billingStatusAuthPendingOption,
      'DENIED' => l10n.billingStatusAuthDeniedOption,
      'APPROVED' || 'PARTIAL' => l10n.billingStatusApprovedOption,
      _ => billingApiLabel(context, item.status),
    };
  }

  if (billingStatus == 'CANCELLED' || status == 'CANCELLED') {
    return l10n.billingStatusCancelledOption;
  }
  if (billingStatus == 'DRAFT') {
    return l10n.billingStatusDraft;
  }
  if (status == 'OVERDUE' && item.balanceDue > 0) {
    return l10n.billingOverdue;
  }
  if (billingStatus == 'PAID' || item.balanceDue <= 0) {
    return l10n.billingStatusPaid;
  }
  if (billingStatus == 'PARTIAL' || item.paidAmount > 0) {
    return l10n.billingStatusPartialOption;
  }
  if (billingStatus == 'ISSUED' || item.balanceDue > 0) {
    return l10n.billingAwaitingPayment;
  }
  return billingApiLabel(context, item.billingStatus ?? item.status);
}

AppWorkspaceStatusTone billingWorkItemStatusTone(BillingWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();

  if (item.isApproval) {
    return switch (status) {
      'PENDING' => AppWorkspaceStatusTone.warning,
      'APPROVED' => AppWorkspaceStatusTone.success,
      'REJECTED' || 'DENIED' => AppWorkspaceStatusTone.error,
      _ => AppWorkspaceStatusTone.neutral,
    };
  }
  if (item.isClaim || item.isPreAuthorization) {
    return switch (status) {
      'PENDING' || 'SUBMITTED' => AppWorkspaceStatusTone.warning,
      'DENIED' || 'REJECTED' => AppWorkspaceStatusTone.error,
      'APPROVED' || 'PAID' || 'SETTLED' || 'PARTIAL' =>
        AppWorkspaceStatusTone.success,
      _ => AppWorkspaceStatusTone.info,
    };
  }
  if (billingStatus == 'CANCELLED' || status == 'CANCELLED') {
    return AppWorkspaceStatusTone.neutral;
  }
  if (billingStatus == 'DRAFT') {
    return AppWorkspaceStatusTone.neutral;
  }
  if (status == 'OVERDUE' && item.balanceDue > 0) {
    return AppWorkspaceStatusTone.error;
  }
  if (billingStatus == 'PAID' || item.balanceDue <= 0) {
    return AppWorkspaceStatusTone.success;
  }
  if (billingStatus == 'PARTIAL' || item.paidAmount > 0) {
    return AppWorkspaceStatusTone.info;
  }
  return AppWorkspaceStatusTone.warning;
}

IconData billingWorkItemStatusIcon(BillingWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();

  if (item.isApproval) {
    return switch (status) {
      'PENDING' => Icons.rule_outlined,
      'APPROVED' => Icons.verified_outlined,
      'REJECTED' || 'DENIED' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };
  }
  if (item.isClaim || item.isPreAuthorization) {
    return switch (status) {
      'PENDING' || 'SUBMITTED' => Icons.health_and_safety_outlined,
      'DENIED' || 'REJECTED' => Icons.cancel_outlined,
      _ => Icons.verified_outlined,
    };
  }
  if (billingStatus == 'CANCELLED' || status == 'CANCELLED') {
    return Icons.block_outlined;
  }
  if (billingStatus == 'DRAFT') {
    return Icons.edit_note_outlined;
  }
  if (status == 'OVERDUE' && item.balanceDue > 0) {
    return Icons.warning_amber_outlined;
  }
  if (billingStatus == 'PAID' || item.balanceDue <= 0) {
    return Icons.verified_outlined;
  }
  if (billingStatus == 'PARTIAL' || item.paidAmount > 0) {
    return Icons.pie_chart_outline;
  }
  return Icons.payments_outlined;
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

final RegExp _billingUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// True when [value] looks like a raw UUID / internal PK.
bool billingLooksLikeUuid(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isNotEmpty && _billingUuidPattern.hasMatch(normalized);
}

/// Presentation label that never surfaces raw UUIDs (billing.md §19).
String? billingPublicLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || billingLooksLikeUuid(normalized)) {
    return null;
  }
  return normalized;
}

/// Invoice / work-item friendly id for tables, dialogs, and print.
String billingWorkItemPublicId(BuildContext context, BillingWorkItem item) {
  return billingPublicLabel(item.displayId) ??
      billingPublicLabel(item.invoiceDisplayId) ??
      context.l10n.billingInvoiceLabel;
}

/// Patient MRN / friendly id for tables and dialogs — never raw patient UUID.
String? billingPatientPublicNumber(BillingWorkItem item) {
  return billingPublicLabel(item.patientDisplayId);
}
