# Project Configuration Schema

This file describes each field exposed inside `project.config.json` and how it maps to the backend/frontend/monitoring services.

## project
- `slug`: machine friendly identifier used in scripts and deploys.
- `name`: Display name for UI copy and Discord embeds.
- `description`: Short marketing sentence that appears in metadata.
- `primaryColor` / `accentColor`: HEX colors consumed by the frontend theme file.
- `logoPath`: Relative path to the logo asset; referenced by `packages/frontend/src/config/project.ts`.

## discord
- `guildId`: Discord server ID used for OAuth guild.join and role sync.
- `holderRoleId`: Default verified role for holders.
- `verifiedRoleIds`: Array of role IDs that should always stick to verified users.
- `announcementChannelId`: Channel used by the monitoring bot for sales/listings alerts.

## collections
List of tracked NFT collections:
- `symbol`: Unique key used across DB + Solana queries.
- `friendlyName`: Human readable label for dashboards.
- `mintAddresses`: Optional allowlist of mint addresses (empty array means fetch from chain each sync).
- `collectionAddress`: Verified collection address used for Helius lookups.
- `holderRoleId`: Discord role assigned when the user holds the collection.
- `minBalance`: Minimum token count required to qualify.

## rewards
- `currency`: Token ticker for UI copy.
- `treasuryWallet`: Base58 wallet that funds payouts.
- `claimProgramId`: Solana program that signs claim instructions.
- `tokenMint`: SPL mint address for the reward token.
- `dailyEmission`: Total reward pool per day.
- `cooldownHours`: Minimum interval between claims.

## frontend
- `apiBaseUrl`: Base HTTP URL used by the React app.
- `appUrl`: Public facing link for metadata + OAuth redirect.

Update `project.config.json` with project-specific values before running bootstrap scripts.

## collectionCountColumns
- Map collection symbols to the Postgres column storing their counts.
