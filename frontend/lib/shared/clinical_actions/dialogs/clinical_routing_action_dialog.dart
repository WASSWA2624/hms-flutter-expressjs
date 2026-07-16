import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Shared triage/OPD routing decision dialog (destination + optional notes).
///
/// Used by encounter flows that persist a route via the triage route endpoint.
class ClinicalRoutingActionDialog extends StatefulWidget {
  const ClinicalRoutingActionDialog({
    required this.routeOptions,
    required this.onSubmit,
    this.title,
    this.routeLabel,
    this.notesLabel,
    this.submitLabel,
    this.initialRoute,
    this.icon = const Icon(Icons.alt_route_outlined),
    this.submitLeadingIcon = AppActionIcons.save,
    this.leadingContent = const <Widget>[],
    this.scrollable = true,
    this.pinActionsToBottom = true,
    this.density = AppFormSectionDensity.compact,
    this.searchable = false,
    super.key,
  });

  final List<AppTriageOption> routeOptions;
  final String? title;
  final String? routeLabel;
  final String? notesLabel;
  final String? submitLabel;
  final String? initialRoute;
  final Widget icon;
  final IconData submitLeadingIcon;
  final List<Widget> leadingContent;
  final bool scrollable;
  final bool pinActionsToBottom;
  final AppFormSectionDensity density;
  final bool searchable;
  final Future<AppFailure?> Function({
    required String routeTo,
    required String notes,
  })
  onSubmit;

  @override
  State<ClinicalRoutingActionDialog> createState() =>
      _ClinicalRoutingActionDialogState();
}

class _ClinicalRoutingActionDialogState
    extends State<ClinicalRoutingActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late String _routeTo;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _routeTo = _initialRoute();
  }

  String _initialRoute() {
    final Set<String> allowed = <String>{
      for (final AppTriageOption option in widget.routeOptions) option.value,
    };
    final String? requested = widget.initialRoute?.trim().toUpperCase();
    if (requested != null &&
        requested.isNotEmpty &&
        allowed.contains(requested)) {
      return requested;
    }
    if (allowed.contains('CONSULTATION')) {
      return 'CONSULTATION';
    }
    return widget.routeOptions.isEmpty
        ? 'CONSULTATION'
        : widget.routeOptions.first.value;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.title ?? l10n.opdRouteDecisionLabel;
    final String submitLabel =
        widget.submitLabel ?? l10n.opdSaveRoutingDecisionAction;
    return AppDialog(
      title: Text(title),
      icon: widget.icon,
      scrollable: widget.scrollable,
      pinActionsToBottom: widget.pinActionsToBottom,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: widget.density,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ...widget.leadingContent,
            AppTriageDecisionField(
              value: _routeTo,
              labelText: widget.routeLabel ?? l10n.opdRouteDecisionLabel,
              enabled: !_isSaving,
              searchable: widget.searchable,
              isRequired: true,
              onChanged: (String? value) =>
                  setState(() => _routeTo = value ?? _routeTo),
              options: widget.routeOptions,
            ),
            AppTextField(
              controller: _notesController,
              labelText: widget.notesLabel ?? l10n.opdNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        submitLabel,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: widget.submitLeadingIcon,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String routeTo = _routeTo.trim();
    if (routeTo.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      routeTo: routeTo,
      notes: _notesController.text.trim(),
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}
