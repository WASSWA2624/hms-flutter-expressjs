import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Persists only the expand/collapse boolean — never patient PHI.
final appPatientDetailsExpandedProvider =
    NotifierProvider<AppPatientDetailsExpandedController, bool>(
      AppPatientDetailsExpandedController.new,
    );

final class AppPatientDetailsExpandedController extends Notifier<bool> {
  @override
  bool build() {
    // Rebuild on logout / account or facility switch so prior-session UI state
    // does not leak; preference payload remains a boolean only.
    watchSessionEpoch(ref);
    final SessionState sessionState = ref.watch(sessionStateProvider);
    final String preferenceKey = preferenceKeyForSession(sessionState.session);
    return ref.read(appPreferencesStoreProvider).getBool(preferenceKey) ??
        false;
  }

  Future<void> setExpanded({required bool expanded}) async {
    if (expanded == state) {
      return;
    }

    final bool previous = state;
    state = expanded;
    final String preferenceKey = preferenceKeyForSession(
      ref.read(sessionStateProvider).session,
    );

    try {
      final bool saved = await ref
          .read(appPreferencesStoreProvider)
          .setBool(preferenceKey, value: expanded);

      if (!saved) {
        throw StateError(
          'Unable to persist patient details expand preference.',
        );
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Preference stores only a boolean, keyed by session scope (never PHI).
  static String preferenceKeyForSession(AuthSession? session) {
    final AuthUserProfile? user = session?.user;
    final String userId = (user?.id ?? session?.subject ?? 'anon').trim();
    final String tenantId = (user?.tenantId ?? 'none').trim();
    final String facilityId = (user?.facilityId ?? 'none').trim();
    return '${AppPreferenceKeys.patientDetailsExpanded}.$tenantId.$facilityId.$userId';
  }
}

/// Patient identity section built on [AppCollapsibleSection].
///
/// Collapsed by default: header shows name · public ID (with copy).
/// Expanded body is a horizontal overflow row:
/// `Icon Parameter name: Parameter value | …`
class AppPatientDetails extends ConsumerStatefulWidget {
  const AppPatientDetails({
    required this.patientName,
    required this.patientNumber,
    this.patientNumberLabel,
    this.ageLabel,
    this.genderLabel,
    this.genderIcon,
    this.compactSupportingText,
    this.status,
    this.alerts = const <AppWorkspaceStatus>[],
    this.expandedFields = const <AppWorkspacePatientContextField>[],
    this.expandedChild,
    this.actions = const <Widget>[],
    this.onCopyPatientNumber,
    this.copyPatientNumberTooltip,
    this.copyPatientNumberMessage,
    this.copyPatientNumberSemanticLabel,
    this.showPatientNumberCopyIcon = true,
    this.showPatientName = true,
    this.showAvatar = true,
    this.semanticLabel,
    this.showActionLabels = false,
    this.fieldStyle = AppWorkspacePatientContextFieldStyle.inline,
    this.persistExpandPreference = true,
    this.initiallyExpanded,
    super.key,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? ageLabel;
  final String? genderLabel;
  final IconData? genderIcon;

  /// Optional non-PHI compact line (workflow subtitle). Prefer age/gender when available.
  final String? compactSupportingText;
  final AppWorkspaceStatus? status;
  final List<AppWorkspaceStatus> alerts;
  final List<AppWorkspacePatientContextField> expandedFields;
  final Widget? expandedChild;
  final List<Widget> actions;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? copyPatientNumberMessage;
  final String? copyPatientNumberSemanticLabel;
  final bool showPatientNumberCopyIcon;
  final bool showPatientName;
  final bool showAvatar;
  final String? semanticLabel;
  final bool showActionLabels;

  /// Kept for API compatibility; body facts always use the overflow row.
  final AppWorkspacePatientContextFieldStyle fieldStyle;
  final bool persistExpandPreference;
  final bool? initiallyExpanded;

  @override
  ConsumerState<AppPatientDetails> createState() => _AppPatientDetailsState();
}

class _AppPatientDetailsState extends ConsumerState<AppPatientDetails> {
  late bool _localExpanded;

  @override
  void initState() {
    super.initState();
    _localExpanded = widget.initiallyExpanded ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<AppWorkspacePatientContextField> bodyFields = _bodyFields(l10n);
    final bool hasExpandableContent =
        bodyFields.isNotEmpty || widget.expandedChild != null;

    final bool expanded = !hasExpandableContent
        ? false
        : (widget.persistExpandPreference
              ? ref.watch(appPatientDetailsExpandedProvider)
              : _localExpanded);

    Widget panel = AppCollapsibleSection(
      titleWidget: _PatientDetailsTitle(
        patientName: widget.patientName,
        patientNumber: widget.patientNumber,
        patientNumberLabel: widget.patientNumberLabel,
        showPatientName: widget.showPatientName,
        showPatientNumberCopyIcon: widget.showPatientNumberCopyIcon,
        onCopyPatientNumber: widget.onCopyPatientNumber,
        copyPatientNumberTooltip: widget.copyPatientNumberTooltip,
        copyPatientNumberMessage: widget.copyPatientNumberMessage,
        copyPatientNumberSemanticLabel: widget.copyPatientNumberSemanticLabel,
      ),
      headerActions: widget.actions,
      collapsible: hasExpandableContent,
      expanded: hasExpandableContent ? expanded : null,
      onExpandedChanged: hasExpandableContent
          ? (bool value) => _toggleExpanded(expanded: value)
          : null,
      initiallyExpanded: false,
      contentPadding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (bodyFields.isNotEmpty) AppPatientContextFactsRow(fields: bodyFields),
          if (bodyFields.isNotEmpty && widget.expandedChild != null)
            SizedBox(height: theme.spacing.sm),
          if (widget.expandedChild != null) widget.expandedChild!,
        ],
      ),
    );

    if (widget.semanticLabel != null) {
      panel = Semantics(
        container: true,
        label: widget.semanticLabel,
        child: panel,
      );
    }

    return panel;
  }

  Future<void> _toggleExpanded({required bool expanded}) async {
    if (widget.persistExpandPreference) {
      await ref
          .read(appPatientDetailsExpandedProvider.notifier)
          .setExpanded(expanded: expanded);
      return;
    }
    setState(() => _localExpanded = expanded);
  }

  List<AppWorkspacePatientContextField> _bodyFields(AppLocalizations l10n) {
    final List<AppWorkspacePatientContextField> fields =
        <AppWorkspacePatientContextField>[];

    final String? age = widget.ageLabel?.trim();
    if (age != null && age.isNotEmpty) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.patientsAgeColumnLabel,
          value: age,
          icon: Icons.cake_outlined,
        ),
      );
    }

    final String? gender = widget.genderLabel?.trim();
    if (gender != null && gender.isNotEmpty) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.patientsGenderLabel,
          value: gender,
          icon: widget.genderIcon ?? Icons.person_outline,
        ),
      );
    }

    final String? supporting = widget.compactSupportingText?.trim();
    if ((age == null || age.isEmpty) &&
        (gender == null || gender.isEmpty) &&
        supporting != null &&
        supporting.isNotEmpty) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.patientsDetailTitle,
          value: supporting,
          icon: Icons.info_outline,
        ),
      );
    }

    final AppWorkspaceStatus? status = widget.status;
    if (status != null && status.label.trim().isNotEmpty) {
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.patientsStatusColumnLabel,
          value: status.label,
          icon: status.icon ?? Icons.flag_outlined,
          tone: status.tone,
        ),
      );
    }

    for (final AppWorkspaceStatus alert in widget.alerts) {
      if (alert.label.trim().isEmpty) {
        continue;
      }
      fields.add(
        AppWorkspacePatientContextField(
          label: l10n.icuColumnAlertLabel,
          value: alert.label,
          icon: alert.icon ?? Icons.warning_amber_outlined,
          tone: alert.tone,
        ),
      );
    }

    fields.addAll(
      widget.expandedFields.where(
        (AppWorkspacePatientContextField field) => field.hasValue,
      ),
    );

    return fields;
  }
}

class _PatientDetailsTitle extends StatelessWidget {
  const _PatientDetailsTitle({
    required this.patientName,
    required this.patientNumber,
    this.patientNumberLabel,
    this.showPatientName = true,
    this.showPatientNumberCopyIcon = true,
    this.onCopyPatientNumber,
    this.copyPatientNumberTooltip,
    this.copyPatientNumberMessage,
    this.copyPatientNumberSemanticLabel,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final bool showPatientName;
  final bool showPatientNumberCopyIcon;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? copyPatientNumberMessage;
  final String? copyPatientNumberSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final String normalizedId = patientNumber.trim();
    final String semanticsLabel =
        '${showPatientName ? patientName : ''} ${normalizedId.isEmpty ? '' : normalizedId}'
            .trim();

    return Semantics(
      label: semanticsLabel,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: theme.spacing.xs,
        runSpacing: theme.spacing.xs / 2,
        children: <Widget>[
          if (showPatientName)
            Text(
              patientName,
              style: nameStyle,
              softWrap: true,
            ),
          if (showPatientName && normalizedId.isNotEmpty)
            Text(
              '·',
              style: nameStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (normalizedId.isNotEmpty)
            AppCopyableIdentifier(
              value: normalizedId,
              tooltip: copyPatientNumberTooltip ?? patientNumberLabel,
              copiedMessage: copyPatientNumberMessage,
              semanticLabel: copyPatientNumberSemanticLabel,
              showCopyIcon: showPatientNumberCopyIcon,
              onCopied: onCopyPatientNumber,
              textStyle: nameStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
