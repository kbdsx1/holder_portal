// Daily Rewards Processing Script
// This script processes daily rewards for all users based on their current daily_rewards entries
// The daily_rewards table now has one entry per user that stays updated via triggers
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { Pool } from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: `${__dirname}/.env` });

// Database connection
const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function processDailyRewards() {
  console.log(`\n[${new Date().toISOString()}] Starting daily rewards processing...`);
  
  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');

    console.log('Connected to database. Processing daily rewards...');

    // Update claim_accounts with the current daily rewards from daily_rewards table
    const updateResult = await client.query(`
      UPDATE claim_accounts ca
      SET unclaimed_amount = unclaimed_amount + dr.total_daily_reward
      FROM daily_rewards dr
      WHERE ca.discord_id = dr.discord_id
      AND dr.total_daily_reward > 0
    `);
    console.log(`Updated ${updateResult.rowCount} claim accounts with daily rewards`);

    // Get stats about processed rewards
    const stats = await client.query(`
      SELECT 
        COUNT(*) as processed_count,
        SUM(total_daily_reward) as total_rewards
      FROM daily_rewards
      WHERE total_daily_reward > 0
    `);

    await client.query('COMMIT');

    const statsData = stats.rows[0];
    console.log('\n=== DAILY REWARDS PROCESSING COMPLETE ===');
    console.log(`Processed Count: ${statsData.processed_count}`);
    console.log(`Total Rewards Distributed: ${statsData.total_rewards} BUX`);
    console.log(`Timestamp: ${new Date().toISOString()}`);
    console.log('==========================================\n');

    return {
      success: true,
      message: 'Daily rewards processed successfully',
      stats: statsData
    };

  } catch (error) {
    if (client) {
      await client.query('ROLLBACK');
    }
    console.error('Error processing daily rewards:', error);
    throw error;
  } finally {
    if (client) {
      client.release();
    }
    await pool.end();
  }
}

// Run the script if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  processDailyRewards()
    .then(result => {
      console.log('Daily rewards processing completed successfully:', result);
      process.exit(0);
    })
    .catch(error => {
      console.error('Daily rewards processing failed:', error);
      process.exit(1);
    });
}

export default processDailyRewards; 