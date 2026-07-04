import 'package:flutter/widgets.dart';

/// Normalizes dialog titles to Title Case while preserving mixed-case tokens and IDs.
String toDialogTitleCase(String value) {
  if (value.trim().isEmpty) {
    return value;
  }

  return value.splitMapJoin(
    RegExp(r'(\s+)'),
    onMatch: (Match match) => match.group(0)!,
    onNonMatch: _titleCaseToken,
  );
}

String _titleCaseToken(String token) {
  if (token.isEmpty) {
    return token;
  }

  if (RegExp(r'\d').hasMatch(token)) {
    return token;
  }

  if (_hasMixedCase(token)) {
    return token;
  }

  if (token.length == 1) {
    return token.toUpperCase();
  }

  return '${token[0].toUpperCase()}${token.substring(1).toLowerCase()}';
}

bool _hasMixedCase(String token) {
  final bool hasUpper = token.contains(RegExp(r'[A-Z]'));
  final bool hasLower = token.contains(RegExp(r'[a-z]'));
  return hasUpper && hasLower;
}

/// Applies [toDialogTitleCase] to plain [Text] dialog titles.
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
    return _copyText(title, toDialogTitleCase(data));
  }

  if (textSpan is! TextSpan ||
      textSpan.children != null ||
      (textSpan.text ?? '').isEmpty) {
    return title;
  }

  return _copyText(title, toDialogTitleCase(textSpan.text!));
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
