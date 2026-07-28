import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showCommunicationsNotificationDetailDialog(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState fallbackState,
  NotificationItem item, {
  required bool canWrite,
}) async {
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  controller.selectNotification(item);
  final CommunicationsWorkspaceState state =
      _readCommunicationsState(ref) ?? fallbackState;
  final NotificationItem notification = state.selectedNotification ?? item;
  if (!context.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.communicationsNotificationDetailTitle),
      icon: const Icon(Icons.notifications_none_outlined),
      scrollable: true,
      maxWidth: 960,
      content: CommunicationsNotificationDetailContent(
        state: state,
        notification: notification,
        canWrite: canWrite,
      ),
      actions: _notificationDialogActions(
        context,
        ref,
        state,
        notification,
        canWrite,
      ),
    ),
  );
}

Future<void> showCommunicationsDeliveryDetailDialog(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState fallbackState,
  NotificationDelivery item,
) async {
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  controller.selectDelivery(item);
  final CommunicationsWorkspaceState state =
      _readCommunicationsState(ref) ?? fallbackState;
  final NotificationDelivery delivery = state.selectedDelivery ?? item;
  if (!context.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.communicationsDeliveryDetailTitle),
      icon: const Icon(Icons.mark_email_read_outlined),
      scrollable: true,
      maxWidth: 960,
      content: CommunicationsDeliveryDetailContent(delivery: delivery),
      actions: _deliveryDialogActions(context, delivery),
    ),
  );
}

Future<void> showCommunicationsTemplateDetailDialog(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState fallbackState,
  CommunicationTemplate item,
) async {
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  controller.selectTemplate(item);
  final CommunicationsWorkspaceState state =
      _readCommunicationsState(ref) ?? fallbackState;
  final CommunicationTemplate template = state.selectedTemplate ?? item;
  if (!context.mounted) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(context.l10n.communicationsTemplateDetailTitle),
      icon: const Icon(Icons.description_outlined),
      scrollable: true,
      maxWidth: 960,
      content: CommunicationsTemplateDetailContent(template: template),
    ),
  );
}

class CommunicationsNotificationDetailContent extends ConsumerWidget {
  const CommunicationsNotificationDetailContent({
    required this.state,
    required this.notification,
    required this.canWrite,
    super.key,
  });

  final CommunicationsWorkspaceState state;
  final NotificationItem notification;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListItemText(
          title: notification.title,
          subtitle: notification.message,
          titleStyle: Theme.of(context).textTheme.titleMedium,
          titleMaxLines: 3,
          subtitleMaxLines: 6,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        Wrap(
          spacing: Theme.of(context).spacing.xs,
          runSpacing: Theme.of(context).spacing.xs,
          children: <Widget>[
            AppWorkspaceStatusBadge(
              status: communicationsPriorityStatus(
                context,
                notification.priority,
              ),
            ),
            AppWorkspaceStatusBadge(
              status: communicationsReadStatus(context, notification),
            ),
            AppWorkspaceStatusBadge(
              status: communicationsDeliveryStatus(
                context,
                notification.effectiveDeliveryStatus,
              ),
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppInfoTileGrid(
          emptyValue: context.l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: context.l10n.communicationsTypeLabel,
              value: communicationsApiLabel(
                context,
                notification.notificationType,
              ),
              icon: Icons.category_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsContextLabel,
              value: communicationsJoinDisplay(<String?>[
                notification.contextType,
                notification.contextPublicId,
              ]),
              icon: Icons.link_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsCreatedAtLabel,
              value: communicationsDateTimeLabel(
                context,
                notification.createdAt,
              ),
              icon: Icons.event_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsReadAtLabel,
              value: communicationsDateTimeLabel(context, notification.readAt),
              icon: Icons.mark_email_read_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        CommunicationsLinkedRecordAction(targetPath: notification.targetPath),
        if (notification.deliveries.isNotEmpty) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          CommunicationsDeliveryHistory(deliveries: notification.deliveries),
        ],
        if (canWrite) SizedBox(height: Theme.of(context).spacing.md),
      ],
    );
  }
}

class CommunicationsDeliveryDetailContent extends StatelessWidget {
  const CommunicationsDeliveryDetailContent({
    required this.delivery,
    super.key,
  });

  final NotificationDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspaceStatusBadge(
          status: communicationsDeliveryStatus(context, delivery.status),
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppInfoTileGrid(
          emptyValue: context.l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: context.l10n.communicationsNotificationLabel,
              value: delivery.notificationTitle,
              icon: Icons.notifications_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsChannelLabel,
              value: communicationsApiLabel(context, delivery.channel),
              icon: Icons.send_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsRecipientLabel,
              value: communicationsDeliveryRecipient(delivery),
              icon: Icons.person_outline,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsAttemptsLabel,
              value: delivery.attemptCount.toString(),
              icon: Icons.replay_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsProviderLabel,
              value: delivery.providerName,
              icon: Icons.cloud_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsSentAtLabel,
              value: communicationsDateTimeLabel(context, delivery.sentAt),
              icon: Icons.schedule_send_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsDeliveredAtLabel,
              value: communicationsDateTimeLabel(context, delivery.deliveredAt),
              icon: Icons.done_all_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsFailedAtLabel,
              value: communicationsDateTimeLabel(context, delivery.failedAt),
              icon: Icons.error_outline,
            ),
          ],
        ),
        if (communicationsNonEmpty(delivery.errorMessage) != null) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          AppMessagePanel(
            title: context.l10n.communicationsDeliveryErrorTitle,
            message: delivery.errorMessage!,
            tone: AppWorkspaceStatusTone.error,
            icon: Icons.error_outline,
          ),
        ],
        SizedBox(height: Theme.of(context).spacing.md),
        CommunicationsLinkedRecordAction(targetPath: delivery.targetPath),
      ],
    );
  }
}

class CommunicationsTemplateDetailContent extends StatelessWidget {
  const CommunicationsTemplateDetailContent({
    required this.template,
    super.key,
  });

  final CommunicationTemplate template;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListItemText(
          title: template.name,
          subtitle: template.description,
          titleStyle: Theme.of(context).textTheme.titleMedium,
          titleMaxLines: 2,
          subtitleMaxLines: 4,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppInfoTileGrid(
          emptyValue: context.l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: context.l10n.communicationsChannelLabel,
              value: communicationsApiLabel(context, template.channel),
              icon: Icons.send_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsSubjectLabel,
              value: template.subject,
              icon: Icons.subject_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsVariablesLabel,
              value: template.variableCount.toString(),
              icon: Icons.dynamic_form_outlined,
            ),
            AppInfoTileData(
              label: context.l10n.communicationsStatusLabel,
              value: communicationsTemplateStatus(context, template).label,
              icon: Icons.flag_outlined,
            ),
          ],
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        AppWorkspaceDetailPanel(
          title: context.l10n.communicationsPreviewTitle,
          titleIcon: Icons.preview_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                template.previewSubject ??
                    template.subject ??
                    context.l10n.profileUnknownValue,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                template.previewBody ??
                    template.body ??
                    context.l10n.profileUnknownValue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommunicationsLinkedRecordAction extends StatelessWidget {
  const CommunicationsLinkedRecordAction({required this.targetPath, super.key});

  final String? targetPath;

  @override
  Widget build(BuildContext context) {
    final String? path = communicationsInternalPath(targetPath);
    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton.secondary(
        label: context.l10n.communicationsOpenLinkedRecordAction,
        leadingIcon: Icons.open_in_new_outlined,
        enabled: path != null,
        onPressed: path == null ? null : () => context.go(path),
      ),
    );
  }
}

class CommunicationsDeliveryHistory extends StatelessWidget {
  const CommunicationsDeliveryHistory({required this.deliveries, super.key});

  final List<NotificationDelivery> deliveries;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: context.l10n.communicationsDeliveryHistoryTitle,
      titleIcon: Icons.mark_email_read_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final NotificationDelivery delivery in deliveries)
            AppListItemRow(
              title: communicationsApiLabel(context, delivery.channel),
              subtitle: communicationsDeliveryRecipient(delivery),
              leadingIcon: Icons.send_outlined,
              padding: EdgeInsets.zero,
              trailing: AppWorkspaceStatusBadge(
                status: communicationsDeliveryStatus(context, delivery.status),
              ),
            ),
        ],
      ),
    );
  }
}

List<Widget> _notificationDialogActions(
  BuildContext context,
  WidgetRef ref,
  CommunicationsWorkspaceState state,
  NotificationItem item,
  bool canWrite,
) {
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  return <Widget>[
    if (canWrite && !item.isRead)
      AppButton.secondary(
        label: context.l10n.communicationsMarkReadAction,
        leadingIcon: Icons.mark_email_read_outlined,
        enabled: !state.isSaving,
        onPressed: () => showCommunicationsConfirmAction(
          context,
          title: context.l10n.communicationsMarkReadDialogTitle,
          body: context.l10n.communicationsMarkNotificationReadDialogBody,
          submitLabel: context.l10n.communicationsMarkReadAction,
          icon: const Icon(Icons.mark_email_read_outlined),
          onConfirm: controller.markSelectedNotificationRead,
        ),
      ),
    if (canWrite && item.isRead)
      AppButton.secondary(
        label: context.l10n.communicationsMarkUnreadAction,
        leadingIcon: Icons.mark_email_unread_outlined,
        enabled: !state.isSaving,
        onPressed: () => showCommunicationsConfirmAction(
          context,
          title: context.l10n.communicationsMarkUnreadDialogTitle,
          body: context.l10n.communicationsMarkNotificationUnreadDialogBody,
          submitLabel: context.l10n.communicationsMarkUnreadAction,
          icon: const Icon(Icons.mark_email_unread_outlined),
          onConfirm: controller.markSelectedNotificationUnread,
        ),
      ),
    if (canWrite)
      AppButton.secondary(
        label: context.l10n.communicationsArchiveAction,
        leadingIcon: Icons.archive_outlined,
        enabled: !state.isSaving,
        onPressed: () => showCommunicationsConfirmAction(
          context,
          title: context.l10n.communicationsArchiveDialogTitle,
          body: context.l10n.communicationsArchiveNotificationDialogBody,
          submitLabel: context.l10n.communicationsArchiveAction,
          icon: const Icon(Icons.archive_outlined),
          onConfirm: controller.archiveSelectedNotification,
        ),
      ),
  ];
}

List<Widget> _deliveryDialogActions(
  BuildContext context,
  NotificationDelivery item,
) {
  final String? path = communicationsInternalPath(item.targetPath);
  return <Widget>[
    if (path != null)
      AppButton.secondary(
        label: context.l10n.communicationsOpenLinkedRecordAction,
        leadingIcon: Icons.open_in_new_outlined,
        onPressed: () => context.go(path),
      ),
  ];
}

Future<void> showCommunicationsConfirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String submitLabel,
  required Widget icon,
  required Future<AppFailure?> Function() onConfirm,
}) async {
  final bool? changed = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppConfirmActionDialog(
      title: title,
      body: body,
      submitLabel: submitLabel,
      icon: icon,
      onConfirm: onConfirm,
    ),
  );
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.communicationsActionSavedMessage)),
    );
  }
}

CommunicationsWorkspaceState? _readCommunicationsState(WidgetRef ref) {
  return ref
      .read(communicationsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (CommunicationsWorkspaceState state) => state,
        failure: (_) => null,
      );
}

String communicationsDeliveryRecipient(NotificationDelivery delivery) {
  return communicationsJoinDisplay(<String?>[
        delivery.recipient?.displayName,
        delivery.recipientTarget,
      ]) ??
      '';
}

String communicationsDateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

AppWorkspaceStatus communicationsReadStatus(
  BuildContext context,
  NotificationItem item,
) {
  return AppWorkspaceStatus(
    label: communicationsReadStateLabel(context, item),
    tone: item.isRead
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.warning,
    icon: item.isRead
        ? Icons.mark_email_read_outlined
        : Icons.mark_email_unread_outlined,
  );
}

String communicationsReadStateLabel(
  BuildContext context,
  NotificationItem item,
) {
  return item.isRead
      ? context.l10n.communicationsReadStatus
      : context.l10n.communicationsUnreadStatus;
}

AppWorkspaceStatus communicationsPriorityStatus(
  BuildContext context,
  String? value,
) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return AppWorkspaceStatus(
    label: communicationsApiLabel(context, value),
    tone: switch (normalized) {
      'HIGH' || 'URGENT' || 'CRITICAL' => AppWorkspaceStatusTone.error,
      'MEDIUM' || 'NORMAL' => AppWorkspaceStatusTone.warning,
      'LOW' => AppWorkspaceStatusTone.neutral,
      _ => AppWorkspaceStatusTone.info,
    },
    icon: switch (normalized) {
      'HIGH' || 'URGENT' || 'CRITICAL' => Icons.priority_high_outlined,
      _ => Icons.low_priority_outlined,
    },
  );
}

AppWorkspaceStatus communicationsDeliveryStatus(
  BuildContext context,
  String? value,
) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return AppWorkspaceStatus(
    label: communicationsApiLabel(context, value),
    tone: switch (normalized) {
      'DELIVERED' || 'SENT' || 'SUCCESS' => AppWorkspaceStatusTone.success,
      'FAILED' || 'BOUNCED' || 'ERROR' => AppWorkspaceStatusTone.error,
      'RETRYING' || 'PENDING' || 'QUEUED' => AppWorkspaceStatusTone.warning,
      _ => AppWorkspaceStatusTone.neutral,
    },
  );
}

AppWorkspaceStatus communicationsTemplateStatus(
  BuildContext context,
  CommunicationTemplate template,
) {
  return AppWorkspaceStatus(
    label: template.isActive
        ? context.l10n.communicationsActiveStatus
        : context.l10n.communicationsInactiveStatus,
    tone: template.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.neutral,
    icon: template.isActive
        ? Icons.check_circle_outline
        : Icons.pause_circle_outline,
  );
}

String communicationsApiLabel(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return context.l10n.profileUnknownValue;
  }

  return normalized
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String? communicationsJoinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? communicationsNonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? communicationsInternalPath(String? value) {
  final String? path = communicationsNonEmpty(value);
  if (path == null || !path.startsWith('/')) {
    return null;
  }
  return path;
}
