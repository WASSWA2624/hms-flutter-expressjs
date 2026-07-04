import 'package:flutter/widgets.dart';

/// Normalizes dialog titles to uppercase for consistent header styling.
String toDialogTitleUppercase(String value) {
  if (value.trim().isEmpty) {
    return value;
  }

  return value.toUpperCase();
}

/// Applies [toDialogTitleUppercase] to plain [Text] dialog titles.
Widget normalizeDialogTitleWidget(Widget title) {
  if (title is! Text) {
    return title;
  }

  final InlineSpan? textSpan = title.textSpan;
  if (textSpan == null) {
    final String? data = title.data;
    if (data == null) {
      return title;
    }
    return _copyText(title, toDialogTitleUppercase(data));
  }

  if (textSpan is! TextSpan ||
      textSpan.children != null ||
      (textSpan.text ?? '').isEmpty) {
    return title;
  }

  return _copyText(title, toDialogTitleUppercase(textSpan.text!));
}

Text _copyText(Text source, String data) {
  return Text(
    data,
    style: source.style,
    strutStyle: source.strutStyle,
    textAlign: source.textAlign,
    textDirection: source.textDirection,
    locale: source.locale,
    softWrap: source.softWrap,
    overflow: source.overflow,
    textScaler: source.textScaler,
    maxLines: source.maxLines,
    semanticsLabel: source.semanticsLabel,
    textWidthBasis: source.textWidthBasis,
    textHeightBehavior: source.textHeightBehavior,
    selectionColor: source.selectionColor,
  );
}
