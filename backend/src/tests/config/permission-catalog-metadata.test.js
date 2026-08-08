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
  });

  it('builds friendly role labels and descriptions', () => {
    expect(getRoleMetadata('DOCTOR')).toEqual({
      displayName: 'Doctor',
      description: 'Licensed physician with clinical documentation and order privileges.'});
    expect(getRoleMetadata('ATTENDING_PHYSICIAN')).toEqual({
      displayName: 'Attending Physician',
      description: 'Senior physician responsible for supervising clinical care.'});
  });
});
