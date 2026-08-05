const toArray = (value) => {
  if (Array.isArray(value)) return value;
  return value ? [value] : [];
};

/**
 * Soft-delete filter for patient-linked rows.
 *
 * Default: require a non-deleted patient (models with required `patient_id`).
 * Pass `{ allowNullPatient: true }` for visitor-capable models (nullable
 * `patient_id`, e.g. appointment) so null-patient rows remain visible.
 *
 * @param {Object} [filters]
 * @param {string|{ allowNullPatient?: boolean, relationName?: string }} [relationNameOrOptions='patient']
 * @param {{ allowNullPatient?: boolean }} [options]
 */
const withActivePatient = (
  filters = {},
  relationNameOrOptions = 'patient',
  options = {}
) => {
  const { AND, ...rest } = filters || {};

  let relationName = 'patient';
  let allowNullPatient = false;

  if (typeof relationNameOrOptions === 'string') {
    relationName = relationNameOrOptions || 'patient';
    allowNullPatient = options.allowNullPatient === true;
  } else if (relationNameOrOptions && typeof relationNameOrOptions === 'object') {
    relationName = relationNameOrOptions.relationName || 'patient';
    allowNullPatient = relationNameOrOptions.allowNullPatient === true;
  }

  const patientClause = allowNullPatient
    ? {
        OR: [
          { patient_id: null },
          {
            [relationName]: {
              deleted_at: null,
            },
          },
        ],
      }
    : {
        [relationName]: {
          deleted_at: null,
        },
      };

  return {
    ...rest,
    deleted_at: null,
    AND: [...toArray(AND), patientClause],
  };
};

module.exports = {
  withActivePatient,
};
