# CannaSolz White-Label Setup

This repo packages backend APIs, a starter React UI, and monitoring/cron scripts so other projects can ship holder verification + Discord automation quickly.

## Prerequisites
- Node.js 18+
- pnpm or npm 9+
- Postgres database with the original schema
- Solana keypair (treasury) and RPC endpoint
- Discord app + bot configured with OAuth redirect `https://YOUR_DOMAIN/api/auth/discord/callback`

## Initial Steps
1. **Install dependencies**
   ```bash
   npm install
   ```
2. **Copy configs**
   - Update `config/project.config.json` with your branding, guild + role IDs, collection symbols, and reward settings.
   - Optionally generate per-customer variants via `npm run create-project` (see `scripts/create-project.mjs`).
3. **Bootstrap env files**
   ```bash
   npm run bootstrap
   ```
   Fill in every prompt; `.env` files will be placed under each package.
4. **Database access**
   - Ensure `POSTGRES_URL` points at a database populated with the required tables and functions.
5. **Run services locally**
   ```bash
   npm run dev
   ```
   This launches backend (Express) and frontend (Vite).
6. **Monitoring jobs**
   ```bash
   npm run jobs
   ```
   or run scripts individually from `packages/monitoring`.

## Deployment Cheatsheet
- **Backend**: Docker, Railway, Render, or any Node host. Provide the same `.env` values.
- **Frontend**: Static host (Vercel, Netlify, Cloudflare Pages) using `npm --workspace packages/frontend run build`.
- **Monitoring**: Railway worker, AWS ECS/Fargate, or PM2 box running `packages/monitoring/src/cron.js` with the same env vars + `config/monitoring.config.json`.

See `BRANDING.md`, `OPERATIONS.md`, and `UPGRADE.md` for deeper guidance.
