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
import 'package:hosspi_hms/shared/components/app_button.dart';
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

/// Compact patient identity + optional expanded workflow fields.
///
/// Compact default: name, public identifier, age, gender.
/// Expanded: caller-supplied [expandedFields] / [expandedChild].
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
    final bool hasExpandableContent =
        widget.expandedFields.any(
          (AppWorkspacePatientContextField field) => field.hasValue,
        ) ||
        widget.expandedChild != null;

    final bool expanded = !hasExpandableContent
        ? false
        : (widget.persistExpandPreference
              ? ref.watch(appPatientDetailsExpandedProvider)
              : _localExpanded);

    final List<Widget> headerActions = <Widget>[
      ...widget.actions,
      if (hasExpandableContent)
        AppButton.tertiary(
          label: expanded
              ? l10n.commonShowLessActionLabel
              : l10n.commonShowMoreActionLabel,
          leadingIcon: expanded ? Icons.expand_less : Icons.expand_more,
          semanticLabel: expanded
              ? l10n.commonShowLessActionLabel
              : l10n.commonShowMoreActionLabel,
          tooltip: expanded
              ? l10n.commonShowLessActionLabel
              : l10n.commonShowMoreActionLabel,
          onPressed: () => _toggleExpanded(expanded: !expanded),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspacePatientContextHeader(
          patientName: widget.patientName,
          patientNumber: widget.patientNumber,
          patientNumberLabel: widget.patientNumberLabel,
          demographicsWidget: _buildDemographics(theme),
          status: widget.status,
          alerts: widget.alerts,
          fields: expanded
              ? widget.expandedFields
              : const <AppWorkspacePatientContextField>[],
          fieldStyle: widget.fieldStyle,
          actions: headerActions,
          onCopyPatientNumber: widget.onCopyPatientNumber,
          copyPatientNumberTooltip: widget.copyPatientNumberTooltip,
          copyPatientNumberMessage: widget.copyPatientNumberMessage,
          copyPatientNumberSemanticLabel: widget.copyPatientNumberSemanticLabel,
          showPatientNumberCopyIcon: widget.showPatientNumberCopyIcon,
          showPatientName: widget.showPatientName,
          showAvatar: widget.showAvatar,
          semanticLabel: widget.semanticLabel,
          showActionLabels: widget.showActionLabels || hasExpandableContent,
        ),
        if (expanded && widget.expandedChild != null) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          widget.expandedChild!,
        ],
      ],
    );
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

  Widget? _buildDemographics(ThemeData theme) {
    final String? age = widget.ageLabel?.trim();
    final String? gender = widget.genderLabel?.trim();
    final String? supporting = widget.compactSupportingText?.trim();
    final bool hasAgeGender =
        (age != null && age.isNotEmpty) ||
        (gender != null && gender.isNotEmpty);
    if (!hasAgeGender && (supporting == null || supporting.isEmpty)) {
      return null;
    }

    if (!hasAgeGender) {
      return Text(
        supporting!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (age != null && age.isNotEmpty)
          Text(
            age,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (gender != null && gender.isNotEmpty) ...<Widget>[
          if (age != null && age.isNotEmpty) SizedBox(width: theme.spacing.xs),
          if (widget.genderIcon != null) ...<Widget>[
            Icon(
              widget.genderIcon,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: theme.spacing.xs),
          ],
          Text(
            gender,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
