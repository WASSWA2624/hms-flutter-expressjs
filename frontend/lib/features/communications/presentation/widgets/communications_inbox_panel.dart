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

/// WhatsApp-style inbox: list-only on phones; list | thread on tablet/desktop.
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

  /// Match WhatsApp Web / tablet: split once past phone widths.
  static const double _splitBreakpoint = AppBreakpoints.md;

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
    final ThemeData theme = Theme.of(context);
    final CommunicationsConversation? selected = state.selectedConversation;
    final CommunicationsWorkspaceController controller = ref.read(
      communicationsWorkspaceControllerProvider.notifier,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= _splitBreakpoint;
        final double paneHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 560;

        if (!isWide && selected != null && canShowThread) {
          return SizedBox(
            height: paneHeight,
            child: CommunicationsThreadView(
              conversation: selected,
              canWrite: effectiveWrite,
              isSaving: state.isSaving,
              isLoadingThread: state.isRefreshingThread,
              composeAutofocus: state.composeAutofocus,
              onComposeAutofocusHandled: controller.clearComposeAutofocus,
              showBackButton: true,
              onBack: controller.clearSelectedConversation,
            ),
          );
        }

        final Widget listPane = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: theme.borders.all(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.md,
                  theme.spacing.sm,
                  theme.spacing.md,
                  theme.spacing.xs,
                ),
                child: Text(
                  context.l10n.communicationsInboxPanelLabel,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: CommunicationsConversationList(
                  state: state,
                  searchController: searchController,
                ),
              ),
            ],
          ),
        );

        if (!isWide) {
          return SizedBox(height: paneHeight, child: listPane);
        }

        final double listWidth = (constraints.maxWidth * 0.38).clamp(
          280.0,
          420.0,
        );

        return SizedBox(
          height: paneHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: listWidth, child: listPane),
              VerticalDivider(
                width: theme.borders.thin,
                thickness: theme.borders.thin,
              ),
              Expanded(
                child: !canShowThread || selected == null
                    ? _EmptyThreadPlaceholder(theme: theme)
                    : CommunicationsThreadView(
                        conversation: selected,
                        canWrite: effectiveWrite,
                        isSaving: state.isSaving,
                        isLoadingThread: state.isRefreshingThread,
                        composeAutofocus: state.composeAutofocus,
                        onComposeAutofocusHandled:
                            controller.clearComposeAutofocus,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyThreadPlaceholder extends StatelessWidget {
  const _EmptyThreadPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: theme.borders.all(),
      ),
      child: Center(
        child: AppWorkspaceStatePanel.empty(
          title: context.l10n.communicationsNoConversationSelectedTitle,
          body: context.l10n.communicationsNoConversationSelectedBody,
          icon: Icons.chat_bubble_outline,
        ),
      ),
    );
  }
}
