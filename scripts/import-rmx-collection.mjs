#!/usr/bin/env node

/**
 * Import KBDS RMX Collection
 * Fetches NFTs from Magic Eden listings and populates the nft_metadata table
 * Note: RMX collection does not have a verified collection address, so we use Magic Eden listings
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
const COLLECTION_SLUG = 'kbds_rmx';
const COLLECTION_SYMBOL = 'KBDS_RMX';
const HELIUS_API_KEY = process.env.HELIUS_API_KEY;
const POSTGRES_URL = process.env.DATABASE_URL || process.env.POSTGRES_URL;
const MAGIC_EDEN_API_BASE = 'https://api-mainnet.magiceden.io/v2';

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
 * Fetch all mint addresses from Magic Eden listings
 */
async function fetchMintAddressesFromListings() {
  console.log(`\n🔍 Fetching mint addresses from Magic Eden listings for ${COLLECTION_SLUG}...\n`);
  
  const mintAddresses = new Set();
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
      
      // Extract mint addresses
      for (const listing of batch) {
        if (listing.tokenMint) {
          mintAddresses.add(listing.tokenMint);
        }
      }
      
      console.log(`   Found ${mintAddresses.size} unique NFTs so far...`);
      
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
  
  console.log(`✅ Found ${mintAddresses.size} unique NFTs from Magic Eden listings\n`);
  return Array.from(mintAddresses);
}

/**
 * Fetch NFT data from Helius using getAsset
 */
async function fetchNFTFromHelius(mintAddress) {
  const requestBody = {
    jsonrpc: '2.0',
    id: 'my-id',
    method: 'getAsset',
    params: {
      id: mintAddress
    }
  };
  
  try {
    const response = await axios.post(
      `https://rpc.helius.xyz/?api-key=${HELIUS_API_KEY}`,
      requestBody,
      {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );
    
    if (response.data.error) {
      console.warn(`⚠️  Error fetching NFT ${mintAddress}:`, response.data.error.message);
      return null;
    }
    
    return response.data.result;
  } catch (error) {
    console.warn(`⚠️  Error fetching NFT ${mintAddress}:`, error.message);
    return null;
  }
}

/**
 * Fetch metadata JSON from URI
 */
async function fetchMetadata(uri) {
  if (!uri) return null;
  
  try {
    // Handle IPFS URIs
    let url = uri;
    if (uri.startsWith('ipfs://')) {
      const ipfsHash = uri.replace('ipfs://', '');
      url = `https://gateway.pinata.cloud/ipfs/${ipfsHash}`;
    } else if (uri.startsWith('https://')) {
      url = uri;
    } else {
      // Try common IPFS gateways
      const ipfsHash = uri.replace(/^ipfs:\/\//, '').replace(/^\/ipfs\//, '');
      url = `https://gateway.pinata.cloud/ipfs/${ipfsHash}`;
    }
    
    const response = await axios.get(url, { timeout: 10000 });
    return response.data;
  } catch (error) {
    console.warn(`⚠️  Failed to fetch metadata from ${uri}:`, error.message);
    return null;
  }
}

/**
 * Upsert NFT into database
 */
async function upsertNFT(client, nft, metadata) {
  const nftMetadata = nft.content?.metadata || {};
  const creators = nftMetadata.creators || nft.creators || [];
  const collection = nft.content?.collection || 
                     nft.grouping?.find((g) => g.groupKey === 'collection') || 
                     null;
  const files = nft.content?.files || [];
  const imageUrl = nftMetadata.image || 
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
      rarity_rank
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9
    )
    ON CONFLICT (mint_address) DO UPDATE SET
      name = EXCLUDED.name,
      symbol = COALESCE(nft_metadata.symbol, EXCLUDED.symbol),
      uri = COALESCE(nft_metadata.uri, EXCLUDED.uri),
      creators = COALESCE(nft_metadata.creators, EXCLUDED.creators),
      collection = COALESCE(nft_metadata.collection, EXCLUDED.collection),
      image_url = COALESCE(nft_metadata.image_url, EXCLUDED.image_url),
      owner_wallet = EXCLUDED.owner_wallet,
      rarity_rank = COALESCE(nft_metadata.rarity_rank, EXCLUDED.rarity_rank)
  `;

  const values = [
    nft.id,
    nftMetadata.name || nft.content?.metadata?.name || null,
    COLLECTION_SYMBOL,
    nftMetadata.uri || nft.content?.json_uri || null,
    creators.length > 0 ? JSON.stringify(creators) : null,
    collection ? JSON.stringify(collection) : null,
    imageUrl,
    nft.ownership?.owner || null,
    nft.rarity?.rank || null
  ];

  await client.query(query, values);
}

/**
 * Main import function
 */
async function main() {
  console.log('🚀 Starting KBDS RMX Collection Import\n');
  console.log(`Collection Slug: ${COLLECTION_SLUG}`);
  console.log(`Collection Symbol: ${COLLECTION_SYMBOL}\n`);
  console.log('⚠️  Note: Using Magic Eden listings to discover NFTs (no verified collection address)\n');

  const client = await pool.connect();
  
  try {
    // Step 1: Discover NFTs from Magic Eden listings
    const mintAddresses = await fetchMintAddressesFromListings();
    
    if (mintAddresses.length === 0) {
      console.log('❌ No NFTs found in Magic Eden listings');
      return;
    }

    console.log(`\n📥 Processing ${mintAddresses.length} NFTs...\n`);
    
    let processed = 0;
    let successful = 0;
    let failed = 0;

    for (const mintAddress of mintAddresses) {
      try {
        // Fetch NFT data from Helius
        const nft = await fetchNFTFromHelius(mintAddress);
        
        if (!nft) {
          failed++;
          continue;
        }
        
        // Fetch metadata JSON if available
        const uri = nft.content?.json_uri || nft.content?.metadata?.uri || null;
        let metadata = null;
        
        if (uri) {
          metadata = await fetchMetadata(uri);
        }
        
        // Upsert NFT into database
        await upsertNFT(client, nft, metadata);
        
        successful++;
        processed++;
        
        if (processed % 10 === 0) {
          console.log(`✅ Processed ${processed}/${mintAddresses.length} NFTs... (${successful} successful, ${failed} failed)`);
        }
        
        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        console.error(`❌ Error processing NFT ${mintAddress}:`, error.message);
        failed++;
        processed++;
      }
    }

    console.log(`\n✅ Import complete!\n`);
    console.log(`📊 Statistics:`);
    console.log(`   Total NFTs processed: ${processed}`);
    console.log(`   Successfully imported: ${successful}`);
    console.log(`   Failed: ${failed}\n`);
    
    if (failed > 0) {
      console.log(`⚠️  Warning: ${failed} NFTs could not be imported.`);
      console.log(`   These may need manual review.`);
    }
    
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

