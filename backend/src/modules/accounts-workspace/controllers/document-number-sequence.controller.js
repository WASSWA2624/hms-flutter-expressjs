/**
 * Document number sequence controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Document Numbering. Business rules,
 * scope, and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const documentSequenceService = require('@services/accounts-workspace/document-number-sequence.service');

const listDocumentSequences = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await documentSequenceService.listDocumentSequences(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.document_sequence.list.success',
    result.items,
    result.pagination
  );
});

const getDocumentSequence = asyncHandler(async (req, res) => {
  const data = await documentSequenceService.getDocumentSequence(
    req.params.documentSequenceIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.document_sequence.get.success',
    data
  );
});

const createDocumentSequence = asyncHandler(async (req, res) => {
  const data = await documentSequenceService.createDocumentSequence(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.document_sequence.create.success',
    data
  );
});

const updateDocumentSequence = asyncHandler(async (req, res) => {
  const data = await documentSequenceService.updateDocumentSequence(
    req.params.documentSequenceIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.document_sequence.update.success',
    data
  );
});

const applyDocumentSequenceAction = asyncHandler(async (req, res) => {
  const data = await documentSequenceService.applyDocumentSequenceAction(
    req.params.documentSequenceIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.document_sequence.action.success',
    data
  );
});

module.exports = {
  listDocumentSequences,
  getDocumentSequence,
  createDocumentSequence,
  updateDocumentSequence,
  applyDocumentSequenceAction,
};
