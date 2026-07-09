import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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

Future<void> openPharmacyStorageRoomDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyStorageRoom? room,
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (_) => _StorageRoomDialog(room: room),
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

    return AppWorkspaceDetailPanel(
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
            label: l10n.pharmacyDeleteStorageRoomAction,
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

  Future<void> _confirmDeleteShelf(
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
    final AppFailure? failure;
    if (widget.room == null) {
      failure = await controller.createStorageRoom(
        PharmacyStorageRoomInput(
          name: _nameController.text.trim(),
          code: _emptyToNull(_codeController.text),
          tenantId: controller.resolveTenantId(),
          facilityId: controller.resolveFacilityId(),
        ),
      );
    } else {
      failure = await controller.updateStorageRoom(
        widget.room!.id,
        PharmacyStorageRoomUpdateInput(
          name: _nameController.text.trim(),
          code: _emptyToNull(_codeController.text),
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
