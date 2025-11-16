import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const defaultConfigPath = path.resolve(__dirname, '../../../..', 'config/project.config.json');

let cachedConfig = null;
let cachedPath = null;

function readConfig(configPath) {
  const filePath = configPath || process.env.PROJECT_CONFIG_PATH || defaultConfigPath;
  const resolvedPath = path.resolve(filePath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`Project config not found at ${resolvedPath}`);
  }

  const contents = fs.readFileSync(resolvedPath, 'utf8');
  const parsed = JSON.parse(contents);
  return { parsed, resolvedPath };
}

export function loadProjectConfig(force = false) {
  if (!force && cachedConfig && cachedPath === (process.env.PROJECT_CONFIG_PATH || defaultConfigPath)) {
    return cachedConfig;
  }

  const { parsed, resolvedPath } = readConfig();
  cachedConfig = parsed;
  cachedPath = resolvedPath;
  return cachedConfig;
}

export function getProjectConfigValue(keyPath, fallback = undefined) {
  const config = loadProjectConfig();
  const segments = keyPath.split('.');
  let current = config;

  for (const segment of segments) {
    if (current && Object.prototype.hasOwnProperty.call(current, segment)) {
      current = current[segment];
    } else {
      return fallback;
    }
  }

  return current;
}
