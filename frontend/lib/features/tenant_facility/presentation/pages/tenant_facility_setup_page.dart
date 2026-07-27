import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_media_url.dart';
import 'package:hosspi_hms/core/utils/app_slug.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/repositories/tenant_facility_repository.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/facility_similarity_dialog.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class TenantFacilitySetupPage extends ConsumerWidget {
  const TenantFacilitySetupPage({super.key, this.initialQuery});

  /// Deep-link targeting parsed from the `/admin/setup` route query string.
  final TenantFacilitySetupPageQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final setup = ref.watch(tenantFacilitySetupControllerProvider);

    ref.listen<int>(
      tenantFacilitySetupSubmissionProvider.select(
        (state) => state.successVersion,
      ),
      (int? previous, int next) {
        if (previous == null || next <= previous || !context.mounted) {
          return;
        }

        _showSaved(context);
      },
    );

    return AsyncStateScaffold<FacilitySetupSnapshot>(
      value: setup,
      loadingTitle: l10n.tenantFacilitySetupLoadingTitle,
      loadingBody: l10n.tenantFacilitySetupLoadingBody,
      maxWidth: PageMaxWidth.dashboard,
      centerVertically: false,
      onRetry: () {
        ref.read(tenantFacilitySetupControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, FacilitySetupSnapshot snapshot) {
        return _TenantFacilitySetupContent(
          snapshot: snapshot,
          initialQuery: initialQuery,
        );
      },
    );
  }
}

class _TenantFacilitySetupContent extends ConsumerWidget {
  const _TenantFacilitySetupContent({
    required this.snapshot,
    this.initialQuery,
  });

  final FacilitySetupSnapshot snapshot;
  final TenantFacilitySetupPageQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canManageTenant = accessPolicy.canManageTenant();
    final bool canManageFacility = accessPolicy.canManageFacility();
    final bool canEditStructure = accessPolicy.canEditFacilitySetupStructure();
    final bool canManageAccess = accessPolicy.grantsAny(const <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ]);

    return AppWorkspace(
      title: tenantFacilitySetupWorkspaceTitle(accessPolicy, l10n),
      leadingIcon: AppRouteIcons.setup,
      maxWidth: PageMaxWidth.dataHeavy,
      scrollable: false,
      toolbar: appWorkspaceToolbarWithLabels(
        l10n,
        showGlobalActions: false,
        showFaultReport: false,
        showHousekeepingRequest: false,
      ),
      body: _SetupBody(
        snapshot: snapshot,
        initialQuery: initialQuery,
        canManageTenant: canManageTenant,
        canManageFacility: canManageFacility,
        canEditStructure: canEditStructure,
        canManageAccess: canManageAccess,
      ),
    );
  }
}

typedef _ProfileFormSubmitRegistrar =
    void Function(
      Future<bool> Function() submit, {
      bool Function()? canSave,
      VoidCallback? onFormStateChanged,
    });

typedef _SetupProfileFormBuilder =
    Widget Function(
      BuildContext context,
      FacilitySetupSnapshot snapshot,
      bool canManageTenant,
      bool canManageFacility,
      bool canEditHrStructure,
      _ProfileFormSubmitRegistrar registerSubmitHandler,
      VoidCallback onDialogStateChanged,
    );

class _SetupProfileDialog extends ConsumerStatefulWidget {
  const _SetupProfileDialog({
    required this.title,
    required this.icon,
    required this.saveLabel,
    required this.formBuilder,
    this.managementSnapshot,
  });

  final String title;
  final IconData icon;
  final String saveLabel;
  final _SetupProfileFormBuilder formBuilder;
  final FacilitySetupSnapshot? managementSnapshot;

  @override
  ConsumerState<_SetupProfileDialog> createState() =>
      _SetupProfileDialogState();
}

class _SetupProfileDialogState extends ConsumerState<_SetupProfileDialog> {
  Future<bool> Function()? _submitHandler;
  bool Function()? _canSaveChecker;

  void _registerSubmitHandler(
    Future<bool> Function() submit, {
    bool Function()? canSave,
    VoidCallback? onFormStateChanged,
  }) {
    _submitHandler = submit;
    _canSaveChecker = canSave;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFormStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSave() async {
    final Future<bool> Function()? submit = _submitHandler;
    if (submit == null) {
      return;
    }
    final bool saved = await submit();
    if (!mounted || !saved) {
      return;
    }

    final Object? savedEntity = ref
        .read(tenantFacilitySetupSubmissionProvider)
        .lastSavedEntity;
    if (widget.managementSnapshot == null) {
      _showSaved(context);
    }
    if (savedEntity is TenantProfile) {
      Navigator.of(context).pop<TenantProfile>(savedEntity);
      return;
    }
    if (savedEntity is FacilityProfile) {
      Navigator.of(context).pop<FacilityProfile>(savedEntity);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final TenantFacilitySetupSubmissionState submission = ref.watch(
      tenantFacilitySetupSubmissionProvider,
    );
    final setup = ref.watch(tenantFacilitySetupControllerProvider);
    final FacilitySetupSnapshot? managementSnapshot = widget.managementSnapshot;
    final Widget content = managementSnapshot != null
        ? widget.formBuilder(
            context,
            managementSnapshot,
            accessPolicy.canManageTenant(),
            accessPolicy.canManageFacility(),
            accessPolicy.canEditFacilitySetupStructure(),
            _registerSubmitHandler,
            _handleFormStateChanged,
          )
        : setup.when(
            data: (result) => result.when(
              success: (FacilitySetupSnapshot snapshot) => widget.formBuilder(
                context,
                snapshot,
                accessPolicy.canManageTenant(),
                accessPolicy.canManageFacility(),
                accessPolicy.canEditFacilitySetupStructure(),
                _registerSubmitHandler,
                _handleFormStateChanged,
              ),
              failure: (AppFailure failure) => AppFailureStateView(
                failure: failure,
                onRetry: () {
                  ref
                      .read(tenantFacilitySetupControllerProvider.notifier)
                      .refresh();
                },
              ),
            ),
            error: (Object error, StackTrace stackTrace) => AppFailureStateView(
              failure: _setupFailure(error),
              onRetry: () {
                ref
                    .read(tenantFacilitySetupControllerProvider.notifier)
                    .refresh();
              },
            ),
            loading: () => AppStateView(
              variant: AppStateViewVariant.loading,
              title: l10n.tenantFacilitySetupLoadingTitle,
              body: l10n.tenantFacilitySetupLoadingBody,
            ),
          );

    return AppDialog(
      title: Text(widget.title),
      icon: Icon(widget.icon),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 880,
      closeEnabled: !submission.isSubmitting,
      content: content,
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          enabled: !submission.isSubmitting,
          onPressed: submission.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.saveLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed:
              submission.isSubmitting || !(_canSaveChecker?.call() ?? true)
              ? null
              : _handleSave,
        ),
      ],
    );
  }
}

Future<TenantProfile?> _openTenantProfileModal(
  BuildContext context, {
  TenantProfile? tenant,
  bool forceCreate = false,
  bool managementMode = false,
}) {
  final AppLocalizations l10n = context.l10n;
  const FacilitySetupSnapshot managementSnapshot = FacilitySetupSnapshot();
  ProviderScope.containerOf(
    context,
  ).read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();

  return showAppDialog<TenantProfile>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
        final String dialogTitle = forceCreate
            ? l10n.tenantFacilityCreateTenantTitle
            : tenant != null
            ? l10n.tenantFacilityEditTenantTitle
            : l10n.tenantFacilityTenantSectionTitle;
        final String saveLabel = forceCreate
            ? l10n.tenantFacilityCreateTenantAction
            : l10n.tenantFacilitySaveTenantAction;

        return _SetupProfileDialog(
          title: dialogTitle,
          icon: Icons.apartment_outlined,
          saveLabel: saveLabel,
          managementSnapshot: managementMode ? managementSnapshot : null,
          formBuilder:
              (
                BuildContext context,
                FacilitySetupSnapshot snapshot,
                bool canManageTenant,
                bool canManageFacility,
                bool canEditHrStructure,
                _ProfileFormSubmitRegistrar registerSubmitHandler,
                VoidCallback onDialogStateChanged,
              ) {
                final TenantProfile? formTenant = forceCreate
                    ? null
                    : (tenant ?? snapshot.tenant);
                final bool isCreate = forceCreate || formTenant == null;

                return _TenantProfileForm(
                  tenant: formTenant,
                  canSubmit: isCreate
                      ? accessPolicy.canCreateTenant()
                      : canManageTenant,
                  framed: false,
                  isCreate: isCreate,
                  sectionBody: isCreate
                      ? l10n.tenantFacilityCreateTenantBody
                      : l10n.tenantFacilityTenantSectionBody,
                  permissionDeniedMessage: isCreate
                      ? l10n.tenantFacilityCreateTenantPermissionRequired
                      : l10n.tenantFacilityPermissionRequired,
                  hideSubmitButton: true,
                  refreshSetupAfterSave: !managementMode,
                  updateSetupSnapshot: !managementMode,
                  registerSubmitHandler: registerSubmitHandler,
                  onDialogStateChanged: onDialogStateChanged,
                );
              },
        );
      },
    ),
  );
}

Future<FacilityProfile?> _openFacilityProfileModal(
  BuildContext context, {
  String? tenantId,
  FacilityProfile? facility,
  bool requireTenantPicker = false,
  bool managementMode = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool isCreate = facility == null;
  const FacilitySetupSnapshot managementSnapshot = FacilitySetupSnapshot();
  ProviderScope.containerOf(
    context,
  ).read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();

  return showAppDialog<FacilityProfile>(
    context: context,
    builder: (BuildContext dialogContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        return _SetupProfileDialog(
          title: isCreate
              ? l10n.tenantFacilityCreateFacilityTitle
              : l10n.tenantFacilityEditFacilityTitle,
          icon: isCreate ? Icons.add_business_outlined : Icons.edit_outlined,
          saveLabel: isCreate
              ? l10n.tenantFacilitySaveFacilityAction
              : l10n.tenantFacilityEditFacilityAction,
          managementSnapshot: managementMode ? managementSnapshot : null,
          formBuilder:
              (
                BuildContext context,
                FacilitySetupSnapshot snapshot,
                bool canManageTenant,
                bool canManageFacility,
                bool canEditHrStructure,
                _ProfileFormSubmitRegistrar registerSubmitHandler,
                VoidCallback onDialogStateChanged,
              ) => _FacilityProfileForm(
                snapshot: snapshot,
                canSubmit: canManageFacility,
                framed: false,
                tenantId: tenantId,
                facility: facility,
                requireTenantPicker: requireTenantPicker,
                hideSubmitButton: true,
                refreshSetupAfterSave: !managementMode,
                registerSubmitHandler: registerSubmitHandler,
                onDialogStateChanged: onDialogStateChanged,
              ),
        );
      },
    ),
  );
}

AppFailure _setupFailure(Object error) {
  if (error is AppFailure) {
    return error;
  }

  return const AppFailure.unexpected();
}

class _SetupBody extends ConsumerStatefulWidget {
  const _SetupBody({
    required this.snapshot,
    required this.canManageTenant,
    required this.canManageFacility,
    required this.canEditStructure,
    required this.canManageAccess,
    this.initialQuery,
  });

  final FacilitySetupSnapshot snapshot;
  final TenantFacilitySetupPageQuery? initialQuery;
  final bool canManageTenant;
  final bool canManageFacility;
  final bool canEditStructure;
  final bool canManageAccess;

  @override
  ConsumerState<_SetupBody> createState() => _SetupBodyState();
}

class _SetupBodyState extends ConsumerState<_SetupBody> {
  TenantFacilitySetupDeskSection? _section;

  List<TenantFacilitySetupDeskSection> get _visibleSections {
    return tenantFacilityVisibleSetupDeskSections(
      canManageTenant: widget.canManageTenant,
      canManageFacility: widget.canManageFacility,
      canManageAccess: widget.canManageAccess,
    );
  }

  TenantFacilitySetupDeskSection get _currentSection {
    final List<TenantFacilitySetupDeskSection> sections = _visibleSections;
    if (sections.isEmpty) {
      return TenantFacilitySetupDeskSection.facility;
    }
    final TenantFacilitySetupDeskSection? selected = _section;
    if (selected != null && sections.contains(selected)) {
      return selected;
    }
    return sections.first;
  }

  @override
  void initState() {
    super.initState();
    _section = TenantFacilitySetupDeskSection.fromQuery(
      widget.initialQuery?.section ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncUrlToCurrentSection();
    });
  }

  @override
  void didUpdateWidget(covariant _SetupBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String previous =
        oldWidget.initialQuery?.signature ?? '';
    final String next = widget.initialQuery?.signature ?? '';
    if (previous == next) {
      return;
    }
    final TenantFacilitySetupDeskSection? fromRoute =
        TenantFacilitySetupDeskSection.fromQuery(
          widget.initialQuery?.section ?? '',
        );
    if (fromRoute != null && fromRoute != _section) {
      setState(() => _section = fromRoute);
    }
  }

  void _refreshSetup() {
    unawaited(
      ref.read(tenantFacilitySetupControllerProvider.notifier).refresh(),
    );
  }

  void _updateUrlForSection(TenantFacilitySetupDeskSection section) {
    if (!mounted) {
      return;
    }
    final String tab = section.routeQueryValue;
    final String location = AppRoutes.tenantFacilitySetup.location(
      queryParameters: <String, String>{if (tab.isNotEmpty) 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  void _syncUrlToCurrentSection() {
    final TenantFacilitySetupDeskSection current = _currentSection;
    final TenantFacilitySetupDeskSection? fromRoute =
        TenantFacilitySetupDeskSection.fromQuery(
          widget.initialQuery?.section ?? '',
        );
    if (fromRoute == current) {
      return;
    }
    _updateUrlForSection(current);
  }

  void _handleTabChanged(TenantFacilitySetupDeskSection section) {
    if (section == _currentSection) {
      return;
    }
    setState(() => _section = section);
    _updateUrlForSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<TenantFacilitySetupDeskSection> sections = _visibleSections;
    final TenantFacilitySetupDeskSection current = _currentSection;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);

    if (sections.isEmpty) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.tenantFacilitySetupTitle,
        body: l10n.tenantFacilitySetupBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          tabs: <AppTabItem>[
            for (final TenantFacilitySetupDeskSection section in sections)
              AppTabItem(
                id: section.name,
                icon: tenantFacilitySetupDeskSectionIcon(section),
                label: tenantFacilitySetupDeskSectionLabel(
                  l10n,
                  section,
                  policy: accessPolicy,
                ),
              ),
          ],
          selectedId: current.name,
          onTabTapped: (String tabId) {
            for (final TenantFacilitySetupDeskSection section in sections) {
              if (section.name == tabId) {
                _handleTabChanged(section);
                break;
              }
            }
          },
        ),
        SizedBox(height: theme.spacing.sm),
        Expanded(child: _buildTabBody(current)),
      ],
    );
  }

  Widget _buildTabBody(TenantFacilitySetupDeskSection section) {
    final FacilitySetupSnapshot snapshot = widget.snapshot;
    // Permission only — each section gates Add on its own prerequisites
    // (e.g. departments require a facility) so the Add control stays visible.
    final bool canSubmitStructure = widget.canEditStructure;

    return switch (section) {
      TenantFacilitySetupDeskSection.tenants => ManageTenantsPanel(
        sessionTenant: snapshot.tenant,
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.facility => ManageFacilitiesPanel(
        sessionFacility: snapshot.facility,
        sessionTenantId: snapshot.tenant?.id ?? snapshot.facility?.tenantId,
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.departments => _DepartmentSetupSection(
        snapshot: snapshot,
        canSubmit: canSubmitStructure,
      ),
      TenantFacilitySetupDeskSection.units => _UnitSetupSection(
        snapshot: snapshot,
        canSubmit: canSubmitStructure,
      ),
      TenantFacilitySetupDeskSection.wards => _WardSetupSection(
        snapshot: snapshot,
        canSubmit: canSubmitStructure,
      ),
      TenantFacilitySetupDeskSection.rooms => _RoomSetupSection(
        snapshot: snapshot,
        canSubmit: canSubmitStructure,
      ),
      TenantFacilitySetupDeskSection.beds => _BedSetupSection(
        snapshot: snapshot,
        canSubmit: canSubmitStructure,
      ),
      TenantFacilitySetupDeskSection.clinicalCatalog =>
          _buildClinicalCatalogBody(snapshot),
      TenantFacilitySetupDeskSection.roles => ManageRolesPermissionsPanel(
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.permissions => ManageRolesPermissionsPanel(
        panel: AccessAdminPanel.permissions,
        onMutated: (_) => _refreshSetup(),
      ),
      TenantFacilitySetupDeskSection.users => ManageUsersPanel(
        onMutated: (_) => _refreshSetup(),
      ),
    };
  }

  Widget _buildClinicalCatalogBody(FacilitySetupSnapshot snapshot) {
    final String? facilityId = snapshot.facility?.id.trim();
    final String? tenantId =
        (snapshot.facility?.tenantId ?? snapshot.tenant?.id)?.trim();

    return FacilityCatalogConfigPanel(
      facilityId: facilityId?.isEmpty == true ? null : facilityId,
      tenantId: tenantId?.isEmpty == true ? null : tenantId,
      defaultCurrency: resolveDefaultCurrency(
        facilityCurrency: snapshot.facility?.currency,
        tenantCurrency: snapshot.tenant?.currency,
      ),
      enabled: widget.canManageFacility || widget.canManageTenant,
    );
  }
}

class _TenantProfileForm extends ConsumerStatefulWidget {
  const _TenantProfileForm({
    required this.tenant,
    required this.canSubmit,
    this.framed = true,
    this.isCreate = false,
    this.sectionBody,
    this.permissionDeniedMessage,
    this.hideSubmitButton = false,
    this.refreshSetupAfterSave = true,
    this.updateSetupSnapshot = true,
    this.registerSubmitHandler,
    this.onDialogStateChanged,
  });

  final TenantProfile? tenant;
  final bool canSubmit;
  final bool framed;
  final bool isCreate;
  final String? sectionBody;
  final String? permissionDeniedMessage;
  final bool hideSubmitButton;
  final bool refreshSetupAfterSave;
  final bool updateSetupSnapshot;
  final _ProfileFormSubmitRegistrar? registerSubmitHandler;
  final VoidCallback? onDialogStateChanged;

  @override
  ConsumerState<_TenantProfileForm> createState() => _TenantProfileFormState();
}

class _TenantProfileFormState extends ConsumerState<_TenantProfileForm> {
  static const AppPageRequest _duplicateLookupRequest = AppPageRequest(
    pageSize: 100,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _feeController;
  late bool _isActive;
  late String _currency;
  bool _slugManuallyEdited = false;
  String? _nameErrorText;
  String? _slugErrorText;
  List<TenantSimilarityMatch> _similarMatches = const <TenantSimilarityMatch>[];
  bool _similarityAccepted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name);
    _slugController = TextEditingController(text: widget.tenant?.slug);
    _contactNameController = TextEditingController(
      text: widget.tenant?.contactName,
    );
    _phoneController = TextEditingController(text: widget.tenant?.contactPhone);
    _emailController = TextEditingController(text: widget.tenant?.contactEmail);
    _feeController = TextEditingController(
      text: widget.tenant?.standardConsultationFee,
    );
    _isActive = widget.tenant?.isActive ?? true;
    _currency = resolveDefaultCurrency(tenantCurrency: widget.tenant?.currency);
    _slugManuallyEdited =
        widget.tenant?.slug != null && widget.tenant!.slug!.trim().isNotEmpty;
    _nameController.addListener(_handleNameChanged);
    _slugController.addListener(_handleSlugChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.registerSubmitHandler?.call(_submit);
    });
  }

  @override
  void didUpdateWidget(_TenantProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registerSubmitHandler != widget.registerSubmitHandler ||
        oldWidget.tenant?.id != widget.tenant?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.registerSubmitHandler?.call(_submit);
      });
    }
    if (oldWidget.tenant?.id != widget.tenant?.id) {
      _nameController.text = widget.tenant?.name ?? '';
      _slugController.text = widget.tenant?.slug ?? '';
      _contactNameController.text = widget.tenant?.contactName ?? '';
      _phoneController.text = widget.tenant?.contactPhone ?? '';
      _emailController.text = widget.tenant?.contactEmail ?? '';
      _feeController.text = widget.tenant?.standardConsultationFee ?? '';
      _isActive = widget.tenant?.isActive ?? true;
      _currency = resolveDefaultCurrency(
        tenantCurrency: widget.tenant?.currency,
      );
      _slugManuallyEdited =
          widget.tenant?.slug != null && widget.tenant!.slug!.trim().isNotEmpty;
      _clearDuplicateState();
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _slugController
      ..removeListener(_handleSlugChanged)
      ..dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    _clearDuplicateState();
    if (!widget.isCreate || _slugManuallyEdited) {
      return;
    }

    final String slug = slugify(_nameController.text);
    if (_slugController.text != slug) {
      _slugController.text = slug;
    }
  }

  void _handleSlugChanged() {
    _clearDuplicateState();
    if (!widget.isCreate) {
      return;
    }

    final String autoSlug = slugify(_nameController.text);
    final String currentSlug = _slugController.text.trim();
    _slugManuallyEdited = currentSlug.isNotEmpty && currentSlug != autoSlug;
  }

  void _clearDuplicateState() {
    if (_nameErrorText == null &&
        _slugErrorText == null &&
        _similarMatches.isEmpty &&
        !_similarityAccepted) {
      return;
    }

    setState(() {
      _nameErrorText = null;
      _slugErrorText = null;
      _similarMatches = const <TenantSimilarityMatch>[];
      _similarityAccepted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final String sectionBody =
        widget.sectionBody ?? l10n.tenantFacilityTenantSectionBody;
    final bool fieldsEnabled = widget.canSubmit && !submission.isSubmitting;
    final String? displayId = widget.tenant?.displayId?.trim();
    final String resolvedCurrency = resolveDefaultCurrency(
      tenantCurrency: _currency,
    );

    final Widget form = Form(
      key: _formKey,
      child: AppFormSection(
        children: <Widget>[
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _nameController,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityTenantNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              errorText: _nameErrorText,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            right: AppTextField(
              controller: _slugController,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityTenantSlugLabel,
              errorText: _slugErrorText,
            ),
          ),
          if (!widget.isCreate &&
              displayId != null &&
              displayId.isNotEmpty)
            AppTextField(
              initialValue: displayId,
              enabled: false,
              readOnly: true,
              labelText: l10n.tenantFacilityTenantDetailsIdLabel,
            ),
          AppSwitchField(
            title: l10n.tenantFacilityActiveLabel,
            subtitle: _isActive
                ? l10n.tenantFacilityActiveSubtitleActive
                : l10n.tenantFacilityActiveSubtitleInactive,
            semanticLabel: l10n.tenantFacilityActiveLabel,
            value: _isActive,
            enabled: fieldsEnabled,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
              _clearDuplicateState();
            },
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppTextField(
              controller: _contactNameController,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityTenantDetailsContactNameLabel,
              isRequired: widget.isCreate,
              textCapitalization: TextCapitalization.words,
              validator: widget.isCreate
                  ? AppValidators.requiredText(l10n.validationRequired)
                  : null,
              onChanged: (_) => _clearDuplicateState(),
            ),
            right: AppPhoneField(
              controller: _phoneController,
              enabled: fieldsEnabled,
              labelText: l10n.profilePhoneLabel,
              countryLabelText: l10n.appPhoneCountryLabel,
              countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
              countryNoResultsText: l10n.appPhoneCountryNoResults,
              numberLabelText: l10n.appPhoneNumberLabel,
              numberHintText: l10n.appPhoneNumberHint,
              invalidPhoneMessage: l10n.appPhoneInvalidMessage,
              requiredMessage: l10n.validationRequired,
              isRequired: widget.isCreate,
              onChanged: (_) => _clearDuplicateState(),
            ),
          ),
          AppResponsiveFieldRow.two(
            gap: AppResponsiveFieldRowGap.form,
            left: AppEmailField(
              controller: _emailController,
              enabled: fieldsEnabled,
              labelText: l10n.profileEmailLabel,
              requiredMessage: l10n.validationRequired,
              invalidEmailMessage: l10n.authEmailInvalidMessage,
              isRequired: widget.isCreate,
              onChanged: (_) => _clearDuplicateState(),
            ),
            right: AppCurrencySelectField(
              value: _currency,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityDefaultCurrencyLabel,
              helperText: l10n.tenantFacilityTenantDefaultCurrencyHelper,
              onChanged: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return;
                }
                setState(() {
                  _currency = value.trim().toUpperCase();
                });
                _clearDuplicateState();
              },
            ),
          ),
          AppCurrencyAmountField(
            amountController: _feeController,
            currency: resolvedCurrency,
            onCurrencyChanged: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return;
              }
              setState(() {
                _currency = value.trim().toUpperCase();
              });
              _clearDuplicateState();
            },
            amountLabelText: l10n.settingsConfigurationConsultationFeeLabel,
            currencyLabelText: l10n.tenantFacilityDefaultCurrencyLabel,
            helperText: l10n.settingsConfigurationConsultationFeeHelper,
            enabled: fieldsEnabled,
            onAmountChanged: (_) => _clearDuplicateState(),
          ),
          if (!widget.hideSubmitButton)
            _SubmitButton(
              enabled: widget.canSubmit,
              isLoading: submission.isSubmitting,
              label: widget.isCreate
                  ? l10n.tenantFacilityCreateTenantAction
                  : l10n.tenantFacilitySaveTenantAction,
              onPressed: _submit,
              permissionDeniedMessage: widget.permissionDeniedMessage,
            )
          else
            _SubmissionFeedback(
              enabled: widget.canSubmit,
              failure: _inlineSubmissionFailure(submission.failure),
              permissionDeniedMessage: widget.permissionDeniedMessage,
            ),
        ],
      ),
    );

    if (widget.framed) {
      return AppScreenSection(
        title: widget.isCreate
            ? l10n.tenantFacilityCreateTenantTitle
            : l10n.tenantFacilityTenantSectionTitle,
        body: sectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          sectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
    );
  }

  Future<bool> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return false;
    }

    final bool canProceed = await _guardAgainstDuplicates();
    if (!canProceed) {
      return false;
    }

    final String fee = _feeController.text.trim();
    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenant(
          id: widget.isCreate ? null : widget.tenant?.mutationId,
          name: _nameController.text,
          slug: _slugController.text,
          isActive: _isActive,
          currency: resolveDefaultCurrency(tenantCurrency: _currency),
          standardConsultationFee: fee.isEmpty ? null : fee,
          clearStandardConsultationFee: fee.isEmpty,
          contactName: _contactNameController.text,
          contactEmail: _emailController.text,
          contactPhone: _phoneController.text,
          confirmSimilar: _similarityAccepted,
          refreshSetup: widget.refreshSetupAfterSave,
          updateSetupSnapshot: widget.updateSetupSnapshot,
        );
    if (!mounted) {
      return false;
    }
    if (saved) {
      return true;
    }

    final AppFailure? failure = ref
        .read(tenantFacilitySetupSubmissionProvider)
        .failure;
    if (!_isTenantSimilarityConflict(failure)) {
      return false;
    }

    // Backend similarity is authoritative. Clear the inline conflict message and
    // reopen the dedicated results dialog so the user can review and confirm.
    ref.read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();
    setState(() {
      _similarityAccepted = false;
    });
    final bool confirmed = await _guardAgainstDuplicates(
      forceReviewMatches: true,
    );
    if (!confirmed || !mounted) {
      return false;
    }
    return ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenant(
          id: widget.isCreate ? null : widget.tenant?.mutationId,
          name: _nameController.text,
          slug: _slugController.text,
          isActive: _isActive,
          currency: resolveDefaultCurrency(tenantCurrency: _currency),
          standardConsultationFee: fee.isEmpty ? null : fee,
          clearStandardConsultationFee: fee.isEmpty,
          contactName: _contactNameController.text,
          contactEmail: _emailController.text,
          contactPhone: _phoneController.text,
          confirmSimilar: true,
          refreshSetup: widget.refreshSetupAfterSave,
          updateSetupSnapshot: widget.updateSetupSnapshot,
        );
  }

  AppFailure? _inlineSubmissionFailure(AppFailure? failure) {
    if (_isTenantSimilarityConflict(failure)) {
      return null;
    }
    return failure;
  }

  bool _isTenantSimilarityConflict(AppFailure? failure) {
    if (failure == null || failure.category != AppFailureCategory.conflict) {
      return false;
    }
    final String detail = (failure.detailMessage ?? '').toLowerCase();
    return detail.contains('similar tenant') ||
        detail.contains('confirm to create anyway') ||
        detail.contains('duplicate_slug') ||
        failure.validationFields.contains('slug') ||
        failure.validationFields.contains('name');
  }

  TenantSimilarityProposedValues _proposedValues() {
    return TenantSimilarityProposedValues(
      name: _nameController.text.trim(),
      slug: _slugController.text.trim().isEmpty
          ? null
          : _slugController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty
          ? null
          : _contactNameController.text.trim(),
      contactPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      contactEmail: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      currency: resolveDefaultCurrency(tenantCurrency: _currency),
      standardConsultationFee: _feeController.text.trim().isEmpty
          ? null
          : _feeController.text.trim(),
    );
  }

  Future<bool> _guardAgainstDuplicates({
    bool forceReviewMatches = false,
  }) async {
    final List<TenantProfile> existing = await _loadExistingTenants();
    final TenantDuplicateCheckResult result = checkTenantDuplicates(
      name: _nameController.text,
      slug: _slugController.text,
      existing: existing,
      excludeTenantId: widget.tenant?.mutationId ?? widget.tenant?.id,
      contactName: _contactNameController.text,
      contactEmail: _emailController.text,
      contactPhone: _phoneController.text,
      currency: resolveDefaultCurrency(tenantCurrency: _currency),
      standardConsultationFee: _feeController.text,
    );

    final bool exactSlugConflict = result.exactSlugConflict;
    final List<TenantSimilarityMatch> reviewMatches = exactSlugConflict
        ? result.similarMatches
              .where((TenantSimilarityMatch match) => match.exactSlugConflict)
              .toList(growable: false)
        : result.overridableMatches;

    if (!mounted) {
      return false;
    }

    // Edit saves with no conflicting peers should not open the empty review
    // dialog; create still shows the no-similar confirmation path.
    if (!widget.isCreate &&
        !forceReviewMatches &&
        !exactSlugConflict &&
        reviewMatches.isEmpty) {
      setState(() {
        _nameErrorText = null;
        _slugErrorText = null;
        _similarMatches = const <TenantSimilarityMatch>[];
        _similarityAccepted = false;
      });
      return true;
    }

    setState(() {
      _nameErrorText = null;
      _slugErrorText = exactSlugConflict
          ? context.l10n.tenantFacilityTenantSlugAlreadyInUse
          : null;
      _similarMatches = const <TenantSimilarityMatch>[];
      if (exactSlugConflict) {
        _similarityAccepted = false;
      }
    });

    final TenantSimilarityDialogResult decision =
        await showTenantSimilarityDialog(
          context,
          proposed: _proposedValues(),
          matches: reviewMatches,
          allowProceed: !exactSlugConflict,
        );
    if (!mounted) {
      return false;
    }

    switch (decision.action) {
      case TenantSimilarityAction.cancel:
        setState(() {
          _similarityAccepted = false;
        });
        return false;
      case TenantSimilarityAction.useExisting:
        final TenantProfile? existingTenant = decision.selectedTenant;
        if (existingTenant != null) {
          Navigator.of(context).pop<TenantProfile>(existingTenant);
        }
        return false;
      case TenantSimilarityAction.proceed:
        setState(() {
          _similarityAccepted = reviewMatches.isNotEmpty || forceReviewMatches;
          _nameErrorText = null;
          _slugErrorText = null;
        });
        return true;
    }
  }

  Future<List<TenantProfile>> _loadExistingTenants() async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final String name = _nameController.text.trim();
    final String slug = _slugController.text.trim();
    final Set<String> seenIds = <String>{};
    final List<TenantProfile> tenants = <TenantProfile>[];

    Future<void> appendMatches(String? search) async {
      final Result<AppPage<TenantProfile>> result = await repository
          .listTenants(request: _duplicateLookupRequest, search: search);
      result.when(
        success: (AppPage<TenantProfile> page) {
          for (final TenantProfile tenant in page.items) {
            if (seenIds.add(tenant.id)) {
              tenants.add(tenant);
            }
          }
        },
        failure: (_) {},
      );
    }

    // Always include an unfiltered page so sparse name/slug searches do not
    // miss candidates the backend similarity check would still catch.
    await appendMatches(null);
    if (name.isNotEmpty) {
      await appendMatches(name);
    }
    if (slug.isNotEmpty && slug != name) {
      await appendMatches(slug);
    }

    return tenants;
  }
}

class _FacilityProfileForm extends ConsumerStatefulWidget {
  const _FacilityProfileForm({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
    this.tenantId,
    this.facility,
    this.requireTenantPicker = false,
    this.hideSubmitButton = false,
    this.refreshSetupAfterSave = true,
    this.registerSubmitHandler,
    this.onDialogStateChanged,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;
  final String? tenantId;
  final FacilityProfile? facility;
  final bool requireTenantPicker;
  final bool hideSubmitButton;
  final bool refreshSetupAfterSave;
  final _ProfileFormSubmitRegistrar? registerSubmitHandler;
  final VoidCallback? onDialogStateChanged;

  @override
  ConsumerState<_FacilityProfileForm> createState() =>
      _FacilityProfileFormState();
}

class _FacilityProfileFormState extends ConsumerState<_FacilityProfileForm> {
  static const AppPageRequest _duplicateLookupRequest = AppPageRequest(
    pageSize: 100,
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressLineController;
  late final TextEditingController _cityController;
  late FacilitySetupType _type;
  late bool _isActive;
  late String _currency;
  String? _existingLogoUrl;
  String? _logoFileName;
  List<int>? _logoBytes;
  String? _logoMimeType;
  bool _logoCleared = false;
  AppImageUploadPendingItem? _pendingLogoItem;
  String? _selectedTenantId;
  String? _selectedCountry;
  List<TenantProfile> _tenantOptions = const <TenantProfile>[];
  bool _loadingTenants = false;
  bool _loadingContact = false;
  AppFailure? _tenantLoadFailure;
  String? _nameErrorText;
  List<FacilitySimilarityMatch> _similarMatches =
      const <FacilitySimilarityMatch>[];
  bool _similarityAccepted = false;

  String _baselineName = '';
  FacilitySetupType _baselineType = FacilitySetupType.hospital;
  bool _baselineIsActive = true;
  String _baselineCurrency = appDefaultCurrencyCode;
  String? _baselinePhone;
  String? _baselineEmail;
  String? _baselineAddressLine1;
  String? _baselineCity;
  String? _baselineCountry;
  String? _baselineLogoUrl;

  FacilityProfile? get _activeFacility => widget.facility;

  bool get _isCreate => widget.facility == null;

  String? get _resolvedTenantId {
    if (widget.requireTenantPicker) {
      return _selectedTenantId ?? widget.tenantId;
    }

    return _selectedTenantId ??
        widget.tenantId ??
        widget.snapshot.tenant?.mutationId ??
        widget.snapshot.tenant?.id ??
        _activeFacility?.tenantId;
  }

  /// Prefer a UUID mutation id when the selected tenant is known by public id.
  String _resolveMutationTenantId(String tenantId) {
    final String normalized = tenantId.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    final TenantProfile? fromOptions = _tenantOptions
        .where(
          (TenantProfile tenant) =>
              tenant.id == normalized ||
              tenant.mutationId == normalized ||
              tenant.displayId == normalized ||
              tenant.slug == normalized,
        )
        .firstOrNull;
    if (fromOptions != null) {
      return fromOptions.mutationId;
    }

    final TenantProfile? fromSnapshot = widget.snapshot.tenant;
    if (fromSnapshot != null &&
        (fromSnapshot.id == normalized ||
            fromSnapshot.mutationId == normalized ||
            fromSnapshot.displayId == normalized ||
            fromSnapshot.slug == normalized)) {
      return fromSnapshot.mutationId;
    }

    return normalized;
  }

  bool get _hasSelectedTenant => (_resolvedTenantId ?? '').trim().isNotEmpty;

  bool _canSave() => widget.canSubmit && _hasSelectedTenant;

  @override
  void initState() {
    super.initState();
    final FacilityProfile? facility = _activeFacility;
    // Create must start blank — never inherit contact/logo from setup snapshot.
    final FacilityContactAddress contact = _isCreate
        ? const FacilityContactAddress()
        : widget.snapshot.contactAddress;
    _selectedTenantId =
        widget.tenantId ??
        (_isCreate ? null : widget.snapshot.tenant?.id) ??
        facility?.tenantId;
    _nameController = TextEditingController(text: facility?.name ?? '');
    _existingLogoUrl = facility?.logoUrl;
    _phoneController = TextEditingController(text: contact.phone ?? '');
    _emailController = TextEditingController(text: contact.email ?? '');
    _addressLineController = TextEditingController(
      text: contact.addressLine1 ?? '',
    );
    _cityController = TextEditingController(text: contact.city ?? '');
    _selectedCountry = contact.country;
    _type = facility?.type ?? FacilitySetupType.hospital;
    _isActive = facility?.isActive ?? true;
    _currency = resolveDefaultCurrency(
      facilityCurrency: facility?.currency,
      tenantCurrency: widget.snapshot.tenant?.currency,
    );
    _captureBaseline();
    _nameController.addListener(_handleNameChanged);
    if (widget.requireTenantPicker) {
      unawaited(_loadTenantOptions());
    }
    if (!_isCreate) {
      unawaited(_hydrateEditContact());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerWithDialog();
    });
  }

  void _captureBaseline() {
    _baselineName = _nameController.text.trim();
    _baselineType = _type;
    _baselineIsActive = _isActive;
    _baselineCurrency = _currency.trim().toUpperCase();
    _baselinePhone = _normalizedOptional(_phoneController.text);
    _baselineEmail = _normalizedOptional(_emailController.text);
    _baselineAddressLine1 = _normalizedOptional(_addressLineController.text);
    _baselineCity = _normalizedOptional(_cityController.text);
    _baselineCountry = _normalizedOptional(_selectedCountry);
    _baselineLogoUrl = _logoCleared
        ? null
        : _normalizedOptional(_existingLogoUrl);
  }

  static String? _normalizedOptional(String? value) {
    final String? normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _coalescePreserved(String current, String? baseline) {
    final String? normalized = _normalizedOptional(current);
    if (normalized != null) {
      return normalized;
    }
    return baseline ?? '';
  }

  String? _coalesceOptionalPreserved(String? current, String? baseline) {
    final String? normalized = _normalizedOptional(current);
    return normalized ?? baseline;
  }

  Future<void> _hydrateEditContact() async {
    final FacilityProfile? facility = _activeFacility;
    if (facility == null) {
      return;
    }
    final FacilityProfile editingFacility = facility;

    final FacilityContactAddress existing = widget.snapshot.contactAddress;
    final bool contactMissing =
        _normalizedOptional(existing.phone) == null &&
        _normalizedOptional(existing.email) == null &&
        _normalizedOptional(existing.addressLine1) == null &&
        _normalizedOptional(existing.city) == null &&
        _normalizedOptional(existing.country) == null;
    final bool logoMissing = _normalizedOptional(_existingLogoUrl) == null;

    if (!contactMissing && !logoMissing) {
      _captureBaseline();
      return;
    }

    setState(() {
      _loadingContact = true;
    });

    final Result<FacilitySetupSnapshot> result = await ref
        .read(tenantFacilityRepositoryProvider)
        .loadSetup(
          facilityId: editingFacility.mutationId,
          tenantId: editingFacility.tenantId,
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (FacilitySetupSnapshot snapshot) {
        final FacilityContactAddress contact = snapshot.contactAddress;
        final FacilityProfile loadedFacility =
            snapshot.facility ?? editingFacility;
        setState(() {
          _loadingContact = false;
          if (_normalizedOptional(_nameController.text) == null &&
              loadedFacility.name.trim().isNotEmpty) {
            _nameController.text = loadedFacility.name;
          }
          _type = loadedFacility.type;
          _isActive = loadedFacility.isActive;
          _currency = resolveDefaultCurrency(
            facilityCurrency: loadedFacility.currency,
            tenantCurrency:
                snapshot.tenant?.currency ?? widget.snapshot.tenant?.currency,
          );
          if (logoMissing) {
            _existingLogoUrl = loadedFacility.logoUrl;
          }
          if (contactMissing) {
            _phoneController.text = contact.phone ?? '';
            _emailController.text = contact.email ?? '';
            _addressLineController.text = contact.addressLine1 ?? '';
            _cityController.text = contact.city ?? '';
            _selectedCountry = contact.country;
          }
          _captureBaseline();
        });
        _notifyDialogState();
      },
      failure: (_) {
        setState(() {
          _loadingContact = false;
        });
        _captureBaseline();
      },
    );
  }

  void _registerWithDialog() {
    widget.registerSubmitHandler?.call(
      _submit,
      canSave: _canSave,
      onFormStateChanged: widget.onDialogStateChanged,
    );
  }

  void _handleNameChanged() {
    if (_nameErrorText != null ||
        _similarMatches.isNotEmpty ||
        _similarityAccepted) {
      setState(() {
        _nameErrorText = null;
        _similarMatches = const <FacilitySimilarityMatch>[];
        _similarityAccepted = false;
      });
      widget.onDialogStateChanged?.call();
    }
  }

  void _notifyDialogState() {
    if (!mounted) {
      return;
    }
    _registerWithDialog();
    widget.onDialogStateChanged?.call();
  }

  Future<void> _loadTenantOptions() async {
    setState(() {
      _loadingTenants = true;
      _tenantLoadFailure = null;
    });
    final result = await ref
        .read(tenantFacilityRepositoryProvider)
        .listTenants(request: const AppPageRequest(pageSize: 100));
    if (!mounted) return;
    result.when(
      success: (AppPage<TenantProfile> page) {
        setState(() {
          _loadingTenants = false;
          _tenantOptions = page.items;
          if (widget.tenantId != null && widget.tenantId!.trim().isNotEmpty) {
            _selectedTenantId = widget.tenantId;
          }
        });
        _notifyDialogState();
      },
      failure: (AppFailure failure) {
        setState(() {
          _loadingTenants = false;
          _tenantLoadFailure = failure;
        });
        _notifyDialogState();
      },
    );
  }

  @override
  void didUpdateWidget(_FacilityProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hideSubmitButton) {
      return;
    }
    if (oldWidget.snapshot.facility?.id != widget.snapshot.facility?.id) {
      _nameController.text = widget.snapshot.facility?.name ?? '';
      _existingLogoUrl = widget.snapshot.facility?.logoUrl;
      _logoFileName = null;
      _logoBytes = null;
      _logoMimeType = null;
      _logoCleared = false;
      _pendingLogoItem = null;
      _phoneController.text = widget.snapshot.contactAddress.phone ?? '';
      _emailController.text = widget.snapshot.contactAddress.email ?? '';
      _addressLineController.text =
          widget.snapshot.contactAddress.addressLine1 ?? '';
      _cityController.text = widget.snapshot.contactAddress.city ?? '';
      _selectedCountry = widget.snapshot.contactAddress.country;
      _type = widget.snapshot.facility?.type ?? FacilitySetupType.hospital;
      _isActive = widget.snapshot.facility?.isActive ?? true;
      _currency = resolveDefaultCurrency(
        facilityCurrency: widget.snapshot.facility?.currency,
        tenantCurrency: widget.snapshot.tenant?.currency,
      );
      _captureBaseline();
      _notifyDialogState();
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (!_hasSelectedTenant) {
      return;
    }
    final String facilityName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_activeFacility?.name ?? 'facility');
    final AppImageUploadPendingItem? picked = await pickAppImageFile(
      context.l10n,
      context: context,
      typeGroupLabel: 'facility-logo',
      showCropAspectPresets: true,
      preferredFileName: buildFacilityLogoFileName(facilityName),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _pendingLogoItem = picked;
      _logoFileName = picked.fileName;
      _logoBytes = picked.bytes;
      _logoMimeType = picked.mimeType;
      _logoCleared = false;
    });
  }

  void _clearLogo() {
    setState(() {
      _pendingLogoItem = null;
      _logoFileName = null;
      _logoBytes = null;
      _logoMimeType = null;
      _existingLogoUrl = null;
      _logoCleared = true;
    });
  }

  List<AppImageUploadPendingItem> get _pendingLogoItems {
    if (_pendingLogoItem == null) {
      return const <AppImageUploadPendingItem>[];
    }
    return <AppImageUploadPendingItem>[_pendingLogoItem!];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEditBase = widget.canSubmit && !submission.isSubmitting;
    final bool fieldsEnabled =
        canEditBase && _hasSelectedTenant && !_loadingContact;
    final bool requireFields = _isCreate;

    final Widget form = Form(
      key: _formKey,
      child: AppFormSection(
        children: <Widget>[
          if (_loadingContact)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.requireTenantPicker) ...<Widget>[
            if (_loadingTenants)
              const Center(child: CircularProgressIndicator())
            else if (_tenantLoadFailure != null)
              AppFailureStateView(
                failure: _tenantLoadFailure!,
                onRetry: () => unawaited(_loadTenantOptions()),
              )
            else
              AppSelectField<String>.searchable(
                value: _selectedTenantId,
                enabled: canEditBase,
                labelText: l10n.tenantFacilitySelectTenantLabel,
                isRequired: true,
                menuHeight: 320,
                options: _tenantOptions
                    .map(
                      (TenantProfile tenant) => AppSelectOption<String>(
                        value: tenant.id,
                        label: tenant.name,
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  setState(() {
                    _selectedTenantId = value;
                  });
                  _notifyDialogState();
                },
                validator: (String? value) => (value ?? '').trim().isEmpty
                    ? l10n.validationRequired
                    : null,
              ),
            if (_tenantOptions.isEmpty &&
                !_loadingTenants &&
                _tenantLoadFailure == null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                l10n.tenantFacilitySelectTenantLoadError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
          ],
          if (widget.snapshot.facilities.length > 1 && widget.facility == null)
            AppSelectField<String>.searchable(
              value: widget.snapshot.facility?.id,
              enabled: !submission.isSubmitting,
              labelText: l10n.tenantFacilityFacilitySelectLabel,
              menuHeight: 320,
              options: <AppSelectOption<String>>[
                for (final FacilityProfile facility
                    in widget.snapshot.facilities)
                  AppSelectOption<String>(
                    value: facility.id,
                    label: facility.name,
                  ),
              ],
              onChanged: (String? value) {
                if (value == null || value == widget.snapshot.facility?.id) {
                  return;
                }
                ref
                    .read(tenantFacilitySetupControllerProvider.notifier)
                    .selectFacility(value);
              },
            ),
          if (_similarMatches.isNotEmpty)
            AppFormInformationBanner(
              title: context.l10n.tenantFacilitySimilarFacilityWarningTitle,
              message: context.l10n.tenantFacilitySimilarFacilityWarningBody,
              variant: AppFormInformationVariant.warning,
              icon: Icons.content_copy_outlined,
              children: <Widget>[
                for (final FacilitySimilarityMatch match
                    in _similarMatches.take(3))
                  Padding(
                    padding: EdgeInsets.only(
                      top: Theme.of(context).spacing.xs,
                    ),
                    child: Text(
                      context.l10n.tenantFacilitySimilarFacilityScoreLabel(
                        match.score,
                      ),
                    ),
                  ),
              ],
            ),
          AppTextField(
            controller: _nameController,
            enabled: fieldsEnabled,
            labelText: l10n.authFacilityNameLabel,
            isRequired: requireFields,
            textCapitalization: TextCapitalization.words,
            errorText: _nameErrorText,
            validator: requireFields
                ? AppValidators.requiredText(l10n.validationRequired)
                : null,
          ),
          AppSelectField<FacilitySetupType>(
            value: _type,
            enabled: fieldsEnabled,
            labelText: l10n.authFacilityTypeLabel,
            isRequired: requireFields,
            options: <AppSelectOption<FacilitySetupType>>[
              for (final type in FacilitySetupType.values)
                AppSelectOption<FacilitySetupType>(
                  value: type,
                  label: tenantFacilityFacilityTypeLabel(l10n, type),
                  leadingIcon: Icon(tenantFacilityFacilityTypeIcon(type)),
                ),
            ],
            onChanged: (FacilitySetupType? value) {
              if (value != null) {
                setState(() {
                  _type = value;
                });
              }
            },
          ),
          AppCurrencySelectField(
            value: _currency,
            enabled: fieldsEnabled,
            labelText: l10n.tenantFacilityDefaultCurrencyLabel,
            helperText: l10n.tenantFacilityDefaultCurrencyHelper,
            onChanged: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return;
              }
              setState(() {
                _currency = value.trim().toUpperCase();
              });
            },
          ),
          AppImageUploadField(
            label: l10n.tenantFacilityLogoLabel,
            helperText: l10n.tenantFacilityLogoHelper,
            chooseLabel: l10n.tenantFacilityChooseLogoAction,
            removeLabel: l10n.tenantFacilityRemoveLogoAction,
            enabled: fieldsEnabled,
            existingImageUrl: _logoCleared ? null : _existingLogoUrl,
            pendingItems: _pendingLogoItems,
            previewSize: 104,
            onChoose: _pickLogo,
            onClear: fieldsEnabled ? _clearLogo : null,
          ),
          AppPhoneField(
            controller: _phoneController,
            enabled: fieldsEnabled,
            labelText: l10n.profilePhoneLabel,
            countryLabelText: l10n.appPhoneCountryLabel,
            countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
            countryNoResultsText: l10n.appPhoneCountryNoResults,
            numberLabelText: l10n.appPhoneNumberLabel,
            numberHintText: l10n.appPhoneNumberHint,
            invalidPhoneMessage: l10n.appPhoneInvalidMessage,
            requiredMessage: l10n.validationRequired,
            isRequired: requireFields,
          ),
          AppEmailField(
            controller: _emailController,
            enabled: fieldsEnabled,
            labelText: l10n.profileEmailLabel,
            isRequired: requireFields,
            requiredMessage: l10n.validationRequired,
            invalidEmailMessage: l10n.authEmailInvalidMessage,
          ),
          AppTextField(
            controller: _addressLineController,
            enabled: fieldsEnabled,
            labelText: l10n.tenantFacilityAddressLineLabel,
            textCapitalization: TextCapitalization.words,
          ),
          _TwoColumnFields(
            left: AppTextField(
              controller: _cityController,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityCityLabel,
              textCapitalization: TextCapitalization.words,
            ),
            right: AppCountryField(
              value: _selectedCountry,
              enabled: fieldsEnabled,
              labelText: l10n.tenantFacilityCountryLabel,
              onChanged: (String? value) {
                setState(() {
                  _selectedCountry = value;
                });
              },
            ),
          ),
          AppSwitchField(
            title: l10n.tenantFacilityActiveLabel,
            value: _isActive,
            enabled: fieldsEnabled,
            onChanged: (bool value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
          if (!widget.hideSubmitButton)
            _SubmitButton(
              enabled: widget.canSubmit && _hasSelectedTenant,
              isLoading: submission.isSubmitting,
              label: _isCreate
                  ? l10n.tenantFacilitySaveFacilityAction
                  : l10n.tenantFacilityEditFacilityAction,
              onPressed: _submit,
            )
          else
            _SubmissionFeedback(
              enabled: widget.canSubmit && _hasSelectedTenant,
              failure: submission.failure,
            ),
        ],
      ),
    );

    if (widget.framed) {
      return AppScreenSection(
        title: _isCreate
            ? l10n.tenantFacilityCreateFacilityTitle
            : l10n.tenantFacilityEditFacilityTitle,
        body: l10n.tenantFacilityFacilitySectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _isCreate
              ? l10n.tenantFacilityCreateFacilityTitle
              : l10n.tenantFacilityEditFacilityTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          l10n.tenantFacilityFacilitySectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
    );
  }

  Future<bool> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return false;
    }

    final String? tenantId = _resolvedTenantId;
    if (tenantId == null) {
      return false;
    }

    final String resolvedName = _isCreate
        ? _nameController.text.trim()
        : _coalescePreserved(_nameController.text, _baselineName);
    if (resolvedName.isEmpty) {
      setState(() {
        _nameErrorText = context.l10n.validationRequired;
      });
      return false;
    }

    final String? resolvedPhone = _isCreate
        ? _normalizedOptional(_phoneController.text)
        : _coalesceOptionalPreserved(_phoneController.text, _baselinePhone);
    final String? resolvedEmail = _isCreate
        ? _normalizedOptional(_emailController.text)
        : _coalesceOptionalPreserved(_emailController.text, _baselineEmail);
    final String? resolvedAddress = _isCreate
        ? _normalizedOptional(_addressLineController.text)
        : _coalesceOptionalPreserved(
            _addressLineController.text,
            _baselineAddressLine1,
          );
    final String? resolvedCity = _isCreate
        ? _normalizedOptional(_cityController.text)
        : _coalesceOptionalPreserved(_cityController.text, _baselineCity);
    final String? resolvedCountry = _isCreate
        ? _normalizedOptional(_selectedCountry)
        : _coalesceOptionalPreserved(_selectedCountry, _baselineCountry);
    final String? resolvedLogoUrl = _logoCleared
        ? null
        : (_normalizedOptional(_existingLogoUrl) ?? _baselineLogoUrl);

    if (!_isCreate) {
      final List<_FacilityFieldChange> changes = _buildFacilityChanges(
        name: resolvedName,
        type: _type,
        isActive: _isActive,
        currency: _currency.trim().toUpperCase(),
        phone: resolvedPhone,
        email: resolvedEmail,
        addressLine1: resolvedAddress,
        city: resolvedCity,
        country: resolvedCountry,
        logoChanged: _logoCleared || _logoBytes != null,
        logoCleared: _logoCleared,
        logoReplaced: _logoBytes != null,
      );
      if (changes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.tenantFacilityNoFacilityChangesMessage,
                ),
              ),
            );
        }
        return false;
      }

      final bool confirmed = await _confirmFacilityChanges(changes);
      if (!confirmed) {
        return false;
      }
    }

    final bool canProceed = await _guardAgainstDuplicates(
      tenantId,
      name: resolvedName,
      phone: resolvedPhone,
      email: resolvedEmail,
      addressLine1: resolvedAddress,
      city: resolvedCity,
      country: resolvedCountry,
    );
    if (!canProceed) {
      return false;
    }

    final FacilityProfile? editingFacility = widget.facility ?? _activeFacility;
    final String resolvedTenantId = _resolveMutationTenantId(tenantId);
    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacility(
          id: editingFacility?.mutationId ?? editingFacility?.id,
          tenantId: resolvedTenantId,
          name: resolvedName,
          type: _type,
          isActive: _isActive,
          logoUrl: resolvedLogoUrl,
          removeLogo: _logoCleared,
          currency: _currency.trim().toUpperCase(),
          logoBytes: _logoBytes,
          logoFileName: _logoFileName,
          logoMimeType: _logoMimeType,
          phone: resolvedPhone,
          email: resolvedEmail,
          addressLine1: resolvedAddress,
          city: resolvedCity,
          country: resolvedCountry,
          confirmSimilar: _similarityAccepted,
          refreshSetup: widget.refreshSetupAfterSave,
        );

    if (saved) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final AppFailure? failure = ref
        .read(tenantFacilitySetupSubmissionProvider)
        .failure;
    if (failure?.messageKey == 'errors.facility.duplicate_name') {
      setState(() {
        _nameErrorText = context.l10n.tenantFacilityFacilityNameAlreadyInUse;
      });
      return false;
    }
    if (!_isFacilitySimilarityConflict(failure)) {
      return false;
    }

    ref.read(tenantFacilitySetupSubmissionProvider.notifier).clearFailure();
    setState(() {
      _similarityAccepted = false;
    });
    final bool confirmed = await _guardAgainstDuplicates(
      tenantId,
      name: resolvedName,
      phone: resolvedPhone,
      email: resolvedEmail,
      addressLine1: resolvedAddress,
      city: resolvedCity,
      country: resolvedCountry,
      forceReviewMatches: true,
    );
    if (!confirmed || !mounted) {
      return false;
    }
    return ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacility(
          id: editingFacility?.mutationId ?? editingFacility?.id,
          tenantId: resolvedTenantId,
          name: resolvedName,
          type: _type,
          isActive: _isActive,
          logoUrl: resolvedLogoUrl,
          removeLogo: _logoCleared,
          currency: _currency.trim().toUpperCase(),
          logoBytes: _logoBytes,
          logoFileName: _logoFileName,
          logoMimeType: _logoMimeType,
          phone: resolvedPhone,
          email: resolvedEmail,
          addressLine1: resolvedAddress,
          city: resolvedCity,
          country: resolvedCountry,
          confirmSimilar: true,
          refreshSetup: widget.refreshSetupAfterSave,
        );
  }

  bool _isFacilitySimilarityConflict(AppFailure? failure) {
    if (failure == null || failure.category != AppFailureCategory.conflict) {
      return false;
    }
    if (failure.messageKey == 'errors.facility.similar_exists') {
      return true;
    }
    final String detail = (failure.detailMessage ?? '').toLowerCase();
    return detail.contains('similar facility') ||
        detail.contains('confirm to create anyway');
  }

  List<_FacilityFieldChange> _buildFacilityChanges({
    required String name,
    required FacilitySetupType type,
    required bool isActive,
    required String currency,
    required String? phone,
    required String? email,
    required String? addressLine1,
    required String? city,
    required String? country,
    required bool logoChanged,
    required bool logoCleared,
    required bool logoReplaced,
  }) {
    final AppLocalizations l10n = context.l10n;
    final List<_FacilityFieldChange> changes = <_FacilityFieldChange>[];

    void addChange(String label, String? previous, String? next) {
      final String previousValue = (previous ?? '').trim();
      final String nextValue = (next ?? '').trim();
      if (previousValue == nextValue) {
        return;
      }
      changes.add(
        _FacilityFieldChange(
          label: label,
          previousValue: previousValue.isEmpty ? '—' : previousValue,
          nextValue: nextValue.isEmpty ? '—' : nextValue,
        ),
      );
    }

    addChange(l10n.authFacilityNameLabel, _baselineName, name);
    addChange(
      l10n.authFacilityTypeLabel,
      tenantFacilityFacilityTypeLabel(l10n, _baselineType),
      tenantFacilityFacilityTypeLabel(l10n, type),
    );
    addChange(
      l10n.tenantFacilityActiveLabel,
      _baselineIsActive
          ? l10n.tenantFacilityStatusActive
          : l10n.tenantFacilityStatusInactive,
      isActive
          ? l10n.tenantFacilityStatusActive
          : l10n.tenantFacilityStatusInactive,
    );
    addChange(
      l10n.tenantFacilityDefaultCurrencyLabel,
      _baselineCurrency,
      currency,
    );
    addChange(l10n.profilePhoneLabel, _baselinePhone, phone);
    addChange(l10n.profileEmailLabel, _baselineEmail, email);
    addChange(
      l10n.tenantFacilityAddressLineLabel,
      _baselineAddressLine1,
      addressLine1,
    );
    addChange(l10n.tenantFacilityCityLabel, _baselineCity, city);
    addChange(l10n.tenantFacilityCountryLabel, _baselineCountry, country);
    if (logoChanged) {
      final String? previousUrl = _normalizedOptional(_baselineLogoUrl);
      final List<int>? nextBytes = logoReplaced ? _logoBytes : null;
      changes.add(
        _FacilityFieldChange(
          label: l10n.tenantFacilityLogoLabel,
          previousValue: previousUrl == null
              ? l10n.tenantFacilityFacilityDetailsNoLogo
              : l10n.tenantFacilityLogoLabel,
          nextValue: logoCleared
              ? l10n.tenantFacilityLogoRemovedLabel
              : l10n.tenantFacilityLogoAddedLabel,
          isLogo: true,
          previousLogoUrl: previousUrl,
          nextLogoBytes: nextBytes,
          logoCleared: logoCleared,
        ),
      );
    }

    return changes;
  }

  Future<bool> _confirmFacilityChanges(
    List<_FacilityFieldChange> changes,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme colorScheme = theme.colorScheme;
        return AppDialog(
          title: Text(l10n.tenantFacilityConfirmFacilityUpdateTitle),
          icon: const Icon(Icons.compare_arrows_outlined),
          scrollable: true,
          maxWidth: 720,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Text(
                          l10n.tenantFacilityConfirmFacilityUpdateBody,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilityFieldPreviousLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      l10n.tenantFacilityFieldNewLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              for (final _FacilityFieldChange change in changes) ...<Widget>[
                _FacilityChangeDiffCard(change: change),
                SizedBox(height: theme.spacing.sm),
              ],
            ],
          ),
          actions: <Widget>[
            AppButton.tertiary(
              label: l10n.commonCancelActionLabel,
              leadingIcon: Icons.close,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton.primary(
              label: l10n.tenantFacilityConfirmFacilityUpdateAction,
              leadingIcon: Icons.check,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<bool> _guardAgainstDuplicates(
    String tenantId, {
    required String name,
    String? phone,
    String? email,
    String? addressLine1,
    String? city,
    String? country,
    bool forceReviewMatches = false,
  }) async {
    final FacilityProfile? editingFacility = widget.facility ?? _activeFacility;

    // Edit saves with an unchanged identity should skip empty review.
    if (!_isCreate &&
        !forceReviewMatches &&
        editingFacility != null &&
        normalizeFacilityName(name) == normalizeFacilityName(_baselineName) &&
        _type == _baselineType &&
        _isActive == _baselineIsActive &&
        normalizeFacilityPhone(phone) == normalizeFacilityPhone(_baselinePhone) &&
        normalizeFacilityEmail(email) ==
            normalizeFacilityEmail(_baselineEmail) &&
        normalizeFacilityAddress(addressLine1) ==
            normalizeFacilityAddress(_baselineAddressLine1) &&
        normalizeFacilityAddress(city) ==
            normalizeFacilityAddress(_baselineCity) &&
        normalizeFacilityAddress(country) ==
            normalizeFacilityAddress(_baselineCountry)) {
      setState(() {
        _nameErrorText = null;
        _similarMatches = const <FacilitySimilarityMatch>[];
        _similarityAccepted = false;
      });
      return true;
    }

    final List<FacilityProfile> existing = await _loadExistingFacilities(
      tenantId,
    );
    final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
      name: name,
      type: _type,
      isActive: _isActive,
      existing: existing,
      excludeFacility: editingFacility,
      excludeFacilityId: editingFacility?.mutationId ?? editingFacility?.id,
      phone: phone,
      email: email,
      addressLine1: addressLine1,
      city: city,
      country: country,
    );

    final bool exactNameConflict = result.exactNameConflict;
    final List<FacilitySimilarityMatch> reviewMatches = exactNameConflict
        ? result.similarMatches
              .where((FacilitySimilarityMatch match) => match.exactNameConflict)
              .toList(growable: false)
        : result.overridableMatches;

    if (!mounted) {
      return false;
    }

    if (!_isCreate &&
        !forceReviewMatches &&
        !exactNameConflict &&
        reviewMatches.isEmpty) {
      setState(() {
        _nameErrorText = null;
        _similarMatches = const <FacilitySimilarityMatch>[];
        _similarityAccepted = false;
      });
      return true;
    }

    // Create always opens review (including zero matches). Edit only when
    // forced by backend conflict or local matches exist.
    if (!_isCreate && !forceReviewMatches && reviewMatches.isEmpty) {
      return true;
    }

    setState(() {
      _nameErrorText = exactNameConflict
          ? context.l10n.tenantFacilityFacilityNameAlreadyInUse
          : null;
      _similarMatches = const <FacilitySimilarityMatch>[];
      if (exactNameConflict) {
        _similarityAccepted = false;
      }
    });

    final FacilitySimilarityDialogResult decision =
        await showFacilitySimilarityDialog(
          context,
          proposed: FacilitySimilarityProposedValues(
            name: name,
            type: _type,
            isActive: _isActive,
            phone: phone,
            email: email,
            addressLine1: addressLine1,
            city: city,
            country: country,
          ),
          matches: reviewMatches,
          allowProceed: !exactNameConflict,
        );
    if (!mounted) {
      return false;
    }

    switch (decision.action) {
      case FacilitySimilarityAction.cancel:
        setState(() {
          _similarityAccepted = false;
          if (reviewMatches.isNotEmpty) {
            _similarMatches = reviewMatches;
          }
        });
        widget.onDialogStateChanged?.call();
        return false;
      case FacilitySimilarityAction.useExisting:
        final FacilityProfile? existingFacility = decision.selectedFacility;
        if (existingFacility != null) {
          Navigator.of(context).pop<FacilityProfile>(existingFacility);
        }
        return false;
      case FacilitySimilarityAction.proceed:
        setState(() {
          _similarityAccepted = reviewMatches.isNotEmpty || forceReviewMatches;
          _nameErrorText = null;
        });
        return true;
    }
  }

  Future<List<FacilityProfile>> _loadExistingFacilities(String tenantId) async {
    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final String name = _nameController.text.trim();
    final Set<String> seenIds = <String>{};
    final List<FacilityProfile> facilities = <FacilityProfile>[];

    Future<void> appendMatches(String? search) async {
      final Result<AppPage<FacilityProfile>> result = await repository
          .listFacilities(
            request: _duplicateLookupRequest,
            tenantId: tenantId,
            search: search,
          );
      result.when(
        success: (AppPage<FacilityProfile> page) {
          for (final FacilityProfile facility in page.items) {
            if (seenIds.add(facility.id)) {
              facilities.add(facility);
            }
          }
        },
        failure: (_) {},
      );
    }

    await appendMatches(name.isEmpty ? null : name);
    if (facilities.isEmpty) {
      await appendMatches(null);
    }

    return facilities;
  }
}

const String _noneSelection = tenantFacilityNoneSelection;

class _DepartmentSetupSection extends ConsumerStatefulWidget {
  const _DepartmentSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  ConsumerState<_DepartmentSetupSection> createState() =>
      _DepartmentSetupSectionState();
}

class _DepartmentSetupSectionState
    extends ConsumerState<_DepartmentSetupSection> {
  static const AppPageRequest _listRequest = AppPageRequest(
    pageSize: AppPageRequest.maxPageSize,
  );

  bool _loading = true;
  AppFailure? _failure;
  List<DepartmentProfile> _departments = const <DepartmentProfile>[];
  List<TenantProfile> _tenantOptions = const <TenantProfile>[];
  List<FacilityProfile> _facilityOptions = const <FacilityProfile>[];
  Map<String, String> _tenantNamesById = const <String, String>{};
  Map<String, String> _facilityNamesById = const <String, String>{};
  String? _tenantFilterId;
  String? _facilityFilterId;
  DepartmentSetupType? _typeFilter;
  bool? _isActiveFilter;
  int _reloadGeneration = 0;

  FacilitySetupSnapshot get snapshot => widget.snapshot;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant _DepartmentSetupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? oldFacilityId = oldWidget.snapshot.facility?.id;
    final String? nextFacilityId = widget.snapshot.facility?.id;
    final String? oldTenantId = oldWidget.snapshot.tenant?.id;
    final String? nextTenantId = widget.snapshot.tenant?.id;
    if (oldFacilityId != nextFacilityId || oldTenantId != nextTenantId) {
      unawaited(_reload());
    }
  }

  List<FacilityProfile> get _facilitiesForFilter {
    final String? tenantFilterId = _tenantFilterId?.trim();
    if (tenantFilterId == null || tenantFilterId.isEmpty) {
      return _facilityOptions
          .where((FacilityProfile facility) => !facility.isDeleted)
          .toList(growable: false);
    }
    return _facilityOptions
        .where(
          (FacilityProfile facility) =>
              !facility.isDeleted && facility.tenantId == tenantFilterId,
        )
        .toList(growable: false);
  }

  void _applyServerFilters(AppSearchBarFilterValue value) {
    final String? nextTenant = value.option(
      TenantFacilityDepartmentsFilterKeys.tenant,
    );
    final String? nextFacility = value.option(
      TenantFacilityDepartmentsFilterKeys.facility,
    );
    final String? nextType = value.option(
      TenantFacilityDepartmentsFilterKeys.type,
    );
    final String? nextActive = value.option(
      TenantFacilityDepartmentsFilterKeys.active,
    );

    DepartmentSetupType? parsedType;
    if (nextType != null) {
      for (final DepartmentSetupType type in DepartmentSetupType.values) {
        if (type.apiValue == nextType) {
          parsedType = type;
          break;
        }
      }
    }

    final bool? parsedActive =
        nextActive == TenantFacilityDepartmentsFilterKeys.activeYes
        ? true
        : nextActive == TenantFacilityDepartmentsFilterKeys.activeNo
        ? false
        : null;

    _tenantFilterId = nextTenant;
    _facilityFilterId = nextFacility;
    _typeFilter = parsedType;
    _isActiveFilter = parsedActive;
    _syncFacilityFilterToOptions();
  }

  void _syncFacilityFilterToOptions() {
    final String? facilityId = _facilityFilterId;
    if (facilityId == null) {
      return;
    }
    final String? tenantFilterId = _tenantFilterId?.trim();
    final bool facilityAllowed = _facilityOptions.any((FacilityProfile facility) {
      if (facility.id != facilityId || facility.isDeleted) {
        return false;
      }
      if (tenantFilterId == null || tenantFilterId.isEmpty) {
        return true;
      }
      return facility.tenantId == tenantFilterId;
    });
    if (!facilityAllowed) {
      _facilityFilterId = null;
    }
  }

  Future<void> _onFiltersChanged(AppSearchBarFilterValue value) async {
    final String? previousTenant = _tenantFilterId;
    _applyServerFilters(value);
    final bool tenantChanged = previousTenant != _tenantFilterId;
    if (tenantChanged) {
      await _reloadFacilityOptions();
      _syncFacilityFilterToOptions();
    }
    await _reload(silent: true);
  }

  Future<void> _reloadFacilityOptions() async {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final TenantFacilityDepartmentsListScope scope =
        tenantFacilityDepartmentsListScope(policy);
    if (!tenantFacilityDepartmentsShowsFacilityFilter(scope)) {
      return;
    }

    final String? tenantId = switch (scope) {
      TenantFacilityDepartmentsListScope.platform => _tenantFilterId,
      TenantFacilityDepartmentsListScope.tenant ||
      TenantFacilityDepartmentsListScope.facility =>
        policy.tenantId ?? snapshot.tenant?.id,
    };

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );
    final Result<AppPage<FacilityProfile>> result = await repository
        .listFacilities(request: _listRequest, tenantId: tenantId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (AppPage<FacilityProfile> page) {
        setState(() {
          _facilityOptions = page.items;
          _facilityNamesById = <String, String>{
            for (final FacilityProfile facility in page.items)
              facility.id: facility.name,
          };
          if (_facilityFilterId != null &&
              !_facilitiesForFilter.any(
                (FacilityProfile facility) => facility.id == _facilityFilterId,
              )) {
            _facilityFilterId = null;
          }
        });
      },
      failure: (_) {},
    );
  }

  Future<void> _reload({bool silent = false}) async {
    final int generation = ++_reloadGeneration;
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final TenantFacilityDepartmentsListScope scope =
        tenantFacilityDepartmentsListScope(policy);
    final String? scopedTenantId = switch (scope) {
      TenantFacilityDepartmentsListScope.platform => _tenantFilterId,
      TenantFacilityDepartmentsListScope.tenant ||
      TenantFacilityDepartmentsListScope.facility =>
        policy.tenantId ?? snapshot.tenant?.id,
    };
    final String? scopedFacilityId =
        scope == TenantFacilityDepartmentsListScope.facility
        ? (policy.facilityId ?? snapshot.facility?.id)
        : _facilityFilterId;

    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }

    if (scope == TenantFacilityDepartmentsListScope.facility &&
        (scopedFacilityId == null || scopedFacilityId.trim().isEmpty)) {
      if (!mounted || generation != _reloadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _departments = const <DepartmentProfile>[];
        _facilityOptions = const <FacilityProfile>[];
        _tenantOptions = const <TenantProfile>[];
        _tenantNamesById = const <String, String>{};
        _facilityNamesById = const <String, String>{};
      });
      return;
    }

    final TenantFacilityRepository repository = ref.read(
      tenantFacilityRepositoryProvider,
    );

    final Future<Result<AppPage<TenantProfile>>>? tenantsFuture =
        tenantFacilityDepartmentsShowsTenantFilter(scope)
        ? repository.listTenants(request: _listRequest)
        : null;
    final Future<Result<AppPage<FacilityProfile>>>? facilitiesFuture =
        tenantFacilityDepartmentsShowsFacilityFilter(scope)
        ? repository.listFacilities(
            request: _listRequest,
            tenantId: scope == TenantFacilityDepartmentsListScope.platform
                ? _tenantFilterId
                : scopedTenantId,
          )
        : null;
    final Future<Result<AppPage<DepartmentProfile>>> departmentsFuture =
        repository.listDepartments(
          request: _listRequest,
          tenantId: scopedTenantId,
          facilityId: scopedFacilityId,
          type: _typeFilter,
          isActive: _isActiveFilter,
          includeDeleted: true,
        );

    final Result<AppPage<TenantProfile>>? tenantsResult = tenantsFuture == null
        ? null
        : await tenantsFuture;
    final Result<AppPage<FacilityProfile>>? facilitiesResult =
        facilitiesFuture == null ? null : await facilitiesFuture;
    final Result<AppPage<DepartmentProfile>> departmentsResult =
        await departmentsFuture;

    if (!mounted || generation != _reloadGeneration) {
      return;
    }

    departmentsResult.when(
      success: (AppPage<DepartmentProfile> page) {
        final Map<String, String> tenantNames = <String, String>{
          if (snapshot.tenant case final TenantProfile tenant)
            tenant.id: tenant.name,
        };
        List<TenantProfile> tenants = const <TenantProfile>[];
        tenantsResult?.when(
          success: (AppPage<TenantProfile> tenantsPage) {
            tenants = tenantsPage.items;
            for (final TenantProfile tenant in tenantsPage.items) {
              tenantNames[tenant.id] = tenant.name;
            }
          },
          failure: (_) {},
        );

        List<FacilityProfile> facilities = <FacilityProfile>[
          ...snapshot.facilities,
          if (snapshot.facility != null) snapshot.facility!,
        ];
        facilitiesResult?.when(
          success: (AppPage<FacilityProfile> facilitiesPage) {
            facilities = facilitiesPage.items;
          },
          failure: (_) {},
        );
        final Map<String, String> facilityNames = <String, String>{
          for (final FacilityProfile facility in facilities)
            facility.id: facility.name,
        };

        setState(() {
          _loading = false;
          _failure = null;
          _departments = page.items;
          _tenantOptions = tenants;
          _facilityOptions = facilities;
          _tenantNamesById = tenantNames;
          _facilityNamesById = facilityNames;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _loading = false;
          _failure = failure;
          if (!silent) {
            _departments = const <DepartmentProfile>[];
          }
        });
      },
    );
  }

  String _facilityLabel(DepartmentProfile department) {
    final String? facilityId = department.facilityId?.trim();
    if (facilityId == null || facilityId.isEmpty) {
      return '—';
    }
    return _facilityNamesById[facilityId] ?? facilityId;
  }

  String _tenantLabel(DepartmentProfile department) {
    final String tenantId = department.tenantId.trim();
    if (tenantId.isEmpty) {
      return '—';
    }
    return _tenantNamesById[tenantId] ?? tenantId;
  }

  Future<void> _afterMutation(Future<void> Function() action) async {
    await action();
    if (!mounted) {
      return;
    }
    await _reload(silent: true);
  }

  List<AppSearchBarFilterGroup> _buildFilterGroups(AppLocalizations l10n) {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final TenantFacilityDepartmentsListScope scope =
        tenantFacilityDepartmentsListScope(policy);
    final List<FacilityProfile> facilities = _facilitiesForFilter;

    return <AppSearchBarFilterGroup>[
      if (tenantFacilityDepartmentsShowsTenantFilter(scope) &&
          _tenantOptions.isNotEmpty)
        AppSearchBarFilterGroup(
          key: TenantFacilityDepartmentsFilterKeys.tenant,
          label: l10n.profileTenantLabel,
          allLabel: l10n.commonAllLabel,
          choices: _tenantOptions
              .map(
                (TenantProfile tenant) => AppSearchBarFilterChoice(
                  value: tenant.id,
                  label: tenant.name,
                  icon: Icons.apartment_outlined,
                ),
              )
              .toList(growable: false),
        ),
      if (tenantFacilityDepartmentsShowsFacilityFilter(scope) &&
          facilities.isNotEmpty)
        AppSearchBarFilterGroup(
          key: TenantFacilityDepartmentsFilterKeys.facility,
          label: l10n.profileFacilityLabel,
          allLabel: l10n.commonAllLabel,
          choices: facilities
              .map(
                (FacilityProfile facility) => AppSearchBarFilterChoice(
                  value: facility.id,
                  label: facility.name,
                  icon: Icons.local_hospital_outlined,
                ),
              )
              .toList(growable: false),
        ),
      AppSearchBarFilterGroup(
        key: TenantFacilityDepartmentsFilterKeys.type,
        label: l10n.tenantFacilityDepartmentTypeLabel,
        allLabel: l10n.commonAllLabel,
        choices: DepartmentSetupType.values
            .map(
              (DepartmentSetupType type) => AppSearchBarFilterChoice(
                value: type.apiValue,
                label: _departmentTypeLabel(l10n, type),
                icon: Icons.category_outlined,
              ),
            )
            .toList(growable: false),
      ),
      AppSearchBarFilterGroup(
        key: TenantFacilityDepartmentsFilterKeys.active,
        label: l10n.tenantFacilityActiveLabel,
        allLabel: l10n.commonAllLabel,
        choices: <AppSearchBarFilterChoice>[
          AppSearchBarFilterChoice(
            value: TenantFacilityDepartmentsFilterKeys.activeYes,
            label: l10n.tenantFacilityTenantStatusActive,
            icon: Icons.toggle_on_outlined,
          ),
          AppSearchBarFilterChoice(
            value: TenantFacilityDepartmentsFilterKeys.activeNo,
            label: l10n.tenantFacilityStatusInactive,
            icon: Icons.toggle_off_outlined,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final TenantFacilityDepartmentsListScope scope =
        tenantFacilityDepartmentsListScope(policy);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = widget.canSubmit;
    final bool isSubmitting = submission.isSubmitting;
    final bool prerequisitesMet = snapshot.facility?.id != null;
    final bool canAdd = canManageRecords && prerequisitesMet && !isSubmitting;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedFacility
        : null;
    final bool showTenantColumn = tenantFacilityDepartmentsShowsTenantColumn(
      scope,
    );
    final bool showFacilityColumn =
        tenantFacilityDepartmentsShowsFacilityColumn(scope);
    final bool showDetailColumns = tenantFacilityDepartmentsShowsDetailColumns(
      scope,
    );

    final List<AppListTableColumn<DepartmentProfile>> leadingColumns =
        <AppListTableColumn<DepartmentProfile>>[
          AppListTableColumn<DepartmentProfile>(
            id: 'id',
            label: l10n.tenantFacilityDepartmentIdLabel,
            preferredWidth: 140,
            cellBuilder: (_, DepartmentProfile department) => Text(
              tenantFacilityHumanFriendlyDisplayId(
                    department.displayId,
                    opaqueId: department.resourceUuid ?? department.id,
                  ) ??
                  '—',
            ),
          ),
        ];

    final List<AppListTableColumn<DepartmentProfile>> extraColumns =
        <AppListTableColumn<DepartmentProfile>>[
          if (showFacilityColumn)
            AppListTableColumn<DepartmentProfile>(
              id: 'facility',
              label: l10n.profileFacilityLabel,
              preferredWidth: 160,
              cellBuilder: (_, DepartmentProfile department) =>
                  Text(_facilityLabel(department)),
            ),
          if (showTenantColumn)
            AppListTableColumn<DepartmentProfile>(
              id: 'tenant',
              label: l10n.profileTenantLabel,
              preferredWidth: 160,
              cellBuilder: (_, DepartmentProfile department) =>
                  Text(_tenantLabel(department)),
            ),
          if (showDetailColumns) ...<AppListTableColumn<DepartmentProfile>>[
            AppListTableColumn<DepartmentProfile>(
              id: 'type',
              label: l10n.tenantFacilityDepartmentTypeLabel,
              preferredWidth: 140,
              cellBuilder: (_, DepartmentProfile department) => Text(
                _departmentTypeLabel(l10n, department.type),
              ),
            ),
            AppListTableColumn<DepartmentProfile>(
              id: 'short_name',
              label: l10n.tenantFacilityDepartmentShortNameLabel,
              preferredWidth: 140,
              cellBuilder: (_, DepartmentProfile department) => Text(
                department.shortName?.trim().isNotEmpty == true
                    ? department.shortName!.trim()
                    : '—',
              ),
            ),
          ],
        ];

    final Widget content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _failure != null
        ? Center(
            child: Text(
              l10n.failureMessage(_failure!),
              textAlign: TextAlign.center,
            ),
          )
        : _SearchableEntityGroup<DepartmentProfile>(
            title: l10n.tenantFacilityDepartmentsListTitle,
            nameColumnLabel: l10n.tenantFacilityDepartmentNameLabel,
            items: _departments,
            emptyLabel: l10n.tenantFacilityNoDepartments,
            noResultsLabel: l10n.tenantFacilitySearchNoResults,
            searchLabel: l10n.tenantFacilitySearchLabel,
            searchHint: l10n.tenantFacilityDepartmentSearchHint,
            addLabel: l10n.tenantFacilityAddDepartmentAction,
            canManageRecords: canManageRecords,
            canAdd: canAdd,
            isSubmitting: isSubmitting,
            blockedMessage: blockedMessage,
            onAdd: () => unawaited(
              _afterMutation(
                () => _openDepartmentDialog(context, snapshot),
              ),
            ),
            columnVisibilityStorageKey:
                'setup_structure_departments_${scope.name}_v3',
            extraFilterGroups: _buildFilterGroups(l10n),
            onFiltersChanged: (AppSearchBarFilterValue value) {
              unawaited(_onFiltersChanged(value));
            },
            titleBuilder: (DepartmentProfile department) => department.name,
            subtitleBuilder: (DepartmentProfile department) =>
                _departmentSubtitle(l10n, snapshot, department),
            statusLabelBuilder: (DepartmentProfile department) {
              if (department.isDeleted) {
                return l10n.tenantFacilityStructureDeletedStatus;
              }
              return _activeStatusLabel(l10n, department.isActive);
            },
            leadingColumns: leadingColumns,
            extraColumns: extraColumns,
            isDeletedBuilder: (DepartmentProfile department) =>
                department.isDeleted,
            onEdit: (DepartmentProfile department) {
              if (department.isDeleted || isSubmitting) {
                return;
              }
              unawaited(
                _afterMutation(
                  () => _openDepartmentDialog(
                    context,
                    snapshot,
                    department: department,
                  ),
                ),
              );
            },
            onDelete: (DepartmentProfile department) => unawaited(
              _afterMutation(
                () => _deleteEntity(
                  context: context,
                  ref: ref,
                  name: department.name,
                  deleteAction: () => ref
                      .read(tenantFacilitySetupSubmissionProvider.notifier)
                      .deleteDepartment(department.mutationId),
                ),
              ),
            ),
            onRestore: (DepartmentProfile department) => unawaited(
              _afterMutation(
                () => _restoreEntity(
                  context: context,
                  ref: ref,
                  name: department.name,
                  restoreAction: () => ref
                      .read(tenantFacilitySetupSubmissionProvider.notifier)
                      .restoreDepartment(department.mutationId),
                ),
              ),
            ),
            onPermanentDelete: (DepartmentProfile department) => unawaited(
              _afterMutation(
                () => _permanentDeleteEntity(
                  context: context,
                  ref: ref,
                  name: department.name,
                  permanentDeleteAction: () => ref
                      .read(tenantFacilitySetupSubmissionProvider.notifier)
                      .permanentDeleteDepartment(department.mutationId),
                ),
              ),
            ),
          );

    if (widget.framed) {
      return content;
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityDepartmentsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _UnitSetupSection extends ConsumerWidget {
  const _UnitSetupSection({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.departments.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedDepartmentForUnits
        : null;

    final Widget content = _SearchableEntityGroup<UnitProfile>(
      title: l10n.tenantFacilityUnitsListTitle,
      nameColumnLabel: l10n.tenantFacilityUnitNameLabel,
      items: snapshot.units,
      emptyLabel: l10n.tenantFacilityNoUnits,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityUnitSearchHint,
      addLabel: l10n.tenantFacilityAddUnitAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      blockedMessage: blockedMessage,
      onAdd: () => _openUnitDialog(context, snapshot),
      scopeLabel: l10n.tenantFacilityUnitDepartmentLabel,
      scopeOptions: <_SearchableEntityGroupScopeOption>[
        for (final DepartmentProfile department in snapshot.departments)
          if (!department.isDeleted)
            _SearchableEntityGroupScopeOption(
              id: department.id,
              label: department.name,
            ),
      ],
      itemScopeId: (UnitProfile unit) => unit.departmentId,
      titleBuilder: (UnitProfile unit) => unit.name,
      subtitleBuilder: (UnitProfile unit) => unit.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _unitSubtitle(l10n, snapshot, unit),
      isDeletedBuilder: (UnitProfile unit) => unit.isDeleted,
      onEdit: (UnitProfile unit) {
        if (unit.isDeleted) {
          return;
        }
        _openUnitDialog(context, snapshot, unit: unit);
      },
      onDelete: (UnitProfile unit) => _deleteEntity(
        context: context,
        ref: ref,
        name: unit.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteUnit(unit.id),
      ),
      onRestore: (UnitProfile unit) => _restoreEntity(
        context: context,
        ref: ref,
        name: unit.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreUnit(unit.id),
      ),
    );

    if (framed) {
      return content;
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityUnitsModalBody,
      blockedMessage: blockedMessage,
      child: content,
    );
  }
}

class _WardSetupSection extends ConsumerWidget {
  const _WardSetupSection({
    required this.snapshot,
    required this.canSubmit,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.departments.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedDepartmentForWards
        : null;

    final Widget content = _SearchableEntityGroup<WardProfile>(
      title: l10n.tenantFacilityWardsLabel,
      nameColumnLabel: l10n.tenantFacilityWardNameLabel,
      items: snapshot.wards,
      emptyLabel: l10n.tenantFacilityNoWards,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityWardSearchHint,
      addLabel: l10n.tenantFacilityAddWardAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      blockedMessage: blockedMessage,
      onAdd: () => _openWardDialog(context, snapshot),
      scopeLabel: l10n.tenantFacilityWardDepartmentLabel,
      scopeOptions: <_SearchableEntityGroupScopeOption>[
        for (final DepartmentProfile department in snapshot.departments)
          if (!department.isDeleted)
            _SearchableEntityGroupScopeOption(
              id: department.id,
              label: department.name,
            ),
      ],
      itemScopeId: (WardProfile ward) => ward.departmentId,
      titleBuilder: (WardProfile ward) => ward.name,
      subtitleBuilder: (WardProfile ward) => ward.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _wardSubtitle(l10n, snapshot, ward),
      isDeletedBuilder: (WardProfile ward) => ward.isDeleted,
      onEdit: (WardProfile ward) {
        if (ward.isDeleted) {
          return;
        }
        _openWardDialog(context, snapshot, ward: ward);
      },
      onDelete: (WardProfile ward) => _deleteEntity(
        context: context,
        ref: ref,
        name: ward.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteWard(ward.id),
      ),
      onRestore: (WardProfile ward) => _restoreEntity(
        context: context,
        ref: ref,
        name: ward.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreWard(ward.id),
      ),
    );

    return content;
  }
}

class _RoomSetupSection extends ConsumerWidget {
  const _RoomSetupSection({
    required this.snapshot,
    required this.canSubmit,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet =
        snapshot.departments.isNotEmpty || snapshot.wards.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedWardOrDepartmentForRooms
        : null;

    final Widget content = _SearchableEntityGroup<RoomProfile>(
      title: l10n.tenantFacilityRoomsLabel,
      nameColumnLabel: l10n.tenantFacilityRoomNameLabel,
      items: snapshot.rooms,
      emptyLabel: l10n.tenantFacilityNoRooms,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityRoomSearchHint,
      addLabel: l10n.tenantFacilityAddRoomAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      blockedMessage: blockedMessage,
      onAdd: () => _openRoomDialog(context, snapshot),
      scopeLabel: l10n.tenantFacilityRoomWardLabel,
      scopeOptions: <_SearchableEntityGroupScopeOption>[
        for (final WardProfile ward in snapshot.wards)
          if (!ward.isDeleted)
            _SearchableEntityGroupScopeOption(id: ward.id, label: ward.name),
      ],
      itemScopeId: (RoomProfile room) => room.wardId,
      titleBuilder: (RoomProfile room) => room.name,
      subtitleBuilder: (RoomProfile room) => room.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _roomSubtitle(l10n, snapshot, room),
      isDeletedBuilder: (RoomProfile room) => room.isDeleted,
      onEdit: (RoomProfile room) {
        if (room.isDeleted) {
          return;
        }
        _openRoomDialog(context, snapshot, room: room);
      },
      onDelete: (RoomProfile room) => _deleteEntity(
        context: context,
        ref: ref,
        name: room.name,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteRoom(room.id),
      ),
      onRestore: (RoomProfile room) => _restoreEntity(
        context: context,
        ref: ref,
        name: room.name,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreRoom(room.id),
      ),
    );

    return content;
  }
}

class _BedSetupSection extends ConsumerWidget {
  const _BedSetupSection({
    required this.snapshot,
    required this.canSubmit,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canManageRecords = canSubmit && !submission.isSubmitting;
    final bool prerequisitesMet = snapshot.wards.isNotEmpty;
    final bool canAdd = canManageRecords && prerequisitesMet;
    final String? blockedMessage = canManageRecords && !prerequisitesMet
        ? l10n.tenantFacilityGateNeedWardsForBeds
        : null;

    final Widget content = _SearchableEntityGroup<BedProfile>(
      title: l10n.tenantFacilityBedsLabel,
      nameColumnLabel: l10n.tenantFacilityBedLabelLabel,
      items: snapshot.beds,
      emptyLabel: l10n.tenantFacilityNoBeds,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityBedSearchHint,
      addLabel: l10n.tenantFacilityAddBedAction,
      canManageRecords: canManageRecords,
      canAdd: canAdd,
      blockedMessage: blockedMessage,
      onAdd: () => _openBedDialog(context, snapshot),
      scopeLabel: l10n.tenantFacilityBedWardLabel,
      scopeOptions: <_SearchableEntityGroupScopeOption>[
        for (final WardProfile ward in snapshot.wards)
          if (!ward.isDeleted)
            _SearchableEntityGroupScopeOption(id: ward.id, label: ward.name),
      ],
      itemScopeId: (BedProfile bed) => bed.wardId,
      titleBuilder: (BedProfile bed) => bed.label,
      subtitleBuilder: (BedProfile bed) => bed.isDeleted
          ? l10n.tenantFacilityStructureDeletedStatus
          : _bedSubtitle(l10n, snapshot, bed),
      isDeletedBuilder: (BedProfile bed) => bed.isDeleted,
      onEdit: (BedProfile bed) {
        if (bed.isDeleted) {
          return;
        }
        _openBedDialog(context, snapshot, bed: bed);
      },
      onDelete: (BedProfile bed) => _deleteEntity(
        context: context,
        ref: ref,
        name: bed.label,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteBed(bed.id),
      ),
      onRestore: (BedProfile bed) => _restoreEntity(
        context: context,
        ref: ref,
        name: bed.label,
        restoreAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .restoreBed(bed.id),
      ),
    );

    return content;
  }
}

class _ModalSectionBody extends StatelessWidget {
  const _ModalSectionBody({
    required this.body,
    required this.child,
    this.blockedMessage,
  });

  final String body;
  final Widget child;
  final String? blockedMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (blockedMessage != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          Text(
            blockedMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.lg),
        child,
      ],
    );
  }
}

class _SearchableEntityGroupScopeOption {
  const _SearchableEntityGroupScopeOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _SearchableEntityGroup<T> extends StatefulWidget {
  const _SearchableEntityGroup({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.noResultsLabel,
    required this.searchLabel,
    required this.searchHint,
    required this.addLabel,
    required this.canManageRecords,
    required this.canAdd,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.isDeletedBuilder,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    this.onPermanentDelete,
    this.isSubmitting = false,
    this.scopeLabel,
    this.scopeOptions = const <_SearchableEntityGroupScopeOption>[],
    this.itemScopeId,
    this.addIcon = Icons.add_circle_outline,
    this.blockedMessage,
    this.leadingColumns,
    this.extraColumns,
    this.extraFilterGroups = const <AppSearchBarFilterGroup>[],
    this.onFiltersChanged,
    this.columnVisibilityStorageKey,
    this.statusLabelBuilder,
    this.nameColumnLabel,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String noResultsLabel;
  final String searchLabel;
  final String searchHint;
  final String addLabel;
  final IconData addIcon;
  final bool canManageRecords;
  final bool canAdd;
  final bool isSubmitting;
  final VoidCallback onAdd;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item) isDeletedBuilder;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final ValueChanged<T> onRestore;
  final ValueChanged<T>? onPermanentDelete;
  final String? scopeLabel;
  final List<_SearchableEntityGroupScopeOption> scopeOptions;
  final String? Function(T item)? itemScopeId;
  final String? blockedMessage;
  final List<AppListTableColumn<T>>? leadingColumns;
  final List<AppListTableColumn<T>>? extraColumns;
  final List<AppSearchBarFilterGroup> extraFilterGroups;
  final ValueChanged<AppSearchBarFilterValue>? onFiltersChanged;
  final String? columnVisibilityStorageKey;
  final String Function(T item)? statusLabelBuilder;
  final String? nameColumnLabel;

  @override
  State<_SearchableEntityGroup<T>> createState() =>
      _SearchableEntityGroupState<T>();
}

class _SearchableEntityGroupState<T> extends State<_SearchableEntityGroup<T>> {
  static const String _statusFilterKey = 'status';
  static const String _scopeFilterKey = 'scope';
  static const String _statusActive = 'active';
  static const String _statusDeleted = 'deleted';
  static const String _allScopes = '__all_scopes__';

  final TextEditingController _searchController = TextEditingController();
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  String _scopeId = _allScopes;

  bool get _hasScopeSelector =>
      widget.scopeLabel != null &&
      widget.scopeOptions.isNotEmpty &&
      widget.itemScopeId != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SearchableEntityGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scopeId == _allScopes) {
      return;
    }
    final bool scopeStillValid = widget.scopeOptions.any(
      (_SearchableEntityGroupScopeOption option) => option.id == _scopeId,
    );
    if (!scopeStillValid) {
      setState(() => _scopeId = _allScopes);
    }
  }

  List<T> get _visibleItems {
    final String? status = _filterValue.options[_statusFilterKey];
    Iterable<T> items = widget.items;
    if (status == _statusActive) {
      items = items.where((T item) => !widget.isDeletedBuilder(item));
    } else if (status == _statusDeleted) {
      items = items.where(widget.isDeletedBuilder);
    }
    final String? Function(T item)? itemScopeId = widget.itemScopeId;
    if (_hasScopeSelector && _scopeId != _allScopes && itemScopeId != null) {
      items = items.where((T item) => itemScopeId(item) == _scopeId);
    }
    return items.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = theme.colorScheme;
    final List<T> items = _visibleItems;
    final bool hasActiveFilters =
        _filterValue.options.isNotEmpty ||
        (_hasScopeSelector && _scopeId != _allScopes);

    final double actionGap = theme.spacing.xs;
    final AppListTableColumn<T> nameColumn = AppListTableColumn<T>(
      id: 'name',
      label: widget.nameColumnLabel ?? widget.title,
      preferredWidth: 200,
      cellBuilder: (BuildContext context, T item) {
        final bool deleted = widget.isDeletedBuilder(item);
        return Text(
          widget.titleBuilder(item),
          style: deleted
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )
              : null,
        );
      },
    );
    final String Function(T item) statusLabel =
        widget.statusLabelBuilder ?? widget.subtitleBuilder;
    final AppListTableColumn<T> statusColumn = AppListTableColumn<T>(
      id: 'status',
      label: l10n.tenantFacilityTenantStatusLabel,
      preferredWidth: 120,
      cellBuilder: (_, T item) => Text(statusLabel(item)),
    );
    final List<AppListTableColumn<T>> leadingColumns =
        widget.leadingColumns ?? <AppListTableColumn<T>>[];
    final List<AppListTableColumn<T>> extraColumns =
        widget.extraColumns ?? <AppListTableColumn<T>>[];
    final bool actionsEnabled = !widget.isSubmitting;
    final AppListTableColumn<T>? actionsColumn = widget.canManageRecords
        ? AppListTableColumn<T>(
            id: 'actions',
            label: l10n.accessAdminColumnActions,
            alwaysVisible: true,
            preferredWidth: widget.onPermanentDelete != null ? 220 : 168,
            cellBuilder: (BuildContext context, T item) {
              final bool deleted = widget.isDeletedBuilder(item);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (deleted) ...<Widget>[
                    AppButton.tertiary(
                      leadingIcon: Icons.restore_outlined,
                      label: l10n.tenantFacilityRestoreStructureAction,
                      semanticLabel: l10n.tenantFacilityRestoreStructureAction,
                      tooltip: l10n.tenantFacilityRestoreStructureAction,
                      enabled: actionsEnabled,
                      onPressed: actionsEnabled
                          ? () => widget.onRestore(item)
                          : null,
                    ),
                    if (widget.onPermanentDelete != null) ...<Widget>[
                      SizedBox(width: actionGap),
                      AppButton.tertiary(
                        leadingIcon: Icons.delete_forever_outlined,
                        label: l10n.tenantFacilityPermanentDeleteAction,
                        semanticLabel: l10n.tenantFacilityPermanentDeleteAction,
                        tooltip: l10n.tenantFacilityPermanentDeleteAction,
                        color: theme.statusColors.error,
                        enabled: actionsEnabled,
                        onPressed: actionsEnabled
                            ? () => widget.onPermanentDelete!(item)
                            : null,
                      ),
                    ],
                  ] else ...<Widget>[
                    AppButton.tertiary(
                      leadingIcon: Icons.edit_outlined,
                      label: l10n.tenantFacilityEditAction,
                      semanticLabel: l10n.tenantFacilityEditAction,
                      tooltip: l10n.tenantFacilityEditAction,
                      enabled: actionsEnabled,
                      onPressed: actionsEnabled
                          ? () => widget.onEdit(item)
                          : null,
                    ),
                    SizedBox(width: actionGap),
                    AppButton.tertiary(
                      leadingIcon: Icons.delete_outline,
                      label: l10n.tenantFacilityDeleteAction,
                      semanticLabel: l10n.tenantFacilityDeleteAction,
                      tooltip: l10n.tenantFacilityDeleteAction,
                      color: theme.statusColors.error,
                      enabled: actionsEnabled,
                      onPressed: actionsEnabled
                          ? () => widget.onDelete(item)
                          : null,
                    ),
                  ],
                ],
              );
            },
          )
        : null;

    final Widget table = AppListTable<T>(
      items: items,
      columnVisibilityStorageKey:
          widget.columnVisibilityStorageKey ??
          'setup_structure_${widget.title}',
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columns: <AppListTableColumn<T>>[
        ...leadingColumns,
        nameColumn,
        ...extraColumns,
        statusColumn,
        if (actionsColumn != null) actionsColumn,
      ],
      columnChoices: <AppListTableColumn<T>>[
        AppListTableColumn<T>(
          id: 'details',
          label: l10n.accessAdminColumnDetails,
          cellBuilder: (_, T item) => Text(widget.subtitleBuilder(item)),
        ),
      ],
      search: AppListTableSearch<T>(
        controller: _searchController,
        semanticLabel: widget.searchLabel,
        hintText: widget.searchHint,
        matcher: (T item, String query) => _entitySearchText(
          widget.titleBuilder(item),
          widget.subtitleBuilder(item),
        ).contains(_normalizeSearch(query)),
        showAdvancedFilterButton: true,
        advancedFilterTitle: l10n.commonFilterActionLabel,
        advancedFilterButtonLabel: l10n.commonFilterActionLabel,
        advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
        advancedFilterResetLabel: l10n.opdClearFiltersAction,
        filterGroups: <AppSearchBarFilterGroup>[
          if (_hasScopeSelector)
            AppSearchBarFilterGroup(
              key: _scopeFilterKey,
              label: widget.scopeLabel!,
              allLabel: l10n.commonAllLabel,
              choices: <AppSearchBarFilterChoice>[
                for (final _SearchableEntityGroupScopeOption option
                    in widget.scopeOptions)
                  AppSearchBarFilterChoice(
                    value: option.id,
                    label: option.label,
                    icon: Icons.filter_alt_outlined,
                  ),
              ],
            ),
          ...widget.extraFilterGroups,
          AppSearchBarFilterGroup(
            key: _statusFilterKey,
            label: l10n.tenantFacilityTenantStatusLabel,
            allLabel: l10n.commonAllLabel,
            choices: <AppSearchBarFilterChoice>[
              AppSearchBarFilterChoice(
                value: _statusActive,
                label: l10n.tenantFacilityTenantStatusActive,
                icon: Icons.check_circle_outline,
              ),
              AppSearchBarFilterChoice(
                value: _statusDeleted,
                label: l10n.tenantFacilityTenantStatusDeleted,
                icon: Icons.delete_outline,
              ),
            ],
          ),
        ],
        filterValue: AppSearchBarFilterValue(
          options: <String, String>{
            ..._filterValue.options,
            if (_hasScopeSelector && _scopeId != _allScopes)
              _scopeFilterKey: _scopeId,
          },
        ),
        hasActiveFilters: hasActiveFilters,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() {
            _filterValue = value;
            final String? nextScope = value.options[_scopeFilterKey];
            if (_hasScopeSelector) {
              _scopeId = (nextScope == null || nextScope.isEmpty)
                  ? _allScopes
                  : nextScope;
            }
          });
          widget.onFiltersChanged?.call(value);
        },
        isLoading: widget.isSubmitting,
        trailingActions: widget.canManageRecords
            ? <AppSearchBarAction>[
                AppSearchBarAction(
                  icon: widget.addIcon,
                  label: widget.addLabel,
                  tooltip: widget.canAdd
                      ? widget.addLabel
                      : (widget.blockedMessage ?? widget.addLabel),
                  enabled: widget.canAdd,
                  onPressed: widget.canAdd ? widget.onAdd : null,
                ),
              ]
            : const <AppSearchBarAction>[],
      ),
      emptyBuilder: (_) {
        final bool searching =
            _searchController.text.trim().isNotEmpty || hasActiveFilters;
        return AppWorkspaceStatePanel.empty(
          title: widget.title,
          body: searching ? widget.noResultsLabel : widget.emptyLabel,
          detail: !searching && !widget.canAdd ? widget.blockedMessage : null,
          action: widget.canManageRecords && !searching
              ? AppButton.primary(
                  label: widget.addLabel,
                  leadingIcon: widget.addIcon,
                  enabled: widget.canAdd,
                  isLoading: widget.isSubmitting,
                  tooltip: widget.canAdd
                      ? widget.addLabel
                      : (widget.blockedMessage ?? widget.addLabel),
                  onPressed: widget.canAdd ? widget.onAdd : null,
                )
              : null,
        );
      },
      mobileItemBuilder: (BuildContext context, T item) {
        return AppListTableMobileItem(
          title: widget.titleBuilder(item),
          caption: widget.subtitleBuilder(item),
        );
      },
    );

    if (!_hasScopeSelector) {
      return table;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _scopeId,
          labelText: widget.scopeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: _allScopes,
              label: l10n.commonAllLabel,
            ),
            for (final _SearchableEntityGroupScopeOption option
                in widget.scopeOptions)
              AppSelectOption<String>(value: option.id, label: option.label),
          ],
          onChanged: (String? value) {
            setState(() {
              _scopeId = value ?? _allScopes;
              final Map<String, String> nextOptions =
                  Map<String, String>.of(_filterValue.options);
              if (_scopeId == _allScopes) {
                nextOptions.remove(_scopeFilterKey);
              } else {
                nextOptions[_scopeFilterKey] = _scopeId;
              }
              _filterValue = AppSearchBarFilterValue(
                options: nextOptions,
                field: _filterValue.field,
                dateFrom: _filterValue.dateFrom,
                dateTo: _filterValue.dateTo,
                texts: _filterValue.texts,
                selections: _filterValue.selections,
              );
            });
          },
        ),
        SizedBox(height: theme.spacing.sm),
        Expanded(child: table),
      ],
    );
  }
}

String _entitySearchText(String title, String subtitle) {
  return _normalizeSearch('$title $subtitle');
}

String _normalizeSearch(String value) {
  return value.trim().toLowerCase();
}

final class _FacilityFieldChange {
  const _FacilityFieldChange({
    required this.label,
    required this.previousValue,
    required this.nextValue,
    this.isLogo = false,
    this.previousLogoUrl,
    this.nextLogoBytes,
    this.logoCleared = false,
  });

  final String label;
  final String previousValue;
  final String nextValue;
  final bool isLogo;
  final String? previousLogoUrl;
  final List<int>? nextLogoBytes;
  final bool logoCleared;
}

class _FacilityChangeDiffCard extends StatelessWidget {
  const _FacilityChangeDiffCard({required this.change});

  final _FacilityFieldChange change;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              change.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 420;
                final Widget previousPane = _FacilityChangeValuePane(
                  tone: _FacilityChangePaneTone.previous,
                  caption: l10n.tenantFacilityFieldPreviousLabel,
                  textValue: change.previousValue,
                  isLogo: change.isLogo,
                  logoUrl: change.previousLogoUrl,
                  emptyLogoLabel: l10n.tenantFacilityFacilityDetailsNoLogo,
                );
                final Widget nextPane = _FacilityChangeValuePane(
                  tone: _FacilityChangePaneTone.next,
                  caption: l10n.tenantFacilityFieldNewLabel,
                  textValue: change.nextValue,
                  isLogo: change.isLogo,
                  logoBytes: change.nextLogoBytes,
                  logoCleared: change.logoCleared,
                  emptyLogoLabel: change.logoCleared
                      ? l10n.tenantFacilityLogoRemovedLabel
                      : l10n.tenantFacilityFacilityDetailsNoLogo,
                );
                final Widget arrow = Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: stacked ? 0 : theme.spacing.sm,
                    vertical: stacked ? theme.spacing.sm : 0,
                  ),
                  child: Icon(
                    stacked
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_forward_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[previousPane, arrow, nextPane],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: previousPane),
                    arrow,
                    Expanded(child: nextPane),
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

enum _FacilityChangePaneTone { previous, next }

class _FacilityChangeValuePane extends StatelessWidget {
  const _FacilityChangeValuePane({
    required this.tone,
    required this.caption,
    required this.textValue,
    required this.isLogo,
    required this.emptyLogoLabel,
    this.logoUrl,
    this.logoBytes,
    this.logoCleared = false,
  });

  final _FacilityChangePaneTone tone;
  final String caption;
  final String textValue;
  final bool isLogo;
  final String emptyLogoLabel;
  final String? logoUrl;
  final List<int>? logoBytes;
  final bool logoCleared;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isPrevious = tone == _FacilityChangePaneTone.previous;
    final Color background = isPrevious
        ? colorScheme.errorContainer.withValues(alpha: 0.28)
        : colorScheme.primaryContainer.withValues(alpha: 0.45);
    final Color border = isPrevious
        ? colorScheme.error.withValues(alpha: 0.22)
        : colorScheme.primary.withValues(alpha: 0.28);
    final Color captionColor = isPrevious
        ? colorScheme.onErrorContainer
        : colorScheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isLogo)
              _FacilityConfirmLogoPreview(
                url: logoUrl,
                bytes: logoBytes,
                cleared: logoCleared,
                emptyLabel: emptyLogoLabel,
                emphasizeRemoval: isPrevious || logoCleared,
              )
            else ...<Widget>[
              Text(
                caption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: captionColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                textValue,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isPrevious ? TextDecoration.lineThrough : null,
                  color: isPrevious
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FacilityConfirmLogoPreview extends StatelessWidget {
  const _FacilityConfirmLogoPreview({
    required this.emptyLabel,
    required this.emphasizeRemoval,
    this.url,
    this.bytes,
    this.cleared = false,
  });

  final String? url;
  final List<int>? bytes;
  final bool cleared;
  final String emptyLabel;
  final bool emphasizeRemoval;

  static const double _previewHeight = 128;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasBytes = bytes != null && bytes!.isNotEmpty;
    final bool hasUrl = (url ?? '').trim().isNotEmpty;
    final Widget image;

    if (hasBytes) {
      image = Image.memory(
        Uint8List.fromList(bytes!),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: colorScheme.error),
      );
    } else if (hasUrl && !cleared) {
      final String? resolvedUrl = resolveAppMediaUrl(
        url,
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(appConfigProvider).apiBaseUrl,
      );
      image = Image.network(
        resolvedUrl ?? url!.trim(),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: colorScheme.error),
      );
    } else {
      image = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            cleared
                ? Icons.hide_image_outlined
                : Icons.image_not_supported_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          SizedBox(height: theme.spacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              emptyLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: double.infinity,
          height: _previewHeight,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Padding(padding: EdgeInsets.all(theme.spacing.sm), child: image),
              if (emphasizeRemoval && (hasUrl || cleared) && !hasBytes)
                ColoredBox(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  child: const SizedBox.expand(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DepartmentFormDialog extends ConsumerStatefulWidget {
  const _DepartmentFormDialog({required this.snapshot, this.department});

  final FacilitySetupSnapshot snapshot;
  final DepartmentProfile? department;

  @override
  ConsumerState<_DepartmentFormDialog> createState() =>
      _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends ConsumerState<_DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortNameController;
  late DepartmentSetupType _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final DepartmentProfile? department = widget.department;
    _nameController = TextEditingController(text: department?.name);
    _shortNameController = TextEditingController(text: department?.shortName);
    _type = department?.type ?? DepartmentSetupType.clinical;
    _isActive = department?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.department != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditDepartmentTitle
            : l10n.tenantFacilityAddDepartmentTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _shortNameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentShortNameLabel,
            ),
            AppSelectField<DepartmentSetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentTypeLabel,
              isRequired: true,
              options: <AppSelectOption<DepartmentSetupType>>[
                for (final type in DepartmentSetupType.values)
                  AppSelectOption<DepartmentSetupType>(
                    value: type,
                    label: _departmentTypeLabel(l10n, type),
                  ),
              ],
              onChanged: (DepartmentSetupType? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _type = value;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final DepartmentProfile? editing = widget.department;
    final String? tenantId =
        editing?.tenantId.trim().isNotEmpty == true
        ? editing!.tenantId.trim()
        : widget.snapshot.tenant?.id.trim();
    final String? facilityId =
        editing?.facilityId?.trim().isNotEmpty == true
        ? editing!.facilityId!.trim()
        : widget.snapshot.facility?.id.trim();
    if (tenantId == null ||
        tenantId.isEmpty ||
        facilityId == null ||
        facilityId.isEmpty) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveDepartment(
          id: editing?.id,
          tenantId: tenantId,
          facilityId: facilityId,
          name: _nameController.text,
          shortName: _shortNameController.text,
          type: _type,
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _UnitFormDialog extends ConsumerStatefulWidget {
  const _UnitFormDialog({required this.snapshot, this.unit});

  final FacilitySetupSnapshot snapshot;
  final UnitProfile? unit;

  @override
  ConsumerState<_UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends ConsumerState<_UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _departmentId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.unit?.name);
    _departmentId =
        widget.unit?.departmentId ??
        (widget.snapshot.departments.length == 1
            ? widget.snapshot.departments.first.id
            : _noneSelection);
    _isActive = widget.unit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.unit != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditUnitTitle
            : l10n.tenantFacilityAddUnitTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityUnitNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _departmentId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityUnitDepartmentLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final DepartmentProfile department
                    in widget.snapshot.departments)
                  AppSelectOption<String>(
                    value: department.id,
                    label: department.name,
                  ),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.departments
                    .map((DepartmentProfile department) => department.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidDepartmentSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _departmentId = value ?? _noneSelection;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveUnit(
          id: widget.unit?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          departmentId: _optionalSelection(_departmentId),
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _WardFormDialog extends ConsumerStatefulWidget {
  const _WardFormDialog({required this.snapshot, this.ward});

  final FacilitySetupSnapshot snapshot;
  final WardProfile? ward;

  @override
  ConsumerState<_WardFormDialog> createState() => _WardFormDialogState();
}

class _WardFormDialogState extends ConsumerState<_WardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late WardSetupType _type;
  late String _departmentId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ward?.name);
    _type = widget.ward?.type ?? WardSetupType.general;
    _departmentId =
        widget.ward?.departmentId ??
        (widget.snapshot.departments.length == 1
            ? widget.snapshot.departments.first.id
            : _noneSelection);
    _isActive = widget.ward?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.ward != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditWardTitle
            : l10n.tenantFacilityAddWardTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<WardSetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardTypeLabel,
              isRequired: true,
              options: <AppSelectOption<WardSetupType>>[
                for (final type in WardSetupType.values)
                  AppSelectOption<WardSetupType>(
                    value: type,
                    label: _wardTypeLabel(l10n, type),
                  ),
              ],
              onChanged: (WardSetupType? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _type = value;
                });
              },
            ),
            AppSelectField<String>.searchable(
              value: _departmentId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardDepartmentLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final DepartmentProfile department
                    in widget.snapshot.departments)
                  AppSelectOption<String>(
                    value: department.id,
                    label: department.name,
                  ),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.departments
                    .map((DepartmentProfile department) => department.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidDepartmentSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _departmentId = value ?? _noneSelection;
                });
              },
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: canEdit,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveWard(
          id: widget.ward?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          type: _type,
          departmentId: _optionalSelection(_departmentId),
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _RoomFormDialog extends ConsumerStatefulWidget {
  const _RoomFormDialog({required this.snapshot, this.room});

  final FacilitySetupSnapshot snapshot;
  final RoomProfile? room;

  @override
  ConsumerState<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends ConsumerState<_RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _floorController;
  late String _wardId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name);
    _floorController = TextEditingController(text: widget.room?.floor);
    _wardId =
        widget.room?.wardId ??
        (widget.snapshot.wards.length == 1
            ? widget.snapshot.wards.first.id
            : _noneSelection);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.room != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditRoomTitle
            : l10n.tenantFacilityAddRoomTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomNameLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomWardLabel,
              helperText: l10n.tenantFacilityRoomWardOptionalHint,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityRoomOutpatientLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: widget.snapshot.wards
                    .map((WardProfile ward) => ward.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidWardSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _wardId = value ?? _noneSelection;
                });
              },
            ),
            AppTextField(
              controller: _floorController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomFloorLabel,
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveRoom(
          id: widget.room?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          wardId: _optionalSelection(_wardId),
          floor: _floorController.text,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _BedFormDialog extends ConsumerStatefulWidget {
  const _BedFormDialog({required this.snapshot, this.bed});

  final FacilitySetupSnapshot snapshot;
  final BedProfile? bed;

  @override
  ConsumerState<_BedFormDialog> createState() => _BedFormDialogState();
}

class _BedFormDialogState extends ConsumerState<_BedFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late String _wardId;
  late String _roomId;
  late BedSetupStatus _status;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.bed?.label);
    _wardId = widget.bed?.wardId ?? _noneSelection;
    _roomId = widget.bed?.roomId ?? _noneSelection;
    _status = widget.bed?.status ?? BedSetupStatus.available;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool isEditing = widget.bed != null;
    final bool canEdit = !submission.isSubmitting;
    final List<RoomProfile> rooms = _optionalSelection(_wardId) == null
        ? widget.snapshot.rooms
        : widget.snapshot.rooms
              .where((RoomProfile room) => room.wardId == _wardId)
              .toList(growable: false);

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditBedTitle
            : l10n.tenantFacilityAddBedTitle,
      ),
      scrollable: true,
      closeEnabled: canEdit,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppTextField(
              controller: _labelController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedLabelLabel,
              isRequired: true,
              textCapitalization: TextCapitalization.characters,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedWardLabel,
              isRequired: true,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: (String? value) {
                final String? requiredError = tenantFacilityRequiredSelection(
                  l10n,
                )(value);
                if (requiredError != null) {
                  return requiredError;
                }

                return tenantFacilityValidReferenceSelection(
                  validIds: widget.snapshot.wards
                      .map((WardProfile ward) => ward.id)
                      .toList(growable: false),
                  invalidMessage: l10n.tenantFacilityInvalidWardSelection,
                )(value);
              },
              onChanged: (String? value) {
                final String nextWardId = value ?? _noneSelection;
                final List<RoomProfile> nextRooms =
                    _optionalSelection(nextWardId) == null
                    ? widget.snapshot.rooms
                    : widget.snapshot.rooms
                          .where(
                            (RoomProfile room) => room.wardId == nextWardId,
                          )
                          .toList(growable: false);
                setState(() {
                  _wardId = nextWardId;
                  if (nextRooms.every(
                    (RoomProfile room) => room.id != _roomId,
                  )) {
                    _roomId = _noneSelection;
                  }
                });
              },
            ),
            AppSelectField<String>.searchable(
              value: _roomId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedRoomLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final RoomProfile room in rooms)
                  AppSelectOption<String>(value: room.id, label: room.name),
              ],
              validator: tenantFacilityValidReferenceSelection(
                validIds: rooms
                    .map((RoomProfile room) => room.id)
                    .toList(growable: false),
                invalidMessage: l10n.tenantFacilityInvalidRoomSelection,
              ),
              onChanged: (String? value) {
                setState(() {
                  _roomId = value ?? _noneSelection;
                });
              },
            ),
            AppSelectField<BedSetupStatus>(
              value: _status,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedStatusLabel,
              isRequired: true,
              options: <AppSelectOption<BedSetupStatus>>[
                for (final status in BedSetupStatus.values)
                  AppSelectOption<BedSetupStatus>(
                    value: status,
                    label: _bedStatusLabel(l10n, status),
                  ),
              ],
              onChanged: (BedSetupStatus? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _status = value;
                });
              },
            ),
            _SubmissionFailureBanner(),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: canEdit,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditing
              ? l10n.tenantFacilitySaveAction
              : l10n.tenantFacilityCreateAction,
          leadingIcon: Icons.save_outlined,
          isLoading: submission.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    final String? wardId = _optionalSelection(_wardId);
    if (tenant == null || facility == null || wardId == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveBed(
          id: widget.bed?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          wardId: wardId,
          label: _labelController.text,
          status: _status,
          roomId: _optionalSelection(_roomId),
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _SubmissionFailureBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppFailure? failure = ref.watch(
      tenantFacilitySetupSubmissionProvider.select((state) => state.failure),
    );
    if (failure == null) {
      return const SizedBox.shrink();
    }

    return AppFormInformationBanner.failure(context: context, failure: failure);
  }
}

Future<void> _openDepartmentDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  DepartmentProfile? department,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DepartmentFormDialog(snapshot: snapshot, department: department),
  );
}

Future<void> _openUnitDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  UnitProfile? unit,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnitFormDialog(snapshot: snapshot, unit: unit),
  );
}

Future<void> _openWardDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  WardProfile? ward,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WardFormDialog(snapshot: snapshot, ward: ward),
  );
}

Future<void> _openRoomDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  RoomProfile? room,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoomFormDialog(snapshot: snapshot, room: room),
  );
}

Future<void> _openBedDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BedProfile? bed,
}) async {
  await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BedFormDialog(snapshot: snapshot, bed: bed),
  );
}

Future<void> _deleteEntity({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<bool> Function() deleteAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.tenantFacilitySoftDeleteStructureTitle,
      body: l10n.tenantFacilitySoftDeleteStructureBody(name),
      highlightedText: name,
      submitLabel: l10n.tenantFacilityDeleteConfirmAction,
      destructive: true,
      icon: const Icon(Icons.delete_outline),
      onConfirm: () async {
        final bool deleted = await deleteAction();
        if (deleted) {
          return null;
        }
        return ref.read(tenantFacilitySetupSubmissionProvider).failure ??
            const AppFailure.unexpected();
      },
    ),
  );
}

Future<void> _restoreEntity({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<bool> Function() restoreAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.tenantFacilityRestoreStructureTitle,
      body: l10n.tenantFacilityRestoreStructureBody(name),
      highlightedText: name,
      submitLabel: l10n.tenantFacilityRestoreStructureAction,
      icon: const Icon(Icons.restore_outlined),
      onConfirm: () async {
        final bool restored = await restoreAction();
        if (restored) {
          return null;
        }
        return ref.read(tenantFacilitySetupSubmissionProvider).failure ??
            const AppFailure.unexpected();
      },
    ),
  );
}

Future<void> _permanentDeleteEntity({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<bool> Function() permanentDeleteAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String? typed = await showAppDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AppTextInputActionDialog(
      title: l10n.tenantFacilityPermanentDeleteDepartmentConfirmationTitle,
      description: l10n.tenantFacilityPermanentDeleteDepartmentWarningBody(name),
      fieldLabel: l10n.tenantFacilityPermanentDeleteConfirmFieldLabel(name),
      submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
      cancelLabel: l10n.commonCancelActionLabel,
      requiredMessage: l10n.validationRequired,
      destructive: true,
      minLines: 1,
      maxLines: 1,
      icon: const Icon(Icons.delete_forever_outlined),
    ),
  );

  if (!context.mounted || typed == null) {
    return;
  }
  if (typed.trim() != name.trim()) {
    return;
  }

  await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: l10n.tenantFacilityPermanentDeleteDepartmentConfirmationTitle,
      body: l10n.tenantFacilityPermanentDeleteDepartmentConfirmationBody(name),
      highlightedText: name,
      submitLabel: l10n.tenantFacilityPermanentDeleteConfirmAction,
      destructive: true,
      icon: const Icon(Icons.delete_forever_outlined),
      onConfirm: () async {
        final bool deleted = await permanentDeleteAction();
        if (deleted) {
          return null;
        }
        final AppFailure? failure =
            ref.read(tenantFacilitySetupSubmissionProvider).failure;
        if (failure?.category == AppFailureCategory.notFound) {
          return null;
        }
        return failure ?? const AppFailure.unexpected();
      },
    ),
  );
}

String? _optionalSelection(String? value) {
  if (value == null || value == _noneSelection) {
    return null;
  }

  return value;
}

String _activeStatusLabel(AppLocalizations l10n, bool isActive) {
  return isActive
      ? l10n.tenantFacilityStatusActive
      : l10n.tenantFacilityStatusInactive;
}

String _departmentSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  DepartmentProfile department,
) {
  // Used for search matching; table shows type/short name/status as columns.
  return _joinParts(<String?>[
    _departmentTypeLabel(l10n, department.type),
    if (department.shortName != null) department.shortName!,
    department.isDeleted
        ? l10n.tenantFacilityStructureDeletedStatus
        : _activeStatusLabel(l10n, department.isActive),
  ]);
}

String _unitSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  UnitProfile unit,
) {
  return _joinParts(<String?>[
    _departmentName(snapshot, unit.departmentId),
    _activeStatusLabel(l10n, unit.isActive),
  ]);
}

String _wardSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  WardProfile ward,
) {
  return _joinParts(<String?>[
    _wardTypeLabel(l10n, ward.type),
    _departmentName(snapshot, ward.departmentId),
    _activeStatusLabel(l10n, ward.isActive),
  ]);
}

String _roomSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  RoomProfile room,
) {
  return _joinParts(<String?>[
    room.wardId != null
        ? _wardName(snapshot, room.wardId)
        : l10n.tenantFacilityRoomOutpatientLabel,
    if (room.floor != null) room.floor!,
  ]);
}

String _bedSubtitle(
  AppLocalizations l10n,
  FacilitySetupSnapshot snapshot,
  BedProfile bed,
) {
  return _joinParts(<String?>[
    _wardName(snapshot, bed.wardId),
    _roomName(snapshot, bed.roomId),
    _bedStatusLabel(l10n, bed.status),
  ]);
}

String _joinParts(List<String?> parts) {
  return parts
      .whereType<String>()
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(', ');
}

String? _departmentName(FacilitySetupSnapshot snapshot, String? departmentId) {
  return snapshot.departments
      .where((DepartmentProfile department) => department.id == departmentId)
      .firstOrNull
      ?.name;
}

String? _wardName(FacilitySetupSnapshot snapshot, String? wardId) {
  return snapshot.wards
      .where((WardProfile ward) => ward.id == wardId)
      .firstOrNull
      ?.name;
}

String? _roomName(FacilitySetupSnapshot snapshot, String? roomId) {
  return snapshot.rooms
      .where((RoomProfile room) => room.id == roomId)
      .firstOrNull
      ?.name;
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: <Widget>[
              left,
              SizedBox(height: theme.spacing.md),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            SizedBox(width: theme.spacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SubmissionFeedback extends StatelessWidget {
  const _SubmissionFeedback({
    required this.enabled,
    this.failure,
    this.permissionDeniedMessage,
  });

  final bool enabled;
  final AppFailure? failure;
  final String? permissionDeniedMessage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String deniedMessage =
        permissionDeniedMessage ?? l10n.tenantFacilityPermissionRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!enabled) ...<Widget>[
          Text(
            deniedMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (failure != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            l10n.failureMessage(failure!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.statusColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubmitButton extends ConsumerWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.permissionDeniedMessage,
  });

  final bool enabled;
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  final String? permissionDeniedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool fullWidth = breakpoint.isMobile;
    final failure = ref.watch(
      tenantFacilitySetupSubmissionProvider.select((state) => state.failure),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppButton.primary(
          label: label,
          leadingIcon: Icons.save_outlined,
          isLoading: isLoading,
          enabled: enabled,
          fullWidth: fullWidth,
          onPressed: onPressed,
        ),
        if (!enabled) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.xs),
          Text(
            permissionDeniedMessage ?? l10n.tenantFacilityPermissionRequired,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (failure != null) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.xs),
          Text(
            l10n.failureMessage(failure),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).statusColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

String _departmentTypeLabel(AppLocalizations l10n, DepartmentSetupType type) {
  return switch (type) {
    DepartmentSetupType.clinical => l10n.tenantFacilityDepartmentTypeClinical,
    DepartmentSetupType.administrative =>
      l10n.tenantFacilityDepartmentTypeAdministrative,
    DepartmentSetupType.support => l10n.tenantFacilityDepartmentTypeSupport,
    DepartmentSetupType.diagnostics =>
      l10n.tenantFacilityDepartmentTypeDiagnostics,
    DepartmentSetupType.other => l10n.tenantFacilityDepartmentTypeOther,
  };
}

String _wardTypeLabel(AppLocalizations l10n, WardSetupType type) {
  return switch (type) {
    WardSetupType.general => l10n.tenantFacilityWardTypeGeneral,
    WardSetupType.icu => l10n.tenantFacilityWardTypeIcu,
    WardSetupType.maternity => l10n.tenantFacilityWardTypeMaternity,
    WardSetupType.pediatric => l10n.tenantFacilityWardTypePediatric,
    WardSetupType.surgical => l10n.tenantFacilityWardTypeSurgical,
    WardSetupType.other => l10n.tenantFacilityWardTypeOther,
  };
}

String _bedStatusLabel(AppLocalizations l10n, BedSetupStatus status) {
  return switch (status) {
    BedSetupStatus.available => l10n.tenantFacilityBedStatusAvailable,
    BedSetupStatus.occupied => l10n.tenantFacilityBedStatusOccupied,
    BedSetupStatus.reserved => l10n.tenantFacilityBedStatusReserved,
    BedSetupStatus.cleaning => l10n.tenantFacilityBedStatusCleaning,
    BedSetupStatus.maintenance => l10n.tenantFacilityBedStatusMaintenance,
    BedSetupStatus.blocked => l10n.tenantFacilityBedStatusBlocked,
    BedSetupStatus.outOfService => l10n.tenantFacilityBedStatusOutOfService,
  };
}

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(context.l10n.tenantFacilitySavedMessage)),
    );
}

/// Opens the tenant profile create/edit dialog from the home dashboard.
Future<TenantProfile?> showTenantFacilityTenantFormDialog(
  BuildContext context, {
  TenantProfile? tenant,
  bool forceCreate = false,
  bool managementMode = false,
}) {
  return _openTenantProfileModal(
    context,
    tenant: tenant,
    forceCreate: forceCreate,
    managementMode: managementMode,
  );
}

/// Opens the facility profile create/edit dialog from the home dashboard.
Future<FacilityProfile?> showTenantFacilityFacilityFormDialog(
  BuildContext context, {
  String? tenantId,
  FacilityProfile? facility,
  bool requireTenantPicker = false,
  bool managementMode = false,
}) {
  return _openFacilityProfileModal(
    context,
    tenantId: tenantId,
    facility: facility,
    requireTenantPicker: requireTenantPicker,
    managementMode: managementMode,
  );
}

/// Shared department create/edit dialog for facility setup.
Future<void> showTenantFacilityDepartmentFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  DepartmentProfile? department,
}) {
  return _openDepartmentDialog(context, snapshot, department: department);
}

/// Shared unit create/edit dialog for facility setup.
Future<void> showTenantFacilityUnitFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  UnitProfile? unit,
}) {
  return _openUnitDialog(context, snapshot, unit: unit);
}

/// Shared ward create/edit dialog for facility setup and management.
Future<void> showTenantFacilityWardFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  WardProfile? ward,
}) {
  return _openWardDialog(context, snapshot, ward: ward);
}

/// Shared room create/edit dialog for facility setup and rooms & beds workspace.
Future<void> showTenantFacilityRoomFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  RoomProfile? room,
}) {
  return _openRoomDialog(context, snapshot, room: room);
}

/// Shared bed create/edit dialog for facility setup and rooms & beds workspace.
Future<void> showTenantFacilityBedFormDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BedProfile? bed,
}) {
  return _openBedDialog(context, snapshot, bed: bed);
}
