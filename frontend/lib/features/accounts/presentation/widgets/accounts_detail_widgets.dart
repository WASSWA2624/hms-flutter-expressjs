import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart'
    hide accountsMoney;
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class AccountsDetailBody extends ConsumerWidget {
  const AccountsDetailBody({
    required this.item,
    required this.canWrite,
    required this.isSaving,
    this.canApprove = false,
    this.onPost,
    this.onApprove,
    this.onReject,
    this.onReverse,
    this.onVoid,
    this.onClose,
    this.onSend,
    this.onOpenGl,
    this.onOpenLedger,
    super.key,
  });

  final AccountsWorkItem item;
  final bool canWrite;
  final bool canApprove;
  final bool isSaving;
  final VoidCallback? onPost;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReverse;
  final VoidCallback? onVoid;
  final VoidCallback? onClose;
  final VoidCallback? onSend;
  final VoidCallback? onOpenGl;
  final VoidCallback? onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.journalNumber,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsWorkItemStatusLabel(context, item),
                      tone: item.canApproveOrReject || item.canPost
                          ? AppWorkspaceStatusTone.warning
                          : AppWorkspaceStatusTone.neutral,
                      icon: accountsWorkItemStatusIcon(item),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              accountsMoney(context, item.amount, item.currency),
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            if (item.source.trim().isNotEmpty)
              _SummaryChip(
                label: AccountsStrings.sourceColumn,
                value: item.source,
              ),
            if ((item.periodLabel ?? '').trim().isNotEmpty)
              _SummaryChip(
                label: AccountsStrings.periodColumn,
                value: item.periodLabel!,
              ),
            if (item.accountLabel.trim().isNotEmpty)
              _SummaryChip(
                label: AccountsStrings.accountColumn,
                value: item.accountLabel,
              ),
            if (item.isApproval && (item.approvalType ?? '').trim().isNotEmpty)
              _SummaryChip(
                label: AccountsStrings.typeColumn,
                value: accountsApprovalTypeLabel(item.approvalType),
              ),
          ],
        ),
        if ((item.requestReason ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          Text(
            AccountsStrings.reasonColumn,
            style: theme.textTheme.labelLarge,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(item.requestReason!, style: theme.textTheme.bodyMedium),
        ],
        SizedBox(height: theme.spacing.md),
        _AccountsDetailActionPanel(
          item: item,
          accessPolicy: accessPolicy,
          canWrite: canWrite,
          canApprove: canApprove,
          isSaving: isSaving,
          onPost: onPost,
          onApprove: onApprove,
          onReject: onReject,
          onReverse: onReverse,
          onVoid: onVoid,
          onClose: onClose,
          onSend: onSend,
          onOpenGl: onOpenGl,
          onOpenLedger: onOpenLedger,
        ),
      ],
    );
  }
}

class _AccountsDetailActionPanel extends StatelessWidget {
  const _AccountsDetailActionPanel({
    required this.item,
    required this.accessPolicy,
    required this.canWrite,
    required this.canApprove,
    required this.isSaving,
    this.onPost,
    this.onApprove,
    this.onReject,
    this.onReverse,
    this.onVoid,
    this.onClose,
    this.onSend,
    this.onOpenGl,
    this.onOpenLedger,
  });

  final AccountsWorkItem item;
  final AppAccessPolicy accessPolicy;
  final bool canWrite;
  final bool canApprove;
  final bool isSaving;
  final VoidCallback? onPost;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReverse;
  final VoidCallback? onVoid;
  final VoidCallback? onClose;
  final VoidCallback? onSend;
  final VoidCallback? onOpenGl;
  final VoidCallback? onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final List<AppActionItem> primary = <AppActionItem>[];
    final List<AppActionItem> secondary = <AppActionItem>[];

    final String? nextLabel = accountsNextActionLabel(
      item,
      canWrite: canWrite,
      canApprove: canApprove,
      canEnter: canEnterAccounts(accessPolicy),
    );

    if (nextLabel == AccountsStrings.approveAction &&
        onApprove != null &&
        item.canApproveOrReject) {
      primary.add(
        AppActionItem(
          label: AccountsStrings.approveAction,
          leadingIcon: Icons.check_circle_outline,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: onApprove,
        ),
      );
    } else if (nextLabel == AccountsStrings.postAction &&
        onPost != null &&
        item.canPost) {
      primary.add(
        AppActionItem(
          label: AccountsStrings.postAction,
          leadingIcon: Icons.publish_outlined,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: onPost,
        ),
      );
    } else if (nextLabel == AccountsStrings.closeAction &&
        onClose != null &&
        item.canClose) {
      primary.add(
        AppActionItem(
          label: AccountsStrings.closeAction,
          leadingIcon: Icons.lock_clock_outlined,
          enabled: !isSaving,
          variant: AppActionVariant.primary,
          onPressed: onClose,
        ),
      );
    }

    if (onReverse != null && item.canReverse && canWrite) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.reverseAction,
          leadingIcon: Icons.undo_outlined,
          enabled: !isSaving,
          onPressed: onReverse,
        ),
      );
    }
    if (onVoid != null && item.canVoid && canWrite) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.voidAction,
          leadingIcon: Icons.block_outlined,
          enabled: !isSaving,
          onPressed: onVoid,
        ),
      );
    }
    if (onReject != null && item.canApproveOrReject && canApprove) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.rejectAction,
          leadingIcon: Icons.cancel_outlined,
          enabled: !isSaving,
          onPressed: onReject,
        ),
      );
    }
    if (onSend != null && canWrite && item.isJournal) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.sendAction,
          leadingIcon: Icons.send_outlined,
          enabled: !isSaving,
          onPressed: onSend,
        ),
      );
    }
    if (onOpenGl != null && item.canOpenGl && canViewAccountsGl(accessPolicy)) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.glAction,
          leadingIcon: Icons.account_balance_outlined,
          enabled: !isSaving,
          onPressed: onOpenGl,
        ),
      );
    }
    if (onOpenLedger != null &&
        item.canOpenLedger &&
        canReadAccountsPatientLedgers(accessPolicy)) {
      secondary.add(
        AppActionItem(
          label: AccountsStrings.ledgerAction,
          leadingIcon: Icons.people_outline,
          enabled: !isSaving,
          onPressed: onOpenLedger,
        ),
      );
    }

    final List<AppActionItem> actions = <AppActionItem>[
      ...primary,
      ...secondary,
    ];
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
