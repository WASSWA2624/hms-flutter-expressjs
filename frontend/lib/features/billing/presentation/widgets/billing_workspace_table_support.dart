import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
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
const String billingNextActionColumnId = 'next_action';

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
}) {
  if (!canWrite) {
    return null;
  }
  final AppLocalizations l10n = context.l10n;
  if (item.canIssue) {
    return l10n.billingIssueAction;
  }
  if (item.canReceivePayment) {
    return l10n.billingReceivePayment;
  }
  if (item.canApproveOrReject) {
    return l10n.billingApproveAction;
  }
  if (item.canSubmitClaim) {
    return l10n.billingSubmitClaimAction;
  }
  if (item.canReconcileClaim) {
    return l10n.billingReconcileClaimAction;
  }
  if (item.canApprovePreAuthorization) {
    return l10n.billingPreAuthApproveAction;
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
  );

  return <String?>[
    billingPatientName(context, item),
    item.effectivePatientNumber,
    item.effectiveDisplayId,
    item.encounterDisplayId,
    item.encounterId,
    billingInvoiceSourceLabel(context, item),
    billingClearanceLabel(context, item.clearanceState),
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
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<BillingWorkItem>> columns =
      _billingColumnBuilders(
        context,
        l10n,
        ref: ref,
        canWrite: canWrite,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final List<String> ids =
      billingDefaultColumnIds[queue] ?? billingDefaultColumnIds.values.first;
  return <AppListTableColumn<BillingWorkItem>>[
    for (final String id in ids) columns[id]!,
  ];
}

List<AppListTableColumn<BillingWorkItem>> billingColumnChoicesForQueue(
  BuildContext context,
  AppLocalizations l10n,
  BillingQueueType queue, {
  required WidgetRef ref,
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<BillingWorkItem>> columns =
      _billingColumnBuilders(
        context,
        l10n,
        ref: ref,
        canWrite: canWrite,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final Set<String> defaultIds =
      (billingDefaultColumnIds[queue] ?? billingDefaultColumnIds.values.first)
          .toSet();
  return <AppListTableColumn<BillingWorkItem>>[
    for (final MapEntry<String, AppListTableColumn<BillingWorkItem>> entry
        in columns.entries)
      if (!defaultIds.contains(entry.key) &&
          entry.key != billingNextActionColumnId)
        entry.value,
  ];
}

Map<String, AppListTableColumn<BillingWorkItem>> _billingColumnBuilders(
  BuildContext context,
  AppLocalizations l10n, {
  required WidgetRef ref,
  required bool canWrite,
  required bool isSaving,
  required BillingNextActionHandler onNextAction,
}) {
  return <String, AppListTableColumn<BillingWorkItem>>{
    billingPatientColumnId: billingPatientColumn(l10n),
    billingInvoiceColumnId: billingInvoiceColumn(l10n),
    billingEncounterColumnId: billingEncounterColumn(l10n),
    billingSourceColumnId: billingSourceColumn(l10n),
    billingAmountDueColumnId: billingAmountDueColumn(l10n),
    billingAmountPaidColumnId: billingAmountPaidColumn(l10n),
    billingUpdatedColumnId: billingUpdatedColumn(l10n),
    billingStatusColumnId: billingStatusColumn(l10n),
    billingNextActionColumnId: billingNextActionColumn(
      l10n: l10n,
      canWrite: canWrite,
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
    label: l10n.billingPatientNameColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.effectivePatientName,
          right.effectivePatientName,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return AppListItemText(
        title: billingPatientName(context, item),
        subtitle: item.effectivePatientNumber ?? l10n.profileUnknownValue,
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
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        item.effectiveDisplayId,
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
          left.encounterDisplayId ?? left.encounterId,
          right.encounterDisplayId ?? right.encounterId,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return Text(
        item.encounterDisplayId ?? item.encounterId ?? l10n.profileUnknownValue,
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
    label: l10n.billingAmountDueColumn,
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

AppListTableColumn<BillingWorkItem> billingStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<BillingWorkItem>(
    id: billingStatusColumnId,
    label: l10n.billingStatusColumn,
    sortComparator: (BillingWorkItem left, BillingWorkItem right) =>
        appListTableCompareText(
          left.clearanceState.name,
          right.clearanceState.name,
        ),
    cellBuilder: (BuildContext context, BillingWorkItem item) {
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: billingClearanceLabel(context, item.clearanceState),
          tone: billingClearanceTone(item.clearanceState),
          icon: billingClearanceIcon(item.clearanceState),
        ),
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
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final BillingWorkItem item;
  final bool canWrite;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final String? label = billingNextActionLabel(
      context,
      item,
      canWrite: canWrite,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final bool enabled = canWrite && !isSaving;
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
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
                        fontWeight: FontWeight.w500,
                        decoration: enabled ? TextDecoration.underline : null,
                        decorationColor: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  if (!enabled) ...<Widget>[
                    SizedBox(width: theme.spacing.xs),
                    Icon(
                      Icons.lock_outlined,
                      size: 10,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


