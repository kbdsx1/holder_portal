#!/usr/bin/env node

/**
 * Update Last Sale Prices from Magic Eden
 * Fetches last sale prices from Magic Eden activities API and updates
 * only the last_sale_price column in the nft_metadata table
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

// Collection configuration - can be changed or made configurable
const COLLECTION_SYMBOL = process.env.COLLECTION_SYMBOL || 'KBDS_OG';
const MAGIC_EDEN_API_BASE = 'https://api-mainnet.magiceden.io/v2';
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
 * Fetch last sale price from Magic Eden activities API
 */
async function fetchLastSalePrice(mintAddress) {
  try {
    const url = `${MAGIC_EDEN_API_BASE}/tokens/${mintAddress}/activities`;
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; KBDS-Holder-Portal/1.0)'
      }
    });

    if (!Array.isArray(response.data) || response.data.length === 0) {
      return null;
    }

    // Find the most recent sale (buyNow or sale type)
    const sales = response.data.filter(activity => 
      activity.type === 'buyNow' || activity.type === 'sale'
    );

    if (sales.length === 0) {
      return null;
    }

    // Get the most recent sale (first in array, as activities are sorted by most recent)
    const lastSale = sales[0];
    const price = lastSale.price;

    if (price && price > 0) {
      return price; // Price is already in SOL
    }

    return null;
  } catch (error) {
    if (error.response && error.response.status === 404) {
      // NFT not found or no activities
      return null;
    }
    // Log error but don't throw - continue with next NFT
    console.warn(`   ⚠️  Error fetching activities for ${mintAddress}: ${error.message}`);
    return null;
  }
}

/**
 * Fetch all sale prices first (without database operations)
 */
async function fetchAllSalePrices(nfts) {
  console.log(`\n🔍 Fetching sale prices from Magic Eden...\n`);
  
  const salePriceMap = new Map();
  let fetched = 0;
  let noSale = 0;
  let errors = 0;
  
  // Process in batches to avoid rate limits
  const BATCH_SIZE = 10;
  
  for (let i = 0; i < nfts.length; i += BATCH_SIZE) {
    const batch = nfts.slice(i, i + BATCH_SIZE);
    
    // Process batch in parallel
    const promises = batch.map(async (nft) => {
      // Skip if already has a last_sale_price
      if (nft.last_sale_price) {
        return { mint: nft.mint_address, price: null, skipped: true };
      }
      
      try {
        const salePrice = await fetchLastSalePrice(nft.mint_address);
        if (salePrice !== null) {
          return { mint: nft.mint_address, price: salePrice, skipped: false };
        } else {
          return { mint: nft.mint_address, price: null, skipped: false };
        }
      } catch (error) {
        return { mint: nft.mint_address, price: null, error: error.message };
      }
    });
    
    const results = await Promise.all(promises);
    
    for (const result of results) {
      if (result.skipped) {
        // Already has price, skip
        continue;
      }
      
      if (result.error) {
        errors++;
        continue;
      }
      
      if (result.price !== null) {
        salePriceMap.set(result.mint, result.price);
        fetched++;
      } else {
        noSale++;
      }
    }
    
    if ((i + BATCH_SIZE) % 100 === 0 || i + BATCH_SIZE >= nfts.length) {
      console.log(`   Fetched prices for ${fetched + noSale}/${nfts.length} NFTs...`);
    }
    
    // Delay between batches to avoid rate limits
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log(`\n✅ Fetched ${fetched} sale prices, ${noSale} with no sales, ${errors} errors\n`);
  return salePriceMap;
}

/**
 * Update last sale prices in database (bulk update)
 */
async function updateLastSalePrices(client, salePriceMap) {
  console.log(`\n📝 Updating last sale prices in database...\n`);
  
  let updated = 0;
  let errors = 0;
  
  // Process in batches for database updates
  const BATCH_SIZE = 50;
  const entries = Array.from(salePriceMap.entries());
  
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const batch = entries.slice(i, i + BATCH_SIZE);
    
    try {
      // Use a transaction for each batch
      await client.query('BEGIN');
      
      for (const [mint, price] of batch) {
        try {
          await client.query(
            `UPDATE nft_metadata 
             SET last_sale_price = $1 
             WHERE mint_address = $2 
             AND symbol = $3`,
            [price, mint, COLLECTION_SYMBOL]
          );
          updated++;
        } catch (error) {
          errors++;
          console.error(`   ❌ Error updating ${mint}:`, error.message);
        }
      }
      
      await client.query('COMMIT');
      
      if ((i + BATCH_SIZE) % 500 === 0 || i + BATCH_SIZE >= entries.length) {
        console.log(`   Updated ${Math.min(i + BATCH_SIZE, entries.length)}/${entries.length} NFTs...`);
      }
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`   ❌ Batch error:`, error.message);
      errors += batch.length;
    }
  }
  
  console.log(`\n✅ Update complete!\n`);
  console.log(`📊 Statistics:`);
  console.log(`   Total sale prices fetched: ${salePriceMap.size}`);
  console.log(`   Successfully updated: ${updated}`);
  console.log(`   Errors: ${errors}\n`);
  
  return { updated, errors };
}

/**
 * Verify updates
 */
async function verifyUpdates(client) {
  console.log(`\n🔍 Verifying updates...\n`);
  
  const { rows } = await client.query(
    `SELECT 
      COUNT(*) as total,
      COUNT(last_sale_price) FILTER (WHERE last_sale_price IS NOT NULL) as with_price,
      AVG(last_sale_price) FILTER (WHERE last_sale_price IS NOT NULL) as avg_price,
      MIN(last_sale_price) FILTER (WHERE last_sale_price IS NOT NULL) as min_price,
      MAX(last_sale_price) FILTER (WHERE last_sale_price IS NOT NULL) as max_price
     FROM nft_metadata 
     WHERE symbol = $1`,
    [COLLECTION_SYMBOL]
  );
  
  const stats = rows[0];
  console.log(`📊 Database Statistics:`);
  console.log(`   Total NFTs: ${stats.total}`);
  console.log(`   With last sale price: ${stats.with_price}`);
  console.log(`   Without last sale price: ${stats.total - stats.with_price}`);
  if (stats.avg_price) {
    console.log(`\n📈 Price Statistics:`);
    console.log(`   Average price: ${parseFloat(stats.avg_price).toFixed(4)} SOL`);
    console.log(`   Min price: ${parseFloat(stats.min_price).toFixed(4)} SOL`);
    console.log(`   Max price: ${parseFloat(stats.max_price).toFixed(4)} SOL\n`);
  }
}

/**
 * Get a fresh database client (reconnects if needed)
 */
async function getClient() {
  try {
    const client = await pool.connect();
    // Test the connection
    await client.query('SELECT 1');
    return client;
  } catch (error) {
    console.warn('⚠️  Connection issue, creating new pool...');
    await pool.end();
    // Recreate pool
    const newPool = new Pool({
      connectionString: POSTGRES_URL,
      ssl: POSTGRES_URL.includes('sslmode=require') ? { rejectUnauthorized: false } : false
    });
    const client = await newPool.connect();
    return client;
  }
}

/**
 * Main function
 */
async function main() {
  console.log('🚀 Starting Last Sale Price Update from Magic Eden\n');
  console.log(`Collection Symbol: ${COLLECTION_SYMBOL}\n`);

  let client = await getClient();
  
  try {
    // Get all NFTs that need last sale price updated
    console.log('📥 Fetching NFTs from database...\n');
    const { rows: nfts } = await client.query(
      `SELECT mint_address, last_sale_price 
       FROM nft_metadata 
       WHERE symbol = $1
       ORDER BY mint_address`,
      [COLLECTION_SYMBOL]
    );
    
    console.log(`✅ Found ${nfts.length} NFTs in database\n`);
    
    if (nfts.length === 0) {
      console.log('❌ No NFTs found in database');
      return;
    }

    // Count how many already have sale prices
    const withPrice = nfts.filter(nft => nft.last_sale_price).length;
    const withoutPrice = nfts.length - withPrice;
    
    console.log(`📊 Current Status:`);
    console.log(`   NFTs with last sale price: ${withPrice}`);
    console.log(`   NFTs without last sale price: ${withoutPrice}\n`);
    
    if (withoutPrice === 0) {
      console.log('✅ All NFTs already have last sale prices!\n');
      await verifyUpdates(client);
      return;
    }

    // Fetch all sale prices first (no database operations during fetch)
    const salePriceMap = await fetchAllSalePrices(nfts);
    
    // Then update database in bulk
    if (salePriceMap.size > 0) {
      await updateLastSalePrices(client, salePriceMap);
    } else {
      console.log('⚠️  No sale prices found to update\n');
    }
    
    // Verify updates
    await verifyUpdates(client);
    
  } catch (error) {
    console.error('❌ Update failed:', error);
    if (error.code === 'ECONNRESET' || error.code === 'EHOSTUNREACH' || error.message.includes('Connection terminated')) {
      console.log('\n⚠️  Connection lost. You can rerun the script to continue where it left off.');
    }
    process.exit(1);
  } finally {
    try {
      client.release();
      await pool.end();
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});

