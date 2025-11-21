#!/usr/bin/env node

/**
 * Update Listing Details from Magic Eden
 * Fetches list_price and original_lister from Magic Eden listings API
 * and updates only those columns (plus is_listed and marketplace if needed)
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

// Collection configuration - can be changed via environment variable
const COLLECTION_SLUG = process.env.COLLECTION_SLUG || 'kbds_og';
const COLLECTION_SYMBOL = process.env.COLLECTION_SYMBOL || 'KBDS_OG';
const MAGIC_EDEN_API_BASE = 'https://api-mainnet.magiceden.io/v2';
const MAGIC_EDEN_ESCROW = '1BWutmTvYPwDtmw9abTkS4Ssr8no61spGAvW1X6NDix';
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
 * Fetch all listings from Magic Eden
 */
async function fetchMagicEdenListings() {
  console.log(`\n🔍 Fetching listings from Magic Eden...\n`);
  
  const listings = new Map();
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
      
      // Extract listing data
      for (const listing of batch) {
        if (listing.tokenMint) {
          listings.set(listing.tokenMint, {
            price: listing.price || null,
            seller: listing.seller || null
          });
        }
      }
      
      console.log(`   Fetched ${listings.size} listings so far...`);
      
      offset += batch.length;
      
      // If we got fewer than the limit, we're done
      if (batch.length < limit) {
        hasMore = false;
      }
      
      // Small delay to avoid rate limits
      await new Promise(resolve => setTimeout(resolve, 200));
      
    } catch (error) {
      console.error(`   Error fetching listings:`, error.message);
      hasMore = false;
    }
  }
  
  console.log(`✅ Found ${listings.size} listings from Magic Eden\n`);
  return listings;
}

/**
 * Update listing details in database
 */
async function updateListingDetails(client, listings) {
  console.log(`\n📝 Updating listing details in database...\n`);
  
  let updated = 0;
  let notFound = 0;
  let errors = 0;
  
  // Process in batches
  const BATCH_SIZE = 50;
  const entries = Array.from(listings.entries());
  
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const batch = entries.slice(i, i + BATCH_SIZE);
    
    try {
      await client.query('BEGIN');
      
      for (const [mint, listing] of batch) {
        try {
          const result = await client.query(
            `UPDATE nft_metadata 
             SET list_price = $1,
                 original_lister = $2,
                 is_listed = TRUE,
                 marketplace = 'MAGICEDEN'
             WHERE mint_address = $3 
             AND symbol = $4`,
            [listing.price, listing.seller, mint, COLLECTION_SYMBOL]
          );
          
          if (result.rowCount > 0) {
            updated++;
          } else {
            notFound++;
          }
        } catch (error) {
          errors++;
          console.error(`   ❌ Error updating ${mint}:`, error.message);
        }
      }
      
      await client.query('COMMIT');
      
      if ((i + BATCH_SIZE) % 100 === 0 || i + BATCH_SIZE >= entries.length) {
        console.log(`   Processed ${Math.min(i + BATCH_SIZE, entries.length)}/${entries.length} listings...`);
      }
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`   ❌ Batch error:`, error.message);
      errors += batch.length;
    }
  }
  
  console.log(`\n✅ Update complete!\n`);
  console.log(`📊 Statistics:`);
  console.log(`   Total listings: ${listings.size}`);
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
      COUNT(*) FILTER (WHERE is_listed = TRUE) as listed,
      COUNT(*) FILTER (WHERE is_listed = TRUE AND marketplace = 'MAGICEDEN') as magic_eden_listed,
      COUNT(*) FILTER (WHERE list_price IS NOT NULL) as with_price,
      COUNT(*) FILTER (WHERE original_lister IS NOT NULL) as with_lister,
      AVG(list_price) FILTER (WHERE list_price IS NOT NULL) as avg_price,
      MIN(list_price) FILTER (WHERE list_price IS NOT NULL) as min_price,
      MAX(list_price) FILTER (WHERE list_price IS NOT NULL) as max_price
     FROM nft_metadata 
     WHERE symbol = $1`,
    [COLLECTION_SYMBOL]
  );
  
  const stats = rows[0];
  console.log(`📊 Database Statistics:`);
  console.log(`   Total NFTs: ${stats.total}`);
  console.log(`   Listed: ${stats.listed}`);
  console.log(`   Magic Eden listed: ${stats.magic_eden_listed}`);
  console.log(`   With list price: ${stats.with_price}`);
  console.log(`   With original lister: ${stats.with_lister}`);
  if (stats.avg_price) {
    console.log(`\n📈 Price Statistics:`);
    console.log(`   Average list price: ${parseFloat(stats.avg_price).toFixed(4)} SOL`);
    console.log(`   Min list price: ${parseFloat(stats.min_price).toFixed(4)} SOL`);
    console.log(`   Max list price: ${parseFloat(stats.max_price).toFixed(4)} SOL\n`);
  }
}

/**
 * Main function
 */
async function main() {
  console.log('🚀 Starting Listing Details Update from Magic Eden\n');
  console.log(`Collection: ${COLLECTION_SLUG}`);
  console.log(`Symbol: ${COLLECTION_SYMBOL}\n`);

  const client = await pool.connect();
  
  try {
    // Fetch listings from Magic Eden
    const listings = await fetchMagicEdenListings();
    
    if (listings.size === 0) {
      console.log('❌ No listings found');
      return;
    }
    
    // Update database
    await updateListingDetails(client, listings);
    
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

