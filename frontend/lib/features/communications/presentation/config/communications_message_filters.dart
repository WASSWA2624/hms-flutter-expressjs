import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

typedef CommunicationsMessageFilterPredicate =
    bool Function(
      CommunicationsConversation conversation,
      String? currentUserId,
    );

@immutable
final class CommunicationsMessageFilter {
  const CommunicationsMessageFilter({
    required this.id,
    required this.labelBuilder,
    this.serverFilter,
    this.unreadOnly = false,
    this.clientOnly = false,
    this.clientPredicate,
    this.icon,
  });

  final String id;
  final String Function(AppLocalizations l10n) labelBuilder;
  final String? serverFilter;
  final bool unreadOnly;
  final bool clientOnly;
  final CommunicationsMessageFilterPredicate? clientPredicate;
  final IconData? icon;
}

const String kCommunicationsMessageFilterAll = 'all';
const String kCommunicationsMessageFilterUnread = 'unread';
const String kCommunicationsMessageFilterSent = 'sent';
const String kCommunicationsMessageFilterRead = 'read';
const String kCommunicationsMessageFilterFavorites = 'favorites';
const String kCommunicationsMessageFilterFlagged = 'flagged';
const String kCommunicationsMessageFilterArchived = 'archived';

const List<CommunicationsMessageFilter> kCommunicationsMessageFilters =
    <CommunicationsMessageFilter>[
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterAll,
        labelBuilder: _allLabel,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterUnread,
        labelBuilder: _unreadLabel,
        serverFilter: 'UNREAD',
        unreadOnly: true,
        clientPredicate: _unreadPredicate,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterSent,
        labelBuilder: _sentLabel,
        serverFilter: 'SENT',
        clientPredicate: _sentPredicate,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterRead,
        labelBuilder: _readLabel,
        serverFilter: 'READ',
        clientPredicate: _readPredicate,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterFavorites,
        labelBuilder: _favoritesLabel,
        serverFilter: 'FAVORITES',
        clientPredicate: _favoritesPredicate,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterFlagged,
        labelBuilder: _flaggedLabel,
        serverFilter: 'FLAGGED',
        clientPredicate: _flaggedPredicate,
      ),
      CommunicationsMessageFilter(
        id: kCommunicationsMessageFilterArchived,
        labelBuilder: _archivedLabel,
        serverFilter: 'ARCHIVED',
        clientPredicate: _archivedPredicate,
      ),
    ];

CommunicationsMessageFilter communicationsMessageFilterById(String id) {
  return kCommunicationsMessageFilters.firstWhere(
    (CommunicationsMessageFilter filter) => filter.id == id,
    orElse: () => kCommunicationsMessageFilters.first,
  );
}

String communicationsMessageFilterIdForQuery(
  CommunicationsWorkspaceQuery query,
) {
  if (query.unreadOnly) {
    return kCommunicationsMessageFilterUnread;
  }
  final String? filter = query.filter?.trim().toUpperCase();
  return switch (filter) {
    'UNREAD' => kCommunicationsMessageFilterUnread,
    'SENT' => kCommunicationsMessageFilterSent,
    'READ' => kCommunicationsMessageFilterRead,
    'FAVORITES' => kCommunicationsMessageFilterFavorites,
    'FLAGGED' => kCommunicationsMessageFilterFlagged,
    'ARCHIVED' => kCommunicationsMessageFilterArchived,
    _ => kCommunicationsMessageFilterAll,
  };
}

CommunicationsWorkspaceQuery communicationsQueryForMessageFilter(
  CommunicationsWorkspaceQuery query,
  CommunicationsMessageFilter filter,
) {
  return query.copyWith(
    unreadOnly: filter.unreadOnly ? true : null,
    clearUnreadOnly: !filter.unreadOnly,
    filter: filter.serverFilter,
    clearFilter: filter.serverFilter == null,
    pageRequest: query.pageRequest.first(),
  );
}

List<CommunicationsConversation> applyCommunicationsMessageFilter(
  List<CommunicationsConversation> conversations,
  CommunicationsMessageFilter filter,
  String? currentUserId, {
  required bool useClientFallback,
}) {
  if (filter.id == kCommunicationsMessageFilterAll) {
    return conversations;
  }
  if (!useClientFallback) {
    return conversations;
  }
  final CommunicationsMessageFilterPredicate? predicate =
      filter.clientPredicate;
  if (predicate == null) {
    return conversations;
  }
  return conversations
      .where(
        (CommunicationsConversation conversation) =>
            predicate(conversation, currentUserId),
      )
      .toList(growable: false);
}

bool communicationsMessageFilterUsesClientFallback(
  CommunicationsMessageFilter filter,
) {
  return filter.clientOnly;
}

String _allLabel(AppLocalizations l10n) => l10n.communicationsAllFilterLabel;
String _unreadLabel(AppLocalizations l10n) =>
    l10n.communicationsUnreadFilterLabel;
String _sentLabel(AppLocalizations l10n) => l10n.communicationsSentFilterLabel;
String _readLabel(AppLocalizations l10n) => l10n.communicationsReadFilterLabel;
String _favoritesLabel(AppLocalizations l10n) =>
    l10n.communicationsFavoritesFilterLabel;
String _flaggedLabel(AppLocalizations l10n) =>
    l10n.communicationsFlaggedFilterLabel;
String _archivedLabel(AppLocalizations l10n) =>
    l10n.communicationsArchivedFilterLabel;

bool _unreadPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) => conversation.unread;

bool _sentPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) {
  if (currentUserId == null || currentUserId.isEmpty) {
    return false;
  }
  return conversation.lastMessage?.senderUserId == currentUserId;
}

bool _readPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) => !conversation.unread;

bool _favoritesPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) => conversation.isFavorite;

bool _flaggedPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) => conversation.isFlagged;

bool _archivedPredicate(
  CommunicationsConversation conversation,
  String? currentUserId,
) => conversation.archived;
