import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_method_selector.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_payment_methods.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('payment method selector renders compact chips', (
    WidgetTester tester,
  ) async {
    SubscriptionPaymentMethodId? selected =
        SubscriptionPaymentMethodId.mobileMoney;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SubscriptionPaymentMethodSelector(
            selected: selected,
            onSelected: (SubscriptionPaymentMethodId method) {
              selected = method;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionPaymentMethodSelector), findsOneWidget);
    expect(find.byIcon(Icons.phone_android_outlined), findsOneWidget);
    expect(find.text('Mobile money'), findsOneWidget);
  });
}
