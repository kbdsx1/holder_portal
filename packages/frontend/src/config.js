import { projectConfig } from './config/projectConfig.js';

const isDev = import.meta.env.DEV;

// In production, always use window.location.origin (same domain for API and frontend on Vercel)
// In dev, use environment variable or fallback to localhost
const defaultApi = import.meta.env.VITE_API_BASE_URL || 
  (isDev 
    ? (projectConfig.frontend?.apiBaseUrl || 'http://localhost:3001')
    : (typeof window !== 'undefined' ? window.location.origin : ''));

const defaultApp = import.meta.env.VITE_FRONTEND_URL || 
  (isDev 
    ? (projectConfig.frontend?.appUrl || 'http://localhost:5173')
    : (typeof window !== 'undefined' ? window.location.origin : ''));

export const API_BASE_URL = defaultApi;
export const FRONTEND_URL = defaultApp;
export const SOLANA_RPC_URL = import.meta.env.VITE_SOLANA_RPC_URL || projectConfig.rewards?.rpcUrl || 'https://api.mainnet-beta.solana.com';
export const TOKEN_SYMBOL = projectConfig.rewards?.currency || 'TOKEN';
export const PROJECT_CONFIG = projectConfig;
