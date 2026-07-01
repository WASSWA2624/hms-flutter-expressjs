import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/core/utils/person_display_name.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

String communicationsRelativeTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  final DateTime local = value.toLocal();
  final DateTime now = DateTime.now();
  final Duration delta = now.difference(local);
  if (delta.inMinutes < 1) {
    return context.l10n.communicationsJustNowLabel;
  }
  if (delta.inHours < 1) {
    return context.l10n.communicationsMinutesAgoLabel(delta.inMinutes);
  }
  if (delta.inDays < 1) {
    return context.l10n.communicationsHoursAgoLabel(delta.inHours);
  }
  if (delta.inDays < 7) {
    return context.l10n.communicationsDaysAgoLabel(delta.inDays);
  }
  return AppFormatters.dateTime(local, Localizations.localeOf(context));
}

String communicationsAbsoluteTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

bool communicationsMessageIsReadByOthers({
  required CommunicationMessage message,
  required List<CommunicationsParticipant> participants,
  required String? currentUserId,
}) {
  if (currentUserId == null || message.senderUserId != currentUserId) {
    return false;
  }
  for (final CommunicationsParticipant participant in participants) {
    if (participant.userId == currentUserId) {
      continue;
    }
    final String? lastReadId = participant.lastReadMessageId;
    if (lastReadId == null || lastReadId.isEmpty) {
      return false;
    }
    if (lastReadId != message.id) {
      return false;
    }
  }
  return participants.any(
    (CommunicationsParticipant participant) =>
        participant.userId != currentUserId,
  );
}

String communicationsConversationTitle(CommunicationsConversation conversation) {
  final String? subject = conversation.subject?.trim();
  if (subject != null && subject.isNotEmpty) {
    return subject;
  }
  final String title = conversation.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return conversation.id;
}

String communicationsConversationAvatarLabel(
  CommunicationsConversation item, {
  String? displayTitle,
}) {
  return personInitials(displayTitle ?? communicationsConversationTitle(item));
}

String communicationsParticipantLabel(CommunicationsParticipant participant) {
  final CommunicationUser? user = participant.user;
  if (user != null) {
    return user.displayName;
  }
  return participant.userId;
}
