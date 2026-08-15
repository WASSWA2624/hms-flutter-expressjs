import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

String accountsUnknownValue() => AccountsStrings.unknownValue;

String accountsStatusLabel(String? status) {
  final String normalized = (status ?? '').trim().toUpperCase();
  return switch (normalized) {
    'PENDING' || 'PENDING_APPROVAL' => AccountsStrings.statusPending,
    'APPROVED' => AccountsStrings.statusApproved,
    'REJECTED' || 'DENIED' => AccountsStrings.statusRejected,
    'DRAFT' || 'UNPOSTED' || 'READY' => AccountsStrings.statusDraft,
    'POSTED' => AccountsStrings.statusPosted,
    'ISSUED' => AccountsStrings.statusIssued,
    'VOIDED' || 'VOID' => AccountsStrings.statusVoided,
    'OPEN' => AccountsStrings.statusOpen,
    'CLOSED' => AccountsStrings.statusClosed,
    'OVERDUE' => AccountsStrings.statusOverdue,
    _ => status?.trim().isNotEmpty == true
        ? status!.trim()
        : AccountsStrings.unknownValue,
  };
}

String accountsWorkItemStatusLabel(BuildContext context, AccountsWorkItem item) {
  return accountsStatusLabel(item.status);
}

IconData accountsWorkItemStatusIcon(AccountsWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  return switch (status) {
    'PENDING' || 'PENDING_APPROVAL' => Icons.rule_outlined,
    'APPROVED' => Icons.verified_outlined,
    'REJECTED' || 'DENIED' => Icons.cancel_outlined,
    'DRAFT' || 'UNPOSTED' || 'READY' => Icons.edit_note_outlined,
    'POSTED' => Icons.check_circle_outline,
    _ => Icons.info_outline,
  };
}

AppWorkspaceStatusTone accountsWorkItemStatusTone(AccountsWorkItem item) {
  if (item.canApproveOrReject || item.canPost) {
    return AppWorkspaceStatusTone.warning;
  }
  final String status = (item.status ?? '').trim().toUpperCase();
  return switch (status) {
    'APPROVED' || 'POSTED' => AppWorkspaceStatusTone.success,
    'REJECTED' || 'DENIED' => AppWorkspaceStatusTone.error,
    'PENDING' || 'DRAFT' => AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String accountsApprovalTypeLabel(String? type) {
  final String normalized = (type ?? '').trim().toUpperCase();
  return switch (normalized) {
    'JOURNAL_POST' || 'POST' => AccountsStrings.approvalTypeJournalPost,
    'VOID' => AccountsStrings.approvalTypeVoid,
    'REVERSAL' || 'REVERSE' => AccountsStrings.approvalTypeReversal,
    'PERIOD_CLOSE' || 'CLOSE' => AccountsStrings.approvalTypePeriodClose,
    _ => type?.trim().isNotEmpty == true
        ? type!.trim()
        : AccountsStrings.unknownValue,
  };
}

String accountsDetailTitleFor(AccountsWorkItem item) {
  if (item.isApproval) {
    return AccountsStrings.detailTitleApproval;
  }
  if (item.isPeriod) {
    return AccountsStrings.detailTitlePeriod;
  }
  return AccountsStrings.detailTitleJournal;
}

String accountsDetailTitle(BuildContext context, AccountsWorkItem item) {
  return accountsDetailTitleFor(item);
}

final RegExp _accountsUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool accountsLooksLikeUuid(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isNotEmpty && _accountsUuidPattern.hasMatch(normalized);
}

/// Presentation label that never surfaces raw UUIDs (accounts.md §19).
String? accountsPublicLabel(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || accountsLooksLikeUuid(normalized)) {
    return null;
  }
  return normalized;
}

String accountsJoinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
}

/// Journal / work-item friendly id for tables, dialogs, and print.
String accountsWorkItemPublicId(AccountsWorkItem item) {
  return accountsPublicLabel(item.journalDisplayId) ??
      accountsPublicLabel(item.displayId) ??
      accountsPublicLabel(item.accountDisplayId) ??
      AccountsStrings.journalColumn;
}

bool accountsWorkItemMatchesSearch(
  BuildContext context,
  AccountsWorkItem item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  final List<String?> haystacks = <String?>[
    accountsWorkItemPublicId(item),
    accountsPublicLabel(item.journalDisplayId),
    accountsPublicLabel(item.accountDisplayId),
    accountsPublicLabel(item.patientDisplayName),
    item.status,
    item.approvalType,
    accountsPublicLabel(item.requestReason),
    accountsPublicLabel(item.requestedByDisplayId),
    accountsPublicLabel(item.periodLabel),
    accountsPublicLabel(item.source),
    accountsPublicLabel(item.reference),
  ];
  for (final String? value in haystacks) {
    if ((value ?? '').toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}

String accountsSectionLabel(
  AppLocalizations l10n,
  AccountsDeskSection section,
) {
  return switch (section) {
    AccountsDeskSection.work => AccountsStrings.openWorkLabel,
    AccountsDeskSection.journals => AccountsStrings.toPostLabel,
    AccountsDeskSection.approvals => AccountsStrings.needApprovalLabel,
    AccountsDeskSection.gl => AccountsStrings.generalLedgerLabel,
    AccountsDeskSection.ledgers => AccountsStrings.patientLedgersLabel,
    AccountsDeskSection.chart => AccountsStrings.accountChartLabel,
    AccountsDeskSection.invoices => AccountsStrings.invoicesLabel,
    AccountsDeskSection.fiscalYearsAndPeriods => l10n.accountsFiscalPeriodsLabel,
    AccountsDeskSection.departmentsAndCostCentres =>
      l10n.accountsDepartmentsLabel,
    AccountsDeskSection.paymentMethods => l10n.accountsPaymentMethodsLabel,
  };
}

String accountsCategoryLabel(AccountsDeskCategory category) {
  return switch (category) {
    AccountsDeskCategory.books => AccountsStrings.booksCategoryLabel,
    AccountsDeskCategory.setupAndControls =>
      AccountsStrings.setupAndControlsCategoryLabel,
  };
}

String? accountsCategoryTooltip(AccountsDeskCategory category) {
  return switch (category) {
    AccountsDeskCategory.books => AccountsStrings.booksCategoryTooltip,
    AccountsDeskCategory.setupAndControls =>
      AccountsStrings.setupAndControlsCategoryTooltip,
  };
}

IconData accountsCategoryIcon(AccountsDeskCategory category) {
  return switch (category) {
    AccountsDeskCategory.books => Icons.menu_book_outlined,
    AccountsDeskCategory.setupAndControls => Icons.tune_outlined,
  };
}

String? accountsSectionTooltip(
  AppLocalizations l10n,
  AccountsDeskSection section,
) {
  return switch (section) {
    AccountsDeskSection.work => AccountsStrings.openWorkTooltip,
    AccountsDeskSection.journals => AccountsStrings.toPostTooltip,
    AccountsDeskSection.approvals => AccountsStrings.needApprovalTooltip,
    AccountsDeskSection.gl => AccountsStrings.generalLedgerTooltip,
    AccountsDeskSection.ledgers => AccountsStrings.patientLedgersTooltip,
    AccountsDeskSection.chart => AccountsStrings.accountChartTooltip,
    AccountsDeskSection.invoices => AccountsStrings.invoicesTooltip,
    AccountsDeskSection.fiscalYearsAndPeriods =>
      l10n.accountsFiscalPeriodsTooltip,
    AccountsDeskSection.departmentsAndCostCentres =>
      l10n.accountsDepartmentsTooltip,
    AccountsDeskSection.paymentMethods =>
      l10n.accountsPaymentMethodsTooltip,
  };
}

String accountsTableSettingsKey(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.work => 'accounts_work_v1',
    AccountsDeskSection.journals => 'accounts_journals_v1',
    AccountsDeskSection.approvals => 'accounts_approvals_v1',
    AccountsDeskSection.gl => 'accounts_gl_v1',
    AccountsDeskSection.ledgers => 'accounts_ledgers_v1',
    AccountsDeskSection.chart => 'accounts_chart_v1',
    AccountsDeskSection.invoices => 'accounts_invoices_v1',
    AccountsDeskSection.fiscalYearsAndPeriods => 'accounts_fiscal_periods_v1',
    AccountsDeskSection.departmentsAndCostCentres => 'accounts_departments_v1',
    AccountsDeskSection.paymentMethods => 'accounts_payment_methods_v1',
  };
}

IconData accountsSectionIcon(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.work => Icons.inventory_2_outlined,
    AccountsDeskSection.journals => Icons.post_add_outlined,
    AccountsDeskSection.approvals => Icons.rule_outlined,
    AccountsDeskSection.gl => Icons.account_balance_outlined,
    AccountsDeskSection.ledgers => Icons.person_outline,
    AccountsDeskSection.chart => Icons.list_alt_outlined,
    AccountsDeskSection.invoices => Icons.receipt_long_outlined,
    AccountsDeskSection.fiscalYearsAndPeriods => Icons.event_note_outlined,
    AccountsDeskSection.departmentsAndCostCentres =>
      Icons.account_tree_outlined,
    AccountsDeskSection.paymentMethods => Icons.payments_outlined,
  };
}

String accountsEmptyBody(AppLocalizations l10n, AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.work => AccountsStrings.openWorkEmpty,
    AccountsDeskSection.journals => AccountsStrings.toPostEmpty,
    AccountsDeskSection.approvals => AccountsStrings.needApprovalEmpty,
    AccountsDeskSection.gl => AccountsStrings.glEmpty,
    AccountsDeskSection.ledgers => AccountsStrings.patientLedgersEmpty,
    AccountsDeskSection.chart => AccountsStrings.chartEmpty,
    AccountsDeskSection.invoices => AccountsStrings.invoicesEmpty,
    AccountsDeskSection.fiscalYearsAndPeriods => l10n.accountsFiscalPeriodsEmpty,
    AccountsDeskSection.departmentsAndCostCentres =>
      l10n.accountsDepartmentsEmpty,
    AccountsDeskSection.paymentMethods => l10n.accountsPaymentMethodsEmpty,
  };
}

String accountsFiscalPeriodStatusLabel(
  AppLocalizations l10n,
  AccountsFiscalPeriodStatus status,
) {
  return switch (status) {
    AccountsFiscalPeriodStatus.draft => l10n.accountsFiscalStatusDraft,
    AccountsFiscalPeriodStatus.active => l10n.accountsFiscalStatusActive,
    AccountsFiscalPeriodStatus.inactive => l10n.accountsFiscalStatusInactive,
    AccountsFiscalPeriodStatus.archived => l10n.accountsFiscalStatusArchived,
  };
}

AppWorkspaceStatusTone accountsFiscalPeriodStatusTone(
  AccountsFiscalPeriodStatus status,
) {
  return switch (status) {
    AccountsFiscalPeriodStatus.active => AppWorkspaceStatusTone.success,
    AccountsFiscalPeriodStatus.draft => AppWorkspaceStatusTone.warning,
    AccountsFiscalPeriodStatus.inactive => AppWorkspaceStatusTone.neutral,
    AccountsFiscalPeriodStatus.archived => AppWorkspaceStatusTone.neutral,
  };
}

String accountsDepartmentStatusLabel(
  AppLocalizations l10n,
  AccountsDepartmentStatus status,
) {
  return switch (status) {
    AccountsDepartmentStatus.draft => l10n.accountsDepartmentStatusDraft,
    AccountsDepartmentStatus.active => l10n.accountsDepartmentStatusActive,
    AccountsDepartmentStatus.inactive => l10n.accountsDepartmentStatusInactive,
    AccountsDepartmentStatus.archived => l10n.accountsDepartmentStatusArchived,
  };
}

AppWorkspaceStatusTone accountsDepartmentStatusTone(
  AccountsDepartmentStatus status,
) {
  return switch (status) {
    AccountsDepartmentStatus.active => AppWorkspaceStatusTone.success,
    AccountsDepartmentStatus.draft => AppWorkspaceStatusTone.warning,
    AccountsDepartmentStatus.inactive => AppWorkspaceStatusTone.neutral,
    AccountsDepartmentStatus.archived => AppWorkspaceStatusTone.neutral,
  };
}

IconData accountsDepartmentStatusIcon(AccountsDepartmentStatus status) {
  return switch (status) {
    AccountsDepartmentStatus.draft => Icons.edit_note_outlined,
    AccountsDepartmentStatus.active => Icons.check_circle_outline,
    AccountsDepartmentStatus.inactive => Icons.pause_circle_outline,
    AccountsDepartmentStatus.archived => Icons.inventory_2_outlined,
  };
}

String accountsPaymentMethodStatusLabel(
  AppLocalizations l10n,
  AccountsPaymentMethodStatus status,
) {
  return switch (status) {
    AccountsPaymentMethodStatus.draft => l10n.accountsPaymentMethodStatusDraft,
    AccountsPaymentMethodStatus.active => l10n.accountsPaymentMethodStatusActive,
    AccountsPaymentMethodStatus.inactive =>
      l10n.accountsPaymentMethodStatusInactive,
    AccountsPaymentMethodStatus.archived =>
      l10n.accountsPaymentMethodStatusArchived,
  };
}

AppWorkspaceStatusTone accountsPaymentMethodStatusTone(
  AccountsPaymentMethodStatus status,
) {
  return switch (status) {
    AccountsPaymentMethodStatus.active => AppWorkspaceStatusTone.success,
    AccountsPaymentMethodStatus.draft => AppWorkspaceStatusTone.warning,
    AccountsPaymentMethodStatus.inactive => AppWorkspaceStatusTone.neutral,
    AccountsPaymentMethodStatus.archived => AppWorkspaceStatusTone.neutral,
  };
}

IconData accountsPaymentMethodStatusIcon(AccountsPaymentMethodStatus status) {
  return switch (status) {
    AccountsPaymentMethodStatus.draft => Icons.edit_note_outlined,
    AccountsPaymentMethodStatus.active => Icons.check_circle_outline,
    AccountsPaymentMethodStatus.inactive => Icons.pause_circle_outline,
    AccountsPaymentMethodStatus.archived => Icons.inventory_2_outlined,
  };
}

/// Localized label for the shared tender taxonomy; never render the raw enum.
String accountsPaymentMethodTypeLabel(
  AppLocalizations l10n,
  AccountsPaymentMethodType type,
) {
  return switch (type) {
    AccountsPaymentMethodType.cash => l10n.accountsPaymentMethodTypeCash,
    AccountsPaymentMethodType.creditCard =>
      l10n.accountsPaymentMethodTypeCreditCard,
    AccountsPaymentMethodType.debitCard =>
      l10n.accountsPaymentMethodTypeDebitCard,
    AccountsPaymentMethodType.prepaidCard =>
      l10n.accountsPaymentMethodTypePrepaidCard,
    AccountsPaymentMethodType.giftCard =>
      l10n.accountsPaymentMethodTypeGiftCard,
    AccountsPaymentMethodType.voucher => l10n.accountsPaymentMethodTypeVoucher,
    AccountsPaymentMethodType.bankCheck =>
      l10n.accountsPaymentMethodTypeBankCheck,
    AccountsPaymentMethodType.mobileMoney =>
      l10n.accountsPaymentMethodTypeMobileMoney,
    AccountsPaymentMethodType.bankTransfer =>
      l10n.accountsPaymentMethodTypeBankTransfer,
    AccountsPaymentMethodType.insurance =>
      l10n.accountsPaymentMethodTypeInsurance,
    AccountsPaymentMethodType.other => l10n.accountsPaymentMethodTypeOther,
  };
}

String accountsPaymentMethodDirectionLabel(
  AppLocalizations l10n,
  AccountsPaymentMethodDirection direction,
) {
  return switch (direction) {
    AccountsPaymentMethodDirection.incoming =>
      l10n.accountsPaymentMethodDirectionIncoming,
    AccountsPaymentMethodDirection.outgoing =>
      l10n.accountsPaymentMethodDirectionOutgoing,
    AccountsPaymentMethodDirection.both =>
      l10n.accountsPaymentMethodDirectionBoth,
  };
}

/// Localized Yes/No for a payment method requirement flag.
String accountsPaymentMethodFlagLabel(AppLocalizations l10n, bool value) {
  return value ? l10n.accountsPaymentMethodYes : l10n.accountsPaymentMethodNo;
}

IconData accountsFiscalPeriodStatusIcon(AccountsFiscalPeriodStatus status) {
  return switch (status) {
    AccountsFiscalPeriodStatus.draft => Icons.edit_note_outlined,
    AccountsFiscalPeriodStatus.active => Icons.check_circle_outline,
    AccountsFiscalPeriodStatus.inactive => Icons.pause_circle_outline,
    AccountsFiscalPeriodStatus.archived => Icons.inventory_2_outlined,
  };
}

/// Localized date-only display; the API keeps ISO-8601.
String accountsDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AccountsStrings.unknownValue;
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

/// Alias used by workspace empty panels.
String accountsSectionEmptyCopy(
  AppLocalizations l10n,
  AccountsDeskSection section,
) => accountsEmptyBody(l10n, section);

String accountsMoney(BuildContext context, num value, String? currencyCode) {
  return AppFormatters.currency(
    value,
    Localizations.localeOf(context),
    currencyCode: currencyCode ?? appDefaultCurrencyCode,
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
}

String accountsDateTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return AccountsStrings.unknownValue;
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String? accountsEmptyToNull(String? value) {
  final String trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}
