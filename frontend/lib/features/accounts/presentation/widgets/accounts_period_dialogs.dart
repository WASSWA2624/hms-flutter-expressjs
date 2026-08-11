import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<AccountsOpenPeriodDraft?> showAccountsOpenPeriodDialog(
  BuildContext context,
) {
  return showAppDialog<AccountsOpenPeriodDraft>(
    context: context,
    builder: (_) => const AccountsOpenPeriodForm(
      dialogTitle: Text(AccountsStrings.openPeriodDialogTitle),
      dialogIcon: Icon(Icons.lock_open_outlined),
    ),
  );
}

Future<AccountsNotesDraft?> showAccountsClosePeriodDialog(
  BuildContext context, {
  AccountsFiscalPeriod? period,
}) {
  return showAppDialog<AccountsNotesDraft>(
    context: context,
    builder: (_) => AccountsClosePeriodForm(
      dialogTitle: const Text(AccountsStrings.closePeriodDialogTitle),
      dialogIcon: const Icon(Icons.lock_clock_outlined),
      period: period,
    ),
  );
}

Future<void> showAccountsBooksDetailDialog(
  BuildContext context, {
  required AccountsFiscalPeriod period,
  VoidCallback? onViewUnposted,
  VoidCallback? onClose,
  VoidCallback? onApprove,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _AccountsBooksDetailDialog(
      period: period,
      onViewUnposted: onViewUnposted,
      onClose: onClose,
      onApprove: onApprove,
    ),
  );
}

class _AccountsBooksDetailDialog extends ConsumerWidget {
  const _AccountsBooksDetailDialog({
    required this.period,
    this.onViewUnposted,
    this.onClose,
    this.onApprove,
  });

  final AccountsFiscalPeriod period;
  final VoidCallback? onViewUnposted;
  final VoidCallback? onClose;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String statusLabel = accountsPeriodStatusLabel(period);
    final AppWorkspaceStatusTone tone = period.isOverdue || period.isPendingApproval
        ? (period.isOverdue
              ? AppWorkspaceStatusTone.error
              : AppWorkspaceStatusTone.warning)
        : (period.isOpen
              ? AppWorkspaceStatusTone.warning
              : AppWorkspaceStatusTone.neutral);

    return AppDialog(
      title: const Text(AccountsStrings.detailTitlePeriod),
      icon: const Icon(Icons.menu_book_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(period.effectiveLabel, style: theme.textTheme.titleLarge),
          SizedBox(height: theme.spacing.sm),
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: statusLabel,
              tone: tone,
              icon: period.isClosed
                  ? Icons.lock_outlined
                  : Icons.lock_open_outlined,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            AccountsStrings.periodChecklistTitle,
            style: theme.textTheme.titleSmall,
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            '${AccountsStrings.periodUnpostedLabel}: ${period.unpostedJournalCount}',
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            '${AccountsStrings.periodPendingApprovalsLabel}: ${period.pendingApprovalsCount}',
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            '${AccountsStrings.periodTrialSnapshotLabel}: ${AccountsStrings.periodTrialSnapshotValue}',
          ),
          if ((period.notes ?? '').trim().isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Text(
              AccountsStrings.notesLabel,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              accountsPublicLabel(period.notes) ?? AccountsStrings.notRecorded,
            ),
          ],
          if (onViewUnposted != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.tertiary(
                label: AccountsStrings.periodViewUnposted,
                icon: Icons.receipt_long_outlined,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  onViewUnposted!();
                },
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: context.l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        AppButton.secondary(
          label: AccountsStrings.periodPrintAction,
          icon: Icons.print_outlined,
          onPressed: () => unawaited(
            printAccountsBooksPacket(
              ref: ref,
              context: context,
              period: period,
            ),
          ),
        ),
        if (onApprove != null)
          AppButton.secondary(
            label: AccountsStrings.approveAction,
            icon: Icons.check_circle_outline,
            onPressed: () {
              Navigator.of(context).maybePop();
              onApprove!();
            },
          ),
        if (onClose != null)
          AppButton.primary(
            label: AccountsStrings.closeAction,
            icon: Icons.lock_clock_outlined,
            onPressed: () {
              Navigator.of(context).maybePop();
              onClose!();
            },
          ),
      ],
    );
  }
}
