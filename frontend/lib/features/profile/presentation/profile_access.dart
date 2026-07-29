import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// View / read UI for the Profile account surface (`profile:read` ∩).
///
/// Profile rights are core/platform (not plan-module mapped); subscription
/// stripping does not apply to these keys. The surface is inherently own-scoped
/// via the current-user profile API.
const AccessRequirement profileReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
);

/// Update mutations on the Profile account surface (`profile:update` ∩):
/// edit profile and change password.
const AccessRequirement profileUpdateRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileUpdate],
);

/// Billing action classes for Profile tab inventory (Req 1).
enum ProfileFinancialClass {
  createCharge,
  settle,
  adjust,
  reverse,
  defer,
  notBillable,
}

/// Financial atom on the Profile tab with explicit classification.
@immutable
final class ProfileFinancialAtom {
  const ProfileFinancialAtom({
    required this.id,
    required this.classification,
    this.auditReason,
  });

  final String id;
  final ProfileFinancialClass classification;
  final String? auditReason;
}

/// Profile tab financial inventory — identity/security only; no patient ledger
/// mutations. Rendered via [SettingsAccountSection] (`/profile`, `/settings?tab=account`).
const List<ProfileFinancialAtom> profileFinancialInventory =
    <ProfileFinancialAtom>[
      ProfileFinancialAtom(
        id: 'tab_surface',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'profile_summary',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'account_details_read',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'professional_details_read',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'roles_read',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'permissions_read',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'copy_identifier',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'loading_empty_error_retry',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'change_password',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'change_password_deep_link',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NOT_REQUIRED',
      ),
      ProfileFinancialAtom(
        id: 'edit_profile',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NO_CHARGE',
      ),
      ProfileFinancialAtom(
        id: 'edit_profile_save',
        classification: ProfileFinancialClass.notBillable,
        auditReason: 'NO_CHARGE',
      ),
    ];

/// True when every Profile tab atom is explicitly not billable.
bool profileTabHasNoBillableActions() {
  return profileFinancialInventory.every(
    (ProfileFinancialAtom atom) =>
        atom.classification == ProfileFinancialClass.notBillable,
  );
}
