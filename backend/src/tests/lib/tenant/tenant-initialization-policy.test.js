/**
 * tenant-initialization-policy unit tests
 *
 * Guards the step 05 contract: a newly created tenant contains configuration and
 * presets and zero rows in any patient-linked or transactional table.
 */

const {
  ALLOWED_INITIAL_TABLES,
  CORE_FORBIDDEN_TABLES,
  listTenantReachableTables,
  listForbiddenTables,
  classifyTable,
  findTenantOperationalRows,
  assertTenantHasNoOperationalData,
} = require('@lib/tenant/tenant-initialization-policy');

/**
 * Prisma double whose forbidden tables are empty unless `rowsByTable` says
 * otherwise. Records every `where` it receives so tenant scoping can be checked.
 */
const buildPrismaStub = ({ rowsByTable = {}, facilityIds = ['facility-1'] } = {}) => {
  const seenWhere = [];
  const stub = {
    facility: {
      findMany: jest.fn(async () => facilityIds.map((id) => ({ id }))),
    },
    __seenWhere: seenWhere,
  };

  for (const table of listTenantReachableTables()) {
    stub[table] = stub[table] || {};
    stub[table].count = jest.fn(async ({ where }) => {
      seenWhere.push({ table, where });
      return rowsByTable[table] || 0;
    });
  }

  return stub;
};

describe('tenant-initialization-policy', () => {
  describe('classification', () => {
    it('classifies every tenant-reachable table as allowed or forbidden', () => {
      const unclassified = listTenantReachableTables().filter(
        (table) => classifyTable(table) === 'out-of-scope'
      );

      expect(unclassified).toEqual([]);
    });

    it('splits reachable tables into exactly allowed plus forbidden', () => {
      const reachable = listTenantReachableTables();
      const forbidden = listForbiddenTables();
      const allowed = reachable.filter((table) => ALLOWED_INITIAL_TABLES.has(table));

      expect(allowed.length + forbidden.length).toBe(reachable.length);
      expect(forbidden.some((table) => ALLOWED_INITIAL_TABLES.has(table))).toBe(false);
    });

    it('contains no allowlist entry that has left the schema', () => {
      const reachable = new Set(listTenantReachableTables());
      const stale = [...ALLOWED_INITIAL_TABLES].filter((table) => !reachable.has(table));

      expect(stale).toEqual([]);
    });

    it('keeps every core patient-linked and transactional table forbidden', () => {
      const forbidden = new Set(listForbiddenTables());
      const dropped = CORE_FORBIDDEN_TABLES.filter((table) => !forbidden.has(table));

      expect(dropped).toEqual([]);
    });

    it.each([
      ['patients', 'patient'],
      ['visits', 'visit_queue'],
      ['encounters', 'encounter'],
      ['admissions', 'admission'],
      ['appointments', 'appointment'],
      ['lab and radiology work', 'patient_report_job'],
      ['bills', 'billable_charge_event'],
      ['invoices', 'invoice'],
      ['payments', 'payment'],
      ['dispensing and stock movement', 'stock_movement'],
      ['patient demographics', 'patient_identifier'],
      ['patient history', 'patient_medical_history'],
    ])('treats %s as forbidden', (_label, table) => {
      expect(classifyTable(table)).toBe('forbidden');
    });

    it.each([
      ['facilities', 'facility'],
      ['departments', 'department'],
      ['units', 'unit'],
      ['default roles', 'role'],
      ['lab tests', 'lab_test'],
      ['lab panels', 'lab_panel'],
      ['radiology procedures', 'radiology_procedure'],
      ['pharmacy master data', 'drug'],
      ['price books', 'price_book_entry'],
      ['subscriptions', 'subscription'],
    ])('keeps %s allowed as initial configuration', (_label, table) => {
      expect(classifyTable(table)).toBe('allowed');
    });
  });

  describe('findTenantOperationalRows', () => {
    it('reports nothing for a tenant with only configuration', async () => {
      const client = buildPrismaStub();

      await expect(findTenantOperationalRows('tenant-1', { client })).resolves.toEqual([]);
    });

    it('reports every forbidden table that holds rows, largest first', async () => {
      const client = buildPrismaStub({
        rowsByTable: { patient: 12, invoice: 40, encounter: 3 },
      });

      const violations = await findTenantOperationalRows('tenant-1', { client });

      expect(violations).toEqual([
        { table: 'invoice', rows: 40, scope: 'tenant_id' },
        { table: 'patient', rows: 12, scope: 'tenant_id' },
        { table: 'encounter', rows: 3, scope: 'tenant_id' },
      ]);
    });

    it('never counts an allowed configuration table', async () => {
      const client = buildPrismaStub({
        rowsByTable: { department: 20, unit: 20, role: 58, staff_position: 65 },
      });

      await expect(findTenantOperationalRows('tenant-1', { client })).resolves.toEqual([]);
      expect(client.department.count).not.toHaveBeenCalled();
      expect(client.role.count).not.toHaveBeenCalled();
    });

    it('scopes every count to the tenant or to that tenant\'s facilities', async () => {
      const client = buildPrismaStub({ facilityIds: ['facility-a', 'facility-b'] });

      await findTenantOperationalRows('tenant-1', { client });

      expect(client.__seenWhere.length).toBeGreaterThan(0);
      for (const { where } of client.__seenWhere) {
        const scoped =
          where?.tenant_id === 'tenant-1'
          || (where?.facility_id?.in || []).every((id) =>
            ['facility-a', 'facility-b'].includes(id)
          );
        expect(scoped).toBe(true);
      }
    });

    it('counts facility-only tables through the tenant\'s facilities', async () => {
      const client = buildPrismaStub({
        rowsByTable: { stock_movement: 7 },
        facilityIds: ['facility-a'],
      });

      const violations = await findTenantOperationalRows('tenant-1', { client });

      expect(violations).toEqual([
        { table: 'stock_movement', rows: 7, scope: 'facility_id' },
      ]);
    });

    it('reports zero for facility-only tables when the tenant has no facility', async () => {
      const client = buildPrismaStub({
        rowsByTable: { stock_movement: 7 },
        facilityIds: [],
      });

      await expect(findTenantOperationalRows('tenant-1', { client })).resolves.toEqual([]);
    });

    it('requires a tenant id', async () => {
      const client = buildPrismaStub();

      await expect(findTenantOperationalRows('', { client })).rejects.toThrow(
        /requires a tenant id/
      );
    });
  });

  describe('assertTenantHasNoOperationalData', () => {
    it('resolves for a freshly created tenant', async () => {
      const client = buildPrismaStub();

      await expect(
        assertTenantHasNoOperationalData('tenant-1', { client })
      ).resolves.toBeUndefined();
    });

    it('throws loudly and names the offending tables', async () => {
      const client = buildPrismaStub({ rowsByTable: { patient: 2, payment: 5 } });

      await expect(
        assertTenantHasNoOperationalData('tenant-1', { client })
      ).rejects.toThrow(/must contain no operational data.*payment=5.*patient=2/);
    });

    it('attaches the violations to the error for callers to report', async () => {
      const client = buildPrismaStub({ rowsByTable: { patient: 2 } });

      const error = await assertTenantHasNoOperationalData('tenant-1', { client }).catch(
        (thrown) => thrown
      );

      expect(error.violations).toEqual([
        { table: 'patient', rows: 2, scope: 'tenant_id' },
      ]);
    });

    it('uses the supplied context label in the message', async () => {
      const client = buildPrismaStub({ rowsByTable: { patient: 1 } });

      await expect(
        assertTenantHasNoOperationalData('tenant-1', { client, context: 'onboarding e2e' })
      ).rejects.toThrow(/^onboarding e2e:/);
    });
  });
});
