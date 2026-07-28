import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/config/communications_message_filters.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_formatters.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class CommunicationsConversationList extends ConsumerWidget {
  const CommunicationsConversationList({
    required this.state,
    required this.searchController,
    required this.canWrite,
    super.key,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    final List<CommunicationsConversation> conversations =
        state.conversations.items;
    final String activeFilterId = communicationsMessageFilterIdForQuery(
      state.query,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSearchBar(
          controller: searchController,
          hintText: context.l10n.communicationsSearchHint,
          semanticLabel: context.l10n.communicationsSearchSemanticLabel,
          clearLabel: context.l10n.communicationsClearSearchAction,
          onSubmitted: controller.applySearch,
          onClear: () => controller.applySearch(''),
        ),
        SizedBox(height: theme.spacing.sm),
        AppWorkspaceOptionToggle<String>(
          value: activeFilterId,
          options: kCommunicationsMessageFilters
              .map(
                (CommunicationsMessageFilter filter) =>
                    AppWorkspaceOptionToggleOption<String>(
                      value: filter.id,
                      label: filter.labelBuilder(context.l10n),
                      icon: filter.icon,
                    ),
              )
              .toList(growable: false),
          onChanged: controller.applyMessageFilter,
        ),
        if (state.usesClientMessageFilter)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Text(
              context.l10n.communicationsClientFilterNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(height: theme.spacing.sm),
        Expanded(
          child: state.isRefreshingConversations && conversations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : conversations.isEmpty
              ? AppWorkspaceStatePanel.empty(
                  title: context.l10n.communicationsNoConversationsTitle,
                  body: context.l10n.communicationsNoConversationsBody,
                  icon: Icons.forum_outlined,
                )
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final CommunicationsConversation item =
                        conversations[index];
                    final bool selected =
                        state.selectedConversation?.id == item.id;
                    return _ConversationRow(
                      conversation: item,
                      selected: selected,
                      onTap: () => controller.selectConversation(item),
                    );
                  },
                ),
        ),
        if (state.conversations.totalItemCount != null &&
            state.conversations.totalItemCount! >
                state.conversations.items.length)
          Align(
            child: AppButton.tertiary(
              label: context.l10n.communicationsLoadMoreAction,
              onPressed: () =>
                  controller.changePage(state.conversations.request.next()),
            ),
          ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final CommunicationsConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = communicationsConversationTitle(conversation);

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.35)
          : conversation.unread
          ? colors.surfaceContainerHighest.withValues(alpha: 0.45)
          : colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                child: Text(
                  communicationsConversationAvatarLabel(
                    conversation,
                    displayTitle: title,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: conversation.unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          communicationsRelativeTime(
                            context,
                            conversation.lastMessageAt,
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      conversation.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Column(
                children: <Widget>[
                  if (conversation.isFavorite)
                    Icon(Icons.star, size: 16, color: colors.tertiary),
                  if (conversation.isFlagged)
                    Icon(Icons.flag, size: 16, color: colors.error),
                  if (conversation.unread)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
