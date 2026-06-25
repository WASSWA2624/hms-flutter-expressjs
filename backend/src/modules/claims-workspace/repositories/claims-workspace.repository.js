/**
 * Claims workspace repository
 *
 * @module modules/claims-workspace/repositories
 * @description Cross-entity Prisma queries that power the insurance and claims
 * workspace aggregator. Reads coverage plans, pre-authorizations, insurance
 * claims, and billable invoices. This module never mutates claim/pre-auth state;
 * mutations remain owned by the insurance-claim and pre-authorization modules.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error?.code === 'P2025') {
      throw new HttpError('errors.resource.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countClaims = async (where = {}) =>
  withDbErrorHandling(() => prisma.insurance_claim.count({ where: { deleted_at: null, ...where } }));

const findManyClaims = async (where = {}, skip = 0, take = 60, orderBy = { submitted_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.insurance_claim.findMany({ where: { deleted_at: null, ...where }, skip, take, orderBy, include })
  );

const countPreAuthorizations = async (where = {}) =>
  withDbErrorHandling(() => prisma.pre_authorization.count({ where: { deleted_at: null, ...where } }));

const findManyPreAuthorizations = async (
  where = {},
  skip = 0,
  take = 60,
  orderBy = { requested_at: 'desc' },
  include = {}
) =>
  withDbErrorHandling(() =>
    prisma.pre_authorization.findMany({ where: { deleted_at: null, ...where }, skip, take, orderBy, include })
  );

const countCoveragePlans = async (where = {}) =>
  withDbErrorHandling(() => prisma.coverage_plan.count({ where: { deleted_at: null, ...where } }));

const findManyCoveragePlans = async (where = {}, skip = 0, take = 50, orderBy = { name: 'asc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.coverage_plan.findMany({ where: { deleted_at: null, ...where }, skip, take, orderBy, include })
  );

const findManyInvoices = async (where = {}, skip = 0, take = 50, orderBy = { issued_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.invoice.findMany({ where: { deleted_at: null, ...where }, skip, take, orderBy, include })
  );

module.exports = {
  countClaims,
  findManyClaims,
  countPreAuthorizations,
  findManyPreAuthorizations,
  countCoveragePlans,
  findManyCoveragePlans,
  findManyInvoices,
};
