import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

enum SubscriptionPaymentFlowIntent { renewal, upgrade }

enum SubscriptionPaymentMethodId {
  bankTransfer('BANK_TRANSFER'),
  mobileMoney('MOBILE_MONEY'),
  creditCard('CREDIT_CARD'),
  debitCard('DEBIT_CARD'),
  cash('CASH'),
  other('OTHER');

  const SubscriptionPaymentMethodId(this.serverValue);

  final String serverValue;

  static SubscriptionPaymentMethodId? fromServer(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final SubscriptionPaymentMethodId method in values) {
      if (method.serverValue == normalized) {
        return method;
      }
    }
    return null;
  }
}

enum MobileMoneyProviderId {
  mtn('MTN'),
  airtel('AIRTEL'),
  mpesa('MPESA'),
  vodacom('VODACOM'),
  tigo('TIGO'),
  orange('ORANGE'),
  zamtel('ZAMTEL'),
  government('GOVERNMENT');

  const MobileMoneyProviderId(this.serverValue);

  final String serverValue;
}

final class SubscriptionPaymentMethodDefinition {
  const SubscriptionPaymentMethodDefinition({
    required this.id,
    required this.icon,
    required this.color,
  });

  final SubscriptionPaymentMethodId id;
  final IconData icon;
  final Color color;
}

const List<SubscriptionPaymentMethodDefinition> subscriptionPaymentMethods =
    <SubscriptionPaymentMethodDefinition>[
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.mobileMoney,
        icon: Icons.phone_android_outlined,
        color: Color(0xFFF59E0B),
      ),
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.bankTransfer,
        icon: Icons.account_balance_outlined,
        color: Color(0xFF2563EB),
      ),
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.creditCard,
        icon: Icons.credit_card_outlined,
        color: Color(0xFF7C3AED),
      ),
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.debitCard,
        icon: Icons.payment_outlined,
        color: Color(0xFF0891B2),
      ),
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.cash,
        icon: Icons.payments_outlined,
        color: Color(0xFF16A34A),
      ),
      SubscriptionPaymentMethodDefinition(
        id: SubscriptionPaymentMethodId.other,
        icon: Icons.more_horiz,
        color: Color(0xFF64748B),
      ),
    ];

SubscriptionPaymentFlowIntent resolveSubscriptionFlowIntent({
  required String? currentPlanId,
  required String? selectedPlanId,
}) {
  if (currentPlanId != null &&
      selectedPlanId != null &&
      currentPlanId == selectedPlanId) {
    return SubscriptionPaymentFlowIntent.renewal;
  }
  return SubscriptionPaymentFlowIntent.upgrade;
}

String subscriptionPaymentMethodLabel(
  AppLocalizations l10n,
  SubscriptionPaymentMethodId method,
) {
  return switch (method) {
    SubscriptionPaymentMethodId.bankTransfer =>
      l10n.subscriptionPaymentMethodBankTransfer,
    SubscriptionPaymentMethodId.mobileMoney =>
      l10n.subscriptionPaymentMethodMobileMoney,
    SubscriptionPaymentMethodId.creditCard =>
      l10n.subscriptionPaymentMethodCreditCard,
    SubscriptionPaymentMethodId.debitCard =>
      l10n.subscriptionPaymentMethodDebitCard,
    SubscriptionPaymentMethodId.cash => l10n.subscriptionPaymentMethodCash,
    SubscriptionPaymentMethodId.other => l10n.subscriptionPaymentMethodOther,
  };
}

String mobileMoneyProviderLabel(
  AppLocalizations l10n,
  MobileMoneyProviderId provider,
) {
  return switch (provider) {
    MobileMoneyProviderId.mtn => l10n.subscriptionMobileMoneyMtn,
    MobileMoneyProviderId.airtel => l10n.subscriptionMobileMoneyAirtel,
    MobileMoneyProviderId.mpesa => l10n.subscriptionMobileMoneyMpesa,
    MobileMoneyProviderId.vodacom => l10n.subscriptionMobileMoneyVodacom,
    MobileMoneyProviderId.tigo => l10n.subscriptionMobileMoneyTigo,
    MobileMoneyProviderId.orange => l10n.subscriptionMobileMoneyOrange,
    MobileMoneyProviderId.zamtel => l10n.subscriptionMobileMoneyZamtel,
    MobileMoneyProviderId.government => l10n.subscriptionMobileMoneyGovernment,
  };
}

bool subscriptionPaymentMethodRequiresProof(
  SubscriptionPaymentMethodId method,
) {
  return switch (method) {
    SubscriptionPaymentMethodId.bankTransfer => true,
    SubscriptionPaymentMethodId.mobileMoney => true,
    SubscriptionPaymentMethodId.cash => true,
    SubscriptionPaymentMethodId.creditCard => false,
    SubscriptionPaymentMethodId.debitCard => false,
    SubscriptionPaymentMethodId.other => false,
  };
}
