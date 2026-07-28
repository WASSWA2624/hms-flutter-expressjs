import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_detail_header.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class BillingGateBadge extends StatelessWidget {
  const BillingGateBadge({required this.state, super.key});

  final BillingClearanceState state;

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      label: billingClearanceLabel(context, state),
      tone: billingClearanceTone(state),
      icon: billingClearanceIcon(state),
    );
  }
}

class BillingDetailBody extends ConsumerWidget {
  const BillingDetailBody({
    required this.item,
    required this.canWrite,
    required this.isSaving,
    this.onReceivePayment,
    this.onIssue,
    this.onRefund,
    this.onAdjust,
    this.onVoid,
    this.onSend,
    this.onApprove,
    this.onReject,
    this.onSubmitClaim,
    this.onReconcileClaim,
    this.onApprovePreAuthorization,
    this.onDenyPreAuthorization,
    this.onViewLedger,
    this.onFinalizeEncounter,
    super.key,
  });

  final BillingWorkItem item;
  final bool canWrite;
  final bool isSaving;
  final VoidCallback? onReceivePayment;
  final VoidCallback? onIssue;
  final VoidCallback? onRefund;
  final VoidCallback? onAdjust;
  final VoidCallback? onVoid;
  final VoidCallback? onSend;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSubmitClaim;
  final VoidCallback? onReconcileClaim;
  final VoidCallback? onApprovePreAuthorization;
  final VoidCallback? onDenyPreAuthorization;
  final VoidCallback? onViewLedger;
  final VoidCallback? onFinalizeEncounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canApprove = accessPolicy.canManageFacility();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: billingPatientName(context, item),
          patientNumber: item.effectivePatientNumber ?? '',
          patientNumberLabel: l10n.billingPatientIdColumn,
          ageLabel: item.patientDateOfBirth == null
              ? null
              : formatPatientAge(l10n, item.patientDateOfBirth),
          genderLabel: () {
            final String? gender = item.patientGender?.trim();
            if (gender == null || gender.isEmpty) {
              return null;
            }
            return patientGenderLabel(l10n, gender);
          }(),
          genderIcon: patientGenderIcon(item.patientGender),
          showAvatar: false,
          copyPatientNumberTooltip: l10n.copyIdentifierAction,
          copyPatientNumberMessage: l10n.identifierCopiedMessage,
          expandedFields: <AppWorkspacePatientContextField>[
            ..._patientContextExpandedFields(context, l10n),
            if (item.isInvoice) ..._invoiceContextFields(context, l10n),
          ],
          actions: onViewLedger == null
              ? const <Widget>[]
              : <Widget>[
                  AppButton.secondary(
                    label: l10n.billingViewLedgerAction,
                    leadingIcon: Icons.account_balance_wallet_outlined,
                    onPressed: onViewLedger,
                  ),
                ],
        ),
        SizedBox(height: theme.spacing.md),
        if (canWrite) ...<Widget>[
          _BillingActionPanel(
            item: item,
            isSaving: isSaving,
            canApprove: canApprove,
            onReceivePayment: onReceivePayment,
            onIssue: onIssue,
            onRefund: onRefund,
            onAdjust: onAdjust,
            onVoid: onVoid,
            onSend: onSend,
            onApprove: onApprove,
            onReject: onReject,
            onSubmitClaim: onSubmitClaim,
            onReconcileClaim: onReconcileClaim,
            onApprovePreAuthorization: onApprovePreAuthorization,
            onDenyPreAuthorization: onDenyPreAuthorization,
            onFinalizeEncounter: onFinalizeEncounter,
          ),
          SizedBox(height: theme.spacing.md),
        ],
        if (item.isInvoice) ...<Widget>[
          _FinancialSummarySection(item: item),
          SizedBox(height: theme.spacing.md),
          _InvoiceLineItemsSection(item: item),
          SizedBox(height: theme.spacing.md),
          _PaymentsSection(item: item),
          SizedBox(height: theme.spacing.md),
          _AdjustmentsSection(item: item),
        ] else
          _NonInvoiceDetailSection(item: item),
      ],
    );
  }

  List<AppWorkspacePatientContextField> _patientContextExpandedFields(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final List<AppWorkspacePatientContextField> fields =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: l10n.billingPaymentStatusLabel,
            value: billingClearanceLabel(context, item.clearanceState),
            icon: billingClearanceIcon(item.clearanceState),
            tone: billingClearanceTone(item.clearanceState),
          ),
        ];

    if (item.isInvoice) {
      final String? encounterId = item.encounterDisplayId ?? item.encounterId;
      if (encounterId != null && encounterId.isNotEmpty) {
        fields.add(
          AppWorkspacePatientContextField(
            label: l10n.billingEncounterLabel,
            value: encounterId,
            icon: Icons.local_hospital_outlined,
          ),
        );
      }
    }

    if (!item.isInvoice) {
      fields.addAll(_nonInvoiceContextFields(context, l10n));
    }

    return fields;
  }

  List<AppWorkspacePatientContextField> _invoiceContextFields(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return <AppWorkspacePatientContextField>[
      AppWorkspacePatientContextField(
        label: l10n.billingInvoiceLabel,
        value: item.effectiveDisplayId,
        icon: Icons.receipt_long_outlined,
        copyable: true,
        copyTooltip: l10n.copyIdentifierAction,
        copiedMessage: l10n.identifierCopiedMessage,
      ),
      AppWorkspacePatientContextField(
        label: l10n.billingInvoiceStatusLabel,
        value: billingApiLabel(context, item.billingStatus ?? item.status),
        icon: Icons.flag_outlined,
      ),
      AppWorkspacePatientContextField(
        label: l10n.billingAmountPaidLabel,
        value: billingMoney(context, item.paidAmount, item.currency),
        icon: Icons.payments_outlined,
        tone: AppWorkspaceStatusTone.success,
      ),
      AppWorkspacePatientContextField(
        label: l10n.billingBalanceColumn,
        value: billingMoney(context, item.balanceDue, item.currency),
        icon: Icons.account_balance_wallet_outlined,
        tone: item.balanceDue <= 0
            ? AppWorkspaceStatusTone.success
            : AppWorkspaceStatusTone.warning,
      ),
    ];
  }

  List<AppWorkspacePatientContextField> _nonInvoiceContextFields(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final List<AppWorkspacePatientContextField> fields =
        <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: item.isInvoice
                ? l10n.billingInvoiceLabel
                : l10n.billingStatusColumn,
            value: item.effectiveDisplayId,
            icon: Icons.receipt_long_outlined,
            copyable: true,
            copyTooltip: l10n.copyIdentifierAction,
            copiedMessage: l10n.identifierCopiedMessage,
          ),
          AppWorkspacePatientContextField(
            label: l10n.billingStatusColumn,
            value: billingApiLabel(context, item.billingStatus ?? item.status),
            icon: Icons.flag_outlined,
          ),
        ];

    if ((item.encounterDisplayId ?? item.encounterId)?.isNotEmpty ?? false) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.billingEncounterLabel,
          value: item.encounterDisplayId ?? item.encounterId ?? '',
          icon: Icons.local_hospital_outlined,
        ),
      );
    }

    if (item.isClaim || item.isPreAuthorization) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.billingCoveragePlanLabel,
          value: item.coveragePlanDisplayId ?? l10n.billingNotRecorded,
          icon: Icons.health_and_safety_outlined,
        ),
      );
    }

    if (item.isApproval) {
      fields.addAll(<AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.billingRequestTypeLabel,
          value: billingApiLabel(context, item.approvalType),
          icon: Icons.rule_outlined,
        ),
        AppWorkspacePatientContextField(
          label: l10n.billingRequesterLabel,
          value: item.requestedByDisplayId ?? l10n.billingNotRecorded,
          icon: Icons.person_outline,
        ),
        AppWorkspacePatientContextField(
          label: l10n.billingLinkedInvoiceLabel,
          value: item.targetDisplayId ?? item.invoiceDisplayId ?? '',
          icon: Icons.receipt_long_outlined,
        ),
      ]);
    }

    return fields;
  }
}

class _BillingActionPanel extends StatelessWidget {
  const _BillingActionPanel({
    required this.item,
    required this.isSaving,
    required this.canApprove,
    this.onReceivePayment,
    this.onIssue,
    this.onRefund,
    this.onAdjust,
    this.onVoid,
    this.onSend,
    this.onApprove,
    this.onReject,
    this.onSubmitClaim,
    this.onReconcileClaim,
    this.onApprovePreAuthorization,
    this.onDenyPreAuthorization,
    this.onFinalizeEncounter,
  });

  final BillingWorkItem item;
  final bool isSaving;
  final bool canApprove;
  final VoidCallback? onReceivePayment;
  final VoidCallback? onIssue;
  final VoidCallback? onRefund;
  final VoidCallback? onAdjust;
  final VoidCallback? onVoid;
  final VoidCallback? onSend;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSubmitClaim;
  final VoidCallback? onReconcileClaim;
  final VoidCallback? onApprovePreAuthorization;
  final VoidCallback? onDenyPreAuthorization;
  final VoidCallback? onFinalizeEncounter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppActionItem> actions = <AppActionItem>[];

    if (item.isInvoice) {
      actions.addAll(<AppActionItem>[
        AppActionItem(
          label: l10n.billingReceivePayment,
          leadingIcon: Icons.point_of_sale,
          enabled: item.canReceivePayment && !isSaving,
          variant: AppActionVariant.primary,
          onPressed: onReceivePayment,
        ),
        AppActionItem(
          label: l10n.billingIssueAction,
          leadingIcon: Icons.outbox_outlined,
          enabled: item.canIssue && !isSaving,
          onPressed: onIssue,
        ),
        AppActionItem(
          label: l10n.billingRefundAction,
          leadingIcon: Icons.assignment_return_outlined,
          enabled: item.canRequestRefund && !isSaving,
          onPressed: onRefund,
        ),
        AppActionItem(
          label: l10n.billingAdjustAction,
          leadingIcon: Icons.tune,
          enabled: item.canRequestAdjustment && !isSaving,
          onPressed: onAdjust,
        ),
        AppActionItem(
          label: l10n.billingVoidAction,
          leadingIcon: Icons.block_outlined,
          enabled: item.canRequestVoid && !isSaving,
          onPressed: onVoid,
        ),
        AppActionItem(
          label: l10n.billingSendAction,
          leadingIcon: Icons.send_outlined,
          enabled: !isSaving,
          onPressed: onSend,
        ),
      ]);
      if (item.canFinalizeEncounterBilling) {
        actions.insert(
          0,
          AppActionItem(
            label: l10n.billingFinalizeEncounterAction,
            leadingIcon: Icons.task_alt_outlined,
            enabled: !isSaving,
            variant: AppActionVariant.primary,
            onPressed: onFinalizeEncounter,
          ),
        );
      }
    }

    if (item.isApproval && canApprove) {
      actions.addAll(<AppActionItem>[
        AppActionItem(
          label: l10n.billingApproveAction,
          leadingIcon: Icons.check_circle_outline,
          enabled: item.canApproveOrReject && !isSaving,
          variant: AppActionVariant.primary,
          onPressed: onApprove,
        ),
        AppActionItem(
          label: l10n.billingRejectAction,
          leadingIcon: Icons.cancel_outlined,
          enabled: item.canApproveOrReject && !isSaving,
          onPressed: onReject,
        ),
      ]);
    }

    if (item.isClaim) {
      if (item.canSubmitClaim) {
        actions.add(
          AppActionItem(
            label: l10n.billingSubmitClaimAction,
            leadingIcon: Icons.upload_outlined,
            enabled: !isSaving,
            variant: AppActionVariant.primary,
            onPressed: onSubmitClaim,
          ),
        );
      }
      if (item.canReconcileClaim) {
        actions.add(
          AppActionItem(
            label: l10n.billingReconcileClaimAction,
            leadingIcon: Icons.fact_check_outlined,
            enabled: !isSaving,
            variant: AppActionVariant.primary,
            onPressed: onReconcileClaim,
          ),
        );
      }
    }

    if (item.isPreAuthorization) {
      if (item.canApprovePreAuthorization) {
        actions.add(
          AppActionItem(
            label: l10n.billingPreAuthApproveAction,
            leadingIcon: Icons.check_circle_outline,
            enabled: !isSaving,
            variant: AppActionVariant.primary,
            onPressed: onApprovePreAuthorization,
          ),
        );
      }
      if (item.canDenyPreAuthorization) {
        actions.add(
          AppActionItem(
            label: l10n.billingPreAuthDenyAction,
            leadingIcon: Icons.cancel_outlined,
            enabled: !isSaving,
            onPressed: onDenyPreAuthorization,
          ),
        );
      }
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppQuickActions(
      title: context.l10n.patientsQuickActionsTitle,
      actions: actions,
      presentation: AppQuickActionsPresentation.detailPanel,
    );
  }
}

class _FinancialSummarySection extends StatelessWidget {
  const _FinancialSummarySection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppReportPreviewPanel(
      title: l10n.billingFinancialSummaryTitle,
      child: AppReportSummaryGrid(
        records: <AppReportSummaryItem>[
          AppReportSummaryItem(
            label: l10n.billingTotalAmountLabel,
            value: billingMoney(context, item.effectiveTotal, item.currency),
            icon: Icons.receipt_long_outlined,
          ),
          AppReportSummaryItem(
            label: l10n.billingAmountPaidLabel,
            value: billingMoney(context, item.paidAmount, item.currency),
            icon: Icons.payments_outlined,
          ),
          AppReportSummaryItem(
            label: l10n.billingBalanceColumn,
            value: billingMoney(context, item.balanceDue, item.currency),
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineItemsSection extends StatelessWidget {
  const _InvoiceLineItemsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (item.items.isEmpty) {
      return AppWorkspaceDetailPanel(
        title: l10n.billingLineItemsTitle,
        child: Text(l10n.billingNoLineItems),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.billingLineItemsTitle,
      child: AppListTable<BillingInvoiceItem>(
        items: item.items,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        displayMode: AppListTableDisplayMode.table,
        itemKeyBuilder: (BillingInvoiceItem lineItem) =>
            ValueKey<String>(lineItem.id),
        columns: <AppListTableColumn<BillingInvoiceItem>>[
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingLineItemDescriptionColumn,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(lineItem.description);
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingLineItemQtyColumn,
            numeric: true,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text('${lineItem.quantity}');
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingLineItemUnitPriceColumn,
            numeric: true,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                billingMoney(context, lineItem.unitPrice, item.currency),
              );
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingLineItemDepartmentColumn,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(lineItem.sourceModule ?? l10n.billingNotRecorded);
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingEncounterLabel,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                lineItem.encounterDisplayId ?? l10n.billingNotRecorded,
              );
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingInvoiceSchemeColumn,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                lineItem.coveragePlanName ??
                    lineItem.insuranceCompanyName ??
                    l10n.billingNotRecorded,
              );
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingInvoicePatientShareColumn,
            numeric: true,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                lineItem.patientShare == null
                    ? l10n.billingNotRecorded
                    : billingMoney(
                        context,
                        lineItem.patientShare!,
                        item.currency,
                      ),
              );
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingInvoiceInsurerShareColumn,
            numeric: true,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                lineItem.insurerShare == null
                    ? l10n.billingNotRecorded
                    : billingMoney(
                        context,
                        lineItem.insurerShare!,
                        item.currency,
                      ),
              );
            },
          ),
          AppListTableColumn<BillingInvoiceItem>(
            label: l10n.billingLineItemAmountColumn,
            numeric: true,
            cellBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
              return Text(
                billingMoney(context, lineItem.totalPrice, item.currency),
              );
            },
          ),
        ],
        mobileItemBuilder: (BuildContext context, BillingInvoiceItem lineItem) {
          return AppListTableMobileItem(
            title: lineItem.description,
            meta: <AppListTableMobileMeta>[
              AppListTableMobileMeta(
                label: l10n.billingQuantityLabel(lineItem.quantity),
                icon: Icons.tag_outlined,
              ),
              if (lineItem.sourceModule != null)
                AppListTableMobileMeta(label: lineItem.sourceModule!),
              AppListTableMobileMeta(
                label: billingMoney(context, lineItem.totalPrice, item.currency),
                icon: Icons.payments_outlined,
              ),
            ],
            showAvatar: false,
          );
        },
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (item.payments.isEmpty) {
      return AppWorkspaceDetailPanel(
        title: l10n.billingPaymentsTitle,
        child: Text(l10n.billingNoPayments),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.billingPaymentsTitle,
      child: Column(
        children: <Widget>[
          for (final BillingPayment payment in item.payments)
            _DetailRow(
              title: billingJoinDisplay(<String?>[
                payment.effectiveDisplayId,
                billingApiLabel(context, payment.method),
              ]),
              subtitle: billingJoinDisplay(<String?>[
                billingApiLabel(context, payment.status),
                payment.transactionRef,
                billingDateTime(context, payment.paidAt),
              ]),
              trailing: billingMoney(context, payment.amount, item.currency),
            ),
        ],
      ),
    );
  }
}

class _AdjustmentsSection extends StatelessWidget {
  const _AdjustmentsSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (item.adjustments.isEmpty) {
      return AppWorkspaceDetailPanel(
        title: l10n.billingAdjustmentsTitle,
        child: Text(l10n.billingNoAdjustments),
      );
    }

    return AppWorkspaceDetailPanel(
      title: l10n.billingAdjustmentsTitle,
      child: Column(
        children: <Widget>[
          for (final BillingAdjustment adjustment in item.adjustments)
            _DetailRow(
              title: adjustment.displayId ?? l10n.billingUnknownValue,
              subtitle: billingJoinDisplay(<String?>[
                billingApiLabel(context, adjustment.status),
                adjustment.reason,
              ]),
              trailing: billingMoney(context, adjustment.amount, item.currency),
            ),
        ],
      ),
    );
  }
}

class _NonInvoiceDetailSection extends StatelessWidget {
  const _NonInvoiceDetailSection({required this.item});

  final BillingWorkItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppReportPreviewPanel(
      title: l10n.billingItemDetailTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if ((item.requestReason ?? '').isNotEmpty)
            _DetailRow(
              title: l10n.billingReasonLabel,
              subtitle: item.requestReason!,
              trailing: billingMoney(context, item.amount, item.currency),
            ),
          if (item.requestedAt != null)
            _DetailRow(
              title: l10n.billingRequesterLabel,
              subtitle: billingJoinDisplay(<String?>[
                item.requestedByDisplayId,
                billingDateTime(context, item.requestedAt),
              ]),
              trailing: billingApiLabel(context, item.status),
            ),
          if (item.submittedAt != null)
            _DetailRow(
              title: l10n.billingSubmitClaimAction,
              subtitle: billingDateTime(context, item.submittedAt),
              trailing: billingApiLabel(context, item.status),
            ),
          if (item.invoiceDisplayId != null)
            _DetailRow(
              title: l10n.billingLinkedInvoiceLabel,
              subtitle: item.invoiceDisplayId!,
              trailing: billingMoney(context, item.amount, item.currency),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(trailing, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}
