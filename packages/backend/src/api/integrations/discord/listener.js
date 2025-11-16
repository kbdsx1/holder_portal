import pg from 'pg';
import { syncUserRoles } from './roles.js';

const pool = new pg.Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
});

async function handleRoleChange(payload) {
  try {
    const data = JSON.parse(payload);
    if (data.event === 'role_update' && data.discord_id) {
      // Directly call syncUserRoles
      const success = await syncUserRoles(data.discord_id, process.env.DISCORD_GUILD_ID);
      if (!success) {
        console.error('Failed to sync roles for user:', data.discord_id);
      }
    }
  } catch (error) {
    console.error('Error handling role change notification:', error);
  }
}

async function startListener() {
  const client = await pool.connect();
  try {
    await client.query('LISTEN role_changes');
    
    client.on('notification', async (msg) => {
      if (msg.channel === 'role_changes') {
        await handleRoleChange(msg.payload);
      }
    });

    console.log('Started listening for role changes');
  } catch (error) {
    console.error('Error in role changes listener:', error);
    client.release();
    // Retry after delay
    setTimeout(startListener, 5000);
  }
}

startListener().catch(console.error); 