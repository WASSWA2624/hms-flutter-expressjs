/**
 * Module Alias Registration Utility
 * 
 * Registers module-scoped aliases (@controllers/*, @services/*, etc.) for runtime resolution
 * These aliases allow imports like:
 * - @controllers/user/UserController → src/modules/user/controllers/UserController.js
 * - @services/user/UserService → src/modules/user/services/UserService.js
 * 
 * Per import-aliases.mdc: Module-scoped aliases must be registered at runtime via module-alias
 */

const path = require('path');
const fs = require('fs');
const moduleAlias = require('module-alias');

/**
 * Register module-scoped aliases for a specific module
 * 
 * @param {string} moduleName - The module name (e.g., 'user', 'product')
 * @throws {Error} If module directory doesn't exist
 */
const registerModuleAliases = (moduleName) => {
  const modulesPath = path.join(__dirname, '..', '..', 'modules');
  const modulePath = path.join(modulesPath, moduleName);
  
  // Verify module directory exists
  if (!fs.existsSync(modulePath)) {
    throw new Error(`Module directory does not exist: ${modulePath}`);
  }
  
  // Register aliases for this module
  const aliases = {
    [`@controllers/${moduleName}`]: path.join(modulePath, 'controllers'),
    [`@services/${moduleName}`]: path.join(modulePath, 'services'),
    [`@repositories/${moduleName}`]: path.join(modulePath, 'repositories'),
    [`@validations/${moduleName}`]: path.join(modulePath, 'schemas'),
    [`@routes/${moduleName}`]: path.join(modulePath, 'routes')
  };
  try {
    moduleAlias.addAliases(aliases);
  } catch (err) {
    throw err;
  }
};

/**
 * Register aliases for all existing modules
 * Scans src/modules/ directory and registers aliases for each module found
 * 
 * This is called automatically on server startup to register aliases for all existing modules
 */
const registerAllModuleAliases = () => {
  const modulesPath = path.join(__dirname, '..', '..', 'modules');
  
  // Check if modules directory exists
  if (!fs.existsSync(modulesPath)) {
    return; // No modules yet, nothing to register
  }
  
  // Read all directories in modules folder
  const modules = fs.readdirSync(modulesPath, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);
  // Register aliases for each module
  modules.forEach(moduleName => {
    try {
      registerModuleAliases(moduleName);
    } catch (err) {
      // Log error but don't throw - allow server to start even if some modules have issues
      console.warn(`Warning: Failed to register aliases for module '${moduleName}':`, err.message);
    }
  });
};

module.exports = {
  registerModuleAliases,
  registerAllModuleAliases
};

