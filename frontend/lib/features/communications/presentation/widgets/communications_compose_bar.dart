import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_mention_utils.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// WhatsApp-style text compose bar (no multimedia attachments).
class CommunicationsComposeBar extends ConsumerStatefulWidget {
  const CommunicationsComposeBar({
    required this.canWrite,
    required this.isSaving,
    this.replyToMessage,
    this.onCancelReply,
    this.autofocus = false,
    this.onAutofocusHandled,
    this.maxAttachments = 0,
    this.onSent,
    super.key,
  });

  final bool canWrite;
  final bool isSaving;
  final CommunicationMessage? replyToMessage;
  final VoidCallback? onCancelReply;
  final bool autofocus;
  final VoidCallback? onAutofocusHandled;
  final int maxAttachments;
  final VoidCallback? onSent;

  @override
  ConsumerState<CommunicationsComposeBar> createState() =>
      _CommunicationsComposeBarState();
}

class _CommunicationsComposeBarState
    extends ConsumerState<CommunicationsComposeBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<CommunicationStaffOption> _mentionOptions = <CommunicationStaffOption>[];
  MentionQuery? _activeMention;

  @override
  void initState() {
    super.initState();
    _scheduleAutofocus();
  }

  @override
  void didUpdateWidget(covariant CommunicationsComposeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus && !oldWidget.autofocus) {
      _scheduleAutofocus();
    }
  }

  void _scheduleAutofocus() {
    if (!widget.autofocus || !widget.canWrite) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      widget.onAutofocusHandled?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!widget.canWrite ||
        !CommunicationsMessagesAtomPermissions.compose.isAllowed(policy)) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: theme.borders.only(top: true),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.sm,
          theme.spacing.sm,
          theme.spacing.sm,
          theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.replyToMessage != null) _replyQuote(context),
            if (_activeMention != null && _mentionOptions.isNotEmpty)
              _mentionOverlay(context),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(theme.radius.lg),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.md,
                        vertical: theme.spacing.xs,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !widget.isSaving,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: context.l10n.communicationsComposeHint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: theme.spacing.sm,
                          ),
                        ),
                        onChanged: _handleTextChanged,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                AppButton(
                  iconOnly: true,
                  icon: Icons.send,
                  label: context.l10n.communicationsSendMessageAction,
                  semanticLabel: context.l10n.communicationsSendMessageAction,
                  tooltip: context.l10n.communicationsSendMessageAction,
                  isLoading: widget.isSaving,
                  enabled: !widget.isSaving && _canSend,
                  onPressed: _canSend ? _send : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSend => _controller.text.trim().isNotEmpty;

  Widget _replyQuote(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CommunicationMessage message = widget.replyToMessage!;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          border: theme.borders.only(
            left: true,
            color: theme.colorScheme.primary,
            width: theme.borders.thick + 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  displayMessageContent(message.preview),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppButton(
                iconOnly: true,
                icon: Icons.close,
                label: context.l10n.commonCancelActionLabel,
                semanticLabel: context.l10n.commonCancelActionLabel,
                onPressed: widget.onCancelReply,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mentionOverlay(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(theme.radius.md),
        color: theme.colorScheme.surface,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _mentionOptions.length,
          itemBuilder: (BuildContext context, int index) {
            final CommunicationStaffOption option = _mentionOptions[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                child: Text(
                  option.label.isEmpty
                      ? '?'
                      : option.label.substring(0, 1).toUpperCase(),
                ),
              ),
              title: Text(option.label),
              subtitle: Text(
                <String?>[option.positionTitle, option.email]
                    .whereType<String>()
                    .where((String v) => v.isNotEmpty)
                    .join(' · '),
              ),
              onTap: () => _insertMention(option),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleTextChanged(String value) async {
    setState(() {});
    final MentionQuery? query = parseActiveMentionQuery(
      value,
      _controller.selection.baseOffset,
    );
    if (query == null) {
      if (_activeMention != null) {
        setState(() {
          _activeMention = null;
          _mentionOptions = <CommunicationStaffOption>[];
        });
      }
      return;
    }
    final List<CommunicationStaffOption> options = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query.query);
    if (!mounted) {
      return;
    }
    setState(() {
      _activeMention = query;
      _mentionOptions = options.take(8).toList(growable: false);
    });
  }

  void _insertMention(CommunicationStaffOption staff) {
    final MentionQuery? query = _activeMention;
    if (query == null) {
      return;
    }
    final String token = '${buildMentionToken(staff)} ';
    final String text = _controller.text;
    final String next = text.replaceRange(
      query.startIndex,
      _controller.selection.baseOffset,
      token,
    );
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: query.startIndex + token.length,
      ),
    );
    setState(() {
      _activeMention = null;
      _mentionOptions = <CommunicationStaffOption>[];
    });
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!widget.canWrite ||
        !CommunicationsMessagesAtomPermissions.compose.isAllowed(policy)) {
      return;
    }
    final String content = _controller.text.trim();
    final CommunicationMessageDraft draft = CommunicationMessageDraft(
      content: content,
      replyToMessageId: widget.replyToMessage?.id,
      mentionedUserIds: extractMentionedUserIds(content),
    );
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .sendMessage(draft);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      _controller.clear();
      setState(() {
        _activeMention = null;
        _mentionOptions = <CommunicationStaffOption>[];
      });
      widget.onCancelReply?.call();
      widget.onSent?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.communicationsMessageSentMessage)),
      );
    }
  }
}
