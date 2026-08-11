import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef BillingNextActionHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      BillingWorkItem item,
    );

const String billingPatientColumnId = 'patient';
const String billingInvoiceColumnId = 'invoice';
const String billingEncounterColumnId = 'encounter';
const String billingSourceColumnId = 'source';
const String billingAmountDueColumnId = 'amount_due';
const String billingAmountPaidColumnId = 'amount_paid';
const String billingUpdatedColumnId = 'updated';
const String billingStatusColumnId = 'status';
const String billingAgeColumnId = 'age';
const String billingNextActionColumnId = 'next_action';
const String billingInsurerColumnId = 'insurer';
const String billingSchemeColumnId = 'scheme';
const String billingPatientShareColumnId = 'patient_share';
const String billingInsurerShareColumnId = 'insurer_share';
const String billingTypeColumnId = 'type';
const String billingByColumnId = 'by';
const String billingReasonColumnId = 'reason';

const Map<BillingQueueType, List<String>> billingDefaultColumnIds =
    <BillingQueueType, List<String>>{
      BillingQueueType.all: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingAmountDueColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
      BillingQueueType.needsIssue: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingEncounterColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
      BillingQueueType.pendingPayment: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingAmountDueColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
      BillingQueueType.claimsPending: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingEncounterColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
      BillingQueueType.approvalRequired: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingAmountDueColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
      BillingQueueType.overdue: <String>[
        billingPatientColumnId,
        billingInvoiceColumnId,
        billingAmountDueColumnId,
        billingStatusColumnId,
        billingNextActionColumnId,
      ],
    };

bool billingWorkItemIsCancelled(BillingWorkItem item) {
  return (item.status ?? '').trim().toUpperCase() == 'CANCELLED' ||
      (item.billingStatus ?? '').trim().toUpperCase() == 'CANCELLED';
}

String? billingNextActionLabel(
  BuildContext context,
  BillingWorkItem item, {
  required bool canWrite,
  bool canApprove = false,
  bool canMutateClaims = false,
}) {
  final AppLocalizations l10n = context.l10n;
  // Priority (billing.md §4.1): Approve → Issue → Pay → Submit → Settle →
  // Auth → Refund → Adjust → Void → Send.
  if (item.canApproveOrReject) {
    return canApprove ? l10n.billingApproveAction : null;
  }
  if (item.canIssue) {
    return canWrite ? l10n.billingIssueAction : null;
  }
  if (item.canReceivePayment) {
    return canWrite ? l10n.billingPayAction : null;
  }
  if (item.canSubmitClaim) {
    return canMutateClaims ? l10n.billingSubmitAction : null;
  }
  if (item.canReconcileClaim) {
    return canMutateClaims ? l10n.billingSettleAction : null;
  }
  if (item.canApprovePreAuthorization) {
    return canMutateClaims ? l10n.billingAuthAction : null;
  }
  if (!canWrite) {
    return null;
  }
  if (item.canRequestRefund) {
    return l10n.billingRequestRefund;
  }
  if (item.canRequestAdjustment) {
    return l10n.billingRequestAdjustment;
  }
  if (item.canRequestVoid) {
    return l10n.billingRequestVoidAction;
  }
  if (item.isInvoice && !billingWorkItemIsCancelled(item)) {
    return l10n.billingSendAction;
  }
  return null;
}

String? billingNextActionTooltip(
  BuildContext context,
  BillingWorkItem item, {
  required bool canWrite,
  bool canApprove = false,
  bool canMutateClaims = false,
}) {
  final AppLocalizations l10n = context.l10n;
  if (item.canApproveOrReject) {
    return canApprove ? l10n.billingApproveActionTooltip : null;
  }
  if (item.canSubmitClaim) {
    return canMutateClaims ? l10n.billingSubmitActionTooltip : null;
  }
  if (item.canReconcileClaim) {
    return canMutateClaims ? l10n.billingSettleActionTooltip : null;
  }
  if (item.canApprovePreAuthorization) {
    return canMutateClaims ? l10n.billingAuthActionTooltip : null;
  }
  return billingNextActionLabel(
    context,
    item,
    canWrite: canWrite,
    canApprove: canApprove,
    canMutateClaims: canMutateClaims,
  );
}

bool billingWorkItemMatchesSearch(
  BuildContext context,
  BillingWorkItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  final String? nextAction = billingNextActionLabel(
    context,
    item,
    canWrite: true,
    canApprove: true,
    canMutateClaims: true,
  );

  return <String?>[
    billingPatientName(context, item),
    billingPatientPublicNumber(item),
    billingWorkItemPublicId(context, item),
    billingPublicLabel(item.encounterDisplayId),
    billingInvoiceSourceLabel(context, item),
    billingWorkItemStatusLabel(context, item),
    billingMoney(context, item.balanceDue, item.currency),
    billingMoney(context, item.paidAmount, item.currency),
    billingDateTime(context, item.timelineAt),
    item.billingStatus,
    item.status,
    nextAction,
  ].any((String? value) => (value ?? '').toLowerCase().contains(needle));
}

List<AppListTableColumn<BillingWorkItem>> billingColumnsForQueue(
  BuildContext context,
  AppLocalizations l10n,
  BillingQueueType queue, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<BillingWorkItem>> columns =
      _billingColumnBuilders(
        context,
        l10n,
        queue: queue,
        ref: ref,
        accessPolicy: accessPolicy,
        canWrite: canWrite,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final List<String> ids =
      billingDefaultColumnIds[queue] ?? billingDefaultColumnIds.values.first;
  final bool showNextAction = billingQueueShowsNextActionColumn(
    accessPolicy,
    queue,
  );
  return <AppListTableColumn<BillingWorkItem>>[
    for (final String id in ids)
      if (id != billingNextActionColumnId || showNextAction) columns[id]!,
  ];
}

List<AppListTableColumn<BillingWorkItem>> billingColumnChoicesForQueue(
  BuildContext context,
  AppLocalizations l10n,
  BillingQueueType queue, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<BillingWorkItem>> columns =
      _billingColumnBuilders(
        context,
        l10n,
        queue: queue,
        ref: ref,
        accessPolicy: accessPolicy,
        canWrite: canWrite,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  if (queue == BillingQueueType.approvalRequired) {
    return <AppListTableColumn<BillingWorkItem>>[
      columns[billingTypeColumnId]!,
      columns[billingByColumnId]!,
      columns[billingReasonColumnId]!,
    ];
  }
  if (queue == BillingQueueType.claimsPending) {
    return <AppListTableColumn<BillingWorkItem>>[
      columns[billingInsurerColumnId]!,
      columns[billingSchemeColumnId]!,
      columns[billingPatientShareColumnId]!,
      columns[billingInsurerShareColumnId]!,
    ];
  }
  final Set<String> defaultIds =
      (billingDefaultColumnIds[queue] ?? billingDefaultColumnIds.values.first)
          .toSet();
  final Set<String> claimsOnlyIds = <String>{
    billingInsurerColumnId,
    billingSchemeColumnId,
    billingPatientShareColumnId,
    billingInsurerShareColumnId,
  };
  return <AppListTableColumn<BillingWorkItem>>[
    for (final MapEntry<String, AppListTableColumn<BillingWorkItem>> entry
        in columns.entries)
      if (!defaultIds.contains(entry.key) &&
          entry.key != billingNextActionColumnId &&
          entry.key != billingTypeColumnId &&
          entry.key != billingByColumnId &&
          entry.key != billingReasonColumnId &&
          !claimsOnlyIds.contains(entry.key) &&
          (entry.key != billingAgeColumnId ||
              queue == BillingQueueType.pendingPayment ||
              queue == BillingQueueType.overdue))
        entry.value,
  ];
}

Map<String, AppListTableColumn<BillingWorkItem>> _billingColumnBuilders(
  BuildContext context,
  AppLocalizations l10n, {
  required BillingQueueType queue,
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  final bool canApprove = canDecideBillingApproval(accessPolicy);
  final bool canMutateClaims = canMutateBillingClaims(accessPolicy);
  return <String, AppListTableColumn<BillingWorkItem>>{
    billingPatientColumnId: billingPatientColumn(l10n),
    billingInvoiceColumnId: billingInvoiceColumn(l10n),
    billingEncounterColumnId: billingEncounterColumn(l10n),
    billingSourceColumnId: billingSourceColumn(l10n),
    billingAmountDueColumnId: billingAmountDueColumn(l10n),
    billingAmountPaidColumnId: billingAmountPaidColumn(l10n),
    billingUpdatedColumnId: billingUpdatedColumn(l10n),
    billingAgeColumnId: billingAgeColumn(l10n),
    billingStatusColumnId: billingStatusColumn(l10n),
    billingTypeColumnId: billingApprovalTypeColumn(l10n),
    billingByColumnId: billingApprovalByColumn(l10n),
    billingReasonColumnId: billingApprovalReasonColumn(l10n),
    billingInsurerColumnId: billingInsurerColumn(l10n),
    billingSchemeColumnId: billingSchemeColumn(l10n),
    billingPatientShareColumnId: billingPatientShareColumn(l10n),
    billingInsurerShareColumnId: billingInsurerShareColumn(l10n),
    billingNextActionColumnId: billingNextActionColumn(
      l10n: l10n,
      canWrite: canWrite,
      canApprove: canApprove,
      canMutateClaims: canMutateClaims,
      isSaving: isSaving,
      onAction: (BuildContext actionContext, BillingWorkItem item) {
        return onNextAction(actionContext, ref, item);
      },
    ),
  };
}

AppListTableColumn<BillingWorkItem> billingPatientColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingPatientColumnId,
    label: l10n.billingPatientColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.effectivePatientName,
          right.effectivePatientName,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return AppListItemText(
        title: billingPatientName(context, item),
        subtitle: billingPatientPublicNumber(item) ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingInvoiceColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingInvoiceColumnId,
    label: l10n.billingInvoiceColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          billingPublicLabel(left.displayId) ??
              billingPublicLabel(left.invoiceDisplayId) ??
              left.id,
          billingPublicLabel(right.displayId) ??
              billingPublicLabel(right.invoiceDisplayId) ??
              right.id,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingWorkItemPublicId(context, item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingEncounterColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingEncounterColumnId,
    label: l10n.billingEncounterLabel,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          billingPublicLabel(left.encounterDisplayId),
          billingPublicLabel(right.encounterDisplayId),
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingPublicLabel(item.encounterDisplayId) ??
            l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingSourceColumn(AppLocalizations l10n) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingSourceColumnId,
    label: l10n.billingSourceColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.invoiceSourceSummary,
          right.invoiceSourceSummary,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingInvoiceSourceLabel(context, item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingAmountDueColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingAmountDueColumnId,
    label: l10n.billingDueLabel,
    numeric: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(left.balanceDue, right.balanceDue),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(billingMoney(context, item.balanceDue, item.currency));
    },
  );
}

AppListTableColumn<BillingWorkItem> billingAmountPaidColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingAmountPaidColumnId,
    label: l10n.billingPaidColumn,
    numeric: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(left.paidAmount, right.paidAmount),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(billingMoney(context, item.paidAmount, item.currency));
    },
  );
}

AppListTableColumn<BillingWorkItem> billingUpdatedColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingUpdatedColumnId,
    label: l10n.billingUpdatedColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareDateTime(left.timelineAt, right.timelineAt),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(billingDateTime(context, item.timelineAt));
    },
  );
}

int? billingInvoiceAgeDays(BillingWorkItem item) {
  final DateTime? issuedAt = item.timelineAt;
  if (issuedAt == null) {
    return null;
  }
  final DateTime now = DateTime.now();
  final DateTime issuedLocal = DateTime(
    issuedAt.year,
    issuedAt.month,
    issuedAt.day,
  );
  final DateTime today = DateTime(now.year, now.month, now.day);
  return today.difference(issuedLocal).inDays;
}

AppListTableColumn<BillingWorkItem> billingAgeColumn(AppLocalizations l10n) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingAgeColumnId,
    label: l10n.billingInvoiceAgeColumn,
    numeric: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(
          billingInvoiceAgeDays(left) ?? -1,
          billingInvoiceAgeDays(right) ?? -1,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      final int? days = billingInvoiceAgeDays(item);
      if (days == null) {
        return Text(l10n.billingNotRecorded);
      }
      return Text('$days');
    },
  );
}

AppListTableColumn<BillingWorkItem> billingStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingStatusColumnId,
    label: l10n.billingStatusColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.billingStatus ?? left.status,
          right.billingStatus ?? right.status,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: billingWorkItemStatusLabel(context, item),
          tone: billingWorkItemStatusTone(item),
          icon: billingWorkItemStatusIcon(item),
        ),
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingApprovalTypeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingTypeColumnId,
    label: l10n.billingTypeColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(left.approvalType, right.approvalType),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingApiLabel(context, item.approvalType),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingApprovalByColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingByColumnId,
    label: l10n.billingByColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.requestedByDisplayId,
          right.requestedByDisplayId,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingPublicLabel(item.requestedByDisplayId) ??
            l10n.billingNotRecorded,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingApprovalReasonColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingReasonColumnId,
    label: l10n.billingReasonLabel,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(left.requestReason, right.requestReason),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        item.requestReason?.trim().isNotEmpty == true
            ? item.requestReason!
            : l10n.billingNotRecorded,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingInsurerColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingInsurerColumnId,
    label: l10n.billingInsurerColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.insurerDisplayName,
          right.insurerDisplayName,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        item.insurerDisplayName ?? l10n.billingNotRecorded,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingSchemeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingSchemeColumnId,
    label: l10n.billingInvoiceSchemeColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.schemeDisplayName,
          right.schemeDisplayName,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        item.schemeDisplayName ?? l10n.billingNotRecorded,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingPatientShareColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingPatientShareColumnId,
    label: l10n.billingInvoicePatientShareColumn,
    numeric: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(
          left.totalPatientShare,
          right.totalPatientShare,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingMoney(context, item.totalPatientShare, item.currency),
      );
    },
  );
}

AppListTableColumn<BillingWorkItem> billingInsurerShareColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingInsurerShareColumnId,
    label: l10n.billingInvoiceInsurerShareColumn,
    numeric: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(
          left.totalInsurerShare,
          right.totalInsurerShare,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        billingMoney(context, item.totalInsurerShare, item.currency),
      );
    },
  );
}

int _billingNextActionSortKey(BillingWorkItem item) {
  if (item.canIssue) {
    return 1;
  }
  if (item.canReceivePayment) {
    return 2;
  }
  if (item.canApproveOrReject) {
    return 3;
  }
  if (item.canSubmitClaim) {
    return 4;
  }
  if (item.canReconcileClaim) {
    return 5;
  }
  if (item.canApprovePreAuthorization) {
    return 6;
  }
  if (item.canRequestRefund) {
    return 7;
  }
  if (item.canRequestAdjustment) {
    return 8;
  }
  if (item.canRequestVoid) {
    return 9;
  }
  if (item.isInvoice && !billingWorkItemIsCancelled(item)) {
    return 10;
  }
  return 99;
}

AppListTableColumn<BillingWorkItem> billingNextActionColumn({
  required AppLocalizations l10n,
  required bool canWrite,
  required bool canApprove,
  required bool canMutateClaims,
  required bool isSaving,
  required Future<void> Function(BuildContext context, BillingWorkItem item)
  onAction,
}) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingNextActionColumnId,
    label: l10n.billingNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareNumber(
          _billingNextActionSortKey(left),
          _billingNextActionSortKey(right),
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return BillingNextActionButton(
        item: item,
        canWrite: canWrite,
        canApprove: canApprove,
        canMutateClaims: canMutateClaims,
        isSaving: isSaving,
        onPressed: () => onAction(context, item),
      );
    },
  );
}

class BillingNextActionButton extends StatelessWidget {
  const BillingNextActionButton({
    required this.item,
    required this.canWrite,
    required this.canApprove,
    required this.canMutateClaims,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final BillingWorkItem item;
  final bool canWrite;
  final bool canApprove;
  final bool canMutateClaims;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final String? label = billingNextActionLabel(
      context,
      item,
      canWrite: canWrite,
      canApprove: canApprove,
      canMutateClaims: canMutateClaims,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = context.l10n;
    final String tooltip = item.canApproveOrReject
        ? l10n.billingApproveActionTooltip
        : item.canReceivePayment
        ? l10n.billingPayActionTooltip
        : item.canIssue
        ? l10n.billingIssueActionTooltip
        : item.canSubmitClaim
        ? l10n.billingSubmitActionTooltip
        : item.canReconcileClaim
        ? l10n.billingSettleActionTooltip
        : item.canApprovePreAuthorization
        ? l10n.billingAuthActionTooltip
        : label;

    final ThemeData theme = Theme.of(context);
    final bool actionAllowed = item.canApproveOrReject
        ? canApprove
        : item.canSubmitClaim ||
              item.canReconcileClaim ||
              item.canApprovePreAuthorization ||
              item.canDenyPreAuthorization
        ? canMutateClaims
        : canWrite;
    final bool enabled = actionAllowed && !isSaving;
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  unawaited(onPressed());
                }
              : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.play_arrow_outlined,
                    size: 14,
                    color: primaryColor,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: AppFontWeight.emphasis,
                        decoration: enabled ? TextDecoration.underline : null,
                        decorationColor: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


