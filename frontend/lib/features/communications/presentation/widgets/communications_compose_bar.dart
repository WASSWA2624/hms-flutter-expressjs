import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_mention_utils.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class CommunicationsComposeBar extends ConsumerStatefulWidget {
  const CommunicationsComposeBar({
    required this.canWrite,
    required this.isSaving,
    this.replyToMessage,
    this.onCancelReply,
    super.key,
  });

  final bool canWrite;
  final bool isSaving;
  final CommunicationMessage? replyToMessage;
  final VoidCallback? onCancelReply;

  @override
  ConsumerState<CommunicationsComposeBar> createState() =>
      _CommunicationsComposeBarState();
}

class _CommunicationsComposeBarState
    extends ConsumerState<CommunicationsComposeBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<CommunicationAttachmentUpload> _attachments =
      <CommunicationAttachmentUpload>[];
  List<CommunicationStaffOption> _mentionOptions = <CommunicationStaffOption>[];
  MentionQuery? _activeMention;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!widget.canWrite) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.replyToMessage != null) _replyQuote(context),
            if (_attachments.isNotEmpty) _attachmentChips(context),
            if (_activeMention != null && _mentionOptions.isNotEmpty)
              _mentionOverlay(context),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                AppButton(
                  iconOnly: true,
                  icon: Icons.attach_file_outlined,
                  label: context.l10n.communicationsAttachFileAction,
                  semanticLabel: context.l10n.communicationsAttachFileAction,
                  tooltip: context.l10n.communicationsAttachFileAction,
                  enabled: !widget.isSaving,
                  onPressed: _pickAttachments,
                ),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: AppTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    labelText: context.l10n.communicationsMessageFieldLabel,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !widget.isSaving,
                    onChanged: _handleTextChanged,
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                AppButton(
                  iconOnly: true,
                  icon: Icons.send_outlined,
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

  bool get _canSend =>
      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

  Widget _replyQuote(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CommunicationMessage message = widget.replyToMessage!;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
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

  Widget _attachmentChips(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Wrap(
        spacing: theme.spacing.xs,
        runSpacing: theme.spacing.xs,
        children: <Widget>[
          for (int index = 0; index < _attachments.length; index++)
            InputChip(
              label: Text(_attachments[index].fileName),
              onDeleted: widget.isSaving
                  ? null
                  : () => setState(() => _attachments.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _mentionOverlay(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Card(
        margin: EdgeInsets.only(bottom: theme.spacing.xs),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final CommunicationStaffOption option in _mentionOptions)
              ListTile(
                dense: true,
                title: Text(option.label),
                subtitle: Text(
                  <String?>[option.positionTitle, option.email]
                      .whereType<String>()
                      .where((String v) => v.isNotEmpty)
                      .join(' · '),
                ),
                onTap: () => _insertMention(option),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTextChanged(String value) async {
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

  Future<void> _pickAttachments() async {
    try {
      final List<XFile> files = await openFiles();
      if (!mounted || files.isEmpty) {
        return;
      }
      final List<CommunicationAttachmentUpload> uploads =
          <CommunicationAttachmentUpload>[];
      for (final XFile file in files.take(5 - _attachments.length)) {
        uploads.add(
          CommunicationAttachmentUpload(
            fileName: file.name,
            bytes: await file.readAsBytes(),
            contentType: file.mimeType,
          ),
        );
      }
      setState(() => _attachments.addAll(uploads));
    } catch (_) {}
  }

  Future<void> _send() async {
    final String content = _controller.text.trim();
    final CommunicationMessageDraft draft = CommunicationMessageDraft(
      content: content,
      replyToMessageId: widget.replyToMessage?.id,
      mentionedUserIds: extractMentionedUserIds(content),
      attachments: List<CommunicationAttachmentUpload>.from(_attachments),
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
        _attachments.clear();
        _activeMention = null;
        _mentionOptions = <CommunicationStaffOption>[];
      });
      widget.onCancelReply?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.communicationsMessageSentMessage)),
      );
    }
  }
}
