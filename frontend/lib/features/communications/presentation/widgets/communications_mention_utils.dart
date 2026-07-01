import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';

final RegExp _mentionTokenPattern = RegExp(r'@\[([^:\]]+):([^\]]+)\]');

String buildMentionToken(CommunicationStaffOption staff) {
  return '@[${staff.id}:${staff.label}]';
}

List<String> extractMentionedUserIds(String content) {
  return _mentionTokenPattern
      .allMatches(content)
      .map((RegExpMatch match) => match.group(1) ?? '')
      .where((String id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String displayMessageContent(String content) {
  return content.replaceAllMapped(
    _mentionTokenPattern,
    (Match match) => '@${match.group(2) ?? ''}',
  );
}

List<InlineSpan> buildMentionTextSpans({
  required String content,
  required TextStyle baseStyle,
  required TextStyle mentionStyle,
}) {
  final List<InlineSpan> spans = <InlineSpan>[];
  int cursor = 0;
  for (final Match match in _mentionTokenPattern.allMatches(content)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(
          text: content.substring(cursor, match.start),
          style: baseStyle,
        ),
      );
    }
    spans.add(TextSpan(text: '@${match.group(2) ?? ''}', style: mentionStyle));
    cursor = match.end;
  }
  if (cursor < content.length) {
    spans.add(TextSpan(text: content.substring(cursor), style: baseStyle));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: displayMessageContent(content), style: baseStyle));
  }
  return spans;
}

MentionQuery? parseActiveMentionQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) {
    return null;
  }
  final String beforeCursor = text.substring(0, cursor);
  final int atIndex = beforeCursor.lastIndexOf('@');
  if (atIndex < 0) {
    return null;
  }
  if (atIndex > 0 && !RegExp(r'\s').hasMatch(beforeCursor[atIndex - 1])) {
    return null;
  }
  final String query = beforeCursor.substring(atIndex + 1);
  if (query.contains(' ') || query.contains('[')) {
    return null;
  }
  return MentionQuery(startIndex: atIndex, query: query);
}

@immutable
final class MentionQuery {
  const MentionQuery({required this.startIndex, required this.query});

  final int startIndex;
  final String query;
}
