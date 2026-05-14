jest.mock('@prisma/client', () => ({
  $disconnect: jest.fn().mockResolvedValue(undefined),
  $queryRawUnsafe: jest.fn(),
}));

jest.mock('@config/env', () => ({
  DATABASE_URL: 'mysql://root:root@localhost:3306/hms_db',
}));

jest.mock('mysql2/promise', () => ({
  createConnection: jest.fn(),
}));

const prisma = require('@prisma/client');
const mysql = require('mysql2/promise');
const {
  assertDatabaseConnection,
  formatMissingSchemaArtifactsMessage,
  resolveDatabaseStartupErrorMessage,
} = require('@lib/health/startupDatabaseCheck');

describe('startupDatabaseCheck', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns the nested access denied message when Prisma wraps it', () => {
    const error = new Error('pool timeout: failed to retrieve a connection from pool after 5000ms');
    error.code = 'P2010';
    error.meta = {
      driverAdapterError: {
        cause: {
          message: "Access denied for user 'root'@'localhost' (using password: YES)",
        },
      },
    };

    expect(resolveDatabaseStartupErrorMessage(error)).toBe(
      "Access denied for user 'root'@'localhost' (using password: YES)"
    );
  });

  it('returns the original message when no nested database cause exists', () => {
    const error = new Error('connect ECONNREFUSED 127.0.0.1:3306');

    expect(resolveDatabaseStartupErrorMessage(error)).toBe(
      'connect ECONNREFUSED 127.0.0.1:3306'
    );
  });

  it('passes when the database probe succeeds', async () => {
    prisma.$queryRawUnsafe
      .mockResolvedValueOnce([{ 1: 1 }])
      .mockResolvedValueOnce([
        { table_name: 'user_permission', column_name: 'id' },
        { table_name: 'user_permission', column_name: 'human_friendly_id' },
        { table_name: 'user_permission', column_name: 'user_id' },
        { table_name: 'user_permission', column_name: 'permission_id' },
        { table_name: 'user_permission', column_name: 'created_at' },
        { table_name: 'user_permission', column_name: 'updated_at' },
        { table_name: 'user_permission', column_name: 'deleted_at' },
        { table_name: 'user_permission', column_name: 'version' },
      ]);
    mysql.createConnection.mockResolvedValue({
      query: jest.fn().mockResolvedValue([[{ ok: 1 }], []]),
      end: jest.fn().mockResolvedValue(undefined),
    });

    await expect(assertDatabaseConnection()).resolves.toBe(true);
    expect(prisma.$queryRawUnsafe).toHaveBeenCalledWith('SELECT 1');
    expect(prisma.$disconnect).not.toHaveBeenCalled();
    expect(mysql.createConnection).not.toHaveBeenCalled();
  });

  it('throws an explicit migration-required error when required schema artifacts are missing', async () => {
    prisma.$queryRawUnsafe
      .mockResolvedValueOnce([{ 1: 1 }])
      .mockResolvedValueOnce([]);

    await expect(assertDatabaseConnection()).rejects.toMatchObject({
      message: formatMissingSchemaArtifactsMessage(['table `user_permission`']),
      code: 'SCHEMA_DRIFT_MISSING_ARTIFACTS',
      missingArtifacts: ['table `user_permission`'],
    });
    expect(prisma.$disconnect).toHaveBeenCalledTimes(1);
    expect(mysql.createConnection).not.toHaveBeenCalled();
  });

  it('throws a simplified startup error and disconnects on failure', async () => {
    const error = new Error('pool timeout');
    error.code = 'P2010';
    error.meta = {
      driverAdapterError: {
        cause: {
          message: "Access denied for user 'root'@'localhost' (using password: YES)",
        },
      },
    };
    prisma.$queryRawUnsafe.mockRejectedValue(error);
    mysql.createConnection.mockRejectedValue(
      new Error("Access denied for user 'root'@'localhost' (using password: YES)")
    );

    await expect(assertDatabaseConnection()).rejects.toMatchObject({
      message: "Access denied for user 'root'@'localhost' (using password: YES)",
      code: 'P2010',
    });
    expect(prisma.$disconnect).toHaveBeenCalledTimes(1);
    expect(mysql.createConnection).toHaveBeenCalledTimes(1);
  });
});
