import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

void main() {
  for (final (String label, Size size) in <(String, Size)>[
    ('desktop', Size(1280, 800)),
    ('phone', Size(390, 780)),
  ]) {
    testWidgets('brand header logo matches the app name height on $label', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, size);

      final String appTitle = tester.element(find.byType(AppLogo)).l10n.appTitle;
      final Text title = tester.widget<Text>(find.text(appTitle));

      // The title pins `height: 1.0`, so its line box equals its font size.
      expect(title.style?.height, 1.0);

      final double logoHeight = tester.getSize(find.byType(AppLogo)).height;
      expect(logoHeight, title.style?.fontSize);
    });
  }
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const AuthShellLayout(child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
