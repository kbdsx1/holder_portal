# Knuckle Bunny Death Squad (KBDS) Holder Portal

This monorepo packages everything needed to launch a holder portal:

1. **Discord OAuth + wallet verification** with automated role assignment
2. **Sales/listings notification bot** + holder sync cron jobs
3. **Daily reward processing and on-chain claims** with a starter React UI

Use it as a white-label base so new projects can configure their branding, drop in IDs, and deploy quickly.

## Repo Layout

```
config/                     Shared project + monitoring configs
scripts/                    Automation helpers (env bootstrap, project generator)
packages/
  backend/                  Express server wiring the exported API routes
  frontend/                 Vite + React UI shell with Solana wallet adapters
  monitoring/               Cron + Discord bot scripts for sync + rewards jobs
```

## Getting Started

1. `npm install`
2. Update `config/project.config.json` with project branding + IDs.
3. `npm run bootstrap` to generate `.env` files for each package.
4. `npm run dev` to start backend + frontend locally.
5. `npm run jobs` (or package-specific scripts) to run monitoring workers.

Detailed walkthroughs live in `SETUP.md`, `BRANDING.md`, and `OPERATIONS.md`.

## White-Label Workflow

- Duplicate `config/project.config.json` per customer (`scripts/create-project.mjs` helps scaffold).
- Set `PROJECT_CONFIG_PATH` env var (or overwrite the default file) before starting services.
- Deploy backend + frontend to your preferred hosts; run monitoring scripts via cron/PM2/Railway workers.
- Share the configuration docs with clients so they can self-serve future tweaks.

## Environment Variables

See `config/env.example` for a full list covering Discord credentials, Postgres, Solana RPC, treasury keys, and optional integrations.
