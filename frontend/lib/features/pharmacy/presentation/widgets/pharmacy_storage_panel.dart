import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_room_similarity_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_shelf_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Result of the create/edit storage-room form (saved room or Use existing).
final class PharmacyStorageRoomFormResult {
  const PharmacyStorageRoomFormResult._({
    required this.useExisting,
    this.room,
  });

  const PharmacyStorageRoomFormResult.cancelled()
    : this._(useExisting: false);

  const PharmacyStorageRoomFormResult.saved(PharmacyStorageRoom room)
    : this._(useExisting: false, room: room);

  const PharmacyStorageRoomFormResult.useExisting(PharmacyStorageRoom room)
    : this._(useExisting: true, room: room);

  final PharmacyStorageRoom? room;
  final bool useExisting;

  bool get hasRoom => room != null;
}

/// Result of the create/edit storage-shelf form (saved shelf or Use existing).
final class PharmacyStorageShelfFormResult {
  const PharmacyStorageShelfFormResult._({
    required this.useExisting,
    this.shelf,
  });

  const PharmacyStorageShelfFormResult.cancelled()
    : this._(useExisting: false);

  const PharmacyStorageShelfFormResult.saved(PharmacyStorageShelf shelf)
    : this._(useExisting: false, shelf: shelf);

  const PharmacyStorageShelfFormResult.useExisting(PharmacyStorageShelf shelf)
    : this._(useExisting: true, shelf: shelf);

  final PharmacyStorageShelf? shelf;
  final bool useExisting;

  bool get hasShelf => shelf != null;
}

Future<PharmacyStorageRoomFormResult> openPharmacyStorageRoomDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
}) async {
  final Object? result = await showAppDialog<Object?>(
    context: context,
    builder: (_) => _StorageRoomDialog(room: room),
  );
  if (result is PharmacyStorageRoomFormResult) {
    return result;
  }
  if (result is PharmacyStorageRoom) {
    return PharmacyStorageRoomFormResult.saved(result);
  }
  return const PharmacyStorageRoomFormResult.cancelled();
}

/// Opens create/edit and, when the user picks Use existing or saves, returns
/// the room that should be shown in details (if any).
Future<PharmacyStorageRoom?> openPharmacyStorageRoomDialogForDetails(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
  required AccessRequirement writeRequirement,
}) async {
  final PharmacyStorageRoomFormResult result =
      await openPharmacyStorageRoomDialog(context, ref, room: room);
  final PharmacyStorageRoom? selected = result.room;
  if (selected == null || !context.mounted) {
    return null;
  }
  await openPharmacyStorageRoomDetailsDialog(
    context,
    ref,
    room: selected,
    writeRequirement: writeRequirement,
  );
  return selected;
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

/// Opens the create/edit shelf dialog. When [room] is null, [availableRooms]
/// must be provided so the user can pick a parent room in the same dialog.
Future<PharmacyStorageShelfFormResult> openPharmacyStorageShelfDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
  PharmacyStorageShelf? shelf,
  List<PharmacyStorageRoom> availableRooms = const <PharmacyStorageRoom>[],
}) async {
  final Object? result = await showAppDialog<Object?>(
    context: context,
    builder: (_) => _StorageShelfDialog(
      room: room,
      shelf: shelf,
      availableRooms: availableRooms,
    ),
  );
  if (result is PharmacyStorageShelfFormResult) {
    return result;
  }
  if (result is PharmacyStorageShelf) {
    return PharmacyStorageShelfFormResult.saved(result);
  }
  return const PharmacyStorageShelfFormResult.cancelled();
}

/// Opens create/edit and then shelf details when a shelf was saved or chosen.
Future<PharmacyStorageShelf?> openPharmacyStorageShelfDialogForDetails(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
  PharmacyStorageShelf? shelf,
  List<PharmacyStorageRoom> availableRooms = const <PharmacyStorageRoom>[],
  required AccessRequirement writeRequirement,
}) async {
  final PharmacyStorageShelfFormResult result =
      await openPharmacyStorageShelfDialog(
        context,
        ref,
        room: room,
        shelf: shelf,
        availableRooms: availableRooms,
      );
  final PharmacyStorageShelf? selected = result.shelf;
  if (selected == null || !context.mounted) {
    return null;
  }
  PharmacyStorageRoom? parent = room;
  if (parent == null || parent.id != selected.storageRoomId) {
    parent = _findShelfParentRoom(ref, selected) ?? room;
  }
  if (parent == null || !context.mounted) {
    return selected;
  }
  await openPharmacyStorageShelfDetailsDialog(
    context,
    ref,
    room: parent,
    shelf: selected,
    writeRequirement: writeRequirement,
  );
  return selected;
}

/// Opens a read/manage details dialog for [shelf].
Future<void> openPharmacyStorageShelfDetailsDialog(
  BuildContext context,
  WidgetRef ref, {
  required PharmacyStorageRoom room,
  required PharmacyStorageShelf shelf,
  required AccessRequirement writeRequirement,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => _StorageShelfDetailsDialog(
      room: room,
      shelf: shelf,
      writeRequirement: writeRequirement,
    ),
  );
}

PharmacyStorageRoom? _findShelfParentRoom(
  WidgetRef ref,
  PharmacyStorageShelf shelf,
) {
  final asyncState = ref.read(pharmacyWorkspaceControllerProvider);
  if (!asyncState.hasValue) {
    return null;
  }
  PharmacyWorkspaceState? state;
  asyncState.requireValue.when(
    success: (PharmacyWorkspaceState value) => state = value,
    failure: (_) {},
  );
  if (state == null) {
    return null;
  }
  final String? roomId = shelf.storageRoomId;
  for (final PharmacyStorageRoom item in state!.storageLayout.rooms) {
    if (roomId != null && item.id == roomId) {
      return item;
    }
    for (final PharmacyStorageShelf candidate in item.shelves) {
      if (candidate.id == shelf.id) {
        return item;
      }
    }
  }
  return null;
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
    return openPharmacyStorageShelfDialog(
      context,
      ref,
      room: room,
      shelf: shelf,
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
    String name = _nameController.text.trim();
    String? code = _emptyToNull(_codeController.text);

    while (mounted) {
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
      final PharmacyStorageRoomSimilarityDialogResult similarityDecision =
          await showPharmacyStorageRoomSimilarityDialog(
            context,
            proposed: PharmacyStorageRoomSimilarityProposedValues(
              name: name,
              code: code,
              isActive: widget.room == null ? null : _isActive,
            ),
            check: check,
            isEdit: widget.room != null,
          );
      if (!mounted) {
        return;
      }

      if (similarityDecision.action ==
          PharmacyStorageRoomSimilarityAction.cancel) {
        setState(() => _isSaving = false);
        return;
      }

      if (similarityDecision.action ==
          PharmacyStorageRoomSimilarityAction.retry) {
        final PharmacyStorageRoomSimilarityProposedValues? next =
            similarityDecision.proposed;
        if (next == null || next.name.trim().isEmpty) {
          setState(() => _isSaving = false);
          return;
        }
        name = next.name.trim();
        code = next.code;
        _nameController.text = name;
        _codeController.text = code ?? '';
        continue;
      }

      if (similarityDecision.action ==
          PharmacyStorageRoomSimilarityAction.useExisting) {
        final PharmacyStorageRoom? existing = similarityDecision.selectedRoom;
        setState(() => _isSaving = false);
        if (existing != null) {
          Navigator.of(
            context,
          ).pop(PharmacyStorageRoomFormResult.useExisting(existing));
        }
        return;
      }

      final PharmacyStorageRoomSimilarityProposedValues? confirmed =
          similarityDecision.proposed;
      if (confirmed != null) {
        name = confirmed.name.trim().isEmpty ? name : confirmed.name.trim();
        code = confirmed.code;
        _nameController.text = name;
        _codeController.text = code ?? '';
      }
      break;
    }

    if (!mounted) {
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
          Navigator.of(
            context,
          ).pop(PharmacyStorageRoomFormResult.saved(created));
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
        Navigator.of(
          context,
        ).pop(PharmacyStorageRoomFormResult.saved(updated));
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
    final ColorScheme colorScheme = theme.colorScheme;
    final AppStatusColors statusColors = theme.statusColors;
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

    final String empty = l10n.clinicalOrderEmptyValueLabel;
    final String roomName =
        (current.name ?? '').trim().isEmpty
            ? l10n.pharmacyStorageRoomLabel
            : current.name!.trim();
    final String statusLabel = current.isSoftDeleted
        ? l10n.pharmacyStorageDeletedLabel
        : current.isActive
        ? l10n.pharmacyStorageActiveLabel
        : l10n.pharmacyStorageInactiveLabel;
    final AppWorkspaceStatusTone statusTone = current.isSoftDeleted
        ? AppWorkspaceStatusTone.error
        : current.isActive
        ? AppWorkspaceStatusTone.success
        : AppWorkspaceStatusTone.warning;
    final Color statusAccent = switch (statusTone) {
      AppWorkspaceStatusTone.error => statusColors.error,
      AppWorkspaceStatusTone.warning => statusColors.warning,
      AppWorkspaceStatusTone.success => statusColors.success,
      _ => colorScheme.primary,
    };
    final Color statusContainer = switch (statusTone) {
      AppWorkspaceStatusTone.error => statusColors.errorContainer,
      AppWorkspaceStatusTone.warning => statusColors.warningContainer,
      AppWorkspaceStatusTone.success => statusColors.successContainer,
      _ => colorScheme.primaryContainer,
    };
    final String? displayId = (current.displayId ?? '').trim().isEmpty
        ? null
        : current.displayId!.trim();
    final String codeValue = (current.code ?? '').trim().isEmpty
        ? empty
        : current.code!.trim();
    final List<PharmacyStorageShelf> shelves = current.shelves;

    return AppDialog(
      title: Text(roomName),
      icon: const Icon(Icons.warehouse_outlined),
      scrollable: true,
      maxWidth: 720,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.sm),
                      child: Icon(
                        Icons.warehouse_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          roomName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(height: theme.spacing.xs),
                        Wrap(
                          spacing: theme.spacing.sm,
                          runSpacing: theme.spacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacing.sm,
                                vertical: theme.spacing.xs / 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusContainer,
                                border: Border.all(
                                  color: statusAccent.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: statusAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              codeValue,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (displayId != null)
                              Text(
                                displayId,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          AppCollapsibleSection(
            title: l10n.pharmacyStorageRoomLabel,
            titleIcon: Icons.info_outline,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            child: AppInfoTileGrid(
              maxColumns: 3,
              emptyValue: empty,
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.pharmacyStorageRoomCodeLabel,
                  value: current.code,
                  icon: Icons.qr_code_2_outlined,
                  copyable: (current.code ?? '').trim().isNotEmpty,
                ),
                AppInfoTileData(
                  label: l10n.pharmacyStorageStatusColumnLabel,
                  value: statusLabel,
                  icon: Icons.flag_outlined,
                ),
                AppInfoTileData(
                  label: l10n.pharmacyStorageShelvesCountColumnLabel,
                  value: '${shelves.length}',
                  icon: Icons.inventory_2_outlined,
                ),
                if (displayId != null)
                  AppInfoTileData(
                    label: l10n.accessAdminColumnDetails,
                    value: displayId,
                    icon: Icons.badge_outlined,
                    copyable: true,
                  ),
                if (current.createdAt != null)
                  AppInfoTileData(
                    label: l10n.pharmacyStorageCreatedAtColumnLabel,
                    value: AppFormatters.dateTime(
                      current.createdAt!,
                      Localizations.localeOf(context),
                    ),
                    icon: Icons.event_outlined,
                  ),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.md),
          AppCollapsibleSection(
            title: l10n.pharmacyStorageShelvesCountColumnLabel,
            titleIcon: Icons.inventory_2_outlined,
            subtitle: '${shelves.length}',
            headerMetaInline: true,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppAccessActionGate(
                  requirement: writeRequirement,
                  builder: (BuildContext context, bool allowed) {
                    if (!allowed || current.isSoftDeleted) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment.centerRight,
                      child: AppButton.secondary(
                        dense: true,
                        label: l10n.pharmacyAddStorageShelfAction,
                        leadingIcon: Icons.add,
                        onPressed: () async {
                          await openPharmacyStorageShelfDialog(
                            context,
                            ref,
                            room: current,
                          );
                        },
                      ),
                    );
                  },
                ),
                if (shelves.isEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  AppContentPanel(
                    tone: AppWorkspaceStatusTone.info,
                    borderRadius: BorderRadius.zero,
                    child: Text(
                      l10n.pharmacyStoragePanelDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ] else ...<Widget>[
                  SizedBox(height: theme.spacing.sm),
                  for (int index = 0; index < shelves.length; index += 1) ...<
                    Widget
                  >[
                    if (index > 0) SizedBox(height: theme.spacing.sm),
                    _StorageRoomShelfRow(
                      shelf: shelves[index],
                      emptyValue: empty,
                      writeRequirement: writeRequirement,
                      canMutate: !current.isSoftDeleted,
                      onEdit: () async {
                        await openPharmacyStorageShelfDialog(
                          context,
                          ref,
                          room: current,
                          shelf: shelves[index],
                        );
                      },
                      onDelete: () async {
                        await confirmDeletePharmacyStorageShelf(
                          context,
                          ref,
                          shelves[index],
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
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
              return AppButton.tertiary(
                label: l10n.pharmacyRestoreStorageRoomAction,
                leadingIcon: Icons.restore_outlined,
                onPressed: () async {
                  await confirmRestorePharmacyStorageRoom(
                    context,
                    ref,
                    current,
                  );
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
                final PharmacyStorageRoomFormResult result =
                    await openPharmacyStorageRoomDialog(
                      context,
                      ref,
                      room: current,
                    );
                if (!context.mounted || result.room == null) {
                  return;
                }
                if (result.useExisting) {
                  Navigator.of(context).pop();
                  if (!context.mounted) {
                    return;
                  }
                  await openPharmacyStorageRoomDetailsDialog(
                    context,
                    ref,
                    room: result.room!,
                    writeRequirement: writeRequirement,
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _StorageRoomShelfRow extends StatelessWidget {
  const _StorageRoomShelfRow({
    required this.shelf,
    required this.emptyValue,
    required this.writeRequirement,
    required this.canMutate,
    required this.onEdit,
    required this.onDelete,
  });

  final PharmacyStorageShelf shelf;
  final String emptyValue;
  final AccessRequirement writeRequirement;
  final bool canMutate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppStatusColors statusColors = theme.statusColors;
    final String code = (shelf.shelfCode ?? '').trim().isEmpty
        ? emptyValue
        : shelf.shelfCode!.trim();
    final String label = (shelf.label ?? '').trim().isEmpty
        ? emptyValue
        : shelf.label!.trim();
    final bool active = shelf.isActive;
    final Color accent = active ? statusColors.success : statusColors.warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    code,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs / 2,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                active
                    ? l10n.pharmacyStorageActiveLabel
                    : l10n.pharmacyStorageInactiveLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppAccessActionGate(
              requirement: writeRequirement,
              builder: (BuildContext context, bool allowed) {
                if (!allowed || !canMutate) {
                  return const SizedBox.shrink();
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(width: theme.spacing.xs),
                    AppButton.tertiary(
                      dense: true,
                      label: l10n.commonEditActionLabel,
                      leadingIcon: Icons.edit_outlined,
                      semanticLabel: l10n.pharmacyEditStorageShelfAction,
                      onPressed: onEdit,
                    ),
                    AppButton.tertiary(
                      dense: true,
                      label: l10n.commonDeleteActionLabel,
                      leadingIcon: Icons.delete_outline,
                      semanticLabel: l10n.pharmacyDeleteStorageShelfAction,
                      onPressed: onDelete,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageShelfDialog extends ConsumerStatefulWidget {
  const _StorageShelfDialog({
    this.room,
    this.shelf,
    this.availableRooms = const <PharmacyStorageRoom>[],
  });

  final PharmacyStorageRoom? room;
  final PharmacyStorageShelf? shelf;
  final List<PharmacyStorageRoom> availableRooms;

  @override
  ConsumerState<_StorageShelfDialog> createState() =>
      _StorageShelfDialogState();
}

class _StorageShelfDialogState extends ConsumerState<_StorageShelfDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _labelController;
  late PharmacyStorageRoom? _selectedRoom;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEdit => widget.shelf != null;
  bool get _roomLocked => widget.room != null || _isEdit;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.shelf?.shelfCode ?? '',
    );
    _labelController = TextEditingController(text: widget.shelf?.label ?? '');
    _isActive = widget.shelf?.isActive ?? true;
    _selectedRoom = widget.room;
    if (_selectedRoom == null && widget.availableRooms.length == 1) {
      _selectedRoom = widget.availableRooms.first;
    }
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
    final List<PharmacyStorageRoom> roomOptions = _roomLocked
        ? <PharmacyStorageRoom>[
            ?_selectedRoom,
          ]
        : widget.availableRooms;
    return AppDialog(
      title: Text(
        _isEdit
            ? l10n.pharmacyEditStorageShelfAction
            : l10n.pharmacyAddStorageShelfAction,
      ),
      icon: const Icon(Icons.inventory_2_outlined),
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _selectedRoom?.id,
            labelText: l10n.pharmacyStorageRoomLabel,
            isRequired: true,
            enabled: !_roomLocked && !_isSaving,
            allowClear: !_roomLocked,
            options: roomOptions
                .map(
                  (PharmacyStorageRoom room) => AppSelectOption<String>(
                    value: room.id,
                    label: room.name ?? room.id,
                    searchText: '${room.name ?? ''} ${room.code ?? ''} ${room.id}',
                  ),
                )
                .toList(growable: false),
            onChanged: _roomLocked
                ? null
                : (String? value) {
                    PharmacyStorageRoom? next;
                    if (value != null) {
                      for (final PharmacyStorageRoom room
                          in widget.availableRooms) {
                        if (room.id == value) {
                          next = room;
                          break;
                        }
                      }
                    }
                    setState(() => _selectedRoom = next);
                  },
            validator: (String? value) => (value ?? '').trim().isEmpty
                ? l10n.validationRequired
                : null,
          ),
          AppTextField(
            controller: _codeController,
            labelText: l10n.pharmacyStorageShelfCodeLabel,
            helperText: _isEdit
                ? null
                : l10n.pharmacyStorageShelfCodeOptionalHint,
          ),
          AppTextField(
            controller: _labelController,
            labelText: l10n.pharmacyStorageShelfLabelField,
            isRequired: true,
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? l10n.validationRequired : null,
          ),
          if (_isEdit)
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
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.pharmacyAddStorageShelfAction,
          leadingIcon: _isEdit ? Icons.save_outlined : Icons.add,
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
    final PharmacyStorageRoom? room = _selectedRoom;
    if (room == null) {
      return;
    }
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final AppLocalizations l10n = context.l10n;
    String label = _labelController.text.trim();
    String? shelfCode = _emptyToNull(_codeController.text);

    while (mounted) {
      final Result<PharmacyStorageShelfSimilarityResult> similarityResult =
          await controller.checkStorageShelfSimilarity(
            roomId: room.id,
            label: label,
            shelfCode: shelfCode,
            excludeShelfId: widget.shelf?.id,
          );
      if (!mounted) {
        return;
      }

      PharmacyStorageShelfSimilarityResult? review;
      final AppFailure? similarityFailure = similarityResult.when(
        success: (PharmacyStorageShelfSimilarityResult value) {
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

      final PharmacyStorageShelfSimilarityResult check =
          review ?? const PharmacyStorageShelfSimilarityResult();
      final PharmacyStorageShelfSimilarityDialogResult similarityDecision =
          await showPharmacyStorageShelfSimilarityDialog(
            context,
            proposed: PharmacyStorageShelfSimilarityProposedValues(
              label: label,
              shelfCode: shelfCode,
              isActive: widget.shelf == null ? null : _isActive,
            ),
            check: check,
            isEdit: widget.shelf != null,
          );
      if (!mounted) {
        return;
      }

      if (similarityDecision.action ==
          PharmacyStorageShelfSimilarityAction.cancel) {
        setState(() => _isSaving = false);
        return;
      }

      if (similarityDecision.action ==
          PharmacyStorageShelfSimilarityAction.retry) {
        final PharmacyStorageShelfSimilarityProposedValues? next =
            similarityDecision.proposed;
        if (next == null || next.label.trim().isEmpty) {
          setState(() => _isSaving = false);
          return;
        }
        label = next.label.trim();
        shelfCode = next.shelfCode;
        _labelController.text = label;
        _codeController.text = shelfCode ?? '';
        continue;
      }

      if (similarityDecision.action ==
          PharmacyStorageShelfSimilarityAction.useExisting) {
        final PharmacyStorageShelf? existing = similarityDecision.selectedShelf;
        setState(() => _isSaving = false);
        if (existing != null) {
          Navigator.of(
            context,
          ).pop(PharmacyStorageShelfFormResult.useExisting(existing));
        }
        return;
      }

      final PharmacyStorageShelfSimilarityProposedValues? confirmed =
          similarityDecision.proposed;
      if (confirmed != null) {
        label = confirmed.label.trim().isEmpty
            ? label
            : confirmed.label.trim();
        shelfCode = confirmed.shelfCode;
        _labelController.text = label;
        _codeController.text = shelfCode ?? '';
      }
      break;
    }

    if (!mounted) {
      return;
    }

    if (widget.shelf == null) {
      final Result<PharmacyStorageShelf> createResult = await controller
          .createStorageShelf(
            room.id,
            PharmacyStorageShelfInput(
              shelfCode: shelfCode,
              label: label,
              confirmSimilar: true,
            ),
          );
      if (!mounted) {
        return;
      }
      createResult.when(
        success: (PharmacyStorageShelf created) {
          Navigator.of(
            context,
          ).pop(PharmacyStorageShelfFormResult.saved(created));
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

    final Result<PharmacyStorageShelf> updateResult = await controller
        .updateStorageShelf(
          widget.shelf!.id,
          PharmacyStorageShelfUpdateInput(
            shelfCode: shelfCode,
            label: label,
            isActive: _isActive,
            confirmSimilar: true,
          ),
        );
    if (!mounted) {
      return;
    }
    updateResult.when(
      success: (PharmacyStorageShelf updated) {
        Navigator.of(
          context,
        ).pop(PharmacyStorageShelfFormResult.saved(updated));
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

class _StorageShelfDetailsDialog extends ConsumerWidget {
  const _StorageShelfDetailsDialog({
    required this.room,
    required this.shelf,
    required this.writeRequirement,
  });

  final PharmacyStorageRoom room;
  final PharmacyStorageShelf shelf;
  final AccessRequirement writeRequirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppStatusColors statusColors = theme.statusColors;
    PharmacyWorkspaceState? state;
    final asyncState = ref.watch(pharmacyWorkspaceControllerProvider);
    if (asyncState.hasValue) {
      asyncState.requireValue.when(
        success: (PharmacyWorkspaceState value) => state = value,
        failure: (_) {},
      );
    }

    PharmacyStorageRoom currentRoom = room;
    PharmacyStorageShelf current = shelf;
    if (state != null) {
      for (final PharmacyStorageRoom item in state!.storageLayout.rooms) {
        if (item.id == room.id) {
          currentRoom = item;
        }
        for (final PharmacyStorageShelf candidate in item.shelves) {
          if (candidate.id == shelf.id) {
            current = candidate;
            currentRoom = item;
          }
        }
      }
    }

    final String empty = l10n.clinicalOrderEmptyValueLabel;
    final String shelfLabel = (current.label ?? '').trim().isEmpty
        ? empty
        : current.label!.trim();
    final String codeValue = (current.shelfCode ?? '').trim().isEmpty
        ? empty
        : current.shelfCode!.trim();
    final String roomName = (currentRoom.name ?? '').trim().isEmpty
        ? currentRoom.id
        : currentRoom.name!.trim();
    final String statusLabel = current.isActive
        ? l10n.pharmacyStorageActiveLabel
        : l10n.pharmacyStorageInactiveLabel;
    final Color accent = current.isActive
        ? statusColors.success
        : statusColors.warning;
    final String? displayId = (current.displayId ?? '').trim().isEmpty
        ? null
        : current.displayId!.trim();

    return AppDialog(
      title: Text(l10n.pharmacyStorageShelfLabel),
      icon: const Icon(Icons.inventory_2_outlined),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.inventory_2_outlined,
                    color: colorScheme.primary,
                    size: theme.appTokens.listIconSize * 1.4,
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          shelfLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: theme.spacing.xs),
                        Wrap(
                          spacing: theme.spacing.sm,
                          runSpacing: theme.spacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacing.sm,
                                vertical: theme.spacing.xs / 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              codeValue,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              roomName,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          AppCollapsibleSection(
            title: l10n.pharmacyStorageShelfLabel,
            titleIcon: Icons.info_outline,
            contentPadding: EdgeInsets.all(theme.spacing.md),
            child: AppInfoTileGrid(
              maxColumns: 3,
              emptyValue: empty,
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.pharmacyStorageShelfCodeLabel,
                  value: current.shelfCode,
                  icon: Icons.qr_code_2_outlined,
                  copyable: (current.shelfCode ?? '').trim().isNotEmpty,
                ),
                AppInfoTileData(
                  label: l10n.pharmacyStorageShelfLabelField,
                  value: current.label,
                  icon: Icons.label_outline,
                  copyable: (current.label ?? '').trim().isNotEmpty,
                ),
                AppInfoTileData(
                  label: l10n.pharmacyStorageRoomLabel,
                  value: roomName,
                  icon: Icons.warehouse_outlined,
                ),
                AppInfoTileData(
                  label: l10n.pharmacyStorageStatusColumnLabel,
                  value: statusLabel,
                  icon: Icons.flag_outlined,
                ),
                if (displayId != null)
                  AppInfoTileData(
                    label: l10n.accessAdminColumnDetails,
                    value: displayId,
                    icon: Icons.badge_outlined,
                    copyable: true,
                  ),
              ],
            ),
          ),
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
            return AppButton.tertiary(
              label: l10n.commonDeleteActionLabel,
              leadingIcon: Icons.delete_outline,
              semanticLabel: l10n.pharmacyDeleteStorageShelfAction,
              onPressed: () async {
                await confirmDeletePharmacyStorageShelf(
                  context,
                  ref,
                  current,
                );
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
            if (!allowed) {
              return const SizedBox.shrink();
            }
            return AppButton.primary(
              label: l10n.commonEditActionLabel,
              leadingIcon: Icons.edit_outlined,
              onPressed: () async {
                final PharmacyStorageShelfFormResult result =
                    await openPharmacyStorageShelfDialog(
                      context,
                      ref,
                      room: currentRoom,
                      shelf: current,
                    );
                if (!context.mounted || result.shelf == null) {
                  return;
                }
                if (result.useExisting) {
                  Navigator.of(context).pop();
                  if (!context.mounted) {
                    return;
                  }
                  final PharmacyStorageRoom parent =
                      _findShelfParentRoom(ref, result.shelf!) ?? currentRoom;
                  await openPharmacyStorageShelfDetailsDialog(
                    context,
                    ref,
                    room: parent,
                    shelf: result.shelf!,
                    writeRequirement: writeRequirement,
                  );
                }
              },
            );
          },
        ),
      ],
    );
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
