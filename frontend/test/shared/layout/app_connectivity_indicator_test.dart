import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/shared/layout/app_connectivity_indicator.dart';

void main() {
  group('AppConnectivityIndicator', () {
    Future<void> pumpIndicator(
      WidgetTester tester, {
      required AppConnectivityStatus status,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppConnectivityIndicator(
              status: status,
              onlineLabel: 'Online',
              offlineLabel: 'Offline',
            ),
          ),
        ),
      );
    }

    testWidgets('shows green wifi icon when online', (
      WidgetTester tester,
    ) async {
      await pumpIndicator(tester, status: AppConnectivityStatus.online);

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      final ThemeData theme = AppTheme.light;

      expect(icon.icon, Icons.wifi);
      expect(icon.color, theme.statusColors.success);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows red wifi-off icon when offline', (
      WidgetTester tester,
    ) async {
      await pumpIndicator(tester, status: AppConnectivityStatus.offline);

      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      final ThemeData theme = AppTheme.light;

      expect(icon.icon, Icons.wifi_off_outlined);
      expect(icon.color, theme.statusColors.error);
      expect(tester.takeException(), isNull);
    });
  });
}
