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

class CommunicationsInboxPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.lg;
    final CommunicationsConversation? selected = state.selectedConversation;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    if (!isWide && selected != null) {
      return CommunicationsThreadView(
        conversation: selected,
        canWrite: canWrite,
        isSaving: state.isSaving,
        isLoadingThread: state.isRefreshingThread,
        composeAutofocus: state.composeAutofocus,
        onComposeAutofocusHandled: controller.clearComposeAutofocus,
        showBackButton: true,
        onBack: controller.clearSelectedConversation,
      );
    }

    final Widget listPanel = AppWorkspaceDetailPanel(
      title: context.l10n.communicationsMessagesPanelLabel,
      description: context.l10n.communicationsListDescription,
      child: SizedBox(
        height: isWide ? 640 : 420,
        child: CommunicationsConversationList(
          state: state,
          searchController: searchController,
          canWrite: canWrite,
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
        SizedBox(width: Theme.of(context).spacing.lg),
        Expanded(
          flex: 7,
          child: selected == null
              ? AppWorkspaceDetailPanel(
                  title: context.l10n.communicationsConversationDetailTitle,
                  child: AppWorkspaceStatePanel.empty(
                    title:
                        context.l10n.communicationsNoConversationSelectedTitle,
                    body:
                        context.l10n.communicationsNoConversationSelectedBody,
                    icon: Icons.forum_outlined,
                    minHeight: 420,
                  ),
                )
              : SizedBox(
                  height: 640,
                  child: CommunicationsThreadView(
                    conversation: selected,
                    canWrite: canWrite,
                    isSaving: state.isSaving,
                    isLoadingThread: state.isRefreshingThread,
                    composeAutofocus: state.composeAutofocus,
                    onComposeAutofocusHandled: controller.clearComposeAutofocus,
                  ),
                ),
        ),
      ],
    );
  }
}
