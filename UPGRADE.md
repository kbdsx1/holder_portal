# Upgrading the Template

1. **Pull latest changes**
   ```bash
   git pull origin main
   ```
2. **Resolve config drift**
   - Keep customer-specific configs in `config/<slug>.config.json`.
   - After pulling, re-run `scripts/create-project.mjs` if new fields were added, then merge diff back into each config file.
3. **Re-bootstrap env files**
   - If `config/env.example` changed, run `npm run bootstrap` and copy any new keys into production secrets.
4. **Run tests/smoke checks**
   - `npm run dev` to ensure backend/frontend still start locally.
   - `npm run jobs` if monitoring scripts changed.
5. **Deploy**
   - Rebuild frontend (`npm --workspace packages/frontend run build`).
   - Redeploy backend + monitoring with the updated Docker image or Node bundle.

Keep customer overrides (logos, content) outside of tracked files or commit them per-customer branch to avoid merge conflicts.
