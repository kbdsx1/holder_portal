#!/usr/bin/env node

/**
 * Import KBDS Art Collection
 * Fetches NFTs from the Art collection and populates the nft_metadata table
 * Note: Art collection does not have burrow traits
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pkg from 'pg';
const { Pool } = pkg;
import axios from 'axios';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

// Try multiple env file locations
dotenv.config({ path: join(rootDir, 'config/.env') });
dotenv.config({ path: join(rootDir, '.env') });

// Collection configuration
const COLLECTION_ADDRESS = '7XxybJDX7P6feMQxDuXdja8Gstbav1KvFxudLVtx28hh';
const COLLECTION_SYMBOL = 'KBDS_ART';
const HELIUS_API_KEY = process.env.HELIUS_API_KEY;
const POSTGRES_URL = process.env.DATABASE_URL || process.env.POSTGRES_URL;

if (!HELIUS_API_KEY) {
  console.error('❌ Missing HELIUS_API_KEY environment variable');
  console.error('   Please set it in config/.env or .env file');
  process.exit(1);
}

if (!POSTGRES_URL) {
  console.error('❌ Missing DATABASE_URL or POSTGRES_URL environment variable');
  console.error('   Please set it in config/.env or .env file');
  process.exit(1);
}

// Database connection
const pool = new Pool({
  connectionString: POSTGRES_URL,
  ssl: POSTGRES_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : false
});

/**
 * Fetch all NFTs from the collection using Helius API
 */
async function fetchCollectionNFTs() {
  if (!HELIUS_API_KEY) {
    throw new Error('HELIUS_API_KEY environment variable is not set');
  }

  console.log(`\n🔍 Fetching NFTs for Art collection (${COLLECTION_ADDRESS})...\n`);

  let allNFTs = [];
  let page = 1;
  const PAGE_SIZE = 1000; // Helius max page size
  let hasMore = true;

  while (hasMore) {
    console.log(`📄 Fetching page ${page}... (${allNFTs.length} NFTs found so far)`);
    
    const requestBody = {
      jsonrpc: '2.0',
      id: 'my-id',
      method: 'getAssetsByGroup',
      params: {
        groupKey: 'collection',
        groupValue: COLLECTION_ADDRESS,
        page,
        limit: PAGE_SIZE
      }
    };
    
    try {
      const response = await axios.post(
        `https://rpc.helius.xyz/?api-key=${HELIUS_API_KEY}`,
        requestBody,
        {
          headers: {
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.data.error) {
        console.error(`❌ Helius API error:`, response.data.error);
        throw new Error(`Helius API error: ${response.data.error.message}`);
      }

      const items = response.data.result?.items || [];
      
      if (!items || items.length === 0) {
        console.log(`\n✅ No more items found. Total: ${allNFTs.length} NFTs`);
        hasMore = false;
        break;
      }

      // Log sample NFT from first page
      if (page === 1 && items.length > 0) {
        const firstNFT = items[0];
        console.log(`\n📦 Sample NFT (first item):`);
        console.log(`   ID: ${firstNFT.id}`);
        console.log(`   Name: ${firstNFT.content?.metadata?.name || 'N/A'}`);
        console.log(`   Owner: ${firstNFT.ownership?.owner || 'N/A'}`);
      }

      allNFTs.push(...items);
      
      // Add delay between requests to avoid rate limits
      await new Promise(resolve => setTimeout(resolve, 500));
      
      page++;
      
      if (items.length < PAGE_SIZE) {
        hasMore = false;
      }
    } catch (error) {
      console.error(`❌ Error fetching page ${page}:`, error.message);
      throw error;
    }
  }

  console.log(`\n✅ Fetched total of ${allNFTs.length} NFTs\n`);
  return allNFTs;
}

/**
 * Upsert NFT into database (no burrow for Art collection)
 */
async function upsertNFT(client, nft) {
  const metadata = nft.content?.metadata || {};
  const creators = metadata?.creators || nft.creators || [];
  const collection = nft.content?.collection || 
                     nft.grouping?.find((g) => g.groupKey === 'collection') || 
                     { value: COLLECTION_ADDRESS };
  const files = nft.content?.files || [];
  const imageUrl = metadata?.image || 
                   files.find((file) => file?.cdn_uri || file?.uri)?.cdn_uri || 
                   files.find((file) => file?.uri)?.uri || 
                   null;

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
      rarity_rank,
      burrows
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
    )
    ON CONFLICT (mint_address) DO UPDATE SET
      name = EXCLUDED.name,
      symbol = COALESCE(nft_metadata.symbol, EXCLUDED.symbol),
      uri = COALESCE(nft_metadata.uri, EXCLUDED.uri),
      creators = COALESCE(nft_metadata.creators, EXCLUDED.creators),
      collection = COALESCE(nft_metadata.collection, EXCLUDED.collection),
      image_url = COALESCE(nft_metadata.image_url, EXCLUDED.image_url),
      owner_wallet = EXCLUDED.owner_wallet,
      rarity_rank = COALESCE(nft_metadata.rarity_rank, EXCLUDED.rarity_rank),
      burrows = nft_metadata.burrows
  `;

  const values = [
    nft.id,
    metadata.name || nft.content?.metadata?.name || null,
    COLLECTION_SYMBOL,
    metadata.uri || nft.content?.json_uri || null,
    creators.length > 0 ? JSON.stringify(creators) : null,
    collection ? JSON.stringify(collection) : null,
    imageUrl,
    nft.ownership?.owner || null,
    nft.rarity?.rank || null,
    null // Art collection has no burrows
  ];

  await client.query(query, values);
}

/**
 * Main import function
 */
async function main() {
  console.log('🚀 Starting KBDS Art Collection Import\n');
  console.log(`Collection Address: ${COLLECTION_ADDRESS}`);
  console.log(`Collection Symbol: ${COLLECTION_SYMBOL}\n`);

  const client = await pool.connect();
  
  try {
    // Fetch all NFTs from the collection
    const nfts = await fetchCollectionNFTs();
    
    if (nfts.length === 0) {
      console.log('❌ No NFTs found in collection');
      return;
    }

    console.log(`\n📥 Processing ${nfts.length} NFTs...\n`);
    
    let processed = 0;

    for (const nft of nfts) {
      try {
        // Upsert NFT into database (no burrow extraction needed)
        await upsertNFT(client, nft);
        
        processed++;
        
        if (processed % 50 === 0) {
          console.log(`✅ Processed ${processed}/${nfts.length} NFTs...`);
        }
        
        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        console.error(`❌ Error processing NFT ${nft.id}:`, error.message);
        // Continue with next NFT
      }
    }

    console.log(`\n✅ Import complete!\n`);
    console.log(`📊 Statistics:`);
    console.log(`   Total NFTs processed: ${processed}\n`);
    
  } catch (error) {
    console.error('❌ Import failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});

