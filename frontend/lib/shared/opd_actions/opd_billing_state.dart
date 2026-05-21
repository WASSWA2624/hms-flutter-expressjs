import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum OpdBillingState { paid, required, notRequired, unknown }

@immutable
final class OpdBillingDisplay {
  const OpdBillingDisplay({
    required this.state,
    required this.statusLabel,
    required this.label,
    required this.tone,
    this.amountLabel,
  });

  final OpdBillingState state;
  final String statusLabel;
  final String label;
  final String? amountLabel;
  final AppWorkspaceStatusTone tone;
}

OpdBillingDisplay opdFlowBillingDisplay(
  BuildContext context,
  OpdFlowSummary flow,
) {
  final AppLocalizations l10n = context.l10n;
  final OpdBillingState state = opdFlowBillingState(flow);
  final String statusLabel = opdFlowBillingStatusLabel(l10n, flow);
  final num? billingAmount = switch (state) {
    OpdBillingState.paid => flow.consultationPaidAmount ?? flow.consultationFee,
    OpdBillingState.required => flow.consultationFee,
    OpdBillingState.notRequired => null,
    OpdBillingState.unknown =>
      flow.consultationPaidAmount ?? flow.consultationFee,
  };
  final String? amountLabel = opdMoneyLabel(
    context,
    billingAmount,
    flow.consultationCurrency,
  );

  return OpdBillingDisplay(
    state: state,
    statusLabel: statusLabel,
    amountLabel: amountLabel,
    label: AppDisplay.joinNonEmpty(<String?>[
      statusLabel,
      amountLabel,
    ], separator: ' | '),
    tone: opdBillingTone(state),
  );
}

OpdBillingDisplay opdQueueBillingDisplay(
  BuildContext context,
  OpdQueueEntry entry,
) {
  final AppLocalizations l10n = context.l10n;
  final OpdBillingState state = opdQueueBillingState(entry);
  final String statusLabel = opdQueueBillingStatusLabel(l10n, entry);
  final num? billingAmount = switch (state) {
    OpdBillingState.paid => entry.amountPaid ?? entry.amountToPay,
    OpdBillingState.required => entry.amountToPay,
    OpdBillingState.notRequired => null,
    OpdBillingState.unknown => entry.amountPaid ?? entry.amountToPay,
  };
  final String? amountLabel = opdMoneyLabel(
    context,
    billingAmount,
    entry.currency,
  );

  return OpdBillingDisplay(
    state: state,
    statusLabel: statusLabel,
    amountLabel: amountLabel,
    label: AppDisplay.joinNonEmpty(<String?>[
      statusLabel,
      amountLabel,
    ], separator: ' | '),
    tone: opdBillingTone(state),
  );
}

OpdBillingState opdFlowBillingState(OpdFlowSummary flow) {
  final String stage = (flow.stage ?? '').toUpperCase();
  final String paymentStatus = (flow.consultationPaymentStatus ?? '')
      .trim()
      .toUpperCase();
  final num? paidAmount = flow.consultationPaidAmount;
  final num? fee = flow.consultationFee;
  final bool paymentCoversFee =
      paidAmount != null &&
      paidAmount > 0 &&
      (fee == null || fee <= 0 || paidAmount >= fee);

  if (flow.consultationPaid ||
      paymentStatus == 'PAID' ||
      paymentStatus == 'CLEARED' ||
      paymentStatus == 'SUCCESS' ||
      paymentStatus == 'SUCCESSFUL' ||
      paymentStatus == 'APPROVED' ||
      (paymentStatus == 'COMPLETED' &&
          (paymentCoversFee || paidAmount == null || fee == null))) {
    return OpdBillingState.paid;
  }
  if (flow.consultationPaymentRequired ||
      paymentStatus == 'PENDING' ||
      paymentStatus == 'PARTIAL' ||
      paymentStatus == 'ISSUED' ||
      paymentStatus == 'INVOICE_CREATED' ||
      stage == 'WAITING_CONSULTATION_PAYMENT') {
    return OpdBillingState.required;
  }
  if (paymentStatus == 'NOT_REQUIRED' || paymentStatus == 'NO_CHARGE') {
    return OpdBillingState.notRequired;
  }
  return OpdBillingState.notRequired;
}

OpdBillingState opdQueueBillingState(OpdQueueEntry entry) {
  final String status = (entry.paymentStatus ?? '').toUpperCase();
  if (entry.amountPaid != null && entry.amountPaid! > 0 && status.isEmpty) {
    return OpdBillingState.paid;
  }
  if (entry.amountToPay != null && entry.amountToPay! > 0 && status.isEmpty) {
    return OpdBillingState.required;
  }
  return switch (status) {
    'PAID' ||
    'COMPLETED' ||
    'COVERED' ||
    'WAIVED' ||
    'CLEARED' ||
    'SUCCESS' ||
    'SUCCESSFUL' ||
    'APPROVED' => OpdBillingState.paid,
    'PENDING' ||
    'PENDING_PAYMENT' ||
    'INVOICE_CREATED' ||
    'ISSUED' ||
    'PARTIAL' => OpdBillingState.required,
    'NOT_REQUIRED' || 'NO_CHARGE' => OpdBillingState.notRequired,
    _ => OpdBillingState.unknown,
  };
}

String opdFlowBillingStatusLabel(AppLocalizations l10n, OpdFlowSummary flow) {
  final OpdBillingState state = opdFlowBillingState(flow);
  if (state == OpdBillingState.paid &&
      (_isTerminalStatus(flow.stage) || _isTerminalStatus(flow.status))) {
    return l10n.opdCompletedFlowSummaryLabel;
  }
  return opdBillingStateLabel(l10n, state);
}

String opdQueueBillingStatusLabel(AppLocalizations l10n, OpdQueueEntry entry) {
  final OpdBillingState state = opdQueueBillingState(entry);
  final String rawStatus = (entry.paymentStatus ?? '').trim();
  if (rawStatus.isNotEmpty && state == OpdBillingState.unknown) {
    return AppDisplay.apiLabel(rawStatus);
  }
  return opdBillingStateLabel(l10n, state);
}

String opdBillingStateLabel(AppLocalizations l10n, OpdBillingState state) {
  return switch (state) {
    OpdBillingState.paid => l10n.opdPaymentPaidLabel,
    OpdBillingState.required => l10n.opdPaymentRequiredLabel,
    OpdBillingState.notRequired => l10n.opdPaymentNotRequiredLabel,
    OpdBillingState.unknown => l10n.profileUnknownValue,
  };
}

String opdBillingStateFilterValue(OpdBillingState state) {
  return switch (state) {
    OpdBillingState.paid => 'PAID',
    OpdBillingState.required => 'REQUIRED',
    OpdBillingState.notRequired => 'NOT_REQUIRED',
    OpdBillingState.unknown => 'UNKNOWN',
  };
}

OpdBillingState opdBillingStateFromFilterValue(String value) {
  return switch (value.toUpperCase()) {
    'PAID' => OpdBillingState.paid,
    'REQUIRED' => OpdBillingState.required,
    'NOT_REQUIRED' => OpdBillingState.notRequired,
    _ => OpdBillingState.unknown,
  };
}

AppWorkspaceStatusTone opdBillingTone(OpdBillingState state) {
  return switch (state) {
    OpdBillingState.paid => AppWorkspaceStatusTone.success,
    OpdBillingState.required => AppWorkspaceStatusTone.warning,
    OpdBillingState.notRequired => AppWorkspaceStatusTone.neutral,
    OpdBillingState.unknown => AppWorkspaceStatusTone.neutral,
  };
}

String? opdMoneyLabel(BuildContext context, num? amount, String? currency) {
  if (amount == null || amount == 0) {
    return null;
  }

  final String? currencyCode = currency?.trim().toUpperCase();
  if (currencyCode == null || currencyCode.isEmpty) {
    return AppFormatters.decimal(amount, Localizations.localeOf(context));
  }

  return AppFormatters.currency(
    amount,
    Localizations.localeOf(context),
    currencyCode: currencyCode,
  );
}

String opdCurrencyAmountInput(num? amount) {
  if (amount == null) {
    return '';
  }
  if (amount is int || amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toString();
}

bool _isTerminalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}
