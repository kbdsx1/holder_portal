#!/usr/bin/env node
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';
import dotenv from 'dotenv';
import { Connection, PublicKey } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, AccountLayout, getMint } from '@solana/spl-token';
import { Pool } from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(rootDir, 'config/.env') });

const projectConfigPath = path.join(rootDir, 'config/project.config.json');
const projectConfig = JSON.parse(fs.readFileSync(projectConfigPath, 'utf8'));

const POSTGRES_URL = process.env.POSTGRES_URL;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';
const TOKEN_MINT = process.env.REWARDS_TOKEN_MINT || projectConfig.rewards?.tokenMint || 'CSz42omfkxXMcrf74ppUtQ9VCbFkoo1A3Eoqnmuwyw7Y';

if (!POSTGRES_URL) {
  console.error('Missing POSTGRES_URL in config/.env');
  process.exit(1);
}

if (!TOKEN_MINT) {
  console.error('Missing rewards token mint');
  process.exit(1);
}

async function fetchTokenHolders() {
  const connection = new Connection(SOLANA_RPC_URL, 'confirmed');
  const mintPubkey = new PublicKey(TOKEN_MINT);
  console.log('[Seed] Fetching mint info for', mintPubkey.toBase58());
  const mintInfo = await getMint(connection, mintPubkey);
  const decimals = mintInfo.decimals;
  console.log('[Seed] Token decimals:', decimals);

  console.log('[Seed] Querying token accounts from chain...');
  const accounts = await connection.getProgramAccounts(TOKEN_PROGRAM_ID, {
    commitment: 'confirmed',
    filters: [
      { dataSize: AccountLayout.span },
      { memcmp: { offset: 0, bytes: mintPubkey.toBase58() } }
    ]
  });

  console.log(`[Seed] Retrieved ${accounts.length} token accounts`);
  const holders = new Map();

  for (const { account } of accounts) {
    const data = AccountLayout.decode(account.data);
    const amountRaw = BigInt(data.amount.toString());
    if (amountRaw === 0n) continue;
    const owner = new PublicKey(data.owner).toBase58();
    const amount = parseFloat(amountRaw.toString()) / 10 ** decimals;
    holders.set(owner, (holders.get(owner) || 0) + amount);
  }

  console.log('[Seed] Aggregated holders:', holders.size);
  return { holders, decimals };
}

async function upsertHolders(holders) {
  const pool = new Pool({
    connectionString: POSTGRES_URL,
    ssl: { rejectUnauthorized: false }
  });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('TRUNCATE token_holders');

    for (const [wallet, balance] of holders) {
      await client.query(
        `INSERT INTO token_holders (wallet_address, balance, last_updated)
         VALUES ($1, $2, CURRENT_TIMESTAMP)
         ON CONFLICT (wallet_address) DO UPDATE
         SET balance = EXCLUDED.balance,
             last_updated = CURRENT_TIMESTAMP`,
        [wallet, balance]
      );
    }

    await client.query('COMMIT');
    console.log('[Seed] Upserted token holders:', holders.size);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

async function main() {
  const { holders } = await fetchTokenHolders();
  await upsertHolders(holders);
  console.log('[Seed] Token holder sync complete.');
}

main().catch((err) => {
  console.error('Seed token holders failed:', err);
  process.exit(1);
});
