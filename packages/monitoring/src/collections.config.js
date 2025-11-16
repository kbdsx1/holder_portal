import { loadProjectConfig } from './config.js';

const project = loadProjectConfig();

const collections = (project.collections || []).map((collection) => ({
  name: collection.friendlyName || collection.symbol,
  address: collection.collectionAddress || collection.symbol,
  groupValue: collection.collectionAddress || collection.symbol,
  minBalance: collection.minBalance || 1
}));

export default collections;
