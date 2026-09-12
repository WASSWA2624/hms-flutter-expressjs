/**
 * Platform preset immutability across catalog domains
 *
 * Step 06, AC3/AC4: a tenant-scoped actor may read a platform preset but never
 * update or delete it, and the refusal is an explicit forbidden response from
 * the API rather than a 404 that pretends the preset is not there.
 *
 * Exercised through each definition service, not through the guard directly, so
 * a domain that forgets to call the guard fails here.
 */

jest.mock('@repositories/drug/drug.repository');
jest.mock('@repositories/clinical-term/clinical-term.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/service-identifier-resolution', () => ({
  resolveIdentifierForFilter: jest.fn(async (args) => args?.value),
  resolveIdentifierForPayload: jest.fn(async (args) => args?.value),
}));

const { HttpError } = require('@lib/errors');
const drugService = require('@services/drug/drug.service');
const drugRepository = require('@repositories/drug/drug.repository');
const clinicalCatalogService = require('@services/clinical-term/clinical-catalog.service');
const clinicalTermRepository = require('@repositories/clinical-term/clinical-term.repository');
const { createAuditLog } = require('@lib/audit');

/** Tenant admin in tenant-a. Carries `permissions`, so it is a request actor. */
const tenantActor = {
  id: 'user-a',
  tenant_id: 'tenant-a',
  roles: ['TENANT_ADMIN'],
  permissions: [],
};

const otherTenantActor = {
  id: 'user-b',
  tenant_id: 'tenant-b',
  roles: ['TENANT_ADMIN'],
  permissions: [],
};

const platformActor = {
  id: 'admin-1',
  roles: ['PLATFORM_ADMIN'],
  permissions: ['platform:admin'],
};

const platformDrug = { id: 'drug-platform', tenant_id: null, name: 'Paracetamol' };
const tenantDrug = { id: 'drug-tenant-a', tenant_id: 'tenant-a', name: 'House Syrup' };

const platformTerm = {
  id: 'term-platform',
  tenant_id: null,
  term_type: 'DIAGNOSIS',
  description: 'Malaria',
};
const tenantTerm = {
  id: 'term-tenant-a',
  tenant_id: 'tenant-a',
  term_type: 'DIAGNOSIS',
  description: 'Local protocol',
};

const catch_ = async (promise) => promise.then(() => null, (error) => error);

describe('platform preset immutability', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  describe('drug definitions', () => {
    it('lets a tenant actor read a platform preset', async () => {
      drugRepository.findById.mockResolvedValue(platformDrug);

      await expect(
        drugService.getDrugById('drug-platform', 'user-a', '127.0.0.1', tenantActor)
      ).resolves.toEqual(expect.objectContaining({ id: 'drug-platform' }));
    });

    it('refuses a tenant actor updating a platform preset', async () => {
      drugRepository.findById.mockResolvedValue(platformDrug);

      const error = await catch_(
        drugService.updateDrug('drug-platform', { name: 'Renamed' }, 'user-a', '127.0.0.1', tenantActor)
      );

      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(403);
      expect(drugRepository.update).not.toHaveBeenCalled();
    });

    it('refuses a tenant actor deleting a platform preset', async () => {
      drugRepository.findById.mockResolvedValue(platformDrug);

      const error = await catch_(
        drugService.deleteDrug('drug-platform', 'user-a', '127.0.0.1', tenantActor)
      );

      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(403);
      expect(drugRepository.softDelete).not.toHaveBeenCalled();
    });

    it('lets a platform actor update a platform preset', async () => {
      drugRepository.findById.mockResolvedValue(platformDrug);
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.update.mockResolvedValue({ ...platformDrug, name: 'Renamed' });

      const error = await catch_(
        drugService.updateDrug('drug-platform', { name: 'Renamed' }, 'admin-1', '127.0.0.1', platformActor)
      );

      expect(error).toBeNull();
      expect(drugRepository.update).toHaveBeenCalled();
    });

    it('lets a tenant actor update its own definition', async () => {
      drugRepository.findById.mockResolvedValue(tenantDrug);
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.update.mockResolvedValue({ ...tenantDrug, name: 'Renamed' });

      const error = await catch_(
        drugService.updateDrug('drug-tenant-a', { name: 'Renamed' }, 'user-a', '127.0.0.1', tenantActor)
      );

      expect(error).toBeNull();
      expect(drugRepository.update).toHaveBeenCalled();
    });

    it('hides another tenant\'s definition entirely', async () => {
      drugRepository.findById.mockResolvedValue(tenantDrug);

      const error = await catch_(
        drugService.updateDrug('drug-tenant-a', { name: 'Renamed' }, 'user-b', '127.0.0.1', otherTenantActor)
      );

      // Not the actor's tenant and not a platform preset: it does not exist.
      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(404);
      expect(drugRepository.update).not.toHaveBeenCalled();
    });
  });

  describe('clinical term definitions', () => {
    const context = (actor) => ({
      user_id: actor.id,
      tenant_id: actor.tenant_id || null,
      roles: actor.roles,
      permissions: actor.permissions,
      ip_address: '127.0.0.1',
    });

    it('refuses a tenant actor updating a platform term with 403, not 404', async () => {
      clinicalTermRepository.findCatalogTerm.mockResolvedValue(platformTerm);

      const error = await catch_(
        clinicalCatalogService.updateCatalogTerm(
          'term-platform',
          { description: 'Renamed' },
          context(tenantActor)
        )
      );

      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(403);
      expect(clinicalTermRepository.updateCatalogTerm).not.toHaveBeenCalled();
    });

    it('refuses a tenant actor deleting a platform term', async () => {
      clinicalTermRepository.findCatalogTerm.mockResolvedValue(platformTerm);

      const error = await catch_(
        clinicalCatalogService.deleteCatalogTerm('term-platform', context(tenantActor))
      );

      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(403);
      expect(clinicalTermRepository.updateCatalogTerm).not.toHaveBeenCalled();
    });

    it('refuses tenant B writing tenant A\'s term', async () => {
      clinicalTermRepository.findCatalogTerm.mockResolvedValue(tenantTerm);

      const error = await catch_(
        clinicalCatalogService.updateCatalogTerm(
          'term-tenant-a',
          { description: 'Renamed' },
          context(otherTenantActor)
        )
      );

      expect(error).toBeInstanceOf(HttpError);
      expect(error.statusCode).toBe(403);
      expect(clinicalTermRepository.updateCatalogTerm).not.toHaveBeenCalled();
    });

    it('lets a tenant actor update its own term', async () => {
      clinicalTermRepository.findCatalogTerm.mockResolvedValue(tenantTerm);
      clinicalTermRepository.updateCatalogTerm.mockResolvedValue({
        ...tenantTerm,
        description: 'Renamed',
      });

      const error = await catch_(
        clinicalCatalogService.updateCatalogTerm(
          'term-tenant-a',
          { description: 'Renamed' },
          context(tenantActor)
        )
      );

      expect(error).toBeNull();
      expect(clinicalTermRepository.updateCatalogTerm).toHaveBeenCalled();
    });
  });

  describe('cross-tenant isolation', () => {
    it('never writes to a definition when the guard refuses', async () => {
      drugRepository.findById.mockResolvedValue(platformDrug);
      clinicalTermRepository.findCatalogTerm.mockResolvedValue(platformTerm);

      await catch_(
        drugService.updateDrug('drug-platform', { name: 'A' }, 'user-a', '127.0.0.1', tenantActor)
      );
      await catch_(
        clinicalCatalogService.updateCatalogTerm(
          'term-platform',
          { description: 'A' },
          {
            user_id: 'user-a',
            tenant_id: 'tenant-a',
            roles: ['TENANT_ADMIN'],
            permissions: [],
          }
        )
      );

      expect(drugRepository.update).not.toHaveBeenCalled();
      expect(drugRepository.softDelete).not.toHaveBeenCalled();
      expect(clinicalTermRepository.updateCatalogTerm).not.toHaveBeenCalled();
    });
  });
});
