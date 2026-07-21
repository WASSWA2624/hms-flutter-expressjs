const toArray = (value) => {
  if (Array.isArray(value)) return value;
  return value ? [value] : [];
};

const withActivePatient = (filters = {}, relationName = 'patient') => {
  const { AND, ...rest } = filters || {};

  return {
    ...rest,
    deleted_at: null,
    AND: [
      ...toArray(AND),
      {
        [relationName]: {
          deleted_at: null,
        },
      },
    ],
  };
};

module.exports = {
  withActivePatient,
};
