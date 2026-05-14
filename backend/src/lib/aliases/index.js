/**
 * Aliases Module Barrel Export
 *
 * Centralized exports for alias registration helpers.
 * Allows importing via @lib/aliases per import-aliases.mdc.
 */

const {
  registerModuleAliases,
  registerAllModuleAliases
} = require('@lib/aliases/registerModuleAliases');

module.exports = {
  registerModuleAliases,
  registerAllModuleAliases
};
