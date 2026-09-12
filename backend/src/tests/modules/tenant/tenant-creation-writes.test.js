/**
 * Tenant creation write-surface tests
 *
 * Step 05, AC1/AC2: the tenant and facility creation paths must write only
 * configuration and identity. This records every table each creation path
 * touches and fails loudly if a patient-linked or transactional table ever
 * appears in that set.
 */

jest.mock('@prisma/client', () => {
  const mockWriteMethods = ['create', 'createMany', 'upsert', 'update', 'updateMany'];
  const mockWrites = { tables: new Set(), calls: [] };

  const mockRowFor = (model) => ({
    id: `${model}-id`,
    tenant_id: 'tenant-id',
    facility_id: 'facility-id',
    name: `${model}-name`,
    slug: `${model}-slug`,
    is_active: true,
    facility_type: 'CLINIC',
    status: 'PENDING',
    deleted_at: null,
  });

  // Records writes instead of performing them. Reads return the shapes the
  // repositories expect; an unrecognised call still returns a plain row, so a
  // newly added write is recorded rather than crashing before the assertion.
  const mockDelegate = (model) =>
    new Proxy(
      {},
      {
        get: (_target, method) => {
          if (typeof method !== 'string') return undefined;
          return jest.fn(async (args) => {
            if (mockWriteMethods.includes(method)) {
              mockWrites.tables.add(model);
              mockWrites.calls.push({ model, method, args });
            }
            if (method === 'findMany') return [];
            if (method === 'count') return 0;
            return mockRowFor(model);
          });
        },
      }
    );

  const mockCache = new Map();
  const mockClient = new Proxy(
    {},
    {
      get: (_target, model) => {
        if (typeof model !== 'string') return undefined;
        if (model === '__writes') return mockWrites;
        if (model === '$transaction') {
          return jest.fn(async (arg) =>
            typeof arg === 'function' ? arg(mockClient) : Promise.resolve([])
          );
        }
        if (model.startsWith('$')) return jest.fn();
        if (!mockCache.has(model)) mockCache.set(model, mockDelegate(model));
        return mockCache.get(model);
      },
    }
  );

  return mockClient;
});

jest.mock('@lib/facility-structure/cascade-soft-delete', () => ({
  softDeleteFacilityStructure: jest.fn(),
  restoreFacilityStructure: jest.fn(),
  restoreBed: jest.fn(),
  restoreUnit: jest.fn(),
  restoreRoom: jest.fn(),
  restoreWard: jest.fn(),
  restoreDepartment: jest.fn(),
}));

const {
  listForbiddenTables,
  CORE_FORBIDDEN_TABLES,
} = require('@lib/tenant/tenant-initialization-policy');

const prisma = require('@prisma/client');
const tenantRepository = require('@repositories/tenant/tenant.repository');
const facilityRepository = require('@repositories/facility/facility.repository');
const authRepository = require('@repositories/auth/auth.repository');

const writes = prisma.__writes;
const touched = () => [...writes.tables].sort();

/** Configuration and identity tables the registration bootstrap is expected to write. */
const EXPECTED_REGISTRATION_TABLES = [
  'facility',
  'registration_attempt',
  'role',
  'tenant',
  'user',
  'user_profile',
  'user_role',
];

describe('tenant creation write surface', () => {
  beforeEach(() => {
    writes.tables.clear();
    writes.calls.length = 0;
  });

  describe('platform-admin tenant create', () => {
    it('writes only the tenant and its default facility', async () => {
      await tenantRepository.createWithDefaultFacility(
        { name: 'Probe Org', slug: 'probe-org', is_active: true },
        { facilityName: 'Probe Org Main Facility' }
      );

      expect(touched()).toEqual(['facility', 'tenant']);
    });
  });

  describe('facility create', () => {
    it('writes only the facility', async () => {
      await facilityRepository.create({
        tenant_id: 'tenant-id',
        name: 'Extra Facility',
        facility_type: 'CLINIC',
        is_active: true,
      });

      expect(touched()).toEqual(['facility']);
    });
  });

  describe('self-serve registration bootstrap', () => {
    beforeEach(async () => {
      await authRepository.registerFacilityOwner({
        email: 'owner@example.com',
        phone: '256700000000',
        password_hash: 'hashed',
        facility_name: 'Probe Facility',
        tenant_name: 'Probe Org',
        facility_type: 'CLINIC',
        admin_name: 'Probe Admin',
        registration_attempt_id: 'attempt-id',
      });
    });

    it('writes only configuration and identity tables', () => {
      expect(touched()).toEqual(EXPECTED_REGISTRATION_TABLES);
    });

    it('writes no forbidden table', () => {
      const forbidden = new Set(listForbiddenTables());

      expect(touched().filter((table) => forbidden.has(table))).toEqual([]);
    });

    it('writes no patient-linked or transactional table', () => {
      expect(CORE_FORBIDDEN_TABLES.filter((table) => writes.tables.has(table))).toEqual([]);
    });
  });

  describe('across every creation path', () => {
    it('never touches a forbidden table', async () => {
      await tenantRepository.createWithDefaultFacility(
        { name: 'Probe Org', slug: 'probe-org' },
        { facilityName: 'Main' }
      );
      await facilityRepository.create({ tenant_id: 'tenant-id', name: 'Extra' });
      await authRepository.registerFacilityOwner({
        email: 'owner2@example.com',
        password_hash: 'hashed',
        facility_name: 'Probe Facility',
        tenant_name: 'Probe Org',
        facility_type: 'CLINIC',
        admin_name: 'Probe Admin',
      });

      const forbidden = new Set(listForbiddenTables());

      expect(touched().filter((table) => forbidden.has(table))).toEqual([]);
    });
  });
});
