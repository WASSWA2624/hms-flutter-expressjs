import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_phone_field.dart';

/// Ascension Island — a three-digit code, the widest shape in the catalog and
/// the case the old fixed-width country segment clipped behind an ellipsis.
const String _longCode = '+247';
const String _shortCode = '+1';

void main() {
  for (final double width in <double>[320, 360, 390, 768, 1024, 1440]) {
    testWidgets('renders the full dialling code at ${width.toInt()}px', (
      WidgetTester tester,
    ) async {
      await _pumpField(tester, width: width, initialCountryCode: _longCode);

      final Finder codeFinder = _countryCodeText(_longCode);
      final Text codeText = tester.widget<Text>(codeFinder);
      // An ellipsized or wrapped code is unreadable, so neither is allowed.
      expect(codeText.overflow, isNot(TextOverflow.ellipsis));
      expect(codeText.softWrap, isFalse);

      // And it is laid out at its unclipped intrinsic width, inside a segment
      // wide enough to hold it.
      final double textWidth = tester.getSize(codeFinder).width;
      expect(textWidth, greaterThan(0));
      expect(_countrySegmentWidth(tester), greaterThanOrEqualTo(textWidth));
      expect(
        tester.takeException(),
        isNull,
        reason: 'the row must not overflow at $width px',
      );
    });
  }

  testWidgets('short codes keep the segment at its minimum width', (
    WidgetTester tester,
  ) async {
    await _pumpField(tester, width: 320, initialCountryCode: _shortCode);
    final double shortSegment = _countrySegmentWidth(tester);

    await _pumpField(tester, width: 320, initialCountryCode: _longCode);
    final double longSegment = _countrySegmentWidth(tester);

    // The long code grows the segment; the short one is floored rather than
    // collapsing to its intrinsic width, so the control does not jitter.
    expect(longSegment, greaterThanOrEqualTo(shortSegment));
    expect(shortSegment, greaterThan(60));
  });

  testWidgets('control stays within the shared input height', (
    WidgetTester tester,
  ) async {
    await _pumpField(tester, width: 320, initialCountryCode: _longCode);

    final ThemeData theme = AppTheme.light;
    final double expected =
        theme.inputDecorationTheme.constraints?.minHeight ?? 48;
    final Size fieldSize = tester.getSize(find.byType(AppPhoneField));

    expect(fieldSize.height, lessThanOrEqualTo(expected + 24));
  });

  testWidgets('national digits still enter and validate', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpField(
      tester,
      width: 320,
      initialCountryCode: '+256',
      controller: controller,
    );

    await tester.enterText(find.byType(TextField).last, '772123456');
    await tester.pump();

    expect(controller.text, startsWith('+256'));
    expect(controller.text.replaceAll(RegExp(r'\D'), ''), contains('772123456'));
  });
}

/// The dialling-code label inside the country button.
Finder _countryCodeText(String code) =>
    find.descendant(of: find.byType(InkWell), matching: find.text(code)).first;

/// Tappable width of the country segment.
double _countrySegmentWidth(WidgetTester tester) {
  return tester.getSize(find.byType(InkWell).first).width;
}

Future<void> _pumpField(
  WidgetTester tester, {
  required double width,
  required String initialCountryCode,
  TextEditingController? controller,
}) async {
  final TextEditingController fieldController =
      controller ?? TextEditingController();
  if (controller == null) {
    addTearDown(fieldController.dispose);
  }

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppPhoneField(
            controller: fieldController,
            initialCountryCode: initialCountryCode,
            labelText: 'Phone',
            countryLabelText: 'Country code',
            countrySearchLabelText: 'Search',
            countryNoResultsText: 'No results',
            numberLabelText: 'Phone number',
            invalidPhoneMessage: 'Invalid phone number',
            enableSpeechToText: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
