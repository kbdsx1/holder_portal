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

    // Check if rewards were already processed today (prevent double processing)
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setUTCDate(todayEnd.getUTCDate() + 1);

    const alreadyProcessed = await client.query(`
      SELECT COUNT(*) as count
      FROM daily_rewards
      WHERE last_accumulated_at >= $1
      AND last_accumulated_at < $2
      AND total_daily_reward > 0
    `, [todayStart.toISOString(), todayEnd.toISOString()]);

    if (Number(alreadyProcessed.rows[0]?.count || 0) > 0) {
      console.log(`⚠️  Rewards already processed today (${alreadyProcessed.rows[0].count} users). Skipping to prevent double payment.`);
      await client.query('ROLLBACK');
      return {
        success: true,
        message: 'Rewards already processed today - skipped to prevent double payment',
        skipped: true
      };
    }

    // First, ensure claim_accounts exists for all users with daily_rewards
    const createResult = await client.query(`
      INSERT INTO claim_accounts (discord_id, discord_name, unclaimed_amount)
      SELECT dr.discord_id, dr.discord_name, 0
      FROM daily_rewards dr
      WHERE NOT EXISTS (
        SELECT 1 FROM claim_accounts ca WHERE ca.discord_id = dr.discord_id
      )
      AND dr.total_daily_reward > 0
    `);
    console.log(`Created ${createResult.rowCount} new claim accounts`);

    // Update claim_accounts with the current daily rewards from daily_rewards table
    // Also update last_accumulated_at to prevent double processing
    const updateResult = await client.query(`
      UPDATE claim_accounts ca
      SET unclaimed_amount = unclaimed_amount + dr.total_daily_reward
      FROM daily_rewards dr
      WHERE ca.discord_id = dr.discord_id
      AND dr.total_daily_reward > 0
    `);
    console.log(`Updated ${updateResult.rowCount} claim accounts with daily rewards`);

    // Mark rewards as accumulated for today
    await client.query(`
      UPDATE daily_rewards
      SET last_accumulated_at = NOW()
      WHERE total_daily_reward > 0
    `);
    console.log(`Marked rewards as accumulated for today`);

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
    console.log(`Total Rewards Distributed: ${statsData.total_rewards} $CSz420`);
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