import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';

@immutable
final class OpdConsultationBillingBreakdown {
  const OpdConsultationBillingBreakdown({
    required this.requiredAmount,
    required this.paidAmount,
    required this.remainingBalance,
    this.currency,
  });

  final num? requiredAmount;
  final num? paidAmount;
  final num? remainingBalance;
  final String? currency;
}

OpdConsultationBillingBreakdown opdConsultationBillingBreakdown(
  OpdFlowSummary flow, {
  OpdFlowDetail? detail,
}) {
  final OpdFlowSummary source = detail?.summary ?? flow;
  final num? requiredAmount = source.consultationFee;
  final num paidAmount =
      detail?.consultationPaidAmount ?? source.consultationPaidAmount ?? 0;
  final num? remainingBalance = requiredAmount == null
      ? null
      : (requiredAmount - paidAmount).clamp(0, double.infinity);
  return OpdConsultationBillingBreakdown(
    requiredAmount: requiredAmount,
    paidAmount: paidAmount > 0 ? paidAmount : null,
    remainingBalance: remainingBalance,
    currency: source.consultationCurrency,
  );
}

class OpdConsultationBillingBreakdownPanel extends StatelessWidget {
  const OpdConsultationBillingBreakdownPanel({
    required this.flow,
    this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final OpdConsultationBillingBreakdown breakdown =
        opdConsultationBillingBreakdown(flow, detail: detail);
    final String? requiredLabel = opdMoneyLabel(
      context,
      breakdown.requiredAmount,
      breakdown.currency,
    );
    final String? paidLabel = opdMoneyLabel(
      context,
      breakdown.paidAmount,
      breakdown.currency,
    );
    final String? remainingLabel = opdMoneyLabel(
      context,
      breakdown.remainingBalance,
      breakdown.currency,
      allowZero: true,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
                Text(
                  l10n.opdBillingSectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppInfoTileGrid(
              minItemWidth: 140,
              emptyValue: l10n.profileUnknownValue,
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.opdBillingRequiredAmountLabel,
                  value: requiredLabel,
                  icon: Icons.payments_outlined,
                ),
                AppInfoTileData(
                  label: l10n.opdBillingAmountPaidLabel,
                  value: paidLabel,
                  icon: Icons.check_circle_outline,
                ),
                AppInfoTileData(
                  label: l10n.opdBillingRemainingBalanceLabel,
                  value: remainingLabel,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
