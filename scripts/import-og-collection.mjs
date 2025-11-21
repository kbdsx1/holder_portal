#!/usr/bin/env node

/**
 * Import KBDS OG Collection
 * Fetches NFTs from the OG collection and populates the nft_metadata table
 * with burrow information extracted from NFT traits
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
const COLLECTION_ADDRESS = 'VkY8idHE9D9JMpjbNdSeSNNeaYWVpoF7U9kynE44CG6';
const COLLECTION_SYMBOL = 'KBDS_OG';
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

// Burrow mapping - maps trait values to database values
const BURROW_MAPPING = {
  'Underground': 'Underground',
  'Outer': 'Outer',
  'Motor City': 'Motor City',
  'Neon Row': 'Neon Row',
  'City Gardens': 'City Gardens',
  'Stream Town': 'Stream Town',
  'Jabberjaw': 'Jabberjaw',
  'None': 'None'
};

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

  console.log(`\n🔍 Fetching NFTs for OG collection (${COLLECTION_ADDRESS})...\n`);

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
 * Extract burrow trait from NFT metadata
 */
function extractBurrow(nft, metadata) {
  // Try multiple sources for traits
  let traits = null;
  
  // Check if traits are in the metadata JSON
  if (metadata?.attributes) {
    traits = metadata.attributes;
  } else if (metadata?.properties?.attributes) {
    traits = metadata.properties.attributes;
  } else if (nft.content?.metadata?.attributes) {
    traits = nft.content.metadata.attributes;
  }
  
  if (!traits || !Array.isArray(traits)) {
    return null;
  }
  
  // Find the burrow trait
  const burrowTrait = traits.find(trait => 
    trait.trait_type?.toLowerCase() === 'burrow' || 
    trait.name?.toLowerCase() === 'burrow'
  );
  
  if (!burrowTrait) {
    return null;
  }
  
  const burrowValue = burrowTrait.value || burrowTrait.value_string;
  if (!burrowValue) {
    return null;
  }
  
  // Map the trait value to database value
  const mappedBurrow = BURROW_MAPPING[burrowValue];
  if (mappedBurrow) {
    return mappedBurrow;
  }
  
  // If not in mapping, return the value as-is (might need manual review)
  console.warn(`⚠️  Unknown burrow value: "${burrowValue}" for NFT ${nft.id}`);
  return burrowValue;
}

/**
 * Upsert NFT into database
 */
async function upsertNFT(client, nft, burrow) {
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
      burrows = COALESCE(EXCLUDED.burrows, nft_metadata.burrows)
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
    burrow || null
  ];

  await client.query(query, values);
}

/**
 * Main import function
 */
async function main() {
  console.log('🚀 Starting KBDS OG Collection Import\n');
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
    let withBurrow = 0;
    let withoutBurrow = 0;
    const burrowCounts = {};

    for (const nft of nfts) {
      try {
        // Fetch metadata JSON
        const uri = nft.content?.json_uri || nft.content?.metadata?.uri || null;
        let metadata = null;
        
        if (uri) {
          metadata = await fetchMetadata(uri);
        }
        
        // Extract burrow trait
        const burrow = extractBurrow(nft, metadata);
        
        if (burrow) {
          withBurrow++;
          burrowCounts[burrow] = (burrowCounts[burrow] || 0) + 1;
        } else {
          withoutBurrow++;
        }
        
        // Upsert NFT into database
        await upsertNFT(client, nft, burrow);
        
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
    console.log(`   Total NFTs processed: ${processed}`);
    console.log(`   NFTs with burrow: ${withBurrow}`);
    console.log(`   NFTs without burrow: ${withoutBurrow}\n`);
    
    if (Object.keys(burrowCounts).length > 0) {
      console.log(`📈 Burrow distribution:`);
      for (const [burrow, count] of Object.entries(burrowCounts).sort((a, b) => b[1] - a[1])) {
        console.log(`   ${burrow}: ${count}`);
      }
    }
    
    if (withoutBurrow > 0) {
      console.log(`\n⚠️  Warning: ${withoutBurrow} NFTs did not have a burrow trait.`);
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

