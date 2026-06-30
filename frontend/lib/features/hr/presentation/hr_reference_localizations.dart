import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Resolves backend HR reference label keys to localized UI strings.
extension HrReferenceLocalizations on AppLocalizations {
  String hrLocalizedOptionLabel(HrOption option) {
    final String? labelKey = option.labelKey?.trim();
    if (labelKey != null && labelKey.isNotEmpty) {
      return hrReferenceLabel(labelKey, fallback: option.label);
    }
    return option.label;
  }

  String hrReferenceLabel(String? labelKey, {String? fallback}) {
    final String key = labelKey?.trim() ?? '';
    if (key.isEmpty) {
      return fallback ?? '';
    }
    if (key.startsWith('labels.hr.reference.role.')) {
      return _roleLabelFromKey(key, fallback: fallback);
    }
    return switch (key) {
      'labels.hr.reference.staff_position.nurse' =>
        hrReferenceStaffPositionNurse,
      'labels.hr.reference.staff_position.senior_nurse' =>
        hrReferenceStaffPositionSeniorNurse,
      'labels.hr.reference.staff_position.staff_nurse' =>
        hrReferenceStaffPositionStaffNurse,
      'labels.hr.reference.staff_position.theatre_nurse' =>
        hrReferenceStaffPositionTheatreNurse,
      'labels.hr.reference.staff_position.scrub_nurse' =>
        hrReferenceStaffPositionScrubNurse,
      'labels.hr.reference.staff_position.ward_manager' =>
        hrReferenceStaffPositionWardManager,
      'labels.hr.reference.staff_position.midwife' =>
        hrReferenceStaffPositionMidwife,
      'labels.hr.reference.staff_position.nursing_assistant' =>
        hrReferenceStaffPositionNursingAssistant,
      'labels.hr.reference.staff_position.doctor' =>
        hrReferenceStaffPositionDoctor,
      'labels.hr.reference.staff_position.consultant_physician' =>
        hrReferenceStaffPositionConsultantPhysician,
      'labels.hr.reference.staff_position.medical_officer' =>
        hrReferenceStaffPositionMedicalOfficer,
      'labels.hr.reference.staff_position.resident_doctor' =>
        hrReferenceStaffPositionResidentDoctor,
      'labels.hr.reference.staff_position.intern' =>
        hrReferenceStaffPositionIntern,
      'labels.hr.reference.staff_position.general_practitioner' =>
        hrReferenceStaffPositionGeneralPractitioner,
      'labels.hr.reference.staff_position.surgeon' =>
        hrReferenceStaffPositionSurgeon,
      'labels.hr.reference.staff_position.anaesthetist' =>
        hrReferenceStaffPositionAnaesthetist,
      'labels.hr.reference.staff_position.paediatrician' =>
        hrReferenceStaffPositionPaediatrician,
      'labels.hr.reference.staff_position.obgyn' =>
        hrReferenceStaffPositionObgyn,
      'labels.hr.reference.staff_position.psychiatrist' =>
        hrReferenceStaffPositionPsychiatrist,
      'labels.hr.reference.staff_position.emergency_physician' =>
        hrReferenceStaffPositionEmergencyPhysician,
      'labels.hr.reference.staff_position.family_medicine_physician' =>
        hrReferenceStaffPositionFamilyMedicinePhysician,
      'labels.hr.reference.staff_position.dental_surgeon' =>
        hrReferenceStaffPositionDentalSurgeon,
      'labels.hr.reference.staff_position.nurse_practitioner' =>
        hrReferenceStaffPositionNursePractitioner,
      'labels.hr.reference.staff_position.physiotherapist' =>
        hrReferenceStaffPositionPhysiotherapist,
      'labels.hr.reference.staff_position.occupational_therapist' =>
        hrReferenceStaffPositionOccupationalTherapist,
      'labels.hr.reference.staff_position.speech_therapist' =>
        hrReferenceStaffPositionSpeechTherapist,
      'labels.hr.reference.staff_position.dietitian' =>
        hrReferenceStaffPositionDietitian,
      'labels.hr.reference.staff_position.clinical_psychologist' =>
        hrReferenceStaffPositionClinicalPsychologist,
      'labels.hr.reference.staff_position.social_worker' =>
        hrReferenceStaffPositionSocialWorker,
      'labels.hr.reference.staff_position.respiratory_therapist' =>
        hrReferenceStaffPositionRespiratoryTherapist,
      'labels.hr.reference.staff_position.lab_technologist' =>
        hrReferenceStaffPositionLabTechnologist,
      'labels.hr.reference.staff_position.medical_laboratory_scientist' =>
        hrReferenceStaffPositionMedicalLaboratoryScientist,
      'labels.hr.reference.staff_position.phlebotomist' =>
        hrReferenceStaffPositionPhlebotomist,
      'labels.hr.reference.staff_position.radiologist' =>
        hrReferenceStaffPositionRadiologist,
      'labels.hr.reference.staff_position.sonographer' =>
        hrReferenceStaffPositionSonographer,
      'labels.hr.reference.staff_position.ecg_technician' =>
        hrReferenceStaffPositionEcgTechnician,
      'labels.hr.reference.staff_position.pharmacist' =>
        hrReferenceStaffPositionPharmacist,
      'labels.hr.reference.staff_position.pharmacy_technician' =>
        hrReferenceStaffPositionPharmacyTechnician,
      'labels.hr.reference.staff_position.pharmacy_assistant' =>
        hrReferenceStaffPositionPharmacyAssistant,
      'labels.hr.reference.staff_position.administrator' =>
        hrReferenceStaffPositionAdministrator,
      'labels.hr.reference.staff_position.hr_officer' =>
        hrReferenceStaffPositionHrOfficer,
      'labels.hr.reference.staff_position.receptionist' =>
        hrReferenceStaffPositionReceptionist,
      'labels.hr.reference.staff_position.medical_records_officer' =>
        hrReferenceStaffPositionMedicalRecordsOfficer,
      'labels.hr.reference.staff_position.health_information_officer' =>
        hrReferenceStaffPositionHealthInformationOfficer,
      'labels.hr.reference.staff_position.patient_relations_officer' =>
        hrReferenceStaffPositionPatientRelationsOfficer,
      'labels.hr.reference.staff_position.billing_clerk' =>
        hrReferenceStaffPositionBillingClerk,
      'labels.hr.reference.staff_position.accounts_officer' =>
        hrReferenceStaffPositionAccountsOfficer,
      'labels.hr.reference.staff_position.insurance_officer' =>
        hrReferenceStaffPositionInsuranceOfficer,
      'labels.hr.reference.staff_position.cashier' =>
        hrReferenceStaffPositionCashier,
      'labels.hr.reference.staff_position.housekeeper' =>
        hrReferenceStaffPositionHousekeeper,
      'labels.hr.reference.staff_position.porter' =>
        hrReferenceStaffPositionPorter,
      'labels.hr.reference.staff_position.security_officer' =>
        hrReferenceStaffPositionSecurityOfficer,
      'labels.hr.reference.staff_position.laundry_attendant' =>
        hrReferenceStaffPositionLaundryAttendant,
      'labels.hr.reference.staff_position.kitchen_staff' =>
        hrReferenceStaffPositionKitchenStaff,
      'labels.hr.reference.staff_position.mortuary_attendant' =>
        hrReferenceStaffPositionMortuaryAttendant,
      'labels.hr.reference.staff_position.ambulance_driver' =>
        hrReferenceStaffPositionAmbulanceDriver,
      'labels.hr.reference.staff_position.ambulance_operator' =>
        hrReferenceStaffPositionAmbulanceOperator,
      'labels.hr.reference.staff_position.biomedical_engineer' =>
        hrReferenceStaffPositionBiomedicalEngineer,
      'labels.hr.reference.staff_position.it_support_officer' =>
        hrReferenceStaffPositionItSupportOfficer,
      'labels.hr.reference.staff_position.maintenance_technician' =>
        hrReferenceStaffPositionMaintenanceTechnician,
      'labels.hr.reference.staff_position.hospital_administrator' =>
        hrReferenceStaffPositionHospitalAdministrator,
      'labels.hr.reference.staff_position.department_head' =>
        hrReferenceStaffPositionDepartmentHead,
      'labels.hr.reference.staff_position.chief_nursing_officer' =>
        hrReferenceStaffPositionChiefNursingOfficer,
      'labels.hr.reference.staff_position.operations_manager' =>
        hrReferenceStaffPositionOperationsManager,
      'labels.hr.reference.staff_position.facility_manager' =>
        hrReferenceStaffPositionFacilityManager,
      'labels.hr.reference.practitioner_type.mo' =>
        hrReferencePractitionerTypeMo,
      'labels.hr.reference.practitioner_type.specialist' =>
        hrReferencePractitionerTypeSpecialist,
      'labels.hr.reference.practitioner_type.resident' =>
        hrReferencePractitionerTypeResident,
      'labels.hr.reference.practitioner_type.intern' =>
        hrReferencePractitionerTypeIntern,
      'labels.hr.reference.practitioner_type.gp' =>
        hrReferencePractitionerTypeGp,
      'labels.hr.reference.practitioner_type.surgeon' =>
        hrReferencePractitionerTypeSurgeon,
      'labels.hr.reference.practitioner_type.anaesthetist' =>
        hrReferencePractitionerTypeAnaesthetist,
      'labels.hr.reference.practitioner_type.paediatrician' =>
        hrReferencePractitionerTypePaediatrician,
      'labels.hr.reference.practitioner_type.obgyn' =>
        hrReferencePractitionerTypeObgyn,
      'labels.hr.reference.practitioner_type.nurse_practitioner' =>
        hrReferencePractitionerTypeNursePractitioner,
      'labels.hr.reference.practitioner_type.dentist' =>
        hrReferencePractitionerTypeDentist,
      'labels.hr.reference.practitioner_type.psychiatrist' =>
        hrReferencePractitionerTypePsychiatrist,
      'labels.hr.reference.practitioner_type.emergency_medicine' =>
        hrReferencePractitionerTypeEmergencyMedicine,
      'labels.hr.reference.practitioner_type.family_medicine' =>
        hrReferencePractitionerTypeFamilyMedicine,
      'labels.hr.reference.practitioner_type.pathologist' =>
        hrReferencePractitionerTypePathologist,
      'labels.hr.reference.practitioner_type.radiologist' =>
        hrReferencePractitionerTypeRadiologist,
      'labels.hr.reference.practitioner_type.dermatologist' =>
        hrReferencePractitionerTypeDermatologist,
      'labels.hr.reference.practitioner_type.cardiologist' =>
        hrReferencePractitionerTypeCardiologist,
      'labels.hr.reference.practitioner_type.ophthalmologist' =>
        hrReferencePractitionerTypeOphthalmologist,
      'labels.hr.reference.practitioner_type.orthopaedic_surgeon' =>
        hrReferencePractitionerTypeOrthopaedicSurgeon,
      'labels.hr.reference.compensation_pay_type.per_consultation' =>
        hrReferenceCompensationPayTypePerConsultation,
      'labels.hr.reference.compensation_pay_type.per_month' =>
        hrReferenceCompensationPayTypePerMonth,
      'labels.hr.reference.compensation_pay_type.per_day' =>
        hrReferenceCompensationPayTypePerDay,
      'labels.hr.reference.compensation_pay_type.per_hour' =>
        hrReferenceCompensationPayTypePerHour,
      'labels.hr.reference.compensation_pay_type.per_procedure' =>
        hrReferenceCompensationPayTypePerProcedure,
      'labels.hr.reference.leave_type.annual' => hrReferenceLeaveTypeAnnual,
      'labels.hr.reference.leave_type.sick' => hrReferenceLeaveTypeSick,
      'labels.hr.reference.leave_type.maternity' =>
        hrReferenceLeaveTypeMaternity,
      'labels.hr.reference.leave_type.paternity' =>
        hrReferenceLeaveTypePaternity,
      'labels.hr.reference.leave_type.compassionate' =>
        hrReferenceLeaveTypeCompassionate,
      'labels.hr.reference.leave_type.unpaid' => hrReferenceLeaveTypeUnpaid,
      'labels.hr.reference.leave_type.study' => hrReferenceLeaveTypeStudy,
      'labels.hr.reference.leave_type.emergency' =>
        hrReferenceLeaveTypeEmergency,
      'labels.hr.reference.leave_type.other' => hrReferenceLeaveTypeOther,
      'labels.hr.reference.leave_half_day_period.morning' =>
        hrReferenceLeaveHalfDayPeriodMorning,
      'labels.hr.reference.leave_half_day_period.afternoon' =>
        hrReferenceLeaveHalfDayPeriodAfternoon,
      _ => fallback ?? key,
    };
  }

  String hrReferenceLeaveTypeLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
      'ANNUAL' => hrReferenceLeaveTypeAnnual,
      'SICK' => hrReferenceLeaveTypeSick,
      'MATERNITY' => hrReferenceLeaveTypeMaternity,
      'PATERNITY' => hrReferenceLeaveTypePaternity,
      'COMPASSIONATE' => hrReferenceLeaveTypeCompassionate,
      'UNPAID' => hrReferenceLeaveTypeUnpaid,
      'STUDY' => hrReferenceLeaveTypeStudy,
      'EMERGENCY' => hrReferenceLeaveTypeEmergency,
      'OTHER' => hrReferenceLeaveTypeOther,
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceLeaveHalfDayPeriodLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
      'MORNING' => hrReferenceLeaveHalfDayPeriodMorning,
      'AFTERNOON' => hrReferenceLeaveHalfDayPeriodAfternoon,
      _ => fallback ?? normalized,
    };
  }

  String hrReferencePractitionerTypeLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
      'MO' => hrReferencePractitionerTypeMo,
      'SPECIALIST' => hrReferencePractitionerTypeSpecialist,
      'RESIDENT' => hrReferencePractitionerTypeResident,
      'INTERN' => hrReferencePractitionerTypeIntern,
      'GP' => hrReferencePractitionerTypeGp,
      'SURGEON' => hrReferencePractitionerTypeSurgeon,
      'ANAESTHETIST' => hrReferencePractitionerTypeAnaesthetist,
      'PAEDIATRICIAN' => hrReferencePractitionerTypePaediatrician,
      'OBGYN' => hrReferencePractitionerTypeObgyn,
      'NURSE_PRACTITIONER' => hrReferencePractitionerTypeNursePractitioner,
      'DENTIST' => hrReferencePractitionerTypeDentist,
      'PSYCHIATRIST' => hrReferencePractitionerTypePsychiatrist,
      'EMERGENCY_MEDICINE' => hrReferencePractitionerTypeEmergencyMedicine,
      'FAMILY_MEDICINE' => hrReferencePractitionerTypeFamilyMedicine,
      'PATHOLOGIST' => hrReferencePractitionerTypePathologist,
      'RADIOLOGIST' => hrReferencePractitionerTypeRadiologist,
      'DERMATOLOGIST' => hrReferencePractitionerTypeDermatologist,
      'CARDIOLOGIST' => hrReferencePractitionerTypeCardiologist,
      'OPHTHALMOLOGIST' => hrReferencePractitionerTypeOphthalmologist,
      'ORTHOPAEDIC_SURGEON' => hrReferencePractitionerTypeOrthopaedicSurgeon,
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceCompensationPayTypeLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
      'PER_CONSULTATION' => hrReferenceCompensationPayTypePerConsultation,
      'PER_MONTH' => hrReferenceCompensationPayTypePerMonth,
      'PER_DAY' => hrReferenceCompensationPayTypePerDay,
      'PER_HOUR' => hrReferenceCompensationPayTypePerHour,
      'PER_PROCEDURE' => hrReferenceCompensationPayTypePerProcedure,
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceStaffPositionLabel(String? name, {String? fallback}) {
    final String normalized = (name ?? '').trim();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized.toLowerCase()) {
      'nurse' => hrReferenceStaffPositionNurse,
      'senior nurse' => hrReferenceStaffPositionSeniorNurse,
      'staff nurse' => hrReferenceStaffPositionStaffNurse,
      'theatre nurse' => hrReferenceStaffPositionTheatreNurse,
      'scrub nurse' => hrReferenceStaffPositionScrubNurse,
      'ward manager' => hrReferenceStaffPositionWardManager,
      'midwife' => hrReferenceStaffPositionMidwife,
      'nursing assistant' => hrReferenceStaffPositionNursingAssistant,
      'doctor' => hrReferenceStaffPositionDoctor,
      'consultant physician' => hrReferenceStaffPositionConsultantPhysician,
      'medical officer' => hrReferenceStaffPositionMedicalOfficer,
      'resident doctor' => hrReferenceStaffPositionResidentDoctor,
      'intern' => hrReferenceStaffPositionIntern,
      'general practitioner' => hrReferenceStaffPositionGeneralPractitioner,
      'surgeon' => hrReferenceStaffPositionSurgeon,
      'anaesthetist' => hrReferenceStaffPositionAnaesthetist,
      'paediatrician' => hrReferenceStaffPositionPaediatrician,
      'obstetrician/gynaecologist' => hrReferenceStaffPositionObgyn,
      'psychiatrist' => hrReferenceStaffPositionPsychiatrist,
      'emergency physician' => hrReferenceStaffPositionEmergencyPhysician,
      'family medicine physician' =>
        hrReferenceStaffPositionFamilyMedicinePhysician,
      'dental surgeon' => hrReferenceStaffPositionDentalSurgeon,
      'nurse practitioner' => hrReferenceStaffPositionNursePractitioner,
      'physiotherapist' => hrReferenceStaffPositionPhysiotherapist,
      'occupational therapist' => hrReferenceStaffPositionOccupationalTherapist,
      'speech therapist' => hrReferenceStaffPositionSpeechTherapist,
      'dietitian' => hrReferenceStaffPositionDietitian,
      'clinical psychologist' => hrReferenceStaffPositionClinicalPsychologist,
      'social worker' => hrReferenceStaffPositionSocialWorker,
      'respiratory therapist' => hrReferenceStaffPositionRespiratoryTherapist,
      'lab technologist' => hrReferenceStaffPositionLabTechnologist,
      'medical laboratory scientist' =>
        hrReferenceStaffPositionMedicalLaboratoryScientist,
      'phlebotomist' => hrReferenceStaffPositionPhlebotomist,
      'radiologist' => hrReferenceStaffPositionRadiologist,
      'sonographer' => hrReferenceStaffPositionSonographer,
      'ecg technician' => hrReferenceStaffPositionEcgTechnician,
      'pharmacist' => hrReferenceStaffPositionPharmacist,
      'pharmacy technician' => hrReferenceStaffPositionPharmacyTechnician,
      'pharmacy assistant' => hrReferenceStaffPositionPharmacyAssistant,
      'administrator' => hrReferenceStaffPositionAdministrator,
      'hr officer' => hrReferenceStaffPositionHrOfficer,
      'receptionist' => hrReferenceStaffPositionReceptionist,
      'medical records officer' =>
        hrReferenceStaffPositionMedicalRecordsOfficer,
      'health information officer' =>
        hrReferenceStaffPositionHealthInformationOfficer,
      'patient relations officer' =>
        hrReferenceStaffPositionPatientRelationsOfficer,
      'billing clerk' => hrReferenceStaffPositionBillingClerk,
      'accounts officer' => hrReferenceStaffPositionAccountsOfficer,
      'insurance officer' => hrReferenceStaffPositionInsuranceOfficer,
      'cashier' => hrReferenceStaffPositionCashier,
      'housekeeper' => hrReferenceStaffPositionHousekeeper,
      'porter' => hrReferenceStaffPositionPorter,
      'security officer' => hrReferenceStaffPositionSecurityOfficer,
      'laundry attendant' => hrReferenceStaffPositionLaundryAttendant,
      'kitchen staff' => hrReferenceStaffPositionKitchenStaff,
      'mortuary attendant' => hrReferenceStaffPositionMortuaryAttendant,
      'ambulance driver' => hrReferenceStaffPositionAmbulanceDriver,
      'ambulance operator' => hrReferenceStaffPositionAmbulanceOperator,
      'biomedical engineer' => hrReferenceStaffPositionBiomedicalEngineer,
      'it support officer' => hrReferenceStaffPositionItSupportOfficer,
      'maintenance technician' => hrReferenceStaffPositionMaintenanceTechnician,
      'hospital administrator' => hrReferenceStaffPositionHospitalAdministrator,
      'department head' => hrReferenceStaffPositionDepartmentHead,
      'chief nursing officer' => hrReferenceStaffPositionChiefNursingOfficer,
      'operations manager' => hrReferenceStaffPositionOperationsManager,
      'facility manager' => hrReferenceStaffPositionFacilityManager,
      _ => fallback ?? normalized,
    };
  }

  String hrReferenceRoleLabel(String? code, {String? fallback}) {
    final String normalized = (code ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return fallback ?? '';
    }
    return switch (normalized) {
      'TENANT_ADMIN' => hrReferenceRoleTenantAdmin,
      'FACILITY_ADMIN' => hrReferenceRoleFacilityAdmin,
      'HR' => hrReferenceRoleHr,
      'OPERATIONS' => hrReferenceRoleOperations,
      'IT_SUPPORT' => hrReferenceRoleItSupport,
      'DOCTOR' => hrReferenceRoleDoctor,
      'ATTENDING_PHYSICIAN' => hrReferenceRoleAttendingPhysician,
      'RESIDENT_PHYSICIAN' => hrReferenceRoleResidentPhysician,
      'SURGEON' => hrReferenceRoleSurgeon,
      'ANESTHESIOLOGIST' => hrReferenceRoleAnesthesiologist,
      'PHYSICIAN_ASSISTANT' => hrReferenceRolePhysicianAssistant,
      'EMERGENCY_PHYSICIAN' => hrReferenceRoleEmergencyPhysician,
      'NURSE' => hrReferenceRoleNurse,
      'LICENSED_PRACTICAL_NURSE' => hrReferenceRoleLicensedPracticalNurse,
      'NURSE_PRACTITIONER' => hrReferenceRoleNursePractitioner,
      'TRIAGE_NURSE' => hrReferenceRoleTriageNurse,
      'MIDWIFE' => hrReferenceRoleMidwife,
      'CHARGE_NURSE' => hrReferenceRoleChargeNurse,
      'PHYSIOTHERAPIST' => hrReferenceRolePhysiotherapist,
      'OCCUPATIONAL_THERAPIST' => hrReferenceRoleOccupationalTherapist,
      'RESPIRATORY_THERAPIST' => hrReferenceRoleRespiratoryTherapist,
      'DIETITIAN' => hrReferenceRoleDietitian,
      'SOCIAL_WORKER' => hrReferenceRoleSocialWorker,
      'CLINICAL_PSYCHOLOGIST' => hrReferenceRoleClinicalPsychologist,
      'LAB_TECH' => hrReferenceRoleLabTech,
      'MEDICAL_LABORATORY_SCIENTIST' => hrReferenceRoleMedicalLaboratoryScientist,
      'PATHOLOGIST' => hrReferenceRolePathologist,
      'RADIOLOGY_TECH' => hrReferenceRoleRadiologyTech,
      'SONOGRAPHER' => hrReferenceRoleSonographer,
      'PHARMACIST' => hrReferenceRolePharmacist,
      'PHARMACY_TECHNICIAN' => hrReferenceRolePharmacyTechnician,
      'RECEPTIONIST' => hrReferenceRoleReceptionist,
      'ADMISSIONS_COORDINATOR' => hrReferenceRoleAdmissionsCoordinator,
      'MEDICAL_RECORDS_CLERK' => hrReferenceRoleMedicalRecordsClerk,
      'BILLING' => hrReferenceRoleBilling,
      'MEDICAL_CODER' => hrReferenceRoleMedicalCoder,
      'AMBULANCE_OPERATOR' => hrReferenceRoleAmbulanceOperator,
      'PARAMEDIC' => hrReferenceRoleParamedic,
      'EMT' => hrReferenceRoleEmt,
      'HOUSE_KEEPER' => hrReferenceRoleHouseKeeper,
      'HOUSEKEEPING_MANAGER' => hrReferenceRoleHousekeepingManager,
      'FOOD_SERVICE_WORKER' => hrReferenceRoleFoodServiceWorker,
      'PORTER' => hrReferenceRolePorter,
      'SECURITY_OFFICER' => hrReferenceRoleSecurityOfficer,
      'MAINTENANCE_ENGINEER' => hrReferenceRoleMaintenanceEngineer,
      'CHAPLAIN' => hrReferenceRoleChaplain,
      'BIOMED' => hrReferenceRoleBiomed,
      'BIOMED_MANAGER' => hrReferenceRoleBiomedManager,
      'UNIT_MANAGER' => hrReferenceRoleUnitManager,
      'WARD_MANAGER' => hrReferenceRoleWardManager,
      'ICU_MANAGER' => hrReferenceRoleIcuManager,
      'THEATRE_MANAGER' => hrReferenceRoleTheatreManager,
      'MORTUARY_STAFF' => hrReferenceRoleMortuaryStaff,
      'MORTUARY_MANAGER' => hrReferenceRoleMortuaryManager,
      _ => fallback ?? normalized,
    };
  }

  String _roleLabelFromKey(String key, {String? fallback}) {
    return switch (key) {
      'labels.hr.reference.role.tenant_admin' => hrReferenceRoleTenantAdmin,
      'labels.hr.reference.role.facility_admin' => hrReferenceRoleFacilityAdmin,
      'labels.hr.reference.role.hr' => hrReferenceRoleHr,
      'labels.hr.reference.role.operations' => hrReferenceRoleOperations,
      'labels.hr.reference.role.it_support' => hrReferenceRoleItSupport,
      'labels.hr.reference.role.doctor' => hrReferenceRoleDoctor,
      'labels.hr.reference.role.attending_physician' =>
        hrReferenceRoleAttendingPhysician,
      'labels.hr.reference.role.resident_physician' =>
        hrReferenceRoleResidentPhysician,
      'labels.hr.reference.role.surgeon' => hrReferenceRoleSurgeon,
      'labels.hr.reference.role.anesthesiologist' =>
        hrReferenceRoleAnesthesiologist,
      'labels.hr.reference.role.physician_assistant' =>
        hrReferenceRolePhysicianAssistant,
      'labels.hr.reference.role.emergency_physician' =>
        hrReferenceRoleEmergencyPhysician,
      'labels.hr.reference.role.nurse' => hrReferenceRoleNurse,
      'labels.hr.reference.role.licensed_practical_nurse' =>
        hrReferenceRoleLicensedPracticalNurse,
      'labels.hr.reference.role.nurse_practitioner' =>
        hrReferenceRoleNursePractitioner,
      'labels.hr.reference.role.triage_nurse' => hrReferenceRoleTriageNurse,
      'labels.hr.reference.role.midwife' => hrReferenceRoleMidwife,
      'labels.hr.reference.role.charge_nurse' => hrReferenceRoleChargeNurse,
      'labels.hr.reference.role.physiotherapist' =>
        hrReferenceRolePhysiotherapist,
      'labels.hr.reference.role.occupational_therapist' =>
        hrReferenceRoleOccupationalTherapist,
      'labels.hr.reference.role.respiratory_therapist' =>
        hrReferenceRoleRespiratoryTherapist,
      'labels.hr.reference.role.dietitian' => hrReferenceRoleDietitian,
      'labels.hr.reference.role.social_worker' => hrReferenceRoleSocialWorker,
      'labels.hr.reference.role.clinical_psychologist' =>
        hrReferenceRoleClinicalPsychologist,
      'labels.hr.reference.role.lab_tech' => hrReferenceRoleLabTech,
      'labels.hr.reference.role.medical_laboratory_scientist' =>
        hrReferenceRoleMedicalLaboratoryScientist,
      'labels.hr.reference.role.pathologist' => hrReferenceRolePathologist,
      'labels.hr.reference.role.radiology_tech' => hrReferenceRoleRadiologyTech,
      'labels.hr.reference.role.sonographer' => hrReferenceRoleSonographer,
      'labels.hr.reference.role.pharmacist' => hrReferenceRolePharmacist,
      'labels.hr.reference.role.pharmacy_technician' =>
        hrReferenceRolePharmacyTechnician,
      'labels.hr.reference.role.receptionist' => hrReferenceRoleReceptionist,
      'labels.hr.reference.role.admissions_coordinator' =>
        hrReferenceRoleAdmissionsCoordinator,
      'labels.hr.reference.role.medical_records_clerk' =>
        hrReferenceRoleMedicalRecordsClerk,
      'labels.hr.reference.role.billing' => hrReferenceRoleBilling,
      'labels.hr.reference.role.medical_coder' => hrReferenceRoleMedicalCoder,
      'labels.hr.reference.role.ambulance_operator' =>
        hrReferenceRoleAmbulanceOperator,
      'labels.hr.reference.role.paramedic' => hrReferenceRoleParamedic,
      'labels.hr.reference.role.emt' => hrReferenceRoleEmt,
      'labels.hr.reference.role.house_keeper' => hrReferenceRoleHouseKeeper,
      'labels.hr.reference.role.housekeeping_manager' =>
        hrReferenceRoleHousekeepingManager,
      'labels.hr.reference.role.food_service_worker' =>
        hrReferenceRoleFoodServiceWorker,
      'labels.hr.reference.role.porter' => hrReferenceRolePorter,
      'labels.hr.reference.role.security_officer' =>
        hrReferenceRoleSecurityOfficer,
      'labels.hr.reference.role.maintenance_engineer' =>
        hrReferenceRoleMaintenanceEngineer,
      'labels.hr.reference.role.chaplain' => hrReferenceRoleChaplain,
      'labels.hr.reference.role.biomed' => hrReferenceRoleBiomed,
      'labels.hr.reference.role.biomed_manager' => hrReferenceRoleBiomedManager,
      'labels.hr.reference.role.unit_manager' => hrReferenceRoleUnitManager,
      'labels.hr.reference.role.ward_manager' => hrReferenceRoleWardManager,
      'labels.hr.reference.role.icu_manager' => hrReferenceRoleIcuManager,
      'labels.hr.reference.role.theatre_manager' => hrReferenceRoleTheatreManager,
      'labels.hr.reference.role.mortuary_staff' => hrReferenceRoleMortuaryStaff,
      'labels.hr.reference.role.mortuary_manager' =>
        hrReferenceRoleMortuaryManager,
      _ => fallback ?? key,
    };
  }

  bool isConsultationFeePractitionerType(String? code) {
    return <String>{
      'MO',
      'SPECIALIST',
      'RESIDENT',
      'GP',
      'SURGEON',
      'ANAESTHETIST',
      'PAEDIATRICIAN',
      'OBGYN',
      'NURSE_PRACTITIONER',
      'DENTIST',
      'PSYCHIATRIST',
      'EMERGENCY_MEDICINE',
      'FAMILY_MEDICINE',
      'DERMATOLOGIST',
      'CARDIOLOGIST',
      'OPHTHALMOLOGIST',
      'ORTHOPAEDIC_SURGEON',
    }.contains((code ?? '').trim().toUpperCase());
  }
}
