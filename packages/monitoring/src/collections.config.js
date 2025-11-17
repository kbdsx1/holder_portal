import { loadProjectConfig } from './config.js';

const project = loadProjectConfig();

const collections = (project.collections || []).map((collection) => ({
  name: collection.friendlyName || collection.symbol,
  symbol: collection.symbol, // Store the actual symbol for database queries
  address: collection.collectionAddress || collection.symbol,
  groupValue: collection.collectionAddress || collection.symbol,
  minBalance: collection.minBalance || 1
}));

export default collections;
