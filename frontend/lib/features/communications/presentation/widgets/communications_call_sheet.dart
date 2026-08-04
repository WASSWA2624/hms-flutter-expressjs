import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showCommunicationsCallSheet(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  CommunicationCallEvent? incoming,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return _CommunicationsCallSheet(
        kind: kind,
        incoming: incoming,
      );
    },
  );
}

class _CommunicationsCallSheet extends ConsumerStatefulWidget {
  const _CommunicationsCallSheet({
    required this.kind,
    this.incoming,
  });

  final String kind;
  final CommunicationCallEvent? incoming;

  @override
  ConsumerState<_CommunicationsCallSheet> createState() =>
      _CommunicationsCallSheetState();
}

class _CommunicationsCallSheetState
    extends ConsumerState<_CommunicationsCallSheet> {
  bool _busy = false;
  CommunicationCallEvent? _active;

  @override
  void initState() {
    super.initState();
    _active = widget.incoming;
    if (widget.incoming == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_start());
      });
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .startCall(kind: widget.kind);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (failure != null) {
      await Navigator.of(context).maybePop();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.communicationsCallFailedMessage)),
      );
      return;
    }
    final Result<CommunicationsWorkspaceState>? workspaceResult = ref
        .read(communicationsWorkspaceControllerProvider)
        .asData
        ?.value;
    final CommunicationsConversation? conversation = workspaceResult?.when(
      success: (CommunicationsWorkspaceState state) => state.selectedConversation,
      failure: (_) => null,
    );
    CommunicationCallEvent? latest;
    final List<CommunicationMessage> messages =
        conversation?.messages ?? const <CommunicationMessage>[];
    for (int index = messages.length - 1; index >= 0; index -= 1) {
      final CommunicationCallEvent? event = messages[index].callEvent;
      if (event != null) {
        latest = event;
        break;
      }
    }
    setState(() => _active = latest);
  }

  Future<void> _update(String action) async {
    final CommunicationCallEvent? call = _active;
    if (call == null) {
      return;
    }
    setState(() => _busy = true);
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .updateCall(callId: call.id, action: action);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (failure == null) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isVideo = widget.kind.toUpperCase() == 'VIDEO';
    final String status = _active?.action ?? 'starting';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isVideo ? Icons.videocam_outlined : Icons.call_outlined,
              size: 48,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              isVideo
                  ? context.l10n.communicationsVideoCallTitle
                  : context.l10n.communicationsVoiceCallTitle,
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              context.l10n.communicationsCallStatusLabel(status),
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: theme.spacing.md),
            Text(
              context.l10n.communicationsCallSignalingHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: theme.spacing.lg),
            if (_busy) const CircularProgressIndicator(),
            if (!_busy && widget.incoming != null && status == 'started')
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: context.l10n.communicationsDeclineCallAction,
                      icon: Icons.call_end,
                      onPressed: () => _update('decline'),
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: AppButton(
                      label: context.l10n.communicationsAcceptCallAction,
                      icon: Icons.call,
                      onPressed: () => _update('accept'),
                    ),
                  ),
                ],
              ),
            if (!_busy &&
                (status == 'started' || status == 'accepted') &&
                widget.incoming == null)
              AppButton(
                label: context.l10n.communicationsEndCallAction,
                icon: Icons.call_end,
                onPressed: () => _update('end'),
              ),
            if (!_busy &&
                widget.incoming != null &&
                (status == 'accepted' || status == 'started'))
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.sm),
                child: AppButton(
                  label: context.l10n.communicationsEndCallAction,
                  icon: Icons.call_end,
                  onPressed: () => _update('end'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
