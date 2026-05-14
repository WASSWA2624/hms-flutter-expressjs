const resolveProblemInstance = (req) =>
  req?.originalUrl || req?.url || req?.path || null;

const toProblemType = (code) => `urn:problem-type:hms:${String(code || 'UNKNOWN_ERROR')}`;

const applyProblemJsonContentType = (res) => {
  if (typeof res.type === 'function') {
    res.type('application/problem+json');
    return;
  }

  if (typeof res.setHeader === 'function') {
    res.setHeader('Content-Type', 'application/problem+json');
  }
};

const createProblemDetails = ({
  status,
  title,
  detail,
  code,
  errors = [],
  meta = {},
  req = null
}) => {
  const problem = {
    type: toProblemType(code),
    title,
    status,
    detail,
    code,
    message: detail,
    errors,
    meta
  };

  const instance = resolveProblemInstance(req);
  if (instance) {
    problem.instance = instance;
  }

  return problem;
};

module.exports = {
  applyProblemJsonContentType,
  createProblemDetails,
  resolveProblemInstance
};
