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
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_supplier_details_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_supplier_similarity_dialog.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_workspace_print_helpers.dart';
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
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canExport = canExportPharmacyWorkspace(policy);
    final bool canPrint = canPrintPharmacyWorkspace(policy);

    return AppListTable<PharmacySupplier>(
      page: widget.state.suppliers,
      isLoading: isBusy,
      columnVisibilityStorageKey: 'pharmacy_catalog_suppliers',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.commonTableSettingsTitle,
      columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
      columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
      columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
      shrinkWrap: !widget.fillHeight,
      onPageChanged: controller.setSupplierPage,
      enableExport: true,
      canExport: canExport,
      exportLabel: l10n.commonTableExportActionLabel,
      exportDialogTitle: l10n.commonTableExportDialogTitle,
      exportCancelLabel: l10n.commonCancelActionLabel,
      exportColumnsSectionLabel: l10n.commonTableExportColumnsSectionLabel,
      exportFiltersSectionLabel: l10n.commonTableExportFiltersSectionLabel,
      exportEmptyColumnsMessage: l10n.commonTableExportEmptyColumnsMessage,
      exportEmptyRowsMessage: l10n.commonTableExportEmptyRowsMessage,
      exportSuccessMessage: l10n.commonTableExportSuccessMessage,
      exportFailureMessage: l10n.commonTableExportFailureMessage,
      enablePrint: true,
      canPrint: canPrint,
      printLabel: l10n.commonPrintActionLabel,
      onPrint: () => printPharmacyWorkspaceList(
        ref: ref,
        context: context,
        title: l10n.pharmacyDeskSuppliersLabel,
        columns: <PharmacyWorkspacePrintColumn>[
          PharmacyWorkspacePrintColumn(
            id: 'name',
            label: l10n.pharmacySupplierNameLabel,
          ),
          PharmacyWorkspacePrintColumn(
            id: 'location',
            label: l10n.pharmacySupplierLocationLabel,
          ),
          PharmacyWorkspacePrintColumn(
            id: 'email',
            label: l10n.pharmacySupplierEmailLabel,
          ),
          PharmacyWorkspacePrintColumn(
            id: 'phone',
            label: l10n.pharmacySupplierPhoneLabel,
          ),
        ],
        rows: <Map<String, String>>[
          for (final PharmacySupplier item in widget.state.suppliers.items)
            <String, String>{
              'name': item.primaryName,
              'location': item.location ?? '',
              'email': item.contactEmail ?? '',
              'phone': item.phone ?? '',
            },
        ],
        emptyText: l10n.pharmacySuppliersEmptyTitle,
      ),
      exportConfig: AppListTableExportConfig<PharmacySupplier>(
        fileNameStem: 'pharmacy_suppliers',
        dateOf: (PharmacySupplier item) => item.createdAt,
      ),
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
        showAdvancedFilterButton: true,
        advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
        advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        advancedFilterCloseLabel: l10n.commonCloseActionLabel,
        enableDateFilter: false,
        allFieldsLabel: l10n.opdAllFieldsFilterLabel,
        textFilters: <AppSearchBarTextFilter>[
          AppSearchBarTextFilter(
            key: 'name',
            label: l10n.pharmacySupplierNameLabel,
            hintText: l10n.pharmacySupplierNameLabel,
            icon: Icons.local_shipping_outlined,
          ),
          AppSearchBarTextFilter(
            key: 'location',
            label: l10n.pharmacySupplierLocationLabel,
            icon: Icons.place_outlined,
          ),
          AppSearchBarTextFilter(
            key: 'email',
            label: l10n.pharmacySupplierEmailLabel,
            icon: Icons.email_outlined,
          ),
          AppSearchBarTextFilter(
            key: 'phone',
            label: l10n.pharmacySupplierPhoneLabel,
            icon: Icons.phone_outlined,
          ),
        ],
        filterValue: AppSearchBarFilterValue(
          texts: <String, String>{
            if (widget.state.supplierQuery.search.trim().isNotEmpty)
              'name': widget.state.supplierQuery.search.trim(),
          },
        ),
        hasActiveFilters: widget.state.supplierQuery.search.trim().isNotEmpty,
        onFilterChanged: (AppSearchBarFilterValue value) {
          final String search = <String?>[
            value.text('name'),
            value.text('location'),
            value.text('email'),
            value.text('phone'),
          ]
              .map((String? part) => (part ?? '').trim())
              .where((String part) => part.isNotEmpty)
              .join(' ');
          unawaited(controller.applySupplierSearch(search));
        },
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
          alwaysVisible: true,
          cellBuilder: (_, PharmacySupplier item) => Text(
            item.primaryName.isEmpty ? '—' : item.primaryName,
          ),
          exportValue: (PharmacySupplier item) => item.primaryName,
        ),
        AppListTableColumn<PharmacySupplier>(
          id: 'location',
          label: l10n.pharmacySupplierLocationLabel,
          preferredWidth: 180,
          alwaysVisible: true,
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
          alwaysVisible: true,
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
          alwaysVisible: true,
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
          fixedWidth: 260,
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
          openPharmacySupplierDetailsDialog(
            context,
            ref,
            supplier: item,
            writeRequirement: widget.writeRequirement,
            onEdit: (PharmacySupplier supplier) =>
                openPharmacySupplierDialog(context, ref, supplier: supplier),
            onDelete: (PharmacySupplier supplier) =>
                _confirmDeleteSupplier(context, supplier),
          ),
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

  Future<bool> _confirmDeleteSupplier(
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
      return false;
    }
    return true;
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
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
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
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: AppValidators.requiredText(
              l10n.pharmacySupplierRequiredName,
            ),
          ),
          AppTextField(
            controller: _locationController,
            labelText: l10n.pharmacySupplierLocationLabel,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          AppEmailField(
            controller: _emailController,
            labelText: l10n.pharmacySupplierEmailLabel,
            invalidEmailMessage: l10n.pharmacySupplierInvalidEmail,
            textInputAction: TextInputAction.next,
            enabled: !_isSaving,
          ),
          AppPhoneField(
            key: _phoneFieldKey,
            controller: _phoneController,
            labelText: l10n.pharmacySupplierPhoneLabel,
            countryLabelText: l10n.appPhoneCountryLabel,
            countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
            countryNoResultsText: l10n.appPhoneCountryNoResults,
            numberLabelText: l10n.appPhoneNumberLabel,
            numberHintText: l10n.appPhoneNumberHint,
            invalidPhoneMessage: l10n.appPhoneInvalidMessage,
            textInputAction: TextInputAction.done,
            enabled: !_isSaving,
            onFieldSubmitted: (_) => unawaited(_submit()),
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: _isEdit
            ? l10n.commonSaveActionLabel
            : l10n.pharmacyAddSupplierAction,
        submitIcon: _isEdit ? Icons.save_outlined : Icons.add,
        isSubmitting: _isSaving,
        onCancel: () => Navigator.of(context).pop(false),
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    AppPhoneField.commitPhone(_phoneFieldKey);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    final PharmacyWorkspaceController controller = ref.read(
      pharmacyWorkspaceControllerProvider.notifier,
    );
    String name = _nameController.text.trim();
    String? location = _emptyToNull(_locationController.text);
    String? email = _emptyToNull(_emailController.text);
    String? phone = _emptyToNull(_phoneController.text);

    while (mounted) {
      final Result<PharmacySupplierSimilarityResult> similarityResult =
          await controller.checkSupplierSimilarity(
            name: name,
            contactEmail: email,
            phone: phone,
            location: location,
            excludeSupplierId: widget.supplier?.id,
          );
      if (!mounted) {
        return;
      }

      PharmacySupplierSimilarityResult? review;
      final AppFailure? similarityFailure = similarityResult.when(
        success: (PharmacySupplierSimilarityResult value) {
          review = value;
          return null;
        },
        failure: (AppFailure failure) => failure,
      );
      if (similarityFailure != null) {
        setState(() => _isSaving = false);
        showAppFailureSnackBar(context, similarityFailure);
        return;
      }

      final PharmacySupplierSimilarityResult check =
          review ?? const PharmacySupplierSimilarityResult();
      final PharmacySupplierSimilarityDialogResult similarityDecision =
          await showPharmacySupplierSimilarityDialog(
            context,
            proposed: PharmacySupplierSimilarityProposedValues(
              name: name,
              location: location,
              contactEmail: email,
              phone: phone,
            ),
            check: check,
            isEdit: _isEdit,
          );
      if (!mounted) {
        return;
      }

      if (similarityDecision.action ==
          PharmacySupplierSimilarityAction.cancel) {
        setState(() => _isSaving = false);
        return;
      }

      if (similarityDecision.action ==
          PharmacySupplierSimilarityAction.retry) {
        final PharmacySupplierSimilarityProposedValues? next =
            similarityDecision.proposed;
        if (next == null || next.name.trim().isEmpty) {
          setState(() => _isSaving = false);
          return;
        }
        name = next.name.trim();
        location = next.location;
        email = next.contactEmail;
        phone = next.phone;
        _nameController.text = name;
        _locationController.text = location ?? '';
        _emailController.text = email ?? '';
        _phoneController.text = phone ?? '';
        continue;
      }

      if (similarityDecision.action ==
          PharmacySupplierSimilarityAction.useExisting) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true);
        return;
      }

      final PharmacySupplierSimilarityProposedValues? confirmed =
          similarityDecision.proposed;
      if (confirmed != null) {
        name = confirmed.name.trim().isEmpty ? name : confirmed.name.trim();
        location = confirmed.location;
        email = confirmed.contactEmail;
        phone = confirmed.phone;
        _nameController.text = name;
        _locationController.text = location ?? '';
        _emailController.text = email ?? '';
        _phoneController.text = phone ?? '';
      }

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
            confirmSimilar: true,
          ),
        );
        if (!mounted) {
          return;
        }
        final bool saved = result.when(
          success: (_) => true,
          failure: (AppFailure failure) {
            setState(() => _isSaving = false);
            showAppFailureSnackBar(context, failure);
            return false;
          },
        );
        if (saved) {
          Navigator.of(context).pop(true);
        }
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
          confirmSimilar: true,
        ),
      );
      if (!mounted) {
        return;
      }
      final bool saved = result.when(
        success: (_) => true,
        failure: (AppFailure failure) {
          setState(() => _isSaving = false);
          showAppFailureSnackBar(context, failure);
          return false;
        },
      );
      if (saved) {
        Navigator.of(context).pop(true);
      }
      return;
    }
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
