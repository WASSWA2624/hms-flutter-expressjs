const { seedVolumeExtendedPack } = require('../../../scripts/seeders/seed-volume-extended-pack');

describe('seed-volume-extended-pack', () => {
  it('skips when target count is zero', async () => {
    const result = await seedVolumeExtendedPack({}, 0, {
      volumeSummary: { skipped: false },
    });

    expect(result).toEqual({
      skipped: true,
      reason: 'target_count_zero',
      created: {},
    });
  });

  it('skips when volume pack was skipped', async () => {
    const result = await seedVolumeExtendedPack({}, 1000, {
      volumeSummary: { skipped: true, reason: 'target_count_zero' },
    });

    expect(result).toEqual({
      skipped: true,
      reason: 'volume_pack_skipped',
      created: {},
    });
  });
});
