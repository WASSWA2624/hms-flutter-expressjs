import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
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
/// Expanded body shows context facts responsively:
/// desktop keeps an overflow row (`Icon Label: Value | …`);
/// mobile stacks one wrapped `Label: Value` row per fact.
///
/// Body always leads with age, gender, phone, and email (dedicated props,
/// matching [expandedFields], or [AppLocalizations.profileUnknownValue]).
class AppPatientDetails extends ConsumerStatefulWidget {
  const AppPatientDetails({
    required this.patientName,
    required this.patientNumber,
    this.patientNumberLabel,
    this.ageLabel,
    this.genderLabel,
    this.genderIcon,
    this.phoneLabel,
    this.emailLabel,
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
    this.collapsible = true,
    super.key,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? ageLabel;
  final String? genderLabel;
  final IconData? genderIcon;
  final String? phoneLabel;
  final String? emailLabel;

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

  /// When false, identity chrome stays open with no expand chevron.
  final bool collapsible;

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
    final bool sectionCollapsible =
        widget.collapsible && hasExpandableContent;

    final bool expanded = !sectionCollapsible
        ? true
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
      collapsible: sectionCollapsible,
      expanded: sectionCollapsible ? expanded : null,
      onExpandedChanged: sectionCollapsible
          ? (bool value) => _toggleExpanded(expanded: value)
          : null,
      initiallyExpanded: !sectionCollapsible,
      contentPadding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.sm,
        theme.spacing.md,
        theme.spacing.md,
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

    final String ageFieldLabel = l10n.patientsAgeColumnLabel;
    final String genderFieldLabel = l10n.patientsGenderLabel;
    final String phoneFieldLabel = l10n.patientsPhoneLabel;
    final String emailFieldLabel = l10n.patientsEmailLabel;
    final String unknown = l10n.profileUnknownValue;

    final AppWorkspacePatientContextField? expandedAge = _expandedFieldFor(
      ageFieldLabel,
    );
    final AppWorkspacePatientContextField? expandedGender = _expandedFieldFor(
      genderFieldLabel,
    );
    final AppWorkspacePatientContextField? expandedPhone = _expandedFieldFor(
      phoneFieldLabel,
    );
    final AppWorkspacePatientContextField? expandedEmail = _expandedFieldFor(
      emailFieldLabel,
    );

    final String age =
        _nonEmpty(widget.ageLabel) ??
        _nonEmpty(expandedAge?.value) ??
        unknown;
    final String gender =
        _nonEmpty(widget.genderLabel) ??
        _nonEmpty(expandedGender?.value) ??
        unknown;
    final String phone =
        _nonEmpty(widget.phoneLabel) ??
        _nonEmpty(expandedPhone?.value) ??
        unknown;
    final String email =
        _nonEmpty(widget.emailLabel) ??
        _nonEmpty(expandedEmail?.value) ??
        unknown;

    fields.add(
      AppWorkspacePatientContextField(
        label: ageFieldLabel,
        value: age,
        icon: expandedAge?.icon ?? Icons.cake_outlined,
      ),
    );
    fields.add(
      AppWorkspacePatientContextField(
        label: genderFieldLabel,
        value: gender,
        icon:
            widget.genderIcon ??
            expandedGender?.icon ??
            Icons.person_outline,
      ),
    );
    fields.add(
      AppWorkspacePatientContextField(
        label: phoneFieldLabel,
        value: phone,
        icon: expandedPhone?.icon ?? Icons.phone_outlined,
      ),
    );
    fields.add(
      AppWorkspacePatientContextField(
        label: emailFieldLabel,
        value: email,
        icon: expandedEmail?.icon ?? Icons.email_outlined,
      ),
    );

    final String? supporting = widget.compactSupportingText?.trim();
    final bool ageKnown = age != unknown;
    final bool genderKnown = gender != unknown;
    if (!ageKnown &&
        !genderKnown &&
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

    final Set<String> coreLabels = <String>{
      ageFieldLabel,
      genderFieldLabel,
      phoneFieldLabel,
      emailFieldLabel,
    };
    fields.addAll(
      widget.expandedFields.where(
        (AppWorkspacePatientContextField field) =>
            field.hasValue && !coreLabels.contains(field.label.trim()),
      ),
    );

    return fields;
  }

  AppWorkspacePatientContextField? _expandedFieldFor(String label) {
    final String normalized = label.trim();
    for (final AppWorkspacePatientContextField field in widget.expandedFields) {
      if (!field.hasValue) {
        continue;
      }
      if (field.label.trim() == normalized) {
        return field;
      }
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
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
    final bool compact = AppBreakpoints.of(context).isMobile;
    final TextStyle? nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: AppFontWeight.emphasis,
    );
    final String normalizedId = patientNumber.trim();
    final String semanticsLabel =
        '${showPatientName ? patientName : ''} ${normalizedId.isEmpty ? '' : normalizedId}'
            .trim();

    final Widget? name = showPatientName
        ? Text(
            patientName,
            style: nameStyle,
            softWrap: true,
          )
        : null;
    final Widget? id = normalizedId.isEmpty
        ? null
        : AppCopyableIdentifier(
            value: normalizedId,
            tooltip: copyPatientNumberTooltip ?? patientNumberLabel,
            copiedMessage: copyPatientNumberMessage,
            semanticLabel: copyPatientNumberSemanticLabel,
            showCopyIcon: showPatientNumberCopyIcon,
            onCopied: onCopyPatientNumber,
            textStyle: nameStyle?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: AppFontWeight.medium,
            ),
          );

    return Semantics(
      label: semanticsLabel,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ?name,
                if (name != null && id != null)
                  SizedBox(height: theme.spacing.xs / 2),
                ?id,
              ],
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs / 2,
              children: <Widget>[
                ?name,
                if (name != null && id != null)
                  Text(
                    '·',
                    style: nameStyle?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ?id,
              ],
            ),
    );
  }
}
