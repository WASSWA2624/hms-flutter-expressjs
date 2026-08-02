import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

Future<PharmacyStorageRoom?> openPharmacyStorageRoomDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
}) async {
  final Object? result = await showAppDialog<Object?>(
    context: context,
    builder: (_) => _StorageRoomDialog(room: room),
  );
  if (result is PharmacyStorageRoom) {
    return result;
  }
  return null;
}

/// Opens a read/manage details dialog for [room].
Future<void> openPharmacyStorageRoomDetailsDialog(
  BuildContext context,
  WidgetRef ref, {
  required PharmacyStorageRoom room,
  required AccessRequirement writeRequirement,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _StorageRoomDetailsDialog(
      room: room,
      writeRequirement: writeRequirement,
    ),
  );
}

/// Opens the create/edit shelf dialog for [room]. Reused by the Storage layout
/// and Shelves catalog tables so shelf CRUD flows stay identical.
Future<void> openPharmacyStorageShelfDialog(
  BuildContext context,
  WidgetRef ref, {
  required PharmacyStorageRoom room,
  PharmacyStorageShelf? shelf,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _StorageShelfDialog(room: room, shelf: shelf),
  );
}

/// Soft-deletes a storage room (cascades shelves).
Future<void> confirmDeletePharmacyStorageRoom(
  BuildContext context,
  WidgetRef ref,
  PharmacyStorageRoom room,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.pharmacyDeleteStorageRoomDialogTitle),
      content: Text(l10n.pharmacyDeleteStorageRoomDialogBody),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.commonDeleteActionLabel,
          leadingIcon: Icons.delete_outline,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .deleteStorageRoom(room.id);
  if (!context.mounted || failure == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
  );
}

Future<void> confirmRestorePharmacyStorageRoom(
  BuildContext context,
  WidgetRef ref,
  PharmacyStorageRoom room,
) async {
  final AppLocalizations l10n = context.l10n;
  final Result<PharmacyStorageRoom> result = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .restoreStorageRoom(room.id);
  if (!context.mounted) {
    return;
  }
  result.when(
    success: (_) {},
    failure: (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
      );
    },
  );
}

Future<void> confirmPermanentDeletePharmacyStorageRoom(
  BuildContext context,
  WidgetRef ref,
  PharmacyStorageRoom room,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.pharmacyPermanentDeleteStorageRoomDialogTitle),
      content: Text(l10n.pharmacyPermanentDeleteStorageRoomDialogBody),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.pharmacyPermanentDeleteStorageRoomAction,
          leadingIcon: Icons.delete_forever_outlined,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .permanentDeleteStorageRoom(room.id);
  if (!context.mounted || failure == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
  );
}

/// Confirms and deletes a storage shelf. Reused by the Shelves table.
Future<void> confirmDeletePharmacyStorageShelf(
  BuildContext context,
  WidgetRef ref,
  PharmacyStorageShelf shelf,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(l10n.pharmacyDeleteStorageShelfDialogTitle),
      content: Text(l10n.pharmacyDeleteStorageShelfDialogBody),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.pharmacyDeleteStorageShelfAction,
          leadingIcon: Icons.delete_outline,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(pharmacyWorkspaceControllerProvider.notifier)
      .deleteStorageShelf(shelf.id);
  if (!context.mounted || failure == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
  );
}

class PharmacyStoragePanel extends ConsumerWidget {
  const PharmacyStoragePanel({
    required this.state,
    required this.writeRequirement,
    this.showHeaderActions = true,
    this.compact = false,
    super.key,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool showHeaderActions;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PharmacyStorageRoom> rooms = state.storageLayout.rooms;
    final Widget roomContent = Stack(
      children: <Widget>[
        if (rooms.isEmpty && !state.isRefreshingStorage)
          AppWorkspaceStatePanel.state(
            variant: AppStateViewVariant.empty,
            title: l10n.pharmacyNoStorageRoomsTitle,
            body: l10n.pharmacyNoStorageRoomsBody,
            icon: Icons.warehouse_outlined,
          )
        else if (rooms.isEmpty)
          const SizedBox.shrink()
        else
          ListView.separated(
            shrinkWrap: !compact,
            physics: compact
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => SizedBox(height: theme.spacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final PharmacyStorageRoom room = rooms[index];
              return Card(
                child: ExpansionTile(
                  title: Text(room.name ?? room.id),
                  subtitle: room.code == null || room.code!.isEmpty
                      ? null
                      : Text(room.code!),
                  trailing: AppAccessActionGate(
                    requirement: writeRequirement,
                    builder: (BuildContext context, bool isAllowed) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (!room.isActive)
                          Padding(
                            padding: EdgeInsets.only(right: theme.spacing.xs),
                            child: Text(
                              l10n.pharmacyStorageInactiveLabel,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        AppButton(
                          iconOnly: true,
                          leadingIcon: Icons.add,
                          label: l10n.pharmacyAddStorageShelfAction,
                          semanticLabel: l10n.pharmacyAddStorageShelfAction,
                          enabled: isAllowed && room.isActive,
                          onPressed: () => _openShelfDialog(context, ref, room),
                        ),
                        AppButton(
                          iconOnly: true,
                          leadingIcon: Icons.edit_outlined,
                          label: l10n.pharmacyEditStorageRoomAction,
                          semanticLabel: l10n.pharmacyEditStorageRoomAction,
                          enabled: isAllowed,
                          onPressed: () => openPharmacyStorageRoomDialog(
                            context,
                            ref,
                            room: room,
                          ),
                        ),
                        AppButton(
                          iconOnly: true,
                          leadingIcon: Icons.delete_outline,
                          label: l10n.pharmacyDeleteStorageRoomAction,
                          semanticLabel: l10n.pharmacyDeleteStorageRoomAction,
                          color: theme.colorScheme.error,
                          enabled: isAllowed,
                          onPressed: () =>
                              _confirmDeleteRoom(context, ref, room),
                        ),
                      ],
                    ),
                  ),
                  children: room.shelves.isEmpty
                      ? <Widget>[
                          Padding(
                            padding: EdgeInsets.all(theme.spacing.md),
                            child: Text(l10n.pharmacyNoStorageShelvesBody),
                          ),
                        ]
                      : room.shelves
                            .map(
                              (PharmacyStorageShelf shelf) => ListTile(
                                title: Text(shelf.displayLabel),
                                subtitle:
                                    shelf.label == null ||
                                        shelf.label!.trim().isEmpty
                                    ? null
                                    : Text(shelf.label!),
                                trailing: _buildShelfTrailing(
                                  context,
                                  ref,
                                  room,
                                  shelf,
                                ),
                                onTap: writeRequirement.allows(ref)
                                    ? () => _openShelfDialog(
                                        context,
                                        ref,
                                        room,
                                        shelf: shelf,
                                      )
                                    : null,
                              ),
                            )
                            .toList(growable: false),
                ),
              );
            },
          ),
        if (state.isRefreshingStorage)
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surface.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppAccessActionGate(
              requirement: writeRequirement,
              builder: (BuildContext context, bool isAllowed) =>
                  AppButton.secondary(
                    label: l10n.pharmacyAddStorageRoomAction,
                    leadingIcon: Icons.add,
                    enabled: isAllowed,
                    onPressed: () =>
                        openPharmacyStorageRoomDialog(context, ref),
                  ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Expanded(child: roomContent),
        ],
      );
    }

    return AppCollapsibleSection(
      title: l10n.pharmacyStoragePanelTitle,
      description: l10n.pharmacyStoragePanelDescription,
      actions: showHeaderActions
          ? <Widget>[
              AppAccessActionGate(
                requirement: writeRequirement,
                builder: (BuildContext context, bool isAllowed) =>
                    AppButton.secondary(
                      label: l10n.pharmacyAddStorageRoomAction,
                      leadingIcon: Icons.add,
                      enabled: isAllowed,
                      onPressed: () =>
                          openPharmacyStorageRoomDialog(context, ref),
                    ),
              ),
            ]
          : const <Widget>[],
      child: roomContent,
    );
  }

  Future<void> _openShelfDialog(
    BuildContext context,
    WidgetRef ref,
    PharmacyStorageRoom room, {
    PharmacyStorageShelf? shelf,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (_) => _StorageShelfDialog(room: room, shelf: shelf),
    );
  }

  Widget _buildShelfTrailing(
    BuildContext context,
    WidgetRef ref,
    PharmacyStorageRoom room,
    PharmacyStorageShelf shelf,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppAccessActionGate(
      requirement: writeRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return shelf.isActive
              ? const SizedBox.shrink()
              : Text(l10n.pharmacyStorageInactiveLabel);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!shelf.isActive)
              Padding(
                padding: EdgeInsets.only(right: theme.spacing.xs),
                child: Text(
                  l10n.pharmacyStorageInactiveLabel,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.edit_outlined,
              label: l10n.pharmacyEditStorageShelfAction,
              semanticLabel: l10n.pharmacyEditStorageShelfAction,
              onPressed: () =>
                  _openShelfDialog(context, ref, room, shelf: shelf),
            ),
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: l10n.pharmacyDeleteStorageShelfAction,
              semanticLabel: l10n.pharmacyDeleteStorageShelfAction,
              color: theme.colorScheme.error,
              onPressed: () => _confirmDeleteShelf(context, ref, shelf),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteRoom(
    BuildContext context,
    WidgetRef ref,
    PharmacyStorageRoom room,
  ) {
    return confirmDeletePharmacyStorageRoom(context, ref, room);
  }

  Future<void> _confirmDeleteShelf(
    BuildContext context,
    WidgetRef ref,
    PharmacyStorageShelf shelf,
  ) {
    return confirmDeletePharmacyStorageShelf(context, ref, shelf);
  }
}

class _StorageRoomDialog extends ConsumerStatefulWidget {
  const _StorageRoomDialog({this.room});

  final PharmacyStorageRoom? room;

  @override
  ConsumerState<_StorageRoomDialog> createState() => _StorageRoomDialogState();
}

class _StorageRoomDialogState extends ConsumerState<_StorageRoomDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _codeController = TextEditingController(text: widget.room?.code ?? '');
    _isActive = widget.room?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isEdit = widget.room != null;
    return AppDialog(
      title: Text(
        isEdit
            ? l10n.pharmacyEditStorageRoomAction
            : l10n.pharmacyAddStorageRoomAction,
      ),
      icon: const Icon(Icons.warehouse_outlined),
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            labelText: l10n.pharmacyStorageRoomNameLabel,
            isRequired: true,
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? l10n.validationRequired : null,
          ),
          AppTextField(
            controller: _codeController,
            labelText: l10n.pharmacyStorageRoomCodeLabel,
          ),
          if (isEdit)
            AppSwitchField(
              title: l10n.pharmacyStorageActiveLabel,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEdit
              ? l10n.commonSaveActionLabel
              : l10n.pharmacyAddStorageRoomAction,
          leadingIcon: isEdit ? Icons.save_outlined : Icons.add,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final AppLocalizations l10n = context.l10n;
    final String name = _nameController.text.trim();
    final String? code = _emptyToNull(_codeController.text);

    final Result<PharmacyStorageRoomSimilarityResult> similarityResult =
        await controller.checkStorageRoomSimilarity(
          name: name,
          code: code,
          excludeRoomId: widget.room?.id,
        );
    if (!mounted) {
      return;
    }

    PharmacyStorageRoomSimilarityResult? review;
    final AppFailure? similarityFailure = similarityResult.when(
      success: (PharmacyStorageRoomSimilarityResult value) {
        review = value;
        return null;
      },
      failure: (AppFailure failure) => failure,
    );
    if (similarityFailure != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
      );
      return;
    }

    final PharmacyStorageRoomSimilarityResult check =
        review ?? const PharmacyStorageRoomSimilarityResult();
    final bool? proceed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool blocked = check.hasExactConflict;
        final bool hasMatches = check.matches.isNotEmpty;
        return AppDialog(
          title: Text(
            blocked
                ? l10n.pharmacyStorageRoomDuplicateDialogTitle
                : hasMatches
                ? l10n.pharmacyStorageRoomSimilarDialogTitle
                : l10n.pharmacyStorageRoomNoSimilarDialogTitle,
          ),
          icon: Icon(
            blocked
                ? Icons.gpp_bad_outlined
                : hasMatches
                ? Icons.warning_amber_outlined
                : Icons.verified_outlined,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                blocked
                    ? l10n.pharmacyStorageRoomDuplicateDialogBody
                    : hasMatches
                    ? l10n.pharmacyStorageRoomSimilarDialogBody(
                        check.closestScore,
                      )
                    : l10n.pharmacyStorageRoomNoSimilarDialogBody,
              ),
              if (hasMatches) ...<Widget>[
                SizedBox(height: Theme.of(dialogContext).spacing.md),
                for (final PharmacyStorageRoomSimilarityMatch match
                    in check.matches.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(match.room.name ?? match.room.id),
                    subtitle: Text(
                      [
                        if ((match.room.code ?? '').isNotEmpty) match.room.code!,
                        '${match.score}%',
                      ].join(' · '),
                    ),
                  ),
              ],
            ],
          ),
          actions: <Widget>[
            AppButton.tertiary(
              label: l10n.commonCancelActionLabel,
              leadingIcon: Icons.close,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            if (!blocked)
              AppButton.primary(
                label: hasMatches
                    ? l10n.pharmacyStorageRoomCreateAnywayAction
                    : l10n.commonContinueActionLabel,
                leadingIcon: Icons.check,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
          ],
        );
      },
    );
    if (proceed != true || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    if (widget.room == null) {
      final Result<PharmacyStorageRoom> createResult = await controller
          .createStorageRoom(
            PharmacyStorageRoomInput(
              name: name,
              code: code,
              tenantId: controller.resolveTenantId(),
              facilityId: controller.resolveFacilityId(),
              confirmSimilar: true,
            ),
          );
      if (!mounted) {
        return;
      }
      createResult.when(
        success: (PharmacyStorageRoom created) {
          Navigator.of(context).pop(created);
        },
        failure: (_) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
          );
        },
      );
      return;
    }

    final Result<PharmacyStorageRoom> updateResult = await controller
        .updateStorageRoom(
          widget.room!.id,
          PharmacyStorageRoomUpdateInput(
            name: name,
            code: code,
            isActive: _isActive,
            confirmSimilar: true,
          ),
        );
    if (!mounted) {
      return;
    }
    updateResult.when(
      success: (PharmacyStorageRoom updated) {
        Navigator.of(context).pop(updated);
      },
      failure: (_) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pharmacyCatalogDeleteFailedMessage)),
        );
      },
    );
  }
}

class _StorageRoomDetailsDialog extends ConsumerWidget {
  const _StorageRoomDetailsDialog({
    required this.room,
    required this.writeRequirement,
  });

  final PharmacyStorageRoom room;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    PharmacyWorkspaceState? state;
    final asyncState = ref.watch(pharmacyWorkspaceControllerProvider);
    if (asyncState.hasValue) {
      asyncState.requireValue.when(
        success: (PharmacyWorkspaceState value) => state = value,
        failure: (_) {},
      );
    }
    PharmacyStorageRoom current = room;
    if (state != null) {
      for (final PharmacyStorageRoom item in state!.storageLayout.rooms) {
        if (item.id == room.id) {
          current = item;
          break;
        }
      }
    }

    return AppDialog(
      title: Text(current.name ?? l10n.pharmacyStorageRoomLabel),
      icon: const Icon(Icons.warehouse_outlined),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('${l10n.pharmacyStorageRoomCodeLabel}: ${current.code ?? '—'}'),
          SizedBox(height: theme.spacing.sm),
          Text(
            '${l10n.pharmacyStorageStatusColumnLabel}: ${current.isSoftDeleted
                ? l10n.pharmacyStorageDeletedLabel
                : current.isActive
                ? l10n.pharmacyStorageActiveLabel
                : l10n.pharmacyStorageInactiveLabel}',
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            '${l10n.pharmacyStorageShelvesCountColumnLabel}: ${current.shelves.length}',
          ),
          if (current.shelves.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            for (final PharmacyStorageShelf shelf in current.shelves.take(8))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(shelf.shelfCode ?? shelf.id),
                subtitle: Text(shelf.label ?? '—'),
              ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppAccessActionGate(
          requirement: writeRequirement,
          builder: (BuildContext context, bool allowed) {
            if (!allowed) {
              return const SizedBox.shrink();
            }
            if (current.isSoftDeleted) {
              return const SizedBox.shrink();
            }
            return AppButton.tertiary(
              label: l10n.commonCreateActionLabel,
              leadingIcon: Icons.add,
              semanticLabel: l10n.pharmacyAddStorageShelfAction,
              onPressed: () async {
                await openPharmacyStorageShelfDialog(
                  context,
                  ref,
                  room: current,
                );
              },
            );
          },
        ),
        AppAccessActionGate(
          requirement: writeRequirement,
          builder: (BuildContext context, bool allowed) {
            if (!allowed) {
              return const SizedBox.shrink();
            }
            if (current.isSoftDeleted) {
              return AppButton.tertiary(
                label: l10n.pharmacyRestoreStorageRoomAction,
                leadingIcon: Icons.restore_outlined,
                onPressed: () async {
                  await confirmRestorePharmacyStorageRoom(context, ref, current);
                },
              );
            }
            return AppButton.tertiary(
              label: l10n.commonDeleteActionLabel,
              leadingIcon: Icons.delete_outline,
              semanticLabel: l10n.pharmacyDeleteStorageRoomAction,
              onPressed: () async {
                await confirmDeletePharmacyStorageRoom(context, ref, current);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),
        AppAccessActionGate(
          requirement: writeRequirement,
          builder: (BuildContext context, bool allowed) {
            if (!allowed || current.isSoftDeleted) {
              return const SizedBox.shrink();
            }
            return AppButton.primary(
              label: l10n.commonEditActionLabel,
              leadingIcon: Icons.edit_outlined,
              onPressed: () async {
                final PharmacyStorageRoom? updated =
                    await openPharmacyStorageRoomDialog(
                      context,
                      ref,
                      room: current,
                    );
                if (updated != null && context.mounted) {
                  // Keep details open; parent will refresh via controller.
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _StorageShelfDialog extends ConsumerStatefulWidget {
  const _StorageShelfDialog({required this.room, this.shelf});

  final PharmacyStorageRoom room;
  final PharmacyStorageShelf? shelf;

  @override
  ConsumerState<_StorageShelfDialog> createState() =>
      _StorageShelfDialogState();
}

class _StorageShelfDialogState extends ConsumerState<_StorageShelfDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _labelController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.shelf?.shelfCode ?? '',
    );
    _labelController = TextEditingController(text: widget.shelf?.label ?? '');
    _isActive = widget.shelf?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isEdit = widget.shelf != null;
    return AppDialog(
      title: Text(
        isEdit
            ? l10n.pharmacyEditStorageShelfAction
            : l10n.pharmacyAddStorageShelfAction,
      ),
      icon: const Icon(Icons.inventory_2_outlined),
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _codeController,
            labelText: l10n.pharmacyStorageShelfCodeLabel,
            isRequired: true,
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? l10n.validationRequired : null,
          ),
          AppTextField(
            controller: _labelController,
            labelText: l10n.pharmacyStorageShelfLabelField,
          ),
          if (isEdit)
            AppSwitchField(
              title: l10n.pharmacyStorageActiveLabel,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEdit
              ? l10n.commonSaveActionLabel
              : l10n.pharmacyAddStorageShelfAction,
          leadingIcon: isEdit ? Icons.save_outlined : Icons.add,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure;
    if (widget.shelf == null) {
      failure = await controller.createStorageShelf(
        widget.room.id,
        PharmacyStorageShelfInput(
          shelfCode: _codeController.text.trim(),
          label: _emptyToNull(_labelController.text),
        ),
      );
    } else {
      failure = await controller.updateStorageShelf(
        widget.shelf!.id,
        PharmacyStorageShelfUpdateInput(
          shelfCode: _codeController.text.trim(),
          label: _emptyToNull(_labelController.text),
          isActive: _isActive,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isSaving = false);
  }
}

String? _emptyToNull(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

extension on AccessRequirement {
  bool allows(WidgetRef ref) {
    return isAllowed(ref.read(appAccessPolicyProvider));
  }
}
