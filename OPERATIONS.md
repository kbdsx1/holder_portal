# Operations Runbook

## Health Checks
- `GET /health` – backend status + project name.
- `GET /api/rewards/events` – should stream SSE data; disconnect/reconnect ensures Postgres LISTEN works.

## Cron / Monitoring
- `packages/monitoring/src/cron.js` reads `config/monitoring.config.json` to decide which sync jobs to run.
- Use `npm --workspace packages/monitoring run start` under a process manager (PM2, systemd) or schedule via hosted cron (Railway, Render, GitHub Actions).
- Long-running jobs log to stdout; collect via your platform.

## Rewards
- Manual trigger: `POST /api/rewards/process-daily` with header `x-secret-token: <CRON_SECRET_TOKEN>`.
- Claim flow uses Solana treasury key stored in `TREASURY_WALLET_SECRET_KEY`; rotate frequently.

## Discord Bot
- Uses `DISCORD_BOT_TOKEN` + `DISCORD_GUILD_ID` from `.env`.
- Update role IDs through `config/project.config.json`; the sync + monitoring scripts consume that file.

## Incident Tips
- If auth fails, verify Discord OAuth redirect URIs + `SESSION_SECRET`.
- Wallet issues typically trace back to incorrect Solana RPC or stale treasury key.
- For SSE silence, ensure Postgres `NOTIFY rewards_processed` triggers are firing and that the monitoring scripts call `process_pending_rewards()`.
