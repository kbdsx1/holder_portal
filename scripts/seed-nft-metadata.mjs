#!/usr/bin/env node
import path from 'path';
import { fileURLToPath } from 'url';
import { Pool } from 'pg';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(rootDir, 'config/.env') });

const HELIUS_API_KEY = process.env.HELIUS_API_KEY;
const POSTGRES_URL = process.env.POSTGRES_URL;
const COLLECTION_ADDRESS = process.env.COLLECTION_ADDRESS || '5uJddP4MezyWfGuYjyPdvSnsSCsE86uHaTQHJRr1Zazg';
const MAGICEDEN_SYMBOL = process.env.MAGICEDEN_SYMBOL || 'cannasolz';
const PAGE_SIZE = Number(process.env.SEED_PAGE_SIZE || 1000);

if (!HELIUS_API_KEY) {
  console.error('Missing HELIUS_API_KEY in config/.env');
  process.exit(1);
}

if (!POSTGRES_URL) {
  console.error('Missing POSTGRES_URL in config/.env');
  process.exit(1);
}

const pool = new Pool({ connectionString: POSTGRES_URL });

async function fetchAssets() {
  const assets = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const body = {
      jsonrpc: '2.0',
      id: `seed-${page}`,
      method: 'getAssetsByGroup',
      params: {
        groupKey: 'collection',
        groupValue: COLLECTION_ADDRESS,
        page,
        limit: PAGE_SIZE
      }
    };

    const response = await fetch(`https://rpc.helius.xyz/?api-key=${HELIUS_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      throw new Error(`Helius error (page ${page}): ${response.status} ${response.statusText}`);
    }

    const payload = await response.json();
    const items = payload?.result?.items ?? [];
    console.log(`Fetched page ${page} (${items.length} assets)`);

    assets.push(...items);
    hasMore = items.length === PAGE_SIZE;
    page += 1;
  }

  console.log(`Total assets fetched: ${assets.length}`);
  return assets;
}

async function fetchMagicEdenListings() {
  const listings = new Map();
  const limit = Number(process.env.MAGICEDEN_LISTING_PAGE_SIZE || 200);
  let offset = 0;

  while (true) {
    const url = `https://api-mainnet.magiceden.dev/v2/collections/${MAGICEDEN_SYMBOL}/listings?offset=${offset}&limit=${limit}`;
    const res = await fetch(url);
    if (!res.ok) {
      console.warn('Magic Eden listings request failed:', res.status);
      break;
    }
    const data = await res.json();
    if (!Array.isArray(data) || data.length === 0) {
      break;
    }

    for (const listing of data) {
      const mint = listing.tokenMint;
      if (!mint) continue;
      const priceLamports = listing.priceLamports ?? null;
      const price = listing.price ?? listing.priceSol ?? (priceLamports ? Number(priceLamports) / 1e9 : null);
      listings.set(mint, {
        price,
        marketplace: 'MagicEden',
        seller: listing.seller || null
      });
    }

    offset += data.length;
    if (data.length < limit) {
      break;
    }
  }

  console.log(`Magic Eden listings fetched: ${listings.size}`);
  return listings;
}

async function fetchMagicEdenSales() {
  const sales = new Map();
  const limit = Number(process.env.MAGICEDEN_SALES_PAGE_SIZE || 200);
  let offset = 0;

  while (true) {
    const url = `https://api-mainnet.magiceden.dev/v2/collections/${MAGICEDEN_SYMBOL}/activities?offset=${offset}&limit=${limit}&kind=sold`;
    const res = await fetch(url);
    if (!res.ok) {
      console.warn('Magic Eden sales request failed:', res.status);
      break;
    }
    const data = await res.json();
    if (!Array.isArray(data) || data.length === 0) {
      break;
    }

    for (const sale of data) {
      const mint = sale.tokenMint;
      if (!mint) continue;
      const priceLamports = sale.priceLamports ?? sale.amount ?? null;
      const price = sale.price ?? sale.priceSol ?? (priceLamports ? Number(priceLamports) / 1e9 : null);
      const recorded = sales.get(mint);
      if (!recorded || (sale.blockTime || 0) > (recorded.blockTime || 0)) {
        sales.set(mint, {
          price,
          blockTime: sale.blockTime || null
        });
      }
    }

    offset += data.length;
    if (data.length < limit) {
      break;
    }
  }

  console.log(`Magic Eden sales fetched: ${sales.size}`);
  return sales;
}

function buildListingInfo(listingEntry, saleEntry) {
  return {
    isListed: Boolean(listingEntry),
    listPrice: listingEntry?.price ?? null,
    marketplace: listingEntry?.marketplace ?? null,
    lastSalePrice: saleEntry?.price ?? null
  };
}

async function upsertAsset(client, asset, listingInfo) {
  const metadata = asset.content?.metadata || {};
  const creators = metadata?.creators || asset.creators || [];
  const collection = asset.content?.collection || asset.grouping?.find((g) => g.groupKey === 'collection') || null;
  const files = asset.content?.files || [];
  const imageUrl = metadata?.image || files.find((file) => file?.cdn_uri || file?.uri)?.cdn_uri || files.find((file) => file?.uri)?.uri || null;

  const query = `
    INSERT INTO nft_metadata (
      mint_address,
      name,
      symbol,
      uri,
      creators,
      collection,
      image_url,
      owner_wallet,
      is_listed,
      list_price,
      last_sale_price,
      marketplace,
      rarity_rank
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
    )
    ON CONFLICT (mint_address) DO UPDATE SET
      name = EXCLUDED.name,
      symbol = EXCLUDED.symbol,
      uri = EXCLUDED.uri,
      creators = EXCLUDED.creators,
      collection = EXCLUDED.collection,
      image_url = EXCLUDED.image_url,
      owner_wallet = EXCLUDED.owner_wallet,
      is_listed = EXCLUDED.is_listed,
      list_price = EXCLUDED.list_price,
      last_sale_price = EXCLUDED.last_sale_price,
      marketplace = EXCLUDED.marketplace,
      rarity_rank = EXCLUDED.rarity_rank
  `;

  const values = [
    asset.id,
    metadata.name || asset.content?.metadata?.name || null,
    metadata.symbol || asset.content?.metadata?.symbol || asset.symbol || null,
    metadata.uri || asset.content?.json_uri || null,
    creators ? JSON.stringify(creators) : null,
    collection ? JSON.stringify(collection) : null,
    imageUrl,
    asset.ownership?.owner || null,
    listingInfo.isListed,
    listingInfo.listPrice,
    listingInfo.lastSalePrice,
    listingInfo.marketplace,
    asset.rarity?.rank || null
  ];

  await client.query(query, values);
}

async function main() {
  const [assets, meListings, meSales] = await Promise.all([
    fetchAssets(),
    fetchMagicEdenListings(),
    fetchMagicEdenSales()
  ]);
  const client = await pool.connect();

  try {
    for (let i = 0; i < assets.length; i += 1) {
      const asset = assets[i];
      const listingEntry = meListings.get(asset.id);
      const saleEntry = meSales.get(asset.id);
      const listingInfo = buildListingInfo(listingEntry, saleEntry);
      await upsertAsset(client, asset, listingInfo);

      if ((i + 1) % 25 === 0) {
        console.log(`Upserted ${i + 1}/${assets.length} assets`);
      }
    }
    console.log('Seeding complete');
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('Seed failed:', error);
  process.exit(1);
});
