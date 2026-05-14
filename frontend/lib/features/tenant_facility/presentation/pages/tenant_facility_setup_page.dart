import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class TenantFacilitySetupPage extends ConsumerWidget {
  const TenantFacilitySetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final setup = ref.watch(tenantFacilitySetupControllerProvider);

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
        return _TenantFacilitySetupContent(snapshot: snapshot);
      },
    );
  }
}

class _TenantFacilitySetupContent extends ConsumerWidget {
  const _TenantFacilitySetupContent({required this.snapshot});

  final FacilitySetupSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canManageTenant = accessPolicy.canManageTenant();
    final bool canManageFacility = accessPolicy.canManageFacility();

    return AppScreen(
      title: l10n.tenantFacilitySetupTitle,
      body: l10n.tenantFacilitySetupBody,
      maxWidth: PageMaxWidth.dashboard,
      headerActions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRetryActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: () {
            ref.read(tenantFacilitySetupControllerProvider.notifier).refresh();
          },
        ),
      ],
      children: <Widget>[
        _SetupGrid(
          children: <Widget>[
            _SetupChecklist(snapshot: snapshot),
            _PermissionGateSummary(
              canManageTenant: canManageTenant,
              canManageFacility: canManageFacility,
            ),
            _TenantProfileForm(
              tenant: snapshot.tenant,
              canSubmit: canManageTenant,
            ),
            _FacilityProfileForm(
              snapshot: snapshot,
              canSubmit: canManageFacility && snapshot.tenant != null,
            ),
            _BranchSetupSection(
              snapshot: snapshot,
              canSubmit: canManageFacility && snapshot.facility != null,
            ),
            _DepartmentUnitSection(
              snapshot: snapshot,
              canSubmit: canManageFacility && snapshot.facility != null,
            ),
            _RoomsWardsBedsSection(snapshot: snapshot),
          ],
        ),
      ],
    );
  }
}

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({required this.snapshot});

  final FacilitySetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScreenSection(
      title: l10n.tenantFacilityChecklistTitle,
      body: l10n.tenantFacilityChecklistBody(
        snapshot.completedChecklistItems,
        4,
      ),
      child: Column(
        children: <Widget>[
          _ChecklistItem(
            completed: snapshot.hasTenant,
            label: l10n.tenantFacilityChecklistTenant,
          ),
          _ChecklistItem(
            completed: snapshot.hasFacilityIdentity,
            label: l10n.tenantFacilityChecklistIdentity,
          ),
          _ChecklistItem(
            completed: snapshot.hasDepartmentsAndUnits,
            label: l10n.tenantFacilityChecklistDepartments,
          ),
          _ChecklistItem(
            completed:
                snapshot.roomsCount > 0 ||
                snapshot.wardsCount > 0 ||
                snapshot.bedsCount > 0,
            label: l10n.tenantFacilityChecklistLocations,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.completed, required this.label});

  final bool completed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed
                ? theme.statusColors.success
                : theme.colorScheme.onSurfaceVariant,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _PermissionGateSummary extends StatelessWidget {
  const _PermissionGateSummary({
    required this.canManageTenant,
    required this.canManageFacility,
  });

  final bool canManageTenant;
  final bool canManageFacility;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScreenSection(
      title: l10n.tenantFacilityPermissionsTitle,
      body: l10n.tenantFacilityPermissionsBody,
      child: Column(
        children: <Widget>[
          _PermissionRow(
            allowed: canManageTenant,
            label: l10n.tenantFacilityTenantAdminPermission,
          ),
          _PermissionRow(
            allowed: canManageFacility,
            label: l10n.tenantFacilityFacilityAdminPermission,
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.allowed, required this.label});

  final bool allowed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool compact = breakpoint.isMobile;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: compact ? 2 : 0),
            child: Icon(
              allowed ? Icons.lock_open_outlined : Icons.lock_outline,
              color: allowed
                  ? theme.statusColors.success
                  : theme.colorScheme.onSurfaceVariant,
              size: theme.appTokens.listIconSize,
            ),
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: Text(
              label,
              style: compact ? theme.textTheme.bodyMedium : null,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            allowed
                ? l10n.tenantFacilityPermissionAllowed
                : l10n.tenantFacilityPermissionDenied,
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _TenantProfileForm extends ConsumerStatefulWidget {
  const _TenantProfileForm({required this.tenant, required this.canSubmit});

  final TenantProfile? tenant;
  final bool canSubmit;

  @override
  ConsumerState<_TenantProfileForm> createState() => _TenantProfileFormState();
}

class _TenantProfileFormState extends ConsumerState<_TenantProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant?.name);
    _slugController = TextEditingController(text: widget.tenant?.slug);
    _isActive = widget.tenant?.isActive ?? true;
  }

  @override
  void didUpdateWidget(_TenantProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant?.id != widget.tenant?.id) {
      _nameController.text = widget.tenant?.name ?? '';
      _slugController.text = widget.tenant?.slug ?? '';
      _isActive = widget.tenant?.isActive ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);

    return AppScreenSection(
      title: l10n.tenantFacilityTenantSectionTitle,
      body: l10n.tenantFacilityTenantSectionBody,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: widget.canSubmit && !submission.isSubmitting,
              labelText: l10n.tenantFacilityTenantNameLabel,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _slugController,
              enabled: widget.canSubmit && !submission.isSubmitting,
              labelText: l10n.tenantFacilityTenantSlugLabel,
            ),
            AppSwitchField(
              title: l10n.tenantFacilityActiveLabel,
              value: _isActive,
              enabled: widget.canSubmit && !submission.isSubmitting,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            _SubmitButton(
              enabled: widget.canSubmit,
              isLoading: submission.isSubmitting,
              label: l10n.tenantFacilitySaveTenantAction,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveTenant(
          id: widget.tenant?.id,
          name: _nameController.text,
          slug: _slugController.text,
          isActive: _isActive,
        );
    if (saved && mounted) {
      _showSaved(context);
    }
  }
}

class _FacilityProfileForm extends ConsumerStatefulWidget {
  const _FacilityProfileForm({required this.snapshot, required this.canSubmit});

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  ConsumerState<_FacilityProfileForm> createState() =>
      _FacilityProfileFormState();
}

class _FacilityProfileFormState extends ConsumerState<_FacilityProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressLineController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late FacilitySetupType _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.snapshot.facility?.name,
    );
    _logoUrlController = TextEditingController(
      text: widget.snapshot.facility?.logoUrl,
    );
    _phoneController = TextEditingController(
      text: widget.snapshot.contactAddress.phone,
    );
    _emailController = TextEditingController(
      text: widget.snapshot.contactAddress.email,
    );
    _addressLineController = TextEditingController(
      text: widget.snapshot.contactAddress.addressLine1,
    );
    _cityController = TextEditingController(
      text: widget.snapshot.contactAddress.city,
    );
    _countryController = TextEditingController(
      text: widget.snapshot.contactAddress.country,
    );
    _type = widget.snapshot.facility?.type ?? FacilitySetupType.hospital;
    _isActive = widget.snapshot.facility?.isActive ?? true;
  }

  @override
  void didUpdateWidget(_FacilityProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.facility?.id != widget.snapshot.facility?.id) {
      _nameController.text = widget.snapshot.facility?.name ?? '';
      _logoUrlController.text = widget.snapshot.facility?.logoUrl ?? '';
      _phoneController.text = widget.snapshot.contactAddress.phone ?? '';
      _emailController.text = widget.snapshot.contactAddress.email ?? '';
      _addressLineController.text =
          widget.snapshot.contactAddress.addressLine1 ?? '';
      _cityController.text = widget.snapshot.contactAddress.city ?? '';
      _countryController.text = widget.snapshot.contactAddress.country ?? '';
      _type = widget.snapshot.facility?.type ?? FacilitySetupType.hospital;
      _isActive = widget.snapshot.facility?.isActive ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEdit = widget.canSubmit && !submission.isSubmitting;

    return AppScreenSection(
      title: l10n.tenantFacilityFacilitySectionTitle,
      body: l10n.tenantFacilityFacilitySectionBody,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              enabled: canEdit,
              labelText: l10n.authFacilityNameLabel,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<FacilitySetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.authFacilityTypeLabel,
              options: <AppSelectOption<FacilitySetupType>>[
                for (final type in FacilitySetupType.values)
                  AppSelectOption<FacilitySetupType>(
                    value: type,
                    label: _facilityTypeLabel(l10n, type),
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
            AppTextField(
              controller: _logoUrlController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityLogoUrlLabel,
              helperText: l10n.tenantFacilityLogoUrlHelper,
              keyboardType: TextInputType.url,
            ),
            AppTextField(
              controller: _phoneController,
              enabled: canEdit,
              labelText: l10n.profilePhoneLabel,
              keyboardType: TextInputType.phone,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppTextField(
              controller: _emailController,
              enabled: canEdit,
              labelText: l10n.profileEmailLabel,
              keyboardType: TextInputType.emailAddress,
              validator: AppValidators.email(l10n.authEmailInvalidMessage),
            ),
            AppTextField(
              controller: _addressLineController,
              enabled: canEdit,
              labelText: l10n.tenantFacilityAddressLineLabel,
              textCapitalization: TextCapitalization.words,
            ),
            _TwoColumnFields(
              left: AppTextField(
                controller: _cityController,
                enabled: canEdit,
                labelText: l10n.tenantFacilityCityLabel,
                textCapitalization: TextCapitalization.words,
              ),
              right: AppTextField(
                controller: _countryController,
                enabled: canEdit,
                labelText: l10n.tenantFacilityCountryLabel,
                textCapitalization: TextCapitalization.words,
              ),
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
            _SubmitButton(
              enabled: widget.canSubmit,
              isLoading: submission.isSubmitting,
              label: l10n.tenantFacilitySaveFacilityAction,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    if (tenant == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .saveFacility(
          id: widget.snapshot.facility?.id,
          tenantId: tenant.id,
          name: _nameController.text,
          type: _type,
          isActive: _isActive,
          logoUrl: _logoUrlController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          addressLine1: _addressLineController.text,
          city: _cityController.text,
          country: _countryController.text,
        );
    if (saved && mounted) {
      _showSaved(context);
    }
  }
}

class _BranchSetupSection extends ConsumerStatefulWidget {
  const _BranchSetupSection({required this.snapshot, required this.canSubmit});

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  ConsumerState<_BranchSetupSection> createState() =>
      _BranchSetupSectionState();
}

class _BranchSetupSectionState extends ConsumerState<_BranchSetupSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEdit = widget.canSubmit && !submission.isSubmitting;

    return AppScreenSection(
      title: l10n.tenantFacilityBranchesSectionTitle,
      body: l10n.tenantFacilityBranchesSectionBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InlineList(
            emptyLabel: l10n.tenantFacilityNoBranches,
            labels: widget.snapshot.branches
                .map((BranchProfile branch) => branch.name)
                .toList(growable: false),
          ),
          SizedBox(height: Theme.of(context).spacing.lg),
          Form(
            key: _formKey,
            child: AppFormSection(
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  controller: _nameController,
                  enabled: canEdit,
                  labelText: l10n.tenantFacilityBranchNameLabel,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
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
                _SubmitButton(
                  enabled: widget.canSubmit,
                  isLoading: submission.isSubmitting,
                  label: l10n.tenantFacilityAddBranchAction,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
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
        .createBranch(
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          isActive: _isActive,
        );
    if (saved && mounted) {
      _nameController.clear();
      _showSaved(context);
    }
  }
}

class _DepartmentUnitSection extends ConsumerStatefulWidget {
  const _DepartmentUnitSection({
    required this.snapshot,
    required this.canSubmit,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;

  @override
  ConsumerState<_DepartmentUnitSection> createState() =>
      _DepartmentUnitSectionState();
}

class _DepartmentUnitSectionState
    extends ConsumerState<_DepartmentUnitSection> {
  final _departmentFormKey = GlobalKey<FormState>();
  final _unitFormKey = GlobalKey<FormState>();
  final _departmentNameController = TextEditingController();
  final _departmentShortNameController = TextEditingController();
  final _unitNameController = TextEditingController();
  DepartmentSetupType _departmentType = DepartmentSetupType.clinical;
  String? _unitDepartmentId;
  bool _departmentActive = true;
  bool _unitActive = true;

  @override
  void dispose() {
    _departmentNameController.dispose();
    _departmentShortNameController.dispose();
    _unitNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEdit = widget.canSubmit && !submission.isSubmitting;

    return AppScreenSection(
      title: l10n.tenantFacilityDepartmentsSectionTitle,
      body: l10n.tenantFacilityDepartmentsSectionBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InlineList(
            emptyLabel: l10n.tenantFacilityNoDepartments,
            labels: widget.snapshot.departments
                .map((DepartmentProfile department) => department.name)
                .toList(growable: false),
          ),
          SizedBox(height: theme.spacing.lg),
          Form(
            key: _departmentFormKey,
            child: AppFormSection(
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  controller: _departmentNameController,
                  enabled: canEdit,
                  labelText: l10n.tenantFacilityDepartmentNameLabel,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
                AppTextField(
                  controller: _departmentShortNameController,
                  enabled: canEdit,
                  labelText: l10n.tenantFacilityDepartmentShortNameLabel,
                ),
                AppSelectField<DepartmentSetupType>(
                  value: _departmentType,
                  enabled: canEdit,
                  labelText: l10n.tenantFacilityDepartmentTypeLabel,
                  options: <AppSelectOption<DepartmentSetupType>>[
                    for (final type in DepartmentSetupType.values)
                      AppSelectOption<DepartmentSetupType>(
                        value: type,
                        label: _departmentTypeLabel(l10n, type),
                      ),
                  ],
                  onChanged: (DepartmentSetupType? value) {
                    if (value != null) {
                      setState(() {
                        _departmentType = value;
                      });
                    }
                  },
                ),
                AppSwitchField(
                  title: l10n.tenantFacilityActiveLabel,
                  value: _departmentActive,
                  enabled: canEdit,
                  onChanged: (bool value) {
                    setState(() {
                      _departmentActive = value;
                    });
                  },
                ),
                _SubmitButton(
                  enabled: widget.canSubmit,
                  isLoading: submission.isSubmitting,
                  label: l10n.tenantFacilityAddDepartmentAction,
                  onPressed: _submitDepartment,
                ),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.xl),
          _InlineList(
            emptyLabel: l10n.tenantFacilityNoUnits,
            labels: widget.snapshot.units
                .map((UnitProfile unit) => unit.name)
                .toList(growable: false),
          ),
          SizedBox(height: theme.spacing.lg),
          Form(
            key: _unitFormKey,
            child: AppFormSection(
              density: AppFormSectionDensity.compact,
              children: <Widget>[
                AppTextField(
                  controller: _unitNameController,
                  enabled: canEdit,
                  labelText: l10n.tenantFacilityUnitNameLabel,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.requiredText(
                    l10n.validationRequired,
                  ),
                ),
                AppSelectField<String>(
                  value: _unitDepartmentId,
                  enabled: canEdit && widget.snapshot.departments.isNotEmpty,
                  labelText: l10n.tenantFacilityUnitDepartmentLabel,
                  options: <AppSelectOption<String>>[
                    for (final DepartmentProfile department
                        in widget.snapshot.departments)
                      AppSelectOption<String>(
                        value: department.id,
                        label: department.name,
                      ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _unitDepartmentId = value;
                    });
                  },
                ),
                AppSwitchField(
                  title: l10n.tenantFacilityActiveLabel,
                  value: _unitActive,
                  enabled: canEdit,
                  onChanged: (bool value) {
                    setState(() {
                      _unitActive = value;
                    });
                  },
                ),
                _SubmitButton(
                  enabled: widget.canSubmit,
                  isLoading: submission.isSubmitting,
                  label: l10n.tenantFacilityAddUnitAction,
                  onPressed: _submitUnit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDepartment() async {
    if (_departmentFormKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .createDepartment(
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _departmentNameController.text,
          shortName: _departmentShortNameController.text,
          type: _departmentType,
          isActive: _departmentActive,
        );
    if (saved && mounted) {
      _departmentNameController.clear();
      _departmentShortNameController.clear();
      _showSaved(context);
    }
  }

  Future<void> _submitUnit() async {
    if (_unitFormKey.currentState?.validate() != true) {
      return;
    }

    final TenantProfile? tenant = widget.snapshot.tenant;
    final FacilityProfile? facility = widget.snapshot.facility;
    if (tenant == null || facility == null) {
      return;
    }

    final bool saved = await ref
        .read(tenantFacilitySetupSubmissionProvider.notifier)
        .createUnit(
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _unitNameController.text,
          departmentId: _unitDepartmentId,
          isActive: _unitActive,
        );
    if (saved && mounted) {
      _unitNameController.clear();
      _showSaved(context);
    }
  }
}

class _RoomsWardsBedsSection extends StatelessWidget {
  const _RoomsWardsBedsSection({required this.snapshot});

  final FacilitySetupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScreenSection(
      title: l10n.tenantFacilityLocationsSectionTitle,
      body: l10n.tenantFacilityLocationsSectionBody,
      child: Wrap(
        spacing: Theme.of(context).spacing.sm,
        runSpacing: Theme.of(context).spacing.sm,
        children: <Widget>[
          _CountTile(
            label: l10n.tenantFacilityRoomsLabel,
            count: snapshot.roomsCount,
          ),
          _CountTile(
            label: l10n.tenantFacilityWardsLabel,
            count: snapshot.wardsCount,
          ),
          _CountTile(
            label: l10n.tenantFacilityBedsLabel,
            count: snapshot.bedsCount,
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool compact = breakpoint.isMobile;
    final double tileWidth = switch (breakpoint) {
      AppBreakpoint.xs => double.infinity,
      AppBreakpoint.sm => 132,
      _ => 120,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? theme.spacing.sm : theme.spacing.md),
        child: SizedBox(
          width: tileWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(count.toString(), style: theme.textTheme.headlineSmall),
              SizedBox(height: theme.spacing.xs),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineList extends StatelessWidget {
  const _InlineList({required this.emptyLabel, required this.labels});

  final String emptyLabel;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final double maxChipWidth = switch (breakpoint) {
      AppBreakpoint.xs => double.infinity,
      AppBreakpoint.sm => 220,
      _ => 260,
    };

    if (labels.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final String label in labels.take(6))
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxChipWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          ),
      ],
    );
  }
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

class _SetupGrid extends StatelessWidget {
  const _SetupGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= 1000;
        final bool compact = constraints.maxWidth < AppBreakpoints.sm;
        final double gap = compact ? theme.spacing.md : theme.spacing.lg;
        final double itemWidth = useTwoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SubmitButton extends ConsumerWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;

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
            l10n.tenantFacilityPermissionRequired,
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

String _facilityTypeLabel(AppLocalizations l10n, FacilitySetupType type) {
  return switch (type) {
    FacilitySetupType.hospital => l10n.authFacilityTypeHospital,
    FacilitySetupType.clinic => l10n.authFacilityTypeClinic,
    FacilitySetupType.lab => l10n.authFacilityTypeLab,
    FacilitySetupType.pharmacy => l10n.authFacilityTypePharmacy,
    FacilitySetupType.other => l10n.authFacilityTypeOther,
  };
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

void _showSaved(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(context.l10n.tenantFacilitySavedMessage)),
    );
}
