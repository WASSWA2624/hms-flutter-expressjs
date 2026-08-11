const {
  getPermissionMetadata,
  getRoleMetadata} = require('@config/permission-catalog-metadata');

describe('permission-catalog-metadata', () => {
  it('builds friendly permission labels and descriptions', () => {
    expect(getPermissionMetadata('patient:read')).toEqual({
      displayName: 'Patient — Read',
      description: 'Allows read access within patient.'});
    expect(getPermissionMetadata('platform:admin')).toEqual({
      displayName: 'Platform — Admin',
      description: 'Full platform administration across tenants and global settings.'});
    expect(getPermissionMetadata('accounts:read')).toEqual({
      displayName: 'Accounts — Read',
      description:
        'Open Accounts workspace and read books data (queues, GL, patient ledgers, chart, periods).',
    });
    expect(getPermissionMetadata('accounts:write')).toEqual({
      displayName: 'Accounts — Write',
      description:
        'Create/post journals, reverse/void/send, open/close periods, and mutate chart of accounts.',
    });
  });

  it('builds friendly role labels and descriptions', () => {
    expect(getRoleMetadata('DOCTOR')).toEqual({
      displayName: 'Doctor',
      description: 'Licensed physician with clinical documentation and order privileges.'});
    expect(getRoleMetadata('ATTENDING_PHYSICIAN')).toEqual({
      displayName: 'Attending',
      description: 'Senior physician responsible for supervising clinical care.'});
    expect(getRoleMetadata('ACCOUNTANT')).toEqual({
      displayName: 'Accountant',
      description:
        'Finance staff managing the Accounts books desk (journals, GL, patient ledgers, chart, period close), reconciliation, and reporting.',
    });
    expect(getRoleMetadata('HR').description).not.toMatch(/Accounts/i);
    expect(getRoleMetadata('HR_STAFF').description).not.toMatch(/Accounts/i);
  });
});
