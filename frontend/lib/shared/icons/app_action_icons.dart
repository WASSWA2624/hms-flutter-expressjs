import 'package:flutter/material.dart';

/// Shared action / feedback icons used across toolbars, dialogs, lists, and
/// status surfaces. Prefer these over ad-hoc Material icons for repeated UI.
///
/// Route destinations use [AppRouteIcons]. Status chips should also include a
/// localized text label — never rely on icon or color alone.
abstract final class AppActionIcons {
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData save = Icons.save_outlined;
  static const IconData cancel = Icons.close;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list;
  static const IconData refresh = Icons.refresh;
  static const IconData more = Icons.more_vert;
  static const IconData settings = Icons.settings_outlined;
  static const IconData notifications = Icons.notifications_none_outlined;
  static const IconData notificationsActive =
      Icons.notifications_active_outlined;
  static const IconData person = Icons.person_outline;
  static const IconData logout = Icons.logout_outlined;
  static const IconData lock = Icons.lock_outline;
  static const IconData visibility = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData time = Icons.schedule_outlined;
  static const IconData print = Icons.print_outlined;
  static const IconData download = Icons.download_outlined;
  static const IconData upload = Icons.upload_outlined;
  static const IconData attach = Icons.attach_file;
  static const IconData info = Icons.info_outline;
  static const IconData warning = Icons.warning_amber_outlined;
  static const IconData error = Icons.error_outline;
  static const IconData success = Icons.check_circle_outline;
  static const IconData complete = Icons.task_alt_outlined;
  static const IconData decision = Icons.fact_check_outlined;

  /// Operational / maintenance triage (not clinical patient triage).
  static const IconData triage = Icons.rule_outlined;

  static const IconData help = Icons.help_outline;
  static const IconData openInNew = Icons.open_in_new;
  static const IconData copy = Icons.copy_outlined;
  static const IconData menu = Icons.menu;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandLess = Icons.expand_less;
  /// Inpatient / bed / admission handoff actions.
  static const IconData bed = Icons.bed_outlined;

  /// Bed release / housekeeping cleaning actions.
  static const IconData cleaning = Icons.cleaning_services_outlined;

  /// Emergency / clinical handoff to a receiving care surface.
  static const IconData handoff = Icons.output_outlined;

  /// Emergency / triage priority severity actions.
  static const IconData priority = Icons.priority_high_outlined;

  /// Ward / unit transfer request actions (ICU, IPD, rooms & beds).
  static const IconData transfer = Icons.swap_horiz_outlined;

  /// Consultation / cashier payment and billing quick actions.
  static const IconData payment = Icons.payments_outlined;

  /// Visit-queue / worklist row actions hub.
  static const IconData queue = Icons.queue_outlined;

  /// Move / reassign a queue entry (stage or provider).
  static const IconData move = Icons.sync_alt_outlined;

  /// Start consultation / begin an encounter from queue.
  static const IconData start = Icons.play_arrow_outlined;
}
