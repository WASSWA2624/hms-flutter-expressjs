/**
 * Error utilities barrel export
 * 
 * @description Centralized exports for error classes and handlers. Allows importing `@lib/errors`.
 */

const AppError = require('@lib/errors/AppError');
const HttpError = require('@lib/errors/HttpError');
const handleApiError = require('@lib/errors/handleApiError');

module.exports = {
  AppError,
  HttpError,
  handleApiError
};

