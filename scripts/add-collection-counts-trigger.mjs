#!/usr/bin/env node
/**
 * Script to add trigger that rebuilds roles when collection_counts changes
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pkg from 'pg';
const { Pool } = pkg;
import { readFileSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
const rootDir = join(__dirname, '..');
dotenv.config({ path: join(rootDir, 'config/.env') });

const POSTGRES_URL = process.env.POSTGRES_URL;

if (!POSTGRES_URL) {
  console.error('ERROR: POSTGRES_URL environment variable is not set');
  process.exit(1);
}

const pool = new Pool({
  connectionString: POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
});

async function addTrigger() {
  const client = await pool.connect();
  try {
    console.log('\n🔄 Adding trigger to rebuild roles on collection_counts changes...');
    
    // Read and execute SQL file
    const sqlPath = join(__dirname, 'add-collection-counts-trigger.sql');
    const sql = readFileSync(sqlPath, 'utf8');
    
    await client.query(sql);
    
    console.log('✅ Trigger added successfully!');
    console.log('\nThe trigger will now automatically:');
    console.log('  1. Update harvester flags when collection_counts changes');
    console.log('  2. Rebuild roles JSONB array for the user');
    console.log('\nThis ensures roles stay current whenever collection_counts is updated.');
    
  } catch (error) {
    console.error('❌ Error adding trigger:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

addTrigger()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

