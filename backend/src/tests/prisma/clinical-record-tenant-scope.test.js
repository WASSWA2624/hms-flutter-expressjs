/**
 * Every table holding patient data must carry its own tenant_id.
 *
 * The Prisma tenant guard scopes a query only when the model has a `tenant_id`
 * column - `tenant-guard.js` returns the query untouched otherwise. A clinical
 * table reachable only through `patient`, `encounter` or `admission` therefore
 * sits outside the guard entirely, and isolation falls to every service
 * remembering a join filter.
 *
 * That is exactly how twenty-two tables leaked across tenants in production: a
 * tenant owning zero patients could read all 1001 radiology orders, 1002 lab
 * orders and 1000 theatre cases belonging to another tenant.
 *
 * This suite fails if a new clinical table is added without `tenant_id`, so the
 * leak cannot be reintroduced by a later migration.
 */

const { Prisma } = require('.prisma/client');

const MODELS = Prisma.dmmf.datamodel.models;

const hasField = (model, field) => model.fields.some((entry) => entry.name === field);

/** Foreign keys that make a table part of a patient's clinical record. */
const CLINICAL_PARENTS = ['patient_id', 'encounter_id', 'admission_id', 'visit_id'];

const clinicalModels = () =>
  MODELS.filter((model) => CLINICAL_PARENTS.some((fk) => hasField(model, fk)));

describe('clinical record tenant scoping', () => {
  it('gives every clinical table its own tenant_id', () => {
    const unscoped = clinicalModels()
      .filter((model) => !hasField(model, 'tenant_id'))
      .map((model) => model.name)
      .sort();

    expect(unscoped).toEqual([]);
  });

  it('covers a meaningful number of clinical tables', () => {
    // Guards the assertion above from passing vacuously if the parent-key
    // convention ever changes and the filter stops matching anything.
    expect(clinicalModels().length).toBeGreaterThan(20);
  });

  it.each([
    'lab_order',
    'radiology_order',
    'theatre_case',
    'follow_up',
    'vital_sign',
    'clinical_note',
    'diagnosis',
    'procedure',
    'nursing_note',
    'ward_round',
    'medication_administration',
    'discharge_summary',
  ])('%s is tenant-scoped', (name) => {
    const model = MODELS.find((entry) => entry.name === name);

    expect(model).toBeDefined();
    expect(hasField(model, 'tenant_id')).toBe(true);
  });

  it('indexes tenant_id on the tables the guard filters', () => {
    // Without an index the injected tenant constraint scans; these tables hold
    // the highest row counts in the schema.
    const fs = require('fs');
    const path = require('path');
    const schema = fs.readFileSync(
      path.join(__dirname, '..', '..', '..', 'prisma', 'schema.prisma'),
      'utf8'
    );

    for (const name of ['lab_order', 'radiology_order', 'theatre_case', 'vital_sign']) {
      const block = schema.slice(
        schema.indexOf(`model ${name} {`),
        schema.indexOf('\n}', schema.indexOf(`model ${name} {`))
      );
      expect(block).toContain('@@index([tenant_id])');
    }
  });
});
