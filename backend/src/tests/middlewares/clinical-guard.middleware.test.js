const {
  requireClinicalDeletePrivilege,
} = require('@middlewares/clinical-guard.middleware');

describe('requireClinicalDeletePrivilege', () => {
  const run = (user) =>
    new Promise((resolve) => {
      const middleware = requireClinicalDeletePrivilege();
      middleware({ user }, {}, (error) => resolve(error || null));
    });

  it('allows facility admins to delete', async () => {
    await expect(run({ roles: ['FACILITY_ADMIN'] })).resolves.toBeNull();
  });

  it('blocks doctors without an admin role', async () => {
    const error = await run({ roles: ['DOCTOR'] });
    expect(error).toMatchObject({
      message: 'errors.auth.insufficient_permissions',
      statusCode: 403,
    });
  });

  it('allows doctors who also have an admin role', async () => {
    await expect(
      run({ roles: ['DOCTOR', 'FACILITY_ADMIN'] })
    ).resolves.toBeNull();
  });
});
