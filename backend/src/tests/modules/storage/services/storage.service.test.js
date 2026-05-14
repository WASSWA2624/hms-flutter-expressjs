jest.mock('fs', () => ({
  promises: {
    writeFile: jest.fn(async () => {}),
    stat: jest.fn(async () => ({ size: 12 })),
    mkdir: jest.fn(async () => {}),
    unlink: jest.fn(async () => {}),
    access: jest.fn(async () => {}),
    readFile: jest.fn(async () => Buffer.from('BMP1mockdata'))
  },
  createWriteStream: jest.fn(() => ({
    on: jest.fn()
  }))
}));

jest.mock('@lib/crypto', () => ({
  encryptBuffer: jest.fn((buffer) => Buffer.concat([Buffer.from('BMP1'), buffer])),
  decryptBuffer: jest.fn(() => Buffer.from('decrypted'))
}));

jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn()
  }
}));

const { createLocalStorageService, sanitizeFilename } = require('@lib/storage');
const { createLocalStorageService: createLocalStorageServiceActual } = jest.requireActual('@lib/storage/local-storage.service');

beforeEach(() => {
  if (createLocalStorageService && createLocalStorageService.mock) {
    createLocalStorageService.mockImplementation((...args) => createLocalStorageServiceActual(...args));
  }
});

describe('StorageService (local)', () => {
  test('uploads buffer and returns metadata', async () => {
    const fs = require('fs').promises;
    fs.writeFile.mockResolvedValue();
    fs.stat.mockResolvedValue({ size: 12 });

    const storage = createLocalStorageService('uploads');
    const result = await storage.upload(Buffer.from('file'), '../unsafe.txt', { encrypt: true, mimeType: 'text/plain' });

    expect(result.path).toBeDefined();
    expect(result.size).toBe(12);
    expect(result.encrypted).toBe(true);
  });

  test('sanitizes filenames to prevent traversal', () => {
    const sanitized = sanitizeFilename('../secret.txt');
    expect(sanitized.includes('..')).toBe(false);
    expect(sanitized.includes('/')).toBe(false);
  });

  test('downloads encrypted buffer via decryptBuffer', async () => {
    const fs = require('fs').promises;
    fs.readFile.mockResolvedValue(Buffer.from('BMP1mockdata'));

    const { decryptBuffer } = require('@lib/crypto');
    decryptBuffer.mockReturnValue(Buffer.from('decrypted'));
    const storage = createLocalStorageService('uploads');
    const data = await storage.download('file.txt');

    expect(decryptBuffer).toHaveBeenCalled();
    expect(data.toString()).toBe('decrypted');
  });
});

describe('StorageService factory', () => {
  test('selects local provider when STORAGE_PROVIDER=local', () => {
    jest.resetModules();
    const { setEnvForTests } = require('@config/env');
    setEnvForTests({
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      NODE_ENV: 'test',
      CORS_ORIGINS: 'http://localhost:3000',
      STORAGE_PROVIDER: 'local'
    });

    const createLocalStorageServiceMock = jest.fn(() => ({ provider: 'local' }));
    const createS3StorageServiceMock = jest.fn(() => ({ provider: 's3' }));

    jest.doMock('@lib/storage', () => ({
      createLocalStorageService: createLocalStorageServiceMock,
      createS3StorageService: createS3StorageServiceMock
    }));

    const { createStorageService } = require('@lib/storage/factory');
    const storage = createStorageService();

    expect(storage.provider).toBe('local');
    expect(createLocalStorageServiceMock).toHaveBeenCalled();
    expect(createS3StorageServiceMock).not.toHaveBeenCalled();
  });

  test('selects s3 provider when STORAGE_PROVIDER=s3', () => {
    jest.resetModules();
    const { setEnvForTests } = require('@config/env');
    setEnvForTests({
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
      NODE_ENV: 'test',
      CORS_ORIGINS: 'http://localhost:3000',
      STORAGE_PROVIDER: 's3',
      AWS_ACCESS_KEY_ID: 'test',
      AWS_SECRET_ACCESS_KEY: 'test',
      AWS_REGION: 'us-east-1',
      AWS_S3_BUCKET: 'bucket'
    });

    const createLocalStorageServiceMock = jest.fn(() => ({ provider: 'local' }));
    const createS3StorageServiceMock = jest.fn(() => ({ provider: 's3' }));

    jest.doMock('@lib/storage', () => ({
      createLocalStorageService: createLocalStorageServiceMock,
      createS3StorageService: createS3StorageServiceMock
    }));

    const { createStorageService } = require('@lib/storage/factory');
    const storage = createStorageService();

    expect(storage.provider).toBe('s3');
    expect(createS3StorageServiceMock).toHaveBeenCalled();
    expect(createLocalStorageServiceMock).not.toHaveBeenCalled();
  });
});
