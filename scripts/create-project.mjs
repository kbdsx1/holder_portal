#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import readline from 'readline/promises';
import { stdin as input, stdout as output } from 'process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const configPath = path.join(repoRoot, 'config', 'project.config.json');

if (!fs.existsSync(configPath)) {
  console.error('Missing config/project.config.json template.');
  process.exit(1);
}

const baseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const rl = readline.createInterface({ input, output });

const ask = async (question, defaultValue = '') => {
  const prompt = defaultValue ? `${question} [${defaultValue}]: ` : `${question}: `;
  const value = (await rl.question(prompt)).trim();
  return value || defaultValue;
};

console.log('Create a new project configuration based on project.config.json');
const slug = await ask('Project slug', baseConfig.project.slug || 'new-project');
const name = await ask('Project name', baseConfig.project.name || 'New Project');
const description = await ask('Description', baseConfig.project.description || 'Holder verification + rewards');
const primaryColor = await ask('Primary color hex', baseConfig.project.primaryColor || '#111111');
const accentColor = await ask('Accent color hex', baseConfig.project.accentColor || '#00FFB2');
const guildId = await ask('Discord guild ID', baseConfig.discord.guildId || '');
const holderRoleId = await ask('Default holder role ID', baseConfig.discord.holderRoleId || '');

await rl.close();

const projectConfig = {
  ...baseConfig,
  project: {
    ...baseConfig.project,
    slug,
    name,
    description,
    primaryColor,
    accentColor
  },
  discord: {
    ...baseConfig.discord,
    guildId,
    holderRoleId
  }
};

const outPath = path.join(repoRoot, 'config', `${slug}.config.json`);
fs.writeFileSync(outPath, JSON.stringify(projectConfig, null, 2));
console.log(`Created ${path.relative(repoRoot, outPath)}`);
console.log('Update the remaining IDs (roles, collections, rewards) manually, then set PROJECT_CONFIG_PATH before starting services.');
