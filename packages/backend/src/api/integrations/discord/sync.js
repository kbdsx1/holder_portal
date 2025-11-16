import { syncUserRoles } from './roles.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { discord_id } = req.body;
  const guildId = process.env.DISCORD_GUILD_ID;

  if (!discord_id) {
    return res.status(400).json({ error: 'Missing discord_id in request body' });
  }

  try {
    const success = await syncUserRoles(discord_id, guildId);
    if (success) {
      res.json({ message: 'Roles synced successfully' });
    } else {
      res.status(500).json({ error: 'Failed to sync roles' });
    }
  } catch (error) {
    console.error('Error syncing roles:', error);
    res.status(500).json({ error: 'Internal server error', details: error.message });
  }
} 