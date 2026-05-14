/**
 * readinessCheck helper tests
 */

const loadReadinessModule = ({
  prismaClient = null,
  mysqlCreateConnectionImpl = null,
} = {}) => {
  jest.resetModules();
  delete globalThis.prisma;

  const warn = jest.fn();
  const error = jest.fn();
  const info = jest.fn();
  const getCurrentISO = jest.fn(() => '2026-02-15T00:00:00.000Z');
  const createConnection =
    mysqlCreateConnectionImpl ||
    jest.fn(async () => {
      throw new Error('connect failed');
    });

  jest.doMock('@lib/logging', () => ({
    logger: { warn, error, info },
  }));
  jest.doMock('@lib/dates', () => ({
    getCurrentISO,
  }));
  jest.doMock('@config/env', () => ({
    DATABASE_URL: 'mysql://demo:demo@localhost:3306/hms_db',
  }));
  jest.doMock('mysql2/promise', () => ({
    createConnection,
  }));

  if (prismaClient) {
    globalThis.prisma = prismaClient;
  }

  const { readinessCheck } = require('@lib/health/readinessCheck');
  return { readinessCheck, warn, createConnection, getCurrentISO };
};

describe('readinessCheck helper', () => {
  afterEach(() => {
    jest.clearAllMocks();
    delete globalThis.prisma;
  });

  it('returns ready from Prisma primary check and skips mysql fallback', async () => {
    const prismaQuery = jest.fn().mockResolvedValue([{ ok: 1 }]);
    const createConnectionMock = jest.fn();
    const { readinessCheck, createConnection } = loadReadinessModule({
      prismaClient: { $queryRaw: prismaQuery },
      mysqlCreateConnectionImpl: createConnectionMock,
    });

    const result = await readinessCheck();

    expect(result).toEqual({
      status: 'ready',
      timestamp: '2026-02-15T00:00:00.000Z',
      checks: { database: 'ok' },
    });
    expect(prismaQuery).toHaveBeenCalledTimes(1);
    expect(createConnection).not.toHaveBeenCalled();
  });

  it('returns ready when Prisma is unavailable and mysql fallback succeeds', async () => {
    const query = jest.fn().mockResolvedValue([[{ ok: 1 }], []]);
    const end = jest.fn().mockResolvedValue(undefined);
    const createConnection = jest.fn().mockResolvedValue({ query, end });

    const { readinessCheck } = loadReadinessModule({
      mysqlCreateConnectionImpl: createConnection,
    });

    const result = await readinessCheck();

    expect(result.status).toBe('ready');
    expect(result.checks.database).toBe('ok');
    expect(createConnection).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledWith('SELECT 1');
    expect(end).toHaveBeenCalledTimes(1);
  });

  it('returns ready when Prisma fails but mysql fallback succeeds', async () => {
    const prismaQuery = jest.fn().mockRejectedValue(new Error('prisma down'));
    const query = jest.fn().mockResolvedValue([[{ ok: 1 }], []]);
    const end = jest.fn().mockResolvedValue(undefined);
    const createConnection = jest.fn().mockResolvedValue({ query, end });
    const { readinessCheck } = loadReadinessModule({
      prismaClient: { $queryRaw: prismaQuery },
      mysqlCreateConnectionImpl: createConnection,
    });

    const result = await readinessCheck();

    expect(result.status).toBe('ready');
    expect(result.checks.database).toBe('ok');
    expect(prismaQuery).toHaveBeenCalledTimes(1);
    expect(createConnection).toHaveBeenCalledTimes(1);
  });

  it('returns not_ready and logs warning when both Prisma and mysql checks fail', async () => {
    const prismaQuery = jest.fn().mockRejectedValue(new Error('prisma down'));
    const createConnection = jest.fn().mockRejectedValue(new Error('mysql down'));
    const { readinessCheck, warn } = loadReadinessModule({
      prismaClient: { $queryRaw: prismaQuery },
      mysqlCreateConnectionImpl: createConnection,
    });

    const result = await readinessCheck();

    expect(result.status).toBe('not_ready');
    expect(result.checks.database).toBe('error');
    expect(warn).toHaveBeenCalledWith(
      'Database readiness check failed',
      expect.objectContaining({ fallback_error: 'mysql down' })
    );
  });

  it('fails over from a hanging Prisma check after the 2-second timeout window', async () => {
    const prismaQuery = jest.fn(() => new Promise(() => {}));
    const createConnection = jest.fn().mockRejectedValue(new Error('mysql down'));
    const { readinessCheck } = loadReadinessModule({
      prismaClient: { $queryRaw: prismaQuery },
      mysqlCreateConnectionImpl: createConnection,
    });

    const startedAt = Date.now();
    const result = await readinessCheck();
    const elapsedMs = Date.now() - startedAt;

    expect(result.status).toBe('not_ready');
    expect(result.checks.database).toBe('error');
    expect(prismaQuery).toHaveBeenCalledTimes(1);
    expect(createConnection).toHaveBeenCalledTimes(1);
    expect(elapsedMs).toBeGreaterThanOrEqual(1900);
    expect(elapsedMs).toBeLessThan(3000);
  });

  it('caches successful readiness checks for ttl window', async () => {
    const prismaQuery = jest.fn().mockResolvedValue([{ ok: 1 }]);
    const { readinessCheck } = loadReadinessModule({
      prismaClient: { $queryRaw: prismaQuery },
    });

    const first = await readinessCheck();
    const second = await readinessCheck();

    expect(first.status).toBe('ready');
    expect(second.status).toBe('ready');
    expect(prismaQuery).toHaveBeenCalledTimes(1);
  });
});
