#!/usr/bin/env node

/**
 * Update Rarity Ranks from HowRare.is
 * Fetches rarity ranks from HowRare.is API and updates only the rarity_rank column
 * in the nft_metadata table without affecting other columns
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pkg from 'pg';
const { Pool } = pkg;
import axios from 'axios';

// No longer need Puppeteer - using HowRare.is API directly

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

// Try multiple env file locations
dotenv.config({ path: join(rootDir, 'config/.env') });
dotenv.config({ path: join(rootDir, '.env') });

// Collection configuration
const COLLECTION_SLUG = 'kbds_og';
const COLLECTION_SYMBOL = 'KBDS_OG';
const MAGIC_EDEN_API_BASE = 'https://api-mainnet.magiceden.io/v2';
const HOWRARE_API_BASE = 'https://howrare.is/api/v1';
const POSTGRES_URL = process.env.DATABASE_URL || process.env.POSTGRES_URL;

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
 * Fetch rarity data from Magic Eden listings API (for listed NFTs)
 * Magic Eden includes HowRare.is rarity ranks in their listings
 */
async function fetchRarityFromMagicEden() {
  console.log(`\n🔍 Fetching rarity data from Magic Eden listings...\n`);
  
  const listings = [];
  let offset = 0;
  const limit = 100;
  let hasMore = true;
  
  while (hasMore) {
    try {
      const url = `${MAGIC_EDEN_API_BASE}/collections/${COLLECTION_SLUG}/listings?offset=${offset}&limit=${limit}`;
      const response = await axios.get(url, {
        timeout: 30000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; KBDS-Holder-Portal/1.0)'
        }
      });
      
      const batch = Array.isArray(response.data) ? response.data : [];
      
      if (batch.length === 0) {
        hasMore = false;
        break;
      }
      
      // Extract rarity data from listings
      for (const listing of batch) {
        if (listing.rarity?.howrare?.rank && listing.tokenMint) {
          listings.push({
            mint: listing.tokenMint,
            rank: listing.rarity.howrare.rank
          });
        }
      }
      
      console.log(`   Fetched ${listings.length} NFTs with rarity from Magic Eden...`);
      
      offset += batch.length;
      
      // If we got fewer than the limit, we're done
      if (batch.length < limit) {
        hasMore = false;
      }
      
      // Small delay to avoid rate limits
      await new Promise(resolve => setTimeout(resolve, 200));
      
    } catch (error) {
      console.error(`   Error fetching Magic Eden listings:`, error.message);
      hasMore = false;
    }
  }
  
  console.log(`✅ Found ${listings.length} NFTs with rarity from Magic Eden\n`);
  return listings;
}

/**
 * Fetch all rarity data from HowRare.is API
 * Uses the official HowRare.is API endpoint
 */
async function fetchRarityFromHowRare() {
  console.log(`\n🔍 Fetching rarity data from HowRare.is API...\n`);
  
  try {
    const url = `https://api.howrare.is/v0.1/collections/${COLLECTION_SLUG}`;
    console.log(`📡 API URL: ${url}`);
    
    const response = await axios.get(url, {
      timeout: 60000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; KBDS-Holder-Portal/1.0)'
      }
    });

    if (!response.data) {
      throw new Error('No data returned from HowRare.is API');
    }

    const data = response.data;
    const result = data.result || {};
    
    if (result.api_code !== 200) {
      throw new Error(`API error: ${result.api_response || 'Unknown error'}`);
    }

    const items = result.data?.items || [];
    
    if (!Array.isArray(items) || items.length === 0) {
      throw new Error('No items found in API response');
    }

    console.log(`✅ Fetched ${items.length} NFTs from HowRare.is API\n`);
    
    // Log sample item structure
    if (items.length > 0) {
      console.log('📦 Sample item structure:');
      const sample = items[0];
      console.log(`   Mint: ${sample.mint || 'N/A'}`);
      console.log(`   Rank: ${sample.rank || 'N/A'}`);
      console.log(`   Name: ${sample.name || 'N/A'}\n`);
    }

    return items;
  } catch (error) {
    if (error.response) {
      console.error(`❌ API Error: ${error.response.status} ${error.response.statusText}`);
      console.error(`   URL: ${error.config?.url}`);
      if (error.response.data) {
        console.error(`   Response: ${JSON.stringify(error.response.data).substring(0, 200)}`);
      }
    } else {
      console.error(`❌ Error fetching rarity data:`, error.message);
    }
    throw error;
  }
}

/**
 * Create a map of mint address to rarity rank
 */
function createRarityMap(items) {
  const rarityMap = new Map();
  
  for (const item of items) {
    // Try different field names for mint address
    const mint = item.mint || item.mint_address || item.id;
    const rank = item.rank || item.rarity_rank || item.rarityRank;
    
    if (!mint) {
      console.warn(`⚠️  Skipping item without mint address:`, JSON.stringify(item).substring(0, 100));
      continue;
    }
    
    if (rank === undefined || rank === null) {
      console.warn(`⚠️  Skipping item without rank: ${mint}`);
      continue;
    }
    
    const rankNum = parseInt(rank);
    if (isNaN(rankNum)) {
      console.warn(`⚠️  Invalid rank value for ${mint}: ${rank}`);
      continue;
    }
    
    rarityMap.set(mint, rankNum);
  }
  
  return rarityMap;
}

/**
 * Update rarity ranks in database
 */
async function updateRarityRanks(client, rarityMap) {
  console.log(`\n📝 Updating rarity ranks in database...\n`);
  
  let updated = 0;
  let notFound = 0;
  let errors = 0;
  
  // Process in batches for better performance
  const BATCH_SIZE = 100;
  const entries = Array.from(rarityMap.entries());
  
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const batch = entries.slice(i, i + BATCH_SIZE);
    
    try {
      // Use a transaction for each batch
      await client.query('BEGIN');
      
      for (const [mint, rank] of batch) {
        try {
          const result = await client.query(
            `UPDATE nft_metadata 
             SET rarity_rank = $1 
             WHERE mint_address = $2 
             AND symbol = $3`,
            [rank, mint, COLLECTION_SYMBOL]
          );
          
          if (result.rowCount > 0) {
            updated++;
          } else {
            notFound++;
            // Check if NFT exists with different symbol or no symbol
            const checkResult = await client.query(
              `SELECT mint_address, symbol FROM nft_metadata WHERE mint_address = $1`,
              [mint]
            );
            if (checkResult.rows.length > 0) {
              console.warn(`⚠️  NFT ${mint} exists but with symbol: ${checkResult.rows[0].symbol || 'NULL'}`);
            }
          }
        } catch (error) {
          errors++;
          console.error(`❌ Error updating ${mint}:`, error.message);
        }
      }
      
      await client.query('COMMIT');
      
      if ((i + BATCH_SIZE) % 500 === 0 || i + BATCH_SIZE >= entries.length) {
        console.log(`   Processed ${Math.min(i + BATCH_SIZE, entries.length)}/${entries.length} NFTs...`);
      }
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`❌ Batch error:`, error.message);
      errors += batch.length;
    }
  }
  
  console.log(`\n✅ Update complete!\n`);
  console.log(`📊 Statistics:`);
  console.log(`   Total rarity entries: ${rarityMap.size}`);
  console.log(`   Successfully updated: ${updated}`);
  console.log(`   Not found in DB: ${notFound}`);
  console.log(`   Errors: ${errors}\n`);
  
  return { updated, notFound, errors };
}

/**
 * Verify updates
 */
async function verifyUpdates(client) {
  console.log(`\n🔍 Verifying updates...\n`);
  
  const { rows } = await client.query(
    `SELECT 
      COUNT(*) as total,
      COUNT(rarity_rank) as with_rank,
      COUNT(*) FILTER (WHERE rarity_rank IS NOT NULL) as has_rank
     FROM nft_metadata 
     WHERE symbol = $1`,
    [COLLECTION_SYMBOL]
  );
  
  const stats = rows[0];
  console.log(`📊 Database Statistics:`);
  console.log(`   Total NFTs: ${stats.total}`);
  console.log(`   With rarity rank: ${stats.has_rank}`);
  console.log(`   Without rarity rank: ${stats.total - stats.has_rank}\n`);
  
  // Show rank distribution
  const { rows: rankStats } = await client.query(
    `SELECT 
      MIN(rarity_rank) as min_rank,
      MAX(rarity_rank) as max_rank,
      AVG(rarity_rank)::integer as avg_rank
     FROM nft_metadata 
     WHERE symbol = $1 AND rarity_rank IS NOT NULL`,
    [COLLECTION_SYMBOL]
  );
  
  if (rankStats[0]?.min_rank) {
    console.log(`📈 Rank Statistics:`);
    console.log(`   Min rank: ${rankStats[0].min_rank}`);
    console.log(`   Max rank: ${rankStats[0].max_rank}`);
    console.log(`   Avg rank: ${rankStats[0].avg_rank}\n`);
  }
}

/**
 * Main function
 */
async function main() {
  console.log('🚀 Starting Rarity Rank Update from HowRare.is\n');
  console.log(`Collection: ${COLLECTION_SLUG}`);
  console.log(`Symbol: ${COLLECTION_SYMBOL}\n`);

  const client = await pool.connect();
  
  try {
    // First, try to get rarity from Magic Eden (faster, but only for listed NFTs)
    let items = await fetchRarityFromMagicEden();
    
    // Get list of all NFTs in database that don't have rarity yet
    const { rows: nftsWithoutRarity } = await client.query(
      `SELECT mint_address FROM nft_metadata 
       WHERE symbol = $1 AND rarity_rank IS NULL`,
      [COLLECTION_SYMBOL]
    );
    
    const nftsWithRarity = new Set(items.map(item => item.mint));
    const missingMints = nftsWithoutRarity
      .map(row => row.mint_address)
      .filter(mint => !nftsWithRarity.has(mint));
    
    console.log(`📊 Statistics:`);
    console.log(`   NFTs with rarity from Magic Eden: ${items.length}`);
    console.log(`   NFTs still needing rarity: ${missingMints.length}\n`);
    
    // If we have NFTs missing rarity, fetch from HowRare.is API
    if (missingMints.length > 0) {
      console.log(`\n🔍 Fetching remaining rarity data from HowRare.is API...\n`);
      const howrareItems = await fetchRarityFromHowRare();
      
      // Create a map of mint to rank
      const howrareMap = new Map(howrareItems.map(item => [
        item.mint,
        item.rank
      ]));
      
      // Add missing items
      let added = 0;
      for (const mint of missingMints) {
        if (howrareMap.has(mint)) {
          items.push({
            mint: mint,
            rank: howrareMap.get(mint)
          });
          added++;
        }
      }
      
      console.log(`✅ Added ${added} more NFTs from HowRare.is API\n`);
    }
    
    // Create rarity map
    const rarityMap = createRarityMap(items);
    console.log(`✅ Created rarity map with ${rarityMap.size} entries\n`);
    
    if (rarityMap.size === 0) {
      console.log('❌ No valid rarity data found');
      return;
    }
    
    // Update database
    await updateRarityRanks(client, rarityMap);
    
    // Verify updates
    await verifyUpdates(client);
    
  } catch (error) {
    console.error('❌ Update failed:', error);
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

