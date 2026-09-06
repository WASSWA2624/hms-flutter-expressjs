import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

/// The 70 canonical role codes from `backend/src/config/roles.js`.
///
/// Every one of them must resolve to a client permission pack. A code that
/// resolves to nothing leaves the user with an empty shell on JWT-only restore
/// (before `/auth/me` hydrates the authoritative grants).
const List<String> _canonicalRoleCodes = <String>[
  'PLATFORM_OWNER',
  'PLATFORM_ADMIN',
  'TENANT_ADMIN',
  'FACILITY_ADMIN',
  'INTEGRATION_ADMIN',
  'HR_STAFF',
  'OPERATIONS_STAFF',
  'DISCHARGE_PLANNER',
  'DENTIST',
  'RADIOLOGIST',
  'ACCOUNTANT',
  'SUPPORT_STAFF',
  'VISITOR_GUEST',
  'DOCTOR',
  'OPD_DOCTOR',
  'ICU_DOCTOR',
  'NURSE',
  'LAB_TECH',
  'RADIOLOGY_TECH',
  'PHARMACIST',
  'PHARMACY_BILLING',
  'RECEPTIONIST',
  'BILLING',
  'OPERATIONS',
  'HR',
  'BIOMED',
  'HOUSE_KEEPER',
  'AMBULANCE_OPERATOR',
  'UNIT_MANAGER',
  'WARD_MANAGER',
  'ICU_MANAGER',
  'THEATRE_MANAGER',
  'HOUSEKEEPING_MANAGER',
  'BIOMED_MANAGER',
  'MORTUARY_STAFF',
  'MORTUARY_MANAGER',
  'ATTENDING_PHYSICIAN',
  'RESIDENT_PHYSICIAN',
  'SURGEON',
  'ANESTHESIOLOGIST',
  'PHYSICIAN_ASSISTANT',
  'EMERGENCY_PHYSICIAN',
  'LICENSED_PRACTICAL_NURSE',
  'NURSE_PRACTITIONER',
  'TRIAGE_NURSE',
  'MIDWIFE',
  'CHARGE_NURSE',
  'PHYSIOTHERAPIST',
  'OCCUPATIONAL_THERAPIST',
  'RESPIRATORY_THERAPIST',
  'DIETITIAN',
  'SOCIAL_WORKER',
  'CLINICAL_PSYCHOLOGIST',
  'PATHOLOGIST',
  'MEDICAL_LABORATORY_SCIENTIST',
  'SONOGRAPHER',
  'PHARMACY_TECHNICIAN',
  'PARAMEDIC',
  'EMT',
  'MEDICAL_RECORDS_CLERK',
  'ADMISSIONS_COORDINATOR',
  'MEDICAL_CODER',
  'IT_SUPPORT',
  'SECURITY_OFFICER',
  'CHAPLAIN',
  'FOOD_SERVICE_WORKER',
  'PORTER',
  'MAINTENANCE_ENGINEER',
  'PATIENT',
  'OTHER',
];

/// Role-pack expansion with no tenant context and no entitlements, so neither
/// the module gate nor the plan cap narrows the result.
Set<AppPermission> _packFor(String roleCode) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(roles: <String>[roleCode]),
    ),
  ).permissions;
}

void main() {
  group('client role packs mirror the backend catalog', () {
    test('every canonical role code resolves to a non-empty pack', () {
      final List<String> empty = <String>[
        for (final String code in _canonicalRoleCodes)
          if (_packFor(code).isEmpty) code,
      ];

      expect(empty, isEmpty);
    });

    test('every canonical role pack carries reports:read', () {
      final List<String> missing = <String>[
        for (final String code in _canonicalRoleCodes)
          if (!_packFor(code).contains(AppPermissions.reportsRead)) code,
      ];

      expect(missing, isEmpty);
    });

    test('narrow clinician packs stay narrower than DOCTOR', () {
      final Set<AppPermission> opd = _packFor('OPD_DOCTOR');
      expect(opd, contains(AppPermissions.opdRead));
      expect(opd, isNot(contains(AppPermissions.ipdRead)));
      expect(opd, isNot(contains(AppPermissions.icuRead)));
      expect(opd, isNot(contains(AppPermissions.theaterRead)));

      final Set<AppPermission> icu = _packFor('ICU_DOCTOR');
      expect(icu, contains(AppPermissions.icuRead));
      expect(icu, isNot(contains(AppPermissions.opdRead)));
      expect(icu, isNot(contains(AppPermissions.theaterRead)));

      final Set<AppPermission> surgeon = _packFor('SURGEON');
      expect(surgeon, contains(AppPermissions.theaterRead));
      expect(surgeon, isNot(contains(AppPermissions.opdRead)));

      final Set<AppPermission> emergency = _packFor('EMERGENCY_PHYSICIAN');
      expect(emergency, contains(AppPermissions.opdRead));
      expect(emergency, isNot(contains(AppPermissions.theaterRead)));
    });

    test('cashier packs keep facility and pharmacy pricing separate', () {
      final Set<AppPermission> billing = _packFor('BILLING');
      expect(billing, contains(AppPermissions.pricingFacilityWrite));
      expect(billing, contains(AppPermissions.lastOfficeRead));
      expect(billing, contains(AppPermissions.lastOfficeWrite));
      expect(billing, isNot(contains(AppPermissions.pricingPharmacyWrite)));
      expect(billing, isNot(contains(AppPermissions.accountsRead)));

      final Set<AppPermission> pharmacyBilling = _packFor('PHARMACY_BILLING');
      expect(pharmacyBilling, contains(AppPermissions.pricingPharmacyWrite));
      expect(pharmacyBilling, contains(AppPermissions.pharmacyRead));
      expect(
        pharmacyBilling,
        isNot(contains(AppPermissions.pricingFacilityWrite)),
      );

      final Set<AppPermission> accountant = _packFor('ACCOUNTANT');
      expect(accountant, contains(AppPermissions.accountsWrite));
      expect(accountant, contains(AppPermissions.financialApprove));
      expect(accountant, isNot(contains(AppPermissions.lastOfficeRead)));

      final Set<AppPermission> coder = _packFor('MEDICAL_CODER');
      expect(coder, contains(AppPermissions.claimsRead));
      expect(coder, isNot(contains(AppPermissions.billingWrite)));
      expect(coder, isNot(contains(AppPermissions.financialApprove)));
      expect(coder, isNot(contains(AppPermissions.evidenceExport)));
    });

    test('assistive packs stay narrower than their lead role', () {
      final Set<AppPermission> tech = _packFor('PHARMACY_TECHNICIAN');
      expect(tech, contains(AppPermissions.pharmacyRead));
      expect(tech, isNot(contains(AppPermissions.pharmacyWrite)));
      expect(tech, isNot(contains(AppPermissions.pricingPharmacyRead)));

      final Set<AppPermission> emt = _packFor('EMT');
      expect(emt, isNot(contains(AppPermissions.clinicalRead)));
      expect(_packFor('PARAMEDIC'), contains(AppPermissions.clinicalRead));

      expect(_packFor('PATHOLOGIST'), contains(AppPermissions.clinicalRead));
      expect(_packFor('LAB_TECH'), isNot(contains(AppPermissions.clinicalRead)));

      final Set<AppPermission> chargeNurse = _packFor('CHARGE_NURSE');
      expect(chargeNurse, contains(AppPermissions.rosterWrite));
      expect(chargeNurse, isNot(contains(AppPermissions.rosterApprove)));
    });

    test('receptionist has no evidence export', () {
      expect(
        _packFor('RECEPTIONIST'),
        isNot(contains(AppPermissions.evidenceExport)),
      );
    });
  });
}
