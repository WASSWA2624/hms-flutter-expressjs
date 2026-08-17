import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_shell_layout.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_logo.dart';

const Size _phoneSize = Size(390, 780);
const Size _tabletSize = Size(768, 1024);
const Size _desktopSize = Size(1280, 800);

void main() {
  group('brand lockup', () {
    for (final (String label, Size size) in <(String, Size)>[
      ('desktop', _desktopSize),
      ('tablet', _tabletSize),
      ('phone', _phoneSize),
    ]) {
      testWidgets('logo matches the app name cap height on $label', (
        WidgetTester tester,
      ) async {
        await _pumpShell(tester, size);

        final String appTitle = tester
            .element(find.byType(AppLogo))
            .l10n
            .appTitle;
        final Text title = tester.widget<Text>(find.text(appTitle));

        // The title pins `height: 1.0`, so its line box equals its font size.
        expect(title.style?.height, 1.0);

        final double logoHeight = tester.getSize(find.byType(AppLogo)).height;
        // Optical match: the mark is the height of the capitals, not the height
        // of the em box those capitals sit inside.
        expect(
          logoHeight,
          closeTo(
            AppLogo.markHeightForFontSize(title.style!.fontSize!),
            0.01,
          ),
        );
        expect(logoHeight, lessThan(title.style!.fontSize!));
      });
    }

    testWidgets('logo bottom rests on the app name baseline', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _desktopSize);

      final String appTitle = tester.element(find.byType(AppLogo)).l10n.appTitle;
      final Text title = tester.widget<Text>(find.text(appTitle));
      final double fontSize = title.style!.fontSize!;

      final Rect logoRect = tester.getRect(find.byType(AppLogo));
      final Rect titleRect = tester.getRect(find.text(appTitle));

      // `height: 1.0` makes the title's rect its line box, so the baseline sits
      // a known fraction below its top.
      expect(titleRect.height, closeTo(fontSize, 0.01));
      final double baselineY = titleRect.top + fontSize * AppLogo.baselineRatio;

      expect(logoRect.bottom, closeTo(baselineY, 0.01));
      expect(
        logoRect.top,
        closeTo(baselineY - AppLogo.markHeightForFontSize(fontSize), 0.01),
      );
    });
  });

  group('panel geometry', () {
    testWidgets('panel fills the viewport height on phone', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _phoneSize);

      expect(_panelRect(tester).height, closeTo(_phoneSize.height, 0.5));
    });

    testWidgets('panel spans the full width on phone', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, _phoneSize);

      expect(_panelRect(tester).width, closeTo(_phoneSize.width, 0.5));
    });

    for (final (String label, Size size, double expectedWidth)
        in <(String, Size, double)>[
      ('tablet', _tabletSize, 480),
      ('desktop', _desktopSize, 520),
    ]) {
      testWidgets('panel is a centred column of $expectedWidth on $label', (
        WidgetTester tester,
      ) async {
        await _pumpShell(tester, size);

        final Rect panel = _panelRect(tester);
        expect(panel.width, closeTo(expectedWidth, 0.5));
        expect(panel.width, lessThan(size.width));
        expect(panel.height, closeTo(size.height, 0.5));
        // Centred over the backdrop.
        expect(panel.center.dx, closeTo(size.width / 2, 0.5));
      });
    }
  });

  group('form placement', () {
    testWidgets('short content is centred in the remaining height', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        _desktopSize,
        child: const SizedBox(key: Key('form'), height: 120),
      );

      final Rect form = tester.getRect(find.byKey(const Key('form')));
      // Midpoint of the space under the branding.
      final double regionCentre =
          (_formRegionTop(tester) + _desktopSize.height) / 2;

      expect(form.center.dy, closeTo(regionCentre, 1.0));
    });

    testWidgets('tall content anchors to the top and scrolls', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        _desktopSize,
        child: const SizedBox(key: Key('form'), height: 2000),
      );

      final Rect form = tester.getRect(find.byKey(const Key('form')));

      // No leading gap: the form starts immediately under the branding.
      expect(form.top, closeTo(_formRegionTop(tester), 1.0));

      // And the overflow is reachable by scrolling.
      await tester.drag(
        find.byKey(AuthShellLayout.formRegionKey),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('form'))).top,
        lessThan(form.top),
      );
    });
  });
}

/// Top edge of the scrollable form region, i.e. the bottom of the brand band.
double _formRegionTop(WidgetTester tester) {
  return tester.getRect(find.byKey(AuthShellLayout.formRegionKey)).top;
}

/// The surface that holds branding and form.
Rect _panelRect(WidgetTester tester) {
  return tester.getRect(find.byKey(AuthShellLayout.panelKey));
}

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  Widget child = const SizedBox.shrink(),
}) async {
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
        home: AuthShellLayout(child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
