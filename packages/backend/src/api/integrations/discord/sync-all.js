import pg from 'pg';
import { syncUserRoles } from './roles.js';

const pool = new pg.Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: {
    rejectUnauthorized: false,
    sslmode: 'require'
  }
});

async function syncAllUsers() {
  const client = await pool.connect();
  try {
    console.log('Starting role sync for all users...');
    
    // Get all users with discord_id from user_roles table
    const result = await client.query('SELECT discord_id FROM user_roles WHERE discord_id IS NOT NULL');
    const totalUsers = result.rows.length;
    console.log(`Found ${totalUsers} users to sync`);

    let successCount = 0;
    let failCount = 0;

    // Process users in batches to avoid rate limits
    for (let i = 0; i < result.rows.length; i++) {
      const { discord_id } = result.rows[i];
      try {
        const success = await syncUserRoles(discord_id, process.env.DISCORD_GUILD_ID);
        if (success) {
          successCount++;
        } else {
          failCount++;
          console.error(`Failed to sync roles for user ${discord_id}`);
        }

        // Log progress every 10 users
        if ((i + 1) % 10 === 0) {
          console.log(`Progress: ${i + 1}/${totalUsers} users processed`);
          console.log(`Success: ${successCount}, Failed: ${failCount}`);
        }

        // Add a small delay between users to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        failCount++;
        console.error(`Error syncing roles for user ${discord_id}:`, error);
      }
    }

    console.log('\nRole sync completed!');
    console.log(`Total users: ${totalUsers}`);
    console.log(`Successful syncs: ${successCount}`);
    console.log(`Failed syncs: ${failCount}`);

  } catch (error) {
    console.error('Error in syncAllUsers:', error);
  } finally {
    client.release();
  }
}

// Run the sync
syncAllUsers().catch(console.error); 