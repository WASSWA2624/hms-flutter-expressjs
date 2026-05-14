const path = require('path');
const SwaggerParser = require('@apidevtools/swagger-parser');

const specPath = path.resolve(__dirname, '..', 'docs', 'api', 'v1', 'openapi.yaml');

const main = async () => {
  try {
    const api = await SwaggerParser.validate(specPath);
    console.log(`[openapi] validated ${api.info.title} ${api.info.version}`);
  } catch (error) {
    console.error(`[openapi] validation failed: ${error.message}`);
    process.exit(1);
  }
};

void main();
