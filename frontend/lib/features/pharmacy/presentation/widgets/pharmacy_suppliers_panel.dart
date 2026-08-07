import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

Future<bool> openPharmacySupplierDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacySupplier? supplier,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (_) => _PharmacySupplierDialog(supplier: supplier),
  );
  return saved == true;
}

class PharmacySuppliersCatalogTab extends ConsumerStatefulWidget {
  const PharmacySuppliersCatalogTab({
    required this.state,
    required this.writeRequirement,
    this.fillHeight = false,
    super.key,
  });

  final PharmacyWorkspaceState state;
  final AccessRequirement writeRequirement;
  final bool fillHeight;

  @override
  ConsumerState<PharmacySuppliersCatalogTab> createState() =>
      _PharmacySuppliersCatalogTabState();
}

class _PharmacySuppliersCatalogTabState
    extends ConsumerState<PharmacySuppliersCatalogTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.state.supplierQuery.search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.state.suppliers.items.isEmpty) {
        unawaited(
          ref
              .read(pharmacyWorkspaceControllerProvider.notifier)
              .applySupplierSearch(''),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final bool isBusy = widget.state.isRefreshingSuppliers;
    final bool canWrite = widget.writeRequirement.allows(ref);

    return AppListTable<PharmacySupplier>(
      page: widget.state.suppliers,
      isLoading: isBusy,
      columnVisibilityStorageKey: 'pharmacy_catalog_suppliers',
      shrinkWrap: !widget.fillHeight,
      onPageChanged: controller.setSupplierPage,
      loadingMoreLabel: l10n.pharmacySuppliersLoadingTitle,
      loadingBuilder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
          child: AppLoadingIndicator.compact(
            title: l10n.pharmacySuppliersLoadingTitle,
            body: l10n.pharmacySuppliersLoadingBody,
          ),
        );
      },
      search: AppListTableSearch<PharmacySupplier>(
        controller: _searchController,
        semanticLabel: l10n.pharmacySupplierSearchHint,
        hintText: l10n.pharmacySupplierSearchHint,
        matcher: (_, _) => true,
        onSubmitted: controller.applySupplierSearch,
        onClear: () => unawaited(controller.applySupplierSearch('')),
        trailingActions: canWrite
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: Icons.add,
                  label: l10n.commonCreateActionLabel,
                  tooltip: l10n.pharmacyAddSupplierAction,
                  enabled: !isBusy,
                  onPressed: isBusy
                      ? null
                      : () => unawaited(openPharmacySupplierDialog(context, ref)),
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.state(
        variant: AppStateViewVariant.empty,
        title: l10n.pharmacySuppliersEmptyTitle,
        body: l10n.pharmacySuppliersEmptyBody,
        icon: Icons.local_shipping_outlined,
      ),
      columns: <AppListTableColumn<PharmacySupplier>>[
        AppListTableColumn<PharmacySupplier>(
          id: 'name',
          label: l10n.pharmacySupplierNameLabel,
          preferredWidth: 200,
          cellBuilder: (_, PharmacySupplier item) => Text(
            item.primaryName.isEmpty ? '—' : item.primaryName,
          ),
          exportValue: (PharmacySupplier item) => item.primaryName,
        ),
        AppListTableColumn<PharmacySupplier>(
          id: 'location',
          label: l10n.pharmacySupplierLocationLabel,
          preferredWidth: 180,
          cellBuilder: (_, PharmacySupplier item) {
            final String location = (item.location ?? '').trim();
            return Text(location.isEmpty ? '—' : location);
          },
          exportValue: (PharmacySupplier item) => item.location ?? '',
        ),
        AppListTableColumn<PharmacySupplier>(
          id: 'email',
          label: l10n.pharmacySupplierEmailLabel,
          preferredWidth: 200,
          cellBuilder: (_, PharmacySupplier item) {
            final String email = (item.contactEmail ?? '').trim();
            return Text(email.isEmpty ? '—' : email);
          },
          exportValue: (PharmacySupplier item) => item.contactEmail ?? '',
        ),
        AppListTableColumn<PharmacySupplier>(
          id: 'phone',
          label: l10n.pharmacySupplierPhoneLabel,
          preferredWidth: 140,
          cellBuilder: (_, PharmacySupplier item) {
            final String phone = (item.phone ?? '').trim();
            return Text(phone.isEmpty ? '—' : phone);
          },
          exportValue: (PharmacySupplier item) => item.phone ?? '',
        ),
        AppListTableColumn<PharmacySupplier>(
          id: 'actions',
          label: l10n.pharmacyLineActionsColumnLabel,
          alwaysVisible: true,
          fixedWidth: 220,
          cellBuilder: (BuildContext context, PharmacySupplier item) {
            return AppAccessActionGate(
              requirement: widget.writeRequirement,
              builder: (BuildContext context, bool _) {
                final ThemeData theme = Theme.of(context);
                final ColorScheme colorScheme = theme.colorScheme;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppButton.tertiary(
                        dense: true,
                        leadingIcon: Icons.edit_outlined,
                        label: l10n.commonEditActionLabel,
                        semanticLabel: l10n.pharmacyEditSupplierAction,
                        tooltip: l10n.pharmacyEditSupplierAction,
                        enabled: !isBusy,
                        onPressed: isBusy
                            ? null
                            : () => unawaited(
                                  openPharmacySupplierDialog(
                                    context,
                                    ref,
                                    supplier: item,
                                  ),
                                ),
                      ),
                      SizedBox(width: theme.spacing.xs),
                      AppButton.tertiary(
                        dense: true,
                        leadingIcon: Icons.delete_outline,
                        label: l10n.commonDeleteActionLabel,
                        semanticLabel: l10n.pharmacyDeleteSupplierAction,
                        tooltip: l10n.pharmacyDeleteSupplierAction,
                        color: colorScheme.error,
                        enabled: !isBusy,
                        onPressed: isBusy
                            ? null
                            : () => unawaited(
                                  _confirmDeleteSupplier(context, item),
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
      onRowSelected: (PharmacySupplier item) {
        unawaited(
          openPharmacySupplierDialog(context, ref, supplier: item),
        );
      },
      mobileItemBuilder: (BuildContext context, PharmacySupplier item) {
        final String email = (item.contactEmail ?? '').trim();
        final String phone = (item.phone ?? '').trim();
        return AppListTableMobileItem(
          title: item.primaryName.isEmpty ? item.id : item.primaryName,
          caption: (item.location ?? '').trim().isEmpty
              ? null
              : item.location!.trim(),
          meta: <AppListTableMobileMeta>[
            if (email.isNotEmpty)
              AppListTableMobileMeta(
                label: email,
                icon: Icons.email_outlined,
              ),
            if (phone.isNotEmpty)
              AppListTableMobileMeta(
                label: phone,
                icon: Icons.phone_outlined,
              ),
          ],
          showAvatar: false,
        );
      },
    );
  }

  Future<void> _confirmDeleteSupplier(
    BuildContext context,
    PharmacySupplier supplier,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.pharmacyDeleteSupplierDialogTitle,
        body: l10n.pharmacyDeleteSupplierDialogBody,
        highlightedText: supplier.primaryName.isEmpty
            ? supplier.id
            : supplier.primaryName,
        submitLabel: l10n.pharmacyDeleteSupplierAction,
        destructive: true,
        icon: const Icon(AppActionIcons.delete),
        submitLeadingIcon: AppActionIcons.delete,
        onConfirm: () => ref
            .read(pharmacyWorkspaceControllerProvider.notifier)
            .deleteSupplier(supplier.id),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
  }
}

class _PharmacySupplierDialog extends ConsumerStatefulWidget {
  const _PharmacySupplierDialog({this.supplier});

  final PharmacySupplier? supplier;

  @override
  ConsumerState<_PharmacySupplierDialog> createState() =>
      _PharmacySupplierDialogState();
}

class _PharmacySupplierDialogState
    extends ConsumerState<_PharmacySupplierDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final PharmacySupplier? supplier = widget.supplier;
    _nameController = TextEditingController(text: supplier?.name ?? '');
    _locationController = TextEditingController(text: supplier?.location ?? '');
    _emailController = TextEditingController(
      text: supplier?.contactEmail ?? '',
    );
    _phoneController = TextEditingController(text: supplier?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isEdit
            ? l10n.pharmacyEditSupplierAction
            : l10n.pharmacyAddSupplierAction,
      ),
      icon: const Icon(Icons.local_shipping_outlined),
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            labelText: l10n.pharmacySupplierNameLabel,
            isRequired: true,
            validator: (String? value) => (value ?? '').trim().isEmpty
                ? l10n.pharmacySupplierRequiredName
                : null,
          ),
          AppTextField(
            controller: _locationController,
            labelText: l10n.pharmacySupplierLocationLabel,
          ),
          AppEmailField(
            controller: _emailController,
            labelText: l10n.pharmacySupplierEmailLabel,
            invalidEmailMessage: l10n.pharmacySupplierInvalidEmail,
            enabled: !_isSaving,
          ),
          AppTextField(
            controller: _phoneController,
            labelText: l10n.pharmacySupplierPhoneLabel,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.pharmacyAddSupplierAction,
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
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    final String name = _nameController.text.trim();
    final String? location = _emptyToNull(_locationController.text);
    final String? email = _emptyToNull(_emailController.text);
    final String? phone = _emptyToNull(_phoneController.text);

    if (_isEdit) {
      final Result<PharmacySupplier> result = await controller.updateSupplier(
        widget.supplier!.id,
        PharmacySupplierUpdateInput(
          name: name,
          location: location ?? '',
          contactEmail: email ?? '',
          phone: phone ?? '',
          clearContactEmail: email == null,
          clearPhone: phone == null,
        ),
      );
      if (!mounted) {
        return;
      }
      result.when(
        success: (_) => Navigator.of(context).pop(true),
        failure: (AppFailure failure) {
          setState(() => _isSaving = false);
          showAppFailureSnackBar(context, failure);
        },
      );
      return;
    }

    final String? tenantId = controller.resolveTenantId();
    if (tenantId == null) {
      setState(() => _isSaving = false);
      showAppFailureSnackBar(context, AppFailure.validation());
      return;
    }

    final Result<PharmacySupplier> result = await controller.createSupplier(
      PharmacySupplierInput(
        tenantId: tenantId,
        name: name,
        location: location,
        contactEmail: email,
        phone: phone,
      ),
    );
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (AppFailure failure) {
        setState(() => _isSaving = false);
        showAppFailureSnackBar(context, failure);
      },
    );
  }
}

String? _emptyToNull(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

extension on AccessRequirement {
  bool allows(WidgetRef ref) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return isAllowed(policy);
  }
}
