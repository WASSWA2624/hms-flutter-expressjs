import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
    final ThemeData theme = Theme.of(context);
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
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        _SetupSummaryGrid(
          children: <Widget>[
            _SetupSummaryCard(
              icon: Icons.apartment_outlined,
              title: l10n.tenantFacilityTenantSectionTitle,
              body: l10n.tenantFacilityTenantSectionBody,
              detail:
                  snapshot.tenant?.name ?? l10n.tenantFacilitySummaryNoTenant,
              statusLabel: snapshot.hasTenant
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.hasTenant,
              onPressed: () => _openTenantProfileModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.local_hospital_outlined,
              title: l10n.tenantFacilityFacilitySectionTitle,
              body: l10n.tenantFacilityFacilitySectionBody,
              detail:
                  snapshot.facility?.name ??
                  l10n.tenantFacilitySummaryNoFacility,
              statusLabel: snapshot.hasFacilityIdentity
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.hasFacilityIdentity,
              onPressed: () => _openFacilityProfileModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.account_tree_outlined,
              title: l10n.tenantFacilityBranchesSectionTitle,
              body: l10n.tenantFacilityBranchesSectionBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.branches.length,
              ),
              statusLabel: snapshot.branches.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.branches.isNotEmpty,
              onPressed: () => _openBranchesModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.groups_2_outlined,
              title: l10n.tenantFacilityDepartmentsListTitle,
              body: l10n.tenantFacilityDepartmentsModalBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.departments.length,
              ),
              statusLabel: snapshot.departments.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.departments.isNotEmpty,
              onPressed: () => _openDepartmentsModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.hub_outlined,
              title: l10n.tenantFacilityUnitsListTitle,
              body: l10n.tenantFacilityUnitsModalBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.units.length,
              ),
              statusLabel: snapshot.units.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.units.isNotEmpty,
              onPressed: () => _openUnitsModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.local_hotel_outlined,
              title: l10n.tenantFacilityWardsLabel,
              body: l10n.tenantFacilityWardsModalBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.wards.length,
              ),
              statusLabel: snapshot.wards.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.wards.isNotEmpty,
              onPressed: () => _openWardsModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.meeting_room_outlined,
              title: l10n.tenantFacilityRoomsLabel,
              body: l10n.tenantFacilityRoomsModalBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.rooms.length,
              ),
              statusLabel: snapshot.rooms.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.rooms.isNotEmpty,
              onPressed: () => _openRoomsModal(context),
            ),
            _SetupSummaryCard(
              icon: Icons.bed_outlined,
              title: l10n.tenantFacilityBedsLabel,
              body: l10n.tenantFacilityBedsModalBody,
              detail: l10n.tenantFacilitySummaryRecordCount(
                snapshot.beds.length,
              ),
              statusLabel: snapshot.beds.isNotEmpty
                  ? l10n.tenantFacilitySummaryConfigured
                  : l10n.tenantFacilitySummaryNeedsSetup,
              completed: snapshot.beds.isNotEmpty,
              onPressed: () => _openBedsModal(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetupSummaryGrid extends StatelessWidget {
  const _SetupSummaryGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = switch (constraints.maxWidth) {
          >= 1180 => 3,
          >= 760 => 2,
          _ => 1,
        };
        final double gap = constraints.maxWidth < AppBreakpoints.sm
            ? theme.spacing.md
            : theme.spacing.lg;
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

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

class _SetupSummaryCard extends StatelessWidget {
  const _SetupSummaryCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.detail,
    required this.statusLabel,
    required this.completed,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String detail;
  final String statusLabel;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color statusColor = completed
        ? theme.statusColors.success
        : colorScheme.onSurfaceVariant;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(icon, color: colorScheme.primary),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.primary),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              SizedBox(height: theme.spacing.md),
              Row(
                children: <Widget>[
                  Icon(
                    completed
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    color: statusColor,
                    size: theme.appTokens.listIconSize,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SetupDetailBuilder =
    Widget Function(
      BuildContext context,
      FacilitySetupSnapshot snapshot,
      bool canManageTenant,
      bool canManageFacility,
    );

class _SetupDetailDialog extends ConsumerWidget {
  const _SetupDetailDialog({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final _SetupDetailBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final setup = ref.watch(tenantFacilitySetupControllerProvider);

    return AppDialog(
      title: Text(title),
      icon: Icon(icon),
      scrollable: true,
      maxWidth: 880,
      content: setup.when(
        data: (result) => result.when(
          success: (FacilitySetupSnapshot snapshot) => builder(
            context,
            snapshot,
            accessPolicy.canManageTenant(),
            accessPolicy.canManageFacility(),
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
            ref.read(tenantFacilitySetupControllerProvider.notifier).refresh();
          },
        ),
        loading: () => AppStateView(
          variant: AppStateViewVariant.loading,
          title: l10n.tenantFacilitySetupLoadingTitle,
          body: l10n.tenantFacilitySetupLoadingBody,
        ),
      ),
    );
  }
}

Future<void> _openTenantProfileModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityTenantSectionTitle,
      icon: Icons.apartment_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _TenantProfileForm(
            tenant: snapshot.tenant,
            canSubmit: canManageTenant,
            framed: false,
          ),
    ),
  );
}

Future<void> _openFacilityProfileModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityFacilitySectionTitle,
      icon: Icons.local_hospital_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _FacilityProfileForm(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.tenant != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openBranchesModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityBranchesSectionTitle,
      icon: Icons.account_tree_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _BranchSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openDepartmentsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityDepartmentsListTitle,
      icon: Icons.groups_2_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _DepartmentSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openUnitsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityUnitsListTitle,
      icon: Icons.hub_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _UnitSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openWardsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityWardsLabel,
      icon: Icons.local_hotel_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _WardSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openRoomsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityRoomsLabel,
      icon: Icons.meeting_room_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _RoomSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

Future<void> _openBedsModal(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<void>(
    context: context,
    builder: (_) => _SetupDetailDialog(
      title: l10n.tenantFacilityBedsLabel,
      icon: Icons.bed_outlined,
      builder:
          (
            BuildContext context,
            FacilitySetupSnapshot snapshot,
            bool canManageTenant,
            bool canManageFacility,
          ) => _BedSetupSection(
            snapshot: snapshot,
            canSubmit: canManageFacility && snapshot.facility != null,
            framed: false,
          ),
    ),
  );
}

AppFailure _setupFailure(Object error) {
  if (error is AppFailure) {
    return error;
  }

  return const AppFailure.unexpected();
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
  const _TenantProfileForm({
    required this.tenant,
    required this.canSubmit,
    this.framed = true,
  });

  final TenantProfile? tenant;
  final bool canSubmit;
  final bool framed;

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
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);

    final Widget form = Form(
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
    );

    if (widget.framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityTenantSectionTitle,
        body: l10n.tenantFacilityTenantSectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.tenantFacilityTenantSectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
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
  const _FacilityProfileForm({
    required this.snapshot,
    required this.canSubmit,
    this.framed = true,
  });

  final FacilitySetupSnapshot snapshot;
  final bool canSubmit;
  final bool framed;

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
    final ThemeData theme = Theme.of(context);
    final submission = ref.watch(tenantFacilitySetupSubmissionProvider);
    final bool canEdit = widget.canSubmit && !submission.isSubmitting;

    final Widget form = Form(
      key: _formKey,
      child: AppFormSection(
        children: <Widget>[
          if (widget.snapshot.facilities.length > 1)
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
    );

    if (widget.framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityFacilitySectionTitle,
        body: l10n.tenantFacilityFacilitySectionBody,
        child: form,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.tenantFacilityFacilitySectionBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        form,
      ],
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

const String _noneSelection = '__none__';

class _BranchSetupSection extends ConsumerWidget {
  const _BranchSetupSection({
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
    final bool canEdit = canSubmit && !submission.isSubmitting;

    final Widget content = _SearchableEntityGroup<BranchProfile>(
      title: l10n.tenantFacilityBranchesListTitle,
      items: snapshot.branches,
      emptyLabel: l10n.tenantFacilityNoBranches,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityBranchSearchHint,
      addLabel: l10n.tenantFacilityAddBranchAction,
      canEdit: canEdit,
      onAdd: () => _openBranchDialog(context, snapshot),
      titleBuilder: (BranchProfile branch) => branch.name,
      subtitleBuilder: (BranchProfile branch) =>
          _activeStatusLabel(l10n, branch.isActive),
      onEdit: (BranchProfile branch) =>
          _openBranchDialog(context, snapshot, branch: branch),
      onDelete: (BranchProfile branch) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteBranch(branch.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityBranchesSectionTitle,
        body: l10n.tenantFacilityBranchesSectionBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityBranchesSectionBody,
      child: content,
    );
  }
}

class _DepartmentSetupSection extends ConsumerWidget {
  const _DepartmentSetupSection({
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
    final bool canEdit = canSubmit && !submission.isSubmitting;

    final Widget content = _SearchableEntityGroup<DepartmentProfile>(
      title: l10n.tenantFacilityDepartmentsListTitle,
      items: snapshot.departments,
      emptyLabel: l10n.tenantFacilityNoDepartments,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityDepartmentSearchHint,
      addLabel: l10n.tenantFacilityAddDepartmentAction,
      canEdit: canEdit,
      onAdd: () => _openDepartmentDialog(context, snapshot),
      titleBuilder: (DepartmentProfile department) => department.name,
      subtitleBuilder: (DepartmentProfile department) =>
          _departmentSubtitle(l10n, snapshot, department),
      onEdit: (DepartmentProfile department) =>
          _openDepartmentDialog(context, snapshot, department: department),
      onDelete: (DepartmentProfile department) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteDepartment(department.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityDepartmentsListTitle,
        body: l10n.tenantFacilityDepartmentsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityDepartmentsModalBody,
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
    final bool canEdit = canSubmit && !submission.isSubmitting;

    final Widget content = _SearchableEntityGroup<UnitProfile>(
      title: l10n.tenantFacilityUnitsListTitle,
      items: snapshot.units,
      emptyLabel: l10n.tenantFacilityNoUnits,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityUnitSearchHint,
      addLabel: l10n.tenantFacilityAddUnitAction,
      canEdit: canEdit,
      onAdd: () => _openUnitDialog(context, snapshot),
      titleBuilder: (UnitProfile unit) => unit.name,
      subtitleBuilder: (UnitProfile unit) =>
          _unitSubtitle(l10n, snapshot, unit),
      onEdit: (UnitProfile unit) =>
          _openUnitDialog(context, snapshot, unit: unit),
      onDelete: (UnitProfile unit) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteUnit(unit.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityUnitsListTitle,
        body: l10n.tenantFacilityUnitsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityUnitsModalBody,
      child: content,
    );
  }
}

class _WardSetupSection extends ConsumerWidget {
  const _WardSetupSection({
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
    final bool canEdit = canSubmit && !submission.isSubmitting;

    final Widget content = _SearchableEntityGroup<WardProfile>(
      title: l10n.tenantFacilityWardsLabel,
      items: snapshot.wards,
      emptyLabel: l10n.tenantFacilityNoWards,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityWardSearchHint,
      addLabel: l10n.tenantFacilityAddWardAction,
      canEdit: canEdit,
      onAdd: () => _openWardDialog(context, snapshot),
      titleBuilder: (WardProfile ward) => ward.name,
      subtitleBuilder: (WardProfile ward) =>
          _wardSubtitle(l10n, snapshot, ward),
      onEdit: (WardProfile ward) =>
          _openWardDialog(context, snapshot, ward: ward),
      onDelete: (WardProfile ward) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteWard(ward.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityWardsLabel,
        body: l10n.tenantFacilityWardsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityWardsModalBody,
      child: content,
    );
  }
}

class _RoomSetupSection extends ConsumerWidget {
  const _RoomSetupSection({
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
    final bool canEdit =
        canSubmit && !submission.isSubmitting && snapshot.wards.isNotEmpty;

    final Widget content = _SearchableEntityGroup<RoomProfile>(
      title: l10n.tenantFacilityRoomsLabel,
      items: snapshot.rooms,
      emptyLabel: l10n.tenantFacilityNoRooms,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityRoomSearchHint,
      addLabel: l10n.tenantFacilityAddRoomAction,
      canEdit: canEdit,
      onAdd: () => _openRoomDialog(context, snapshot),
      titleBuilder: (RoomProfile room) => room.name,
      subtitleBuilder: (RoomProfile room) =>
          _roomSubtitle(l10n, snapshot, room),
      onEdit: (RoomProfile room) =>
          _openRoomDialog(context, snapshot, room: room),
      onDelete: (RoomProfile room) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteRoom(room.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityRoomsLabel,
        body: l10n.tenantFacilityRoomsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityRoomsModalBody,
      child: content,
    );
  }
}

class _BedSetupSection extends ConsumerWidget {
  const _BedSetupSection({
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
    final bool canEdit =
        canSubmit && !submission.isSubmitting && snapshot.wards.isNotEmpty;

    final Widget content = _SearchableEntityGroup<BedProfile>(
      title: l10n.tenantFacilityBedsLabel,
      items: snapshot.beds,
      emptyLabel: l10n.tenantFacilityNoBeds,
      noResultsLabel: l10n.tenantFacilitySearchNoResults,
      searchLabel: l10n.tenantFacilitySearchLabel,
      searchHint: l10n.tenantFacilityBedSearchHint,
      addLabel: l10n.tenantFacilityAddBedAction,
      canEdit: canEdit,
      onAdd: () => _openBedDialog(context, snapshot),
      titleBuilder: (BedProfile bed) => bed.label,
      subtitleBuilder: (BedProfile bed) => _bedSubtitle(l10n, snapshot, bed),
      onEdit: (BedProfile bed) => _openBedDialog(context, snapshot, bed: bed),
      onDelete: (BedProfile bed) => _deleteEntity(
        context: context,
        deleteAction: () => ref
            .read(tenantFacilitySetupSubmissionProvider.notifier)
            .deleteBed(bed.id),
      ),
    );

    if (framed) {
      return AppScreenSection(
        title: l10n.tenantFacilityBedsLabel,
        body: l10n.tenantFacilityBedsModalBody,
        child: content,
      );
    }

    return _ModalSectionBody(
      body: l10n.tenantFacilityBedsModalBody,
      child: content,
    );
  }
}

class _ModalSectionBody extends StatelessWidget {
  const _ModalSectionBody({required this.body, required this.child});

  final String body;
  final Widget child;

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
        SizedBox(height: theme.spacing.lg),
        child,
      ],
    );
  }
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
    required this.canEdit,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String noResultsLabel;
  final String searchLabel;
  final String searchHint;
  final String addLabel;
  final bool canEdit;
  final VoidCallback onAdd;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;

  @override
  State<_SearchableEntityGroup<T>> createState() =>
      _SearchableEntityGroupState<T>();
}

class _SearchableEntityGroupState<T> extends State<_SearchableEntityGroup<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<T> filteredItems = _filteredItems();
    final bool isSearching = _query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          controller: _searchController,
          labelText: widget.searchLabel,
          hintText: widget.searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: isSearching
              ? AppIconButton(
                  icon: Icons.close,
                  semanticLabel: l10n.tenantFacilityClearSearchAction,
                  tooltip: l10n.tenantFacilityClearSearchAction,
                  onPressed: _clearSearch,
                )
              : null,
          textInputAction: TextInputAction.search,
          onChanged: (String value) {
            setState(() {
              _query = value;
            });
          },
        ),
        SizedBox(height: theme.spacing.md),
        _EntityGroup<T>(
          title: widget.title,
          items: filteredItems,
          emptyLabel: isSearching ? widget.noResultsLabel : widget.emptyLabel,
          addLabel: widget.addLabel,
          canEdit: widget.canEdit,
          onAdd: widget.onAdd,
          titleBuilder: widget.titleBuilder,
          subtitleBuilder: widget.subtitleBuilder,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ],
    );
  }

  List<T> _filteredItems() {
    final String query = _normalizeSearch(_query);
    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items
        .where(
          (T item) => _entitySearchText(
            widget.titleBuilder(item),
            widget.subtitleBuilder(item),
          ).contains(query),
        )
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }
}

String _entitySearchText(String title, String subtitle) {
  return _normalizeSearch('$title $subtitle');
}

String _normalizeSearch(String value) {
  return value.trim().toLowerCase();
}

class _EntityGroup<T> extends StatelessWidget {
  const _EntityGroup({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.addLabel,
    required this.canEdit,
    required this.onAdd,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<T> items;
  final String emptyLabel;
  final String addLabel;
  final bool canEdit;
  final VoidCallback onAdd;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            if (canEdit)
              AppButton.secondary(
                label: addLabel,
                leadingIcon: Icons.add,
                onPressed: onAdd,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final T item in items) ...<Widget>[
                _EntityRow(
                  title: titleBuilder(item),
                  subtitle: subtitleBuilder(item),
                  canEdit: canEdit,
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                ),
                if (item != items.last) const Divider(height: 1),
              ],
            ],
          ),
      ],
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({
    required this.title,
    required this.subtitle,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            AppIconButton(
              icon: Icons.edit_outlined,
              semanticLabel: l10n.tenantFacilityEditAction,
              onPressed: onEdit,
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              semanticLabel: l10n.tenantFacilityDeleteAction,
              onPressed: onDelete,
              color: theme.statusColors.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _BranchFormDialog extends ConsumerStatefulWidget {
  const _BranchFormDialog({required this.snapshot, this.branch});

  final FacilitySetupSnapshot snapshot;
  final BranchProfile? branch;

  @override
  ConsumerState<_BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends ConsumerState<_BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branch?.name);
    _isActive = widget.branch?.isActive ?? true;
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
    final bool isEditing = widget.branch != null;
    final bool canEdit = !submission.isSubmitting;

    return AppDialog(
      title: Text(
        isEditing
            ? l10n.tenantFacilityEditBranchTitle
            : l10n.tenantFacilityAddBranchTitle,
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
              labelText: l10n.tenantFacilityBranchNameLabel,
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
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
            _SubmissionFailureText(),
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
        .saveBranch(
          id: widget.branch?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          isActive: _isActive,
        );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
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
  late String _branchId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final DepartmentProfile? department = widget.department;
    _nameController = TextEditingController(text: department?.name);
    _shortNameController = TextEditingController(text: department?.shortName);
    _type = department?.type ?? DepartmentSetupType.clinical;
    _branchId = department?.branchId ?? _noneSelection;
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
            AppSelectField<String>.searchable(
              value: _branchId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityDepartmentBranchLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final BranchProfile branch in widget.snapshot.branches)
                  AppSelectOption<String>(value: branch.id, label: branch.name),
              ],
              onChanged: (String? value) {
                setState(() {
                  _branchId = value ?? _noneSelection;
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
            _SubmissionFailureText(),
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
        .saveDepartment(
          id: widget.department?.id,
          tenantId: tenant.id,
          facilityId: facility.id,
          name: _nameController.text,
          shortName: _shortNameController.text,
          branchId: _optionalSelection(_branchId),
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
    _departmentId = widget.unit?.departmentId ?? _noneSelection;
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
            _SubmissionFailureText(),
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
    _departmentId = widget.ward?.departmentId ?? _noneSelection;
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
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<WardSetupType>(
              value: _type,
              enabled: canEdit,
              labelText: l10n.tenantFacilityWardTypeLabel,
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
            _SubmissionFailureText(),
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
    _wardId = widget.room?.wardId ?? _noneSelection;
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
              textCapitalization: TextCapitalization.words,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityRoomWardLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: _requiredSelection(l10n),
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
            _SubmissionFailureText(),
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
              textCapitalization: TextCapitalization.characters,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            AppSelectField<String>.searchable(
              value: _wardId,
              enabled: canEdit,
              labelText: l10n.tenantFacilityBedWardLabel,
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: _noneSelection,
                  label: l10n.tenantFacilityNoSelectionLabel,
                ),
                for (final WardProfile ward in widget.snapshot.wards)
                  AppSelectOption<String>(value: ward.id, label: ward.name),
              ],
              validator: _requiredSelection(l10n),
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
            _SubmissionFailureText(),
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

class _SubmissionFailureText extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(
      tenantFacilitySetupSubmissionProvider.select((state) => state.failure),
    );
    if (failure == null) {
      return const SizedBox.shrink();
    }

    return Text(
      context.l10n.failureMessage(failure),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).statusColors.error,
      ),
    );
  }
}

Future<void> _openBranchDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BranchProfile? branch,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BranchFormDialog(snapshot: snapshot, branch: branch),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _openDepartmentDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  DepartmentProfile? department,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DepartmentFormDialog(snapshot: snapshot, department: department),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _openUnitDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  UnitProfile? unit,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnitFormDialog(snapshot: snapshot, unit: unit),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _openWardDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  WardProfile? ward,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WardFormDialog(snapshot: snapshot, ward: ward),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _openRoomDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  RoomProfile? room,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoomFormDialog(snapshot: snapshot, room: room),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _openBedDialog(
  BuildContext context,
  FacilitySetupSnapshot snapshot, {
  BedProfile? bed,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BedFormDialog(snapshot: snapshot, bed: bed),
  );
  if (saved == true && context.mounted) {
    _showSaved(context);
  }
}

Future<void> _deleteEntity({
  required BuildContext context,
  required Future<bool> Function() deleteAction,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppDialog(
      title: Text(l10n.tenantFacilityDeleteConfirmationTitle),
      content: Text(l10n.tenantFacilityDeleteConfirmationBody),
      icon: Icon(
        Icons.delete_outline,
        color: Theme.of(context).statusColors.error,
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton.primary(
          label: l10n.tenantFacilityDeleteConfirmAction,
          leadingIcon: Icons.delete_outline,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }

  final bool deleted = await deleteAction();
  if (deleted && context.mounted) {
    _showSaved(context);
  }
}

FormFieldValidator<String> _requiredSelection(AppLocalizations l10n) {
  return (String? value) =>
      _optionalSelection(value) == null ? l10n.validationRequired : null;
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
  return _joinParts(<String?>[
    _departmentTypeLabel(l10n, department.type),
    if (department.shortName != null) department.shortName!,
    _branchName(snapshot, department.branchId),
    _activeStatusLabel(l10n, department.isActive),
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
    _wardName(snapshot, room.wardId),
    if (room.floor != null) room.floor!,
    l10n.tenantFacilityRoomsLabel,
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

String? _branchName(FacilitySetupSnapshot snapshot, String? branchId) {
  return snapshot.branches
      .where((BranchProfile branch) => branch.id == branchId)
      .firstOrNull
      ?.name;
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
