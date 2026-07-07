import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

PharmacyWorkspaceState? _readPharmacyWorkspaceState(WidgetRef ref) {
  return ref
      .read(pharmacyWorkspaceControllerProvider)
      .value
      ?.when(
        success: (PharmacyWorkspaceState value) => value,
        failure: (_) => null,
      );
}

Future<void> openPharmacyCatalogDialog(
  BuildContext context,
  WidgetRef ref, {
  PharmacyCatalogTab initialTab = PharmacyCatalogTab.drugs,
}) async {
  final PharmacyWorkspaceState? initialState = _readPharmacyWorkspaceState(ref);
  if (initialState == null) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _PharmacyCatalogDialog(
      initialState: initialState,
      initialTab: initialTab,
    ),
  );
}

class _PharmacyCatalogDialog extends ConsumerStatefulWidget {
  const _PharmacyCatalogDialog({
    required this.initialState,
    required this.initialTab,
  });

  final PharmacyWorkspaceState initialState;
  final PharmacyCatalogTab initialTab;

  @override
  ConsumerState<_PharmacyCatalogDialog> createState() =>
      _PharmacyCatalogDialogState();
}

class _PharmacyCatalogDialogState
    extends ConsumerState<_PharmacyCatalogDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(pharmacyWorkspaceControllerProvider.notifier)
          .prepareCatalogTab(widget.initialTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PharmacyWorkspaceState state =
        ref
            .watch(pharmacyWorkspaceControllerProvider)
            .value
            ?.when(
              success: (PharmacyWorkspaceState value) => value,
              failure: (_) => _initialState,
            ) ??
        _initialState;
    return AppDialog(
      title: Text(l10n.pharmacyCatalogPanelTitle),
      icon: const Icon(Icons.inventory_2_outlined),
      scrollable: false,
      maxWidth: 1080,
      content: PharmacyCatalogPanel(state: state, fillHeight: true),
    );
  }

  PharmacyWorkspaceState get _initialState {
    if (widget.initialState.catalogTab == widget.initialTab) {
      return widget.initialState;
    }
    return widget.initialState.copyWith(catalogTab: widget.initialTab);
  }
}
