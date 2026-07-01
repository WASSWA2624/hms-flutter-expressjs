import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_conversation_list.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_thread_view.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class CommunicationsInboxPanel extends ConsumerStatefulWidget {
  const CommunicationsInboxPanel({
    required this.state,
    required this.searchController,
    required this.canWrite,
    super.key,
  });

  final CommunicationsWorkspaceState state;
  final TextEditingController searchController;
  final bool canWrite;

  @override
  ConsumerState<CommunicationsInboxPanel> createState() =>
      _CommunicationsInboxPanelState();
}

class _CommunicationsInboxPanelState
    extends ConsumerState<CommunicationsInboxPanel> {
  CommunicationsInboxFilter _filter = CommunicationsInboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.lg;
    final CommunicationsConversation? selected =
        widget.state.selectedConversation;

    if (!isWide && selected != null) {
      return CommunicationsThreadView(
        conversation: selected,
        canWrite: widget.canWrite,
        isSaving: widget.state.isSaving,
        showBackButton: true,
        onBack: ref
            .read(communicationsWorkspaceControllerProvider.notifier)
            .clearSelectedConversation,
      );
    }

    final Widget listPanel = AppWorkspaceDetailPanel(
      title: context.l10n.communicationsInboxPanelLabel,
      description: context.l10n.communicationsListDescription,
      child: SizedBox(
        height: isWide ? 640 : 420,
        child: CommunicationsConversationList(
          state: widget.state,
          searchController: widget.searchController,
          canWrite: widget.canWrite,
          selectedFilter: _filter,
          onFilterChanged: _applyFilter,
        ),
      ),
    );

    if (!isWide) {
      return listPanel;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 5, child: listPanel),
        SizedBox(width: theme.spacing.lg),
        Expanded(
          flex: 7,
          child: selected == null
              ? AppWorkspaceDetailPanel(
                  title: context.l10n.communicationsConversationDetailTitle,
                  child: AppWorkspaceStatePanel.empty(
                    title:
                        context.l10n.communicationsNoConversationSelectedTitle,
                    body: context.l10n.communicationsNoConversationSelectedBody,
                    icon: Icons.forum_outlined,
                    minHeight: 420,
                  ),
                )
              : SizedBox(
                  height: 640,
                  child: CommunicationsThreadView(
                    conversation: selected,
                    canWrite: widget.canWrite,
                    isSaving: widget.state.isSaving,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _applyFilter(CommunicationsInboxFilter filter) async {
    setState(() => _filter = filter);
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );
    switch (filter) {
      case CommunicationsInboxFilter.all:
        await controller.applyFilter();
      case CommunicationsInboxFilter.unread:
        await controller.applyFilter(unreadOnly: true);
      case CommunicationsInboxFilter.favorites:
        await controller.applyFilter(filter: 'FAVORITES');
      case CommunicationsInboxFilter.flagged:
        await controller.applyFilter(filter: 'FLAGGED');
      case CommunicationsInboxFilter.archived:
        await controller.applyFilter(filter: 'ARCHIVED');
    }
  }
}
