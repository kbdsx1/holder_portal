import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './main.css';
import '@solana/wallet-adapter-react-ui/styles.css';
import { projectConfig } from './config/projectConfig.js';
import { applyBranding } from './utils/branding.js';

applyBranding(projectConfig);

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
