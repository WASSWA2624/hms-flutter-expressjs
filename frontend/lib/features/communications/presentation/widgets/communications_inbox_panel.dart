import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
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
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.tab.isAllowed(policy)) {
      return const SizedBox.shrink();
    }
    final bool canShowThread =
        CommunicationsMessagesAtomPermissions.thread.isAllowed(policy) &&
        CommunicationsMessagesAtomPermissions.detail.isAllowed(policy);
    final bool effectiveWrite =
        canWrite &&
        CommunicationsMessagesAtomPermissions.write.isAllowed(policy);
    final bool isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.lg;
    final CommunicationsConversation? selected = state.selectedConversation;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    if (!isWide && selected != null && canShowThread) {
      return CommunicationsThreadView(
        conversation: selected,
        canWrite: effectiveWrite,
        isSaving: state.isSaving,
        isLoadingThread: state.isRefreshingThread,
        composeAutofocus: state.composeAutofocus,
        onComposeAutofocusHandled: controller.clearComposeAutofocus,
        showBackButton: true,
        onBack: controller.clearSelectedConversation,
      );
    }

    // Sibling titled sections under Row (never nested): inbox list + empty
    // detail. Selected thread uses its own header chrome (not a second nested
    // section) so Conversation detail and Messages stay siblings only when
    // nothing is selected.
    final Widget listSection = AppWorkspaceDetailPanel(
      title: context.l10n.communicationsInboxPanelLabel,
      collapsible: false,
      child: SizedBox(
        height: isWide ? 600 : 380,
        child: CommunicationsConversationList(
          state: state,
          searchController: searchController,
        ),
      ),
    );

    if (!isWide) {
      return listSection;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 5, child: listSection),
        SizedBox(width: Theme.of(context).spacing.lg),
        Expanded(
          flex: 7,
          child: !canShowThread || selected == null
              ? AppWorkspaceDetailPanel(
                  title: context.l10n.communicationsConversationDetailTitle,
                  collapsible: false,
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
                    canWrite: effectiveWrite,
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
