import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  root: path.resolve(__dirname),
  server: {
    port: Number(process.env.FRONTEND_PORT) || 5173,
    fs: {
      allow: [
        path.resolve(__dirname),
        path.resolve(__dirname, '../../config')
      ]
    }
  },
  envDir: path.resolve(__dirname, '../../config'),
  build: {
    outDir: 'dist'
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@config': path.resolve(__dirname, '../../config')
    }
  }
});
