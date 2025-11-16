import 'dotenv/config';
import pkg from 'pg';
import fetch from 'node-fetch';

const { Pool } = pkg;

const {
  POSTGRES_URL,
  HELIUS_API_KEY,
  COLLECTION_ADDRESS,
  DISCORD_BOT_TOKEN,
  DISCORD_ACTIVITY_CHANNEL_ID
} = process.env;

if (!POSTGRES_URL) throw new Error('POSTGRES_URL missing');
if (!HELIUS_API_KEY) throw new Error('HELIUS_API_KEY missing');
if (!COLLECTION_ADDRESS) throw new Error('COLLECTION_ADDRESS missing');
if (!DISCORD_BOT_TOKEN) throw new Error('DISCORD_BOT_TOKEN missing');
if (!DISCORD_ACTIVITY_CHANNEL_ID) throw new Error('DISCORD_ACTIVITY_CHANNEL_ID missing');

const pool = new Pool({ connectionString: POSTGRES_URL });

async function fetchAssetsByCollection(page = 1) {
  // Prefer JSON-RPC getAssetsByGroup which is stable for collections
  const url = `https://mainnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}`;
  const body = {
    jsonrpc: '2.0',
    id: 'cannasolz-assets',
    method: 'getAssetsByGroup',
    params: {
      groupKey: 'collection',
      groupValue: COLLECTION_ADDRESS,
      page,
      limit: 1000
    }
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  // If Helius isn't configured or collection is unknown, avoid failing the workflow
  if (!res.ok) {
    console.warn('Helius non-OK response:', res.status);
    return { items: [] };
  }
  const data = await res.json().catch(() => ({}));
  // Expected shape: { result: { items: [...] } } or { result: [...] } depending on Helius version
  if (data?.result?.items) return data.result;
  if (Array.isArray(data?.result)) return { items: data.result };
  return { items: [] };
}

async function postDiscordEmbed({ name, mint, oldOwner, newOwner, image }) {
  const url = `https://discord.com/api/v10/channels/${DISCORD_ACTIVITY_CHANNEL_ID}/messages`;
  const embed = {
    title: 'Ownership Change',
    description: `**${name || mint}** transferred ownership`,
    color: 0x95D5B2,
    fields: [
      { name: 'Mint', value: `\`${mint}\``, inline: false },
      { name: 'From', value: oldOwner ? `\`${oldOwner}\`` : '`Unknown`', inline: true },
      { name: 'To', value: newOwner ? `\`${newOwner}\`` : '`Unknown`', inline: true }
    ],
    thumbnail: image ? { url: image } : undefined,
    timestamp: new Date().toISOString()
  };
  await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bot ${DISCORD_BOT_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ embeds: [embed] })
  });
}

async function run() {
  const client = await pool.connect();
  try {
    let page = 1;
    while (true) {
      const data = await fetchAssetsByCollection(page);
      const assets = data?.items || data?.result || data?.nfts || [];
      if (!assets.length) break;

      for (const a of assets) {
        const mint = a?.id || a?.mint || a?.tokenAddress;
        const owner = a?.ownership?.owner || a?.owner || a?.token_info?.owner;
        const name = a?.name || a?.content?.metadata?.name;
        const image = a?.image || a?.content?.links?.image;
        if (!mint || !owner) continue;

        const { rows } = await client.query('SELECT owner_wallet, name FROM nft_metadata WHERE mint_address = $1', [mint]);
        const current = rows[0];
        if (!current) {
          // Insert minimal row so next runs track it
          await client.query(
            'INSERT INTO nft_metadata (mint_address, name, owner_wallet, owner_discord_id, owner_name) VALUES ($1, $2, $3, NULL, NULL) ON CONFLICT (mint_address) DO NOTHING',
            [mint, name || null, owner]
          );
          continue;
        }

        if ((current.owner_wallet || '') !== owner) {
          // Update owner and send embed
          await client.query(
            'UPDATE nft_metadata SET owner_wallet=$2, is_listed=false, list_price=NULL, last_sale_price=NULL WHERE mint_address=$1',
            [mint, owner]
          );
          await postDiscordEmbed({
            name: current.name || name || mint,
            mint,
            oldOwner: current.owner_wallet,
            newOwner: owner,
            image
          });
        }
      }

      // Helius pagination varies; assume page increment until empty
      page += 1;
      if (assets.length < 1000) break;
    }
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((e) => {
  console.warn('Ownership change monitor non-fatal error:', e?.message || e);
  // Do not fail the workflow on API issues; exit 0 so the other job (holders) still runs cleanly
  process.exit(0);
});


