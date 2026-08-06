const {
  pickAnchor,
  requiredForeignKeys,
  seedFillerPack,
} = require('../../../scripts/seeders/seed-filler-pack');

describe('seed-filler-pack', () => {
  it('resolves singular and plural anchor keys', () => {
    expect(pickAnchor({ tenant_id: 't1' }, 'tenant_id', 1)).toBe('t1');
    expect(pickAnchor({ patient_ids: ['p1', 'p2'] }, 'patient_id', 1)).toBe('p2');
    expect(pickAnchor({}, 'shift_id', 1)).toBeUndefined();
  });

  it('skips models with unsatisfied required foreign keys', async () => {
    const upsert = jest.fn();
    const ctx = {
      prisma: {
        orphan_model: {
          count: jest.fn(async () => 0),
          upsert: jest.fn(),
        },
      },
      schema: {
        enumValuesByName: new Map(),
        modelsByName: new Map([
          [
            'orphan_model',
            {
              fields: [
                { name: 'id', kind: 'scalar', isId: true },
                { name: 'shift_id', kind: 'scalar', isOptional: false, hasDefault: false },
                { name: 'title', kind: 'scalar', type: 'String', isOptional: false, hasDefault: false },
              ],
              fieldByName: new Map([
                ['id', { name: 'id', isId: true }],
                ['shift_id', { name: 'shift_id', kind: 'scalar', isOptional: false, hasDefault: false }],
                ['title', { name: 'title', kind: 'scalar', type: 'String', isOptional: false, hasDefault: false }],
              ]),
            },
          ],
        ]),
      },
      upsert,
      date: jest.fn(() => new Date()),
    };

    const result = await seedFillerPack(ctx, 5, { tenant_id: 't1' });
    expect(result.skipped_models).toBe(1);
    expect(upsert).not.toHaveBeenCalled();
  });

  it('fills eligible models up to the target count with anchors', async () => {
    const upsert = jest.fn(async (model, key, data) => ({ id: key, ...data }));
    const count = jest.fn(async () => 2);
    const ctx = {
      prisma: {
        note_pad: {
          count,
          upsert: jest.fn(),
        },
      },
      schema: {
        enumValuesByName: new Map(),
        modelsByName: new Map([
          [
            'note_pad',
            {
              fields: [
                { name: 'id', kind: 'scalar', isId: true },
                { name: 'tenant_id', kind: 'scalar', isOptional: false, hasDefault: false },
                {
                  name: 'title',
                  kind: 'scalar',
                  type: 'String',
                  isOptional: false,
                  hasDefault: false,
                },
                { name: 'deleted_at', kind: 'scalar', isOptional: true },
              ],
              fieldByName: new Map([
                ['id', { name: 'id', isId: true }],
                ['tenant_id', { name: 'tenant_id', kind: 'scalar', isOptional: false, hasDefault: false }],
                ['title', { name: 'title', kind: 'scalar', type: 'String', isOptional: false, hasDefault: false }],
                ['deleted_at', { name: 'deleted_at', isOptional: true }],
              ]),
            },
          ],
        ]),
      },
      upsert,
      date: jest.fn(() => new Date()),
    };

    const result = await seedFillerPack(ctx, 5, { tenant_id: 'tenant-1' });
    expect(result.created).toBe(3);
    expect(upsert).toHaveBeenCalledTimes(3);
    expect(upsert.mock.calls[0][2].tenant_id).toBe('tenant-1');
  });

  it('detects required foreign keys from schema metadata', () => {
    const keys = requiredForeignKeys({
      fields: [
        { name: 'tenant_id', kind: 'scalar', isOptional: false, hasDefault: false },
        { name: 'optional_ref_id', kind: 'scalar', isOptional: true, hasDefault: false },
        { name: 'title', kind: 'scalar', isOptional: false, hasDefault: false },
      ],
    });
    expect(keys.map((field) => field.name)).toEqual(['tenant_id']);
  });
});
