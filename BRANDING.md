# Branding & Customization

Use this checklist when deploying the template for a new project.

## Config Files
- `config/project.config.json`
  - Update `project` block (name, slug, colors, logo path).
  - Replace Discord IDs, collection metadata, and reward settings.
- `config/monitoring.config.json`
  - Adjust channel IDs and cron expressions per job.

## Frontend
- Drop a logo inside `packages/frontend/src/assets/logo.svg` and update `config/project.config.json` `logoPath`.
- Override theme colors via CSS variables in `packages/frontend/src/theme.css` or edit the config values to feed a theming hook.
- Add new pages/components under `packages/frontend/src` and register them in `App.jsx`.

## Backend
- Set `FRONTEND_URL` + `API_BASE_URL` env vars to the deployed domains.
- Provide Solana program + treasury keys for reward claims.
- Update default Discord role fallbacks in `project.config.json`; the API reads them via `loadProjectConfig()`.

## Monitoring/Bots
- Edit `config/project.config.json` collections so role sync + sales notifications use the right mint symbols.
- Confirm `DISCORD_BOT_TOKEN` + `DISCORD_ACTIVITY_CHANNEL_ID` env vars before running `packages/monitoring/src/cron.js`.

After each change, re-run `npm run bootstrap` if you modified `.env.example`, and redeploy services so they pick up the refreshed config.
