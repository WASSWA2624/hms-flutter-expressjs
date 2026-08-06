const {
  DEFAULT_DEMO_VOLUME_TARGET,
  MIN_APPLICABLE_VOLUME,
  resolveSecondaryTarget,
  resolveVolumeTargets,
  seedVolumePack,
} = require('../../../scripts/seeders/seed-volume-pack');

describe('seed-volume-pack', () => {
  it('exports default volume constants', () => {
    expect(DEFAULT_DEMO_VOLUME_TARGET).toBe(1000);
    expect(MIN_APPLICABLE_VOLUME).toBe(100);
  });

  it('resolves secondary targets relative to high-traffic volume', () => {
    expect(resolveVolumeTargets(0)).toEqual({ skipped: true, highTraffic: 0, secondary: 0 });
    expect(resolveVolumeTargets(1000)).toEqual({
      skipped: false,
      highTraffic: 1000,
      secondary: 200,
    });
    expect(resolveSecondaryTarget(100)).toBe(100);
    expect(resolveSecondaryTarget(50)).toBe(50);
  });

  it('skips when target count is zero', async () => {
    const result = await seedVolumePack({}, 0, {});
    expect(result).toEqual({
      skipped: true,
      reason: 'target_count_zero',
      targets: { skipped: true, highTraffic: 0, secondary: 0 },
      created: {},
    });
  });

  it('creates status-diverse volume rows for the demo facility', async () => {
    const upserted = [];
    const ctx = {
      upsert: jest.fn(async (model, key, data) => {
        upserted.push({ model, key, data });
        return { id: `${model}-${key}`, ...data, unit: data.unit || 'u' };
      }),
      date: jest.fn((day = 0, minute = 0) => new Date(Date.UTC(2026, 1, 15 + day, 9, minute))),
      hash: jest.fn(() => 'abcdef1234567890'),
    };

    const orgPack = {
      facilities: {
        'demo:main': { id: 'facility-1', tenant_id: 'tenant-1' },
      },
    };
    const accessPack = {
      users: {
        'demo:doctor': { id: 'user-doctor' },
        'demo:nurse': { id: 'user-nurse' },
        'demo:lab': { id: 'user-lab' },
        'demo:radiology': { id: 'user-rad' },
        'demo:pharmacy': { id: 'user-pharm' },
        'demo:billing': { id: 'user-bill' },
        'demo:biomed': { id: 'user-biomed' },
        'demo:reception': { id: 'user-reception' },
      },
    };
    const clinicalCatalogPack = {
      lab: { tests: { 'demo:cbc': { id: 'lab-1', unit: 'x10^9/L' } } },
      radiology: { tests: { 'demo:cxr': { id: 'rad-1' } } },
      pharmacy: {
        drugs: { 'demo:amox': { id: 'drug-1' } },
        inventoryItems: { 'demo:stock': { id: 'inv-1' } },
      },
    };
    const biomedicalPack = { registries: { demo: { id: 'eq-1' } } };
    const mortuaryPack = { deceasedProfiles: { 'demo:external': { id: 'mdp-1' } } };

    const result = await seedVolumePack(ctx, 6, {
      orgPack,
      accessPack,
      clinicalPack: { patients: {} },
      clinicalCatalogPack,
      operationsPack: { inventoryItems: {} },
      biomedicalPack,
      mortuaryPack,
    });

    expect(result.skipped).toBe(false);
    expect(result.created.patients).toBe(6);
    expect(result.created.appointments).toBe(6);
    expect(result.created.encounters).toBe(6);
    expect(upserted.some((entry) => entry.model === 'appointment')).toBe(true);
    expect(upserted.some((entry) => entry.model === 'lab_order')).toBe(true);
    expect(upserted.some((entry) => entry.model === 'pharmacy_order')).toBe(true);
    expect(upserted.some((entry) => entry.model === 'invoice')).toBe(true);
    expect(upserted.some((entry) => entry.model === 'equipment_work_order')).toBe(true);
    expect(upserted.some((entry) => entry.model === 'mortuary_case')).toBe(true);

    const appointmentStatuses = new Set(
      upserted.filter((entry) => entry.model === 'appointment').map((entry) => entry.data.status)
    );
    expect(appointmentStatuses.size).toBeGreaterThan(1);
  });
});
