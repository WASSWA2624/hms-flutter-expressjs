jest.mock('@middlewares/auth.middleware', () => ({
  authenticate: () => (req, _res, next) => {
    req.user = { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1', roles: ['PHARMACIST'] };
    next();
  },
  authorize: () => (_req, _res, next) => next()}));
jest.mock('@controllers/pharmacy-workspace/pharmacy-workspace.controller', () =>
  new Proxy(
    {},
    {
      get: (_target, property) => {
        if (property === '__esModule' || property === 'then') return undefined;
        return (req, res) =>
          res.status(200).json({
            handler: String(property),
            body: req.body,
            file: req.file ? { originalname: req.file.originalname, size: req.file.size } : null});
      }}
  )
);

const express = require('express');
const request = require('supertest');
const router = require('@routes/pharmacy-workspace/pharmacy-workspace.routes');

const buildApp = () => {
  const app = express();
  app.use('/pharmacy', router);
  app.use((error, _req, res, _next) =>
    res.status(error.statusCode || (error.name === 'ZodError' ? 400 : 500)).json({
      message: error.message}));
  return app;
};

describe('pharmacy drug import routes', () => {
  it('accepts a multipart upload and validates commit fields', async () => {
    const response = await request(buildApp())
      .post('/pharmacy/drugs/import/commit')
      .field('source', 'medic_erp')
      .field('plan_hash', 'c'.repeat(64))
      .field('decisions', JSON.stringify([{ key: 'a|b', action: 'SKIP' }]))
      .field('confirm_review', 'true')
      .attach('file', Buffer.from('xlsx-bytes'), 'stock.xlsx');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      handler: 'commitDrugImport',
      body: {
        source: 'MEDIC_ERP',
        plan_hash: 'c'.repeat(64),
        decisions: [{ key: 'a|b', action: 'SKIP' }],
        confirm_review: true},
      file: { originalname: 'stock.xlsx', size: 10 }});
  });

  it('routes previews to the preview handler', async () => {
    const response = await request(buildApp())
      .post('/pharmacy/drugs/import/preview')
      .field('source', 'MEDIC_ERP')
      .attach('file', Buffer.from('xlsx'), 'stock.xlsx');

    expect(response.status).toBe(200);
    expect(response.body.handler).toBe('previewDrugImport');
  });

  it('accepts large files and decision payloads beyond multer defaults', async () => {
    const decisions = Array.from({ length: 30000 }, (_, index) => ({
      key: `imported product ${index}|brand ${index}`,
      action: 'SKIP'}));
    const response = await request(buildApp())
      .post('/pharmacy/drugs/import/commit')
      .field('source', 'MEDIC_ERP')
      .field('plan_hash', 'd'.repeat(64))
      .field('decisions', JSON.stringify(decisions))
      .attach('file', Buffer.alloc(6 * 1024 * 1024), 'stock.xlsx');

    expect(response.status).toBe(200);
    expect(response.body.body.decisions).toHaveLength(30000);
    expect(response.body.file.size).toBe(6 * 1024 * 1024);
  });

  it('turns misnamed uploads into a localized 400', async () => {
    const response = await request(buildApp())
      .post('/pharmacy/drugs/import/preview')
      .field('source', 'MEDIC_ERP')
      .attach('upload', Buffer.from('x'), 'stock.xlsx');

    expect(response.status).toBe(400);
    expect(response.body.message).toBe('errors.pharmacy_drug_import.invalid_file');
  });

  it('rejects commits without a valid plan hash', async () => {
    const response = await request(buildApp())
      .post('/pharmacy/drugs/import/commit')
      .field('source', 'MEDIC_ERP')
      .field('plan_hash', 'nope')
      .attach('file', Buffer.from('x'), 'stock.xlsx');

    expect(response.status).toBe(400);
  });
});
