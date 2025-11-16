import { loadProjectConfig } from '../../config/project.js';

const project = loadProjectConfig();
const collectionConfigs = project.collections || [];
const countColumns = project.collectionCountColumns || {};

export function getCollectionConfigs() {
  return collectionConfigs;
}

export function getCollectionBySymbol(symbol) {
  if (!symbol) return undefined;
  return collectionConfigs.find((collection) => collection.symbol?.toUpperCase() === symbol.toUpperCase());
}

export function getCollectionCountColumn(symbol) {
  if (!symbol) return undefined;
  return countColumns[symbol.toUpperCase()];
}
