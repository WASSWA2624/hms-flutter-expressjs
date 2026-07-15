import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_compose_bar.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_formatters.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_manage_members_dialog.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_mention_utils.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class CommunicationsThreadView extends ConsumerStatefulWidget {
  const CommunicationsThreadView({
    required this.conversation,
    required this.canWrite,
    required this.isSaving,
    this.isLoadingThread = false,
    this.composeAutofocus = false,
    this.onComposeAutofocusHandled,
    this.showBackButton = false,
    this.onBack,
    super.key,
  });

  final CommunicationsConversation conversation;
  final bool canWrite;
  final bool isSaving;
  final bool isLoadingThread;
  final bool composeAutofocus;
  final VoidCallback? onComposeAutofocusHandled;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  ConsumerState<CommunicationsThreadView> createState() =>
      _CommunicationsThreadViewState();
}

class _CommunicationsThreadViewState
    extends ConsumerState<CommunicationsThreadView> {
  final ScrollController _scrollController = ScrollController();
  CommunicationMessage? _replyToMessage;

  @override
  void didUpdateWidget(covariant CommunicationsThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _replyToMessage = null;
      _scrollToBottom();
    } else if (oldWidget.conversation.messages.length !=
        widget.conversation.messages.length) {
      _scrollToBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CommunicationsConversation conversation = widget.conversation;
    final String? currentUserId = ref
        .watch(sessionStateProvider)
        .session
        ?.user
        ?.id;
    final String title = communicationsConversationTitle(conversation);
    final bool isEmpty = conversation.messages.isEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ThreadHeader(
            conversation: conversation,
            title: title,
            canWrite: widget.canWrite,
            isSaving: widget.isSaving,
            showBackButton: widget.showBackButton,
            onBack: widget.onBack,
          ),
          Expanded(
            child: widget.isLoadingThread
                ? const Center(child: CircularProgressIndicator())
                : isEmpty
                ? Center(
                    child: AppMessagePanel(
                      message: widget.canWrite
                          ? context.l10n.communicationsFirstMessageHint
                          : context.l10n.communicationsNoMessagesBody,
                      icon: Icons.forum_outlined,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(theme.spacing.md),
                    itemCount: conversation.messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CommunicationMessage message =
                          conversation.messages[index];
                      final bool isOwn =
                          message.senderUserId != null &&
                          message.senderUserId == currentUserId;
                      return _MessageBubble(
                        message: message,
                        isOwn: isOwn,
                        isGroup: conversation.isGroup,
                        participants: conversation.participants,
                        currentUserId: currentUserId,
                        onReply: widget.canWrite
                            ? () => setState(() => _replyToMessage = message)
                            : null,
                      );
                    },
                  ),
          ),
          CommunicationsComposeBar(
            canWrite: widget.canWrite,
            isSaving: widget.isSaving,
            replyToMessage: _replyToMessage,
            autofocus: widget.composeAutofocus,
            onAutofocusHandled: widget.onComposeAutofocusHandled,
            readOnlyBanner: context.l10n.communicationsComposeReadOnlyBody,
            onCancelReply: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }
}

class _ThreadHeader extends ConsumerWidget {
  const _ThreadHeader({
    required this.conversation,
    required this.title,
    required this.canWrite,
    required this.isSaving,
    required this.showBackButton,
    this.onBack,
  });

  final CommunicationsConversation conversation;
  final String title;
  final bool canWrite;
  final bool isSaving;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        children: <Widget>[
          if (showBackButton)
            AppButton(
              iconOnly: true,
              icon: Icons.arrow_back,
              label: context.l10n.communicationsBackToInboxAction,
              semanticLabel: context.l10n.communicationsBackToInboxAction,
              onPressed: onBack,
            ),
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
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (conversation.isGroup)
                  Text(
                    context.l10n.communicationsGroupMembersLabel(
                      conversation.participants.length,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (canWrite)
            PopupMenuButton<String>(
              tooltip: context.l10n.communicationsThreadMenuAction,
              onSelected: (String value) =>
                  _handleMenu(context, ref, controller, value),
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'favorite',
                    child: Text(
                      conversation.isFavorite
                          ? context.l10n.communicationsUnfavoriteAction
                          : context.l10n.communicationsFavoriteAction,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'flag',
                    child: Text(
                      conversation.isFlagged
                          ? context.l10n.communicationsUnflagAction
                          : context.l10n.communicationsFlagAction,
                    ),
                  ),
                  if (conversation.unread)
                    PopupMenuItem<String>(
                      value: 'read',
                      child: Text(context.l10n.communicationsMarkReadAction),
                    ),
                  PopupMenuItem<String>(
                    value: conversation.archived ? 'unarchive' : 'archive',
                    child: Text(
                      conversation.archived
                          ? context.l10n.communicationsUnarchiveAction
                          : context.l10n.communicationsArchiveAction,
                    ),
                  ),
                  if (conversation.isGroup)
                    PopupMenuItem<String>(
                      value: 'members',
                      child: Text(
                        context.l10n.communicationsManageMembersAction,
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    CommunicationsWorkspaceController controller,
    String value,
  ) async {
    switch (value) {
      case 'favorite':
        await controller.toggleSelectedConversationFavorite();
      case 'flag':
        await controller.toggleSelectedConversationFlag();
      case 'read':
        await controller.markSelectedConversationRead();
      case 'archive':
        await controller.archiveSelectedConversation();
      case 'unarchive':
        await controller.unarchiveSelectedConversation();
      case 'members':
        await showCommunicationsManageMembersDialogImpl(
          context,
          ref,
          conversation: conversation,
        );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.isGroup,
    required this.participants,
    required this.currentUserId,
    this.onReply,
  });

  final CommunicationMessage message;
  final bool isOwn;
  final bool isGroup;
  final List<CommunicationsParticipant> participants;
  final String? currentUserId;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Alignment alignment = isOwn
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final Color bubbleColor = isOwn
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final bool isRead = communicationsMessageIsReadByOthers(
      message: message,
      participants: participants,
      currentUserId: currentUserId,
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: theme.spacing.sm),
          child: Column(
            crossAxisAlignment: isOwn
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              if (isGroup && !isOwn)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.xs),
                  child: Text(
                    message.sender?.displayName ??
                        context.l10n.profileUnknownValue,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              Material(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(theme.radius.md),
                child: InkWell(
                  onLongPress: onReply,
                  borderRadius: BorderRadius.circular(theme.radius.md),
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (message.replyToMessage != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: theme.spacing.xs),
                            child: Text(
                              displayMessageContent(
                                message.replyToMessage!.content ?? '',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if ((message.content ?? '').trim().isNotEmpty)
                          RichText(
                            text: TextSpan(
                              children: buildMentionTextSpans(
                                content: message.content ?? '',
                                baseStyle: theme.textTheme.bodyMedium!,
                                mentionStyle: theme.textTheme.bodyMedium!
                                    .copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        if (message.attachments.isNotEmpty)
                          ...message.attachments.map(
                            (CommunicationAttachment attachment) => Padding(
                              padding: EdgeInsets.only(top: theme.spacing.xs),
                              child: _AttachmentTile(attachment: attachment),
                            ),
                          ),
                        SizedBox(height: theme.spacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Tooltip(
                              message: communicationsAbsoluteTime(
                                context,
                                message.sentAt,
                              ),
                              child: Text(
                                communicationsRelativeTime(
                                  context,
                                  message.sentAt,
                                ),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            if (isOwn) ...<Widget>[
                              SizedBox(width: theme.spacing.xs),
                              Icon(
                                isRead ? Icons.done_all : Icons.check,
                                size: 14,
                                color: isRead
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final CommunicationAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isImage =
        (attachment.contentType ?? '').startsWith('image/') ||
        attachment.attachmentKind?.toUpperCase() == 'IMAGE';

    if (isImage && attachment.publicUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Image.network(
          attachment.publicUrl!,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          cacheHeight: 280,
          errorBuilder: (_, _, _) => _fileRow(context),
        ),
      );
    }
    return _fileRow(context);
  }

  Widget _fileRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.attach_file, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
