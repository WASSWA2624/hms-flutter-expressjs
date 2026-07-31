import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class HomeTenantContextPanel extends ConsumerStatefulWidget {
  const HomeTenantContextPanel({
    required this.tenantOptions,
    required this.request,
    super.key,
  });

  final List<HomeTenantOption> tenantOptions;
  final HomeDashboardRequest request;

  @override
  ConsumerState<HomeTenantContextPanel> createState() =>
      _HomeTenantContextPanelState();
}

class _HomeTenantContextPanelState
    extends ConsumerState<HomeTenantContextPanel> {
  String? _selectedTenantId;
  String? _selectedFacilityId;

  @override
  void initState() {
    super.initState();
    _selectedTenantId = widget.request.tenantId;
    _selectedFacilityId = widget.request.facilityId;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<HomeDashboardLookups>> lookups = ref.watch(
      homeLookupsControllerProvider(
        HomeDashboardRequest(
          tenantId: _selectedTenantId,
          facilityId: _selectedFacilityId,
        ),
      ),
    );

    return lookups.when(
      loading: () => const _ContextPanelShell(
        children: <Widget>[
          AppMessagePanel(
            message: 'Loading tenant and facility options...',
            icon: Icons.hourglass_top_outlined,
          ),
        ],
      ),
      error: (_, _) => _ContextPanelShell(
        children: <Widget>[
          _TenantButtons(
            tenantOptions: widget.tenantOptions,
            request: widget.request,
          ),
        ],
      ),
      data: (Result<HomeDashboardLookups> result) {
        return result.when(
          success: (HomeDashboardLookups data) {
            final List<HomeLookupOption> tenants = _tenantChoices(data);
            final List<HomeLookupOption> facilities = data.facilitiesForTenant(
              _selectedTenantId,
            );

            return _ContextPanelShell(
              children: <Widget>[
                if (tenants.isNotEmpty)
                  _LookupDropdown(
                    label: 'Tenant',
                    value: _selectedTenantId,
                    options: tenants,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedTenantId = value;
                        _selectedFacilityId = null;
                      });
                    },
                  ),
                if (facilities.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _LookupDropdown(
                    label: 'Facility',
                    value: _selectedFacilityId,
                    options: facilities,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedFacilityId = value;
                      });
                    },
                  ),
                ],
                if (tenants.isEmpty && widget.tenantOptions.isNotEmpty)
                  _TenantButtons(
                    tenantOptions: widget.tenantOptions,
                    request: widget.request,
                  ),
                if (tenants.isEmpty && widget.tenantOptions.isEmpty)
                  const AppMessagePanel(
                    message: 'No tenant options were returned.',
                    icon: Icons.info_outline,
                  ),
                const SizedBox(height: 16),
                AppButton.primary(
                  label: 'Open dashboard',
                  leadingIcon: Icons.dashboard_outlined,
                  onPressed: _selectedTenantId == null
                      ? null
                      : () => _openDashboard(context),
                ),
              ],
            );
          },
          failure: (_) => _ContextPanelShell(
            children: <Widget>[
              _TenantButtons(
                tenantOptions: widget.tenantOptions,
                request: widget.request,
              ),
            ],
          ),
        );
      },
    );
  }

  List<HomeLookupOption> _tenantChoices(HomeDashboardLookups lookups) {
    if (lookups.tenants.isNotEmpty) {
      return lookups.tenants;
    }
    return widget.tenantOptions
        .map(
          (HomeTenantOption option) =>
              HomeLookupOption(id: option.id, label: option.label),
        )
        .toList(growable: false);
  }

  void _openDashboard(BuildContext context) {
    context.go(
      AppRoutes.home.location(
        queryParameters: <String, String>{
          'tenant_id': _selectedTenantId!,
          'facility_id': ?_selectedFacilityId,
        },
      ),
    );
  }
}

class _ContextPanelShell extends StatelessWidget {
  const _ContextPanelShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: 'Tenant context required',
      description:
          'Choose tenant and facility scope to view operational dashboard content.',
      leadingIcon: Icons.account_tree_outlined,
      children: children,
    );
  }
}

class _TenantButtons extends StatelessWidget {
  const _TenantButtons({required this.tenantOptions, required this.request});

  final List<HomeTenantOption> tenantOptions;
  final HomeDashboardRequest request;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveWrap(
      minItemWidth: 220,
      children: <Widget>[
        for (final HomeTenantOption option in tenantOptions)
          AppButton.secondary(
            label: option.label,
            leadingIcon: Icons.business_outlined,
            onPressed: () {
              context.go(
                AppRoutes.home.location(
                  queryParameters: <String, String>{
                    'tenant_id': option.id,
                    if (request.facilityId != null)
                      'facility_id': request.facilityId!,
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LookupDropdown extends StatelessWidget {
  const _LookupDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<HomeLookupOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>(
      labelText: label,
      value: value,
      options: options
          .map(
            (HomeLookupOption option) =>
                AppSelectOption<String>(value: option.id, label: option.label),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}
