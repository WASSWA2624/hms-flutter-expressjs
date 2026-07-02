import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

Future<void> showAppGlobalHousekeepingRequestDialog({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onCompleted,
}) async {
  final AsyncValue<Result<HousekeepingWorkspaceState>> workspace = ref.read(
    housekeepingWorkspaceControllerProvider,
  );
  if (workspace.isLoading || workspace.hasError) {
    unawaited(
      ref.read(housekeepingWorkspaceControllerProvider.notifier).refresh(),
    );
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AppGlobalHousekeepingRequestDialog(),
  );

  if (saved == true) {
    onCompleted?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.housekeepingSavedMessage)),
      );
    }
  }
}

class _AppGlobalHousekeepingRequestDialog extends ConsumerStatefulWidget {
  const _AppGlobalHousekeepingRequestDialog();

  @override
  ConsumerState<_AppGlobalHousekeepingRequestDialog> createState() =>
      _AppGlobalHousekeepingRequestDialogState();
}

class _AppGlobalHousekeepingRequestDialogState
    extends ConsumerState<_AppGlobalHousekeepingRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  String? _facilityId;
  String? _assetId;
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<HousekeepingWorkspaceState>> workspace = ref.watch(
      housekeepingWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.housekeepingRequestMaintenanceDialogTitle),
      icon: const Icon(Icons.cleaning_services_outlined),
      scrollable: true,
      closeEnabled: !_isSubmitting,
      content: workspace.when(
        loading: () => AppStateView(
          variant: AppStateViewVariant.loading,
          title: l10n.housekeepingLoadingTitle,
          body: l10n.housekeepingLoadingBody,
        ),
        error: (_, _) => AppStateView(
          variant: AppStateViewVariant.error,
          title: l10n.errorNotFoundTitle,
          body: l10n.errorNotFoundMessage,
          action: AppButton.primary(
            label: l10n.commonRetryActionLabel,
            onPressed: () {
              ref
                  .read(housekeepingWorkspaceControllerProvider.notifier)
                  .refresh();
            },
          ),
        ),
        data: (Result<HousekeepingWorkspaceState> result) {
          return switch (result) {
            ResultFailure<HousekeepingWorkspaceState>() => AppStateView(
              variant: AppStateViewVariant.error,
              title: l10n.errorNotFoundTitle,
              body: l10n.errorNotFoundMessage,
            ),
            ResultSuccess<HousekeepingWorkspaceState>(value: final state) =>
              _buildForm(context, state),
          };
        },
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      AppButton.tertiary(
        label: l10n.commonCancelActionLabel,
        enabled: !_isSubmitting,
        onPressed: _isSubmitting
            ? null
            : () => Navigator.of(context).maybePop(),
      ),
      AppButton.primary(
        label: l10n.housekeepingRequestMaintenanceSubmitAction,
        leadingIcon: Icons.build_circle_outlined,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : _submit,
      ),
    ];
  }

  Widget _buildForm(BuildContext context, HousekeepingWorkspaceState state) {
    final AppLocalizations l10n = context.l10n;

    return AppFormShell(
      formKey: _formKey,
      enabled: !_isSubmitting,
      formStatus: appFormFailureStatus(context, _failure),
      children: <Widget>[
        AppSelectField<String>.searchable(
          value: _facilityId,
          labelText: l10n.housekeepingFacilityFieldLabel,
          hintText: l10n.housekeepingFacilityFieldHint,
          options: _lookupOptions(state.overview.lookups.facilities),
          onChanged: (String? value) => setState(() => _facilityId = value),
        ),
        AppSelectField<String>.searchable(
          value: _assetId,
          labelText: l10n.housekeepingAssetFieldLabel,
          hintText: l10n.housekeepingAssetFieldHint,
          options: _lookupOptions(state.overview.lookups.assets),
          onChanged: (String? value) => setState(() => _assetId = value),
        ),
        AppTextField(
          controller: _descriptionController,
          labelText: l10n.housekeepingDescriptionFieldLabel,
          hintText: l10n.housekeepingDescriptionFieldHint,
          isRequired: true,
          maxLines: 4,
          validator: AppValidators.requiredText(
            l10n.housekeepingDescriptionRequiredMessage,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(housekeepingWorkspaceControllerProvider.notifier)
        .createMaintenanceRequest(
          HousekeepingMaintenanceRequestDraft(
            status: 'OPEN',
            facilityId: _facilityId,
            assetId: _assetId,
            description: _descriptionController.text.trim(),
            reportedAt: DateTime.now(),
          ),
        );

    if (!mounted) {
      return;
    }

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _failure = failure;
      _isSubmitting = false;
    });
  }
}

List<AppSelectOption<String>> _lookupOptions(
  List<HousekeepingLookupOption> options,
) {
  return <AppSelectOption<String>>[
    for (final HousekeepingLookupOption option in options)
      AppSelectOption<String>(
        value: option.id,
        label: option.subtitle == null
            ? option.label
            : '${option.label} - ${option.subtitle}',
      ),
  ];
}
