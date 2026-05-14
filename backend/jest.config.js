module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/src/tests/**/*.test.js'],
  testPathIgnorePatterns: ['/node_modules/'],
  moduleNameMapper: {
    '^@app/(.*)$': '<rootDir>/src/app/$1',
    '^@lib/(.*)$': '<rootDir>/src/lib/$1',
    '^@config/(.*)$': '<rootDir>/src/config/$1',
    '^@middlewares/(.*)$': '<rootDir>/src/middlewares/$1',
    '^@logs/(.*)$': '<rootDir>/logs/$1',
    '^@websockets/(.*)$': '<rootDir>/src/websockets/$1',
    '^@prisma/client/runtime/(.*)$': '<rootDir>/node_modules/@prisma/client/runtime/$1',
    '^@prisma/client/runtime$': '<rootDir>/node_modules/@prisma/client/runtime',
    '^@prisma/client$': '<rootDir>/src/prisma/client.js',
    '^@modules/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/$2',
    '^@controllers/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/controllers/$2',
    '^@services/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/services/$2',
    '^@repositories/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/repositories/$2',
    '^@validations/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/schemas/$2',
    '^@routes/([^/]+)/(.*)$': '<rootDir>/src/modules/$1/routes/$2'
  },
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/tests/**',
    '!src/generated/**',
    '!src/server.js',
    '!src/app/index.js'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  setupFilesAfterEnv: ['<rootDir>/src/tests/setup.js'],
  coverageThreshold: {
    global: {
      statements: 67,
      branches: 47,
      functions: 69,
      lines: 69
    }
  },
  verbose: false,
  testTimeout: 10000,
  clearMocks: true,
  resetMocks: false,
  restoreMocks: true
};

