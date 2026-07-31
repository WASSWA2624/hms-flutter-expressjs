import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_rich_text_editor.dart';

void main() {
  group('AppRichTextMarkup', () {
    test('wrapSelection inserts markers around the selection', () {
      final TextEditingController controller = TextEditingController(
        text: 'Hello world',
      );
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);

      AppRichTextMarkup.wrapSelection(
        controller,
        prefix: '**',
        suffix: '**',
      );

      expect(controller.text, 'Hello **world**');
      expect(controller.selection.baseOffset, 15);
    });

    test('toTextSpan renders bold italic and underline', () {
      final TextSpan span = AppRichTextMarkup.toTextSpan(
        '**bold** *italic* __under__',
        const TextStyle(),
      );

      expect(span.toPlainText(), 'bold italic under');
    });

    test('plainText strips formatting markers', () {
      expect(
        AppRichTextMarkup.plainText('**bold** and *italic*'),
        'bold and italic',
      );
    });

    test('toggleLinePrefix adds and removes bullet prefix', () {
      final TextEditingController controller = TextEditingController(
        text: 'Item one',
      );
      controller.selection = const TextSelection.collapsed(offset: 4);

      AppRichTextMarkup.toggleLinePrefix(controller, prefix: '- ');
      expect(controller.text, '- Item one');

      AppRichTextMarkup.toggleLinePrefix(controller, prefix: '- ');
      expect(controller.text, 'Item one');
    });
  });
}
