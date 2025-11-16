import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '../../..');
const defaultMonitoringConfig = path.join(repoRoot, 'config', 'monitoring.config.json');
const defaultProjectConfig = path.join(repoRoot, 'config', 'project.config.json');

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Config file not found: ${filePath}`);
  }
  const raw = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(raw);
}

export function loadProjectConfig(customPath) {
  const target = customPath || process.env.PROJECT_CONFIG_PATH || defaultProjectConfig;
  return readJson(path.resolve(target));
}

export function loadMonitoringConfig(customPath) {
  const target = customPath || process.env.MONITORING_CONFIG_PATH || defaultMonitoringConfig;
  return readJson(path.resolve(target));
}
