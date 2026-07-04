import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/utils/app_dialog_title.dart';

void main() {
  group('toDialogTitleUppercase', () {
    test('converts text to uppercase', () {
      expect(toDialogTitleUppercase('Lab Result Entry'), 'LAB RESULT ENTRY');
      expect(toDialogTitleUppercase('confirm action'), 'CONFIRM ACTION');
      expect(toDialogTitleUppercase('Order LAB0000006 Details'),
          'ORDER LAB0000006 DETAILS');
    });

    test('preserves empty and whitespace-only values', () {
      expect(toDialogTitleUppercase(''), '');
      expect(toDialogTitleUppercase('   '), '   ');
    });
  });

  group('normalizeDialogTitleWidget', () {
    testWidgets('uppercases plain Text titles', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: normalizeDialogTitleWidget(const Text('Edit record')),
        ),
      );

      expect(find.text('EDIT RECORD'), findsOneWidget);
    });

    testWidgets('uppercases simple TextSpan titles', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: normalizeDialogTitleWidget(
            const Text.rich(TextSpan(text: 'Lab result entry')),
          ),
        ),
      );

      expect(find.text('LAB RESULT ENTRY'), findsOneWidget);
    });

    testWidgets('leaves non-Text titles unchanged', (WidgetTester tester) async {
      const Widget customTitle = SizedBox(key: Key('custom-title'));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: normalizeDialogTitleWidget(customTitle),
        ),
      );

      expect(find.byKey(const Key('custom-title')), findsOneWidget);
    });

    testWidgets('leaves complex TextSpan titles unchanged',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: normalizeDialogTitleWidget(
            const Text.rich(
              TextSpan(
                text: 'Order ',
                children: <InlineSpan>[
                  TextSpan(text: 'LAB0000006'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Order '), findsOneWidget);
      expect(find.text('ORDER LAB0000006'), findsNothing);
    });
  });
}
