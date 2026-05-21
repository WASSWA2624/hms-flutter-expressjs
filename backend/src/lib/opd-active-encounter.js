const { HttpError } = require('@lib/errors');

const ACTIVE_OPD_ENCOUNTER_TYPES = Object.freeze(['OPD', 'EMERGENCY']);
const ACTIVE_OPD_LOCK_FACILITY_FALLBACK = 'GLOBAL';

const isActiveOpdEncounter = ({ encounter_type, status, deleted_at }) =>
  ACTIVE_OPD_ENCOUNTER_TYPES.includes(encounter_type) &&
  status === 'OPEN' &&
  !deleted_at;

const buildActiveOpdLockKey = ({ tenantId, facilityId, patientId }) => {
  if (!tenantId || !patientId) return null;
  return `opd:${tenantId}:${facilityId || ACTIVE_OPD_LOCK_FACILITY_FALLBACK}:${patientId}`;
};

const activeOpdLockKeyForEncounter = (encounter) => {
  if (!encounter || !isActiveOpdEncounter(encounter)) return null;
  return buildActiveOpdLockKey({
    tenantId: encounter.tenant_id,
    facilityId: encounter.facility_id,
    patientId: encounter.patient_id
  });
};

const isActiveOpdLockUniqueError = (error) => {
  if (!error || error.code !== 'P2002') return false;
  const target = error.meta?.target;
  if (Array.isArray(target)) {
    return target.includes('active_opd_lock_key');
  }
  return String(target || '').includes('active_opd_lock_key');
};

const throwActiveOpdEncounterExists = (details = {}) => {
  throw new HttpError('errors.opd_flow.active_encounter_exists', 409, [
    {
      field: 'patient_id',
      ...details
    }
  ]);
};

const throwIfActiveOpdLockError = (error) => {
  if (!isActiveOpdLockUniqueError(error)) return;
  throwActiveOpdEncounterExists();
};

module.exports = {
  ACTIVE_OPD_ENCOUNTER_TYPES,
  activeOpdLockKeyForEncounter,
  buildActiveOpdLockKey,
  isActiveOpdEncounter,
  isActiveOpdLockUniqueError,
  throwActiveOpdEncounterExists,
  throwIfActiveOpdLockError
};
