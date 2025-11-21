import expressPkg from 'express';
import dbPool from '../config/database.js';
import { parse } from 'cookie';

const userWalletsRouter = expressPkg.Router();

// GET /api/user/wallets - returns all wallets linked to the current Discord user
userWalletsRouter.get('/', async (req, res) => {
  // Fallback auth: hydrate session from cookie in serverless
  if (!req.session?.user) {
    const cookies = parse(req.headers.cookie || '');
    if (cookies.discord_user) {
      try {
        const user = JSON.parse(cookies.discord_user);
        req.session = req.session || {};
        req.session.user = {
          discord_id: user.id || user.discord_id,
          discord_username: user.username || user.discord_username,
          discord_display_name: user.discord_display_name || user.global_name || user.display_name || user.username,
          avatar: user.avatar || null
        };
      } catch {
        // ignore parse errors
      }
    }
  }
  if (!req.session?.user?.discord_id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  try {
    const result = await dbPool.query(
      'SELECT wallet_address FROM user_wallets WHERE discord_id = $1',
      [req.session.user.discord_id]
    );
    const wallets = result.rows.map(row => ({
      wallet_address: row.wallet_address
    }));
    res.json({ wallets });
  } catch (error) {
    console.error('Error fetching user wallets:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/user/wallets - add a new wallet for the current Discord user
userWalletsRouter.post('/', async (req, res) => {
  // Fallback auth: hydrate session from cookie in serverless
  if (!req.session?.user) {
    const cookies = parse(req.headers.cookie || '');
    if (cookies.discord_user) {
      try {
        const user = JSON.parse(cookies.discord_user);
        req.session = req.session || {};
        req.session.user = {
          discord_id: user.id || user.discord_id,
          discord_username: user.username || user.discord_username,
          discord_display_name: user.discord_display_name || user.global_name || user.display_name || user.username,
          avatar: user.avatar || null
        };
      } catch {
        // ignore parse errors
      }
    }
  }
  if (!req.session?.user?.discord_id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  const { wallet_address } = req.body;
  if (!wallet_address) {
    return res.status(400).json({ error: 'Missing wallet_address' });
  }
  try {
    const discordId = req.session.user.discord_id;
    const discordName = req.session.user.discord_username || req.session.user.discord_name || null;

    // Insert wallet if not already present
    await dbPool.query(
      `INSERT INTO user_wallets (discord_id, wallet_address, discord_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (discord_id, wallet_address) DO UPDATE SET discord_name = EXCLUDED.discord_name`,
      [discordId, wallet_address, discordName]
    );

    // Sync ownership in nft_metadata for this wallet
    await dbPool.query(
      `
        UPDATE nft_metadata
        SET owner_discord_id = $1,
            owner_name = $2
        WHERE owner_wallet = $3
      `,
      [discordId, discordName, wallet_address]
    );

    // Upsert collection_counts per-colour and totals for this user
    // First ensure cNFT columns exist
    try {
      await dbPool.query(`
        ALTER TABLE collection_counts 
        ADD COLUMN IF NOT EXISTS cnft_gold_count INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS cnft_silver_count INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS cnft_purple_count INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS cnft_dark_green_count INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS cnft_light_green_count INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS cnft_total_count INTEGER DEFAULT 0
      `);
    } catch (error) {
      // Columns might already exist, ignore
      if (error.code !== '42701') console.error('Error adding cNFT columns:', error.message);
    }

    await dbPool.query(
      `
        INSERT INTO collection_counts (
          discord_id, discord_name,
          -- OG Collection burrow counts
          underground_count, outer_count, motor_city_count, neon_row_count,
          city_gardens_count, stream_town_count, jabberjaw_count, none_count, og_total_count,
          -- YOTR Collection burrow counts
          yotr_underground_count, yotr_outer_count, yotr_motor_city_count, yotr_neon_row_count,
          yotr_city_gardens_count, yotr_stream_town_count, yotr_jabberjaw_count, yotr_nomad_count, yotr_total_count,
          -- Art and Pinups
          art_count,
          pinups_total_count, pinups_underground_count, pinups_outer_count, pinups_motor_city_count,
          pinups_neon_row_count, pinups_city_gardens_count, pinups_stream_town_count, pinups_jabberjaw_count,
          total_count, last_updated
        )
        SELECT
          $1::varchar AS discord_id,
          $2::varchar AS discord_name,
          -- OG Collection (KBDS_OG) burrow counts
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Underground') AS underground_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Outer') AS outer_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Motor City') AS motor_city_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Neon Row') AS neon_row_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'City Gardens') AS city_gardens_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Stream Town') AS stream_town_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'Jabberjaw') AS jabberjaw_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG' AND nm.burrows = 'None') AS none_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_OG') AS og_total_count,
          -- YOTR Collection (KBDS_YOTR) burrow counts
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Underground') AS yotr_underground_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Outer') AS yotr_outer_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Motor City') AS yotr_motor_city_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Neon Row') AS yotr_neon_row_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'City Gardens') AS yotr_city_gardens_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Stream Town') AS yotr_stream_town_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Jabberjaw') AS yotr_jabberjaw_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR' AND nm.burrows = 'Nomad') AS yotr_nomad_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_YOTR') AS yotr_total_count,
          -- Art Collection (KBDS_ART)
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_ART') AS art_count,
          -- Pinups Collection (KBDS_PINUPS) burrow counts
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS') AS pinups_total_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Underground') AS pinups_underground_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Outer') AS pinups_outer_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Motor City') AS pinups_motor_city_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Neon Row') AS pinups_neon_row_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'City Gardens') AS pinups_city_gardens_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Stream Town') AS pinups_stream_town_count,
          COUNT(*) FILTER (WHERE nm.symbol = 'KBDS_PINUPS' AND nm.burrows = 'Jabberjaw') AS pinups_jabberjaw_count,
          -- Total count (all KBDS collections)
          COUNT(*) FILTER (WHERE nm.symbol IN ('KBDS_OG', 'KBDS_YOTR', 'KBDS_ART', 'KBDS_PINUPS')) AS total_count,
          NOW() AS last_updated
        FROM nft_metadata nm
        WHERE EXISTS (
          SELECT 1 FROM user_wallets uw 
          WHERE uw.discord_id = $1::varchar 
          AND uw.wallet_address = nm.owner_wallet
        )
        ON CONFLICT (discord_id) DO UPDATE SET
          discord_name = EXCLUDED.discord_name,
          -- OG Collection
          underground_count = EXCLUDED.underground_count,
          outer_count = EXCLUDED.outer_count,
          motor_city_count = EXCLUDED.motor_city_count,
          neon_row_count = EXCLUDED.neon_row_count,
          city_gardens_count = EXCLUDED.city_gardens_count,
          stream_town_count = EXCLUDED.stream_town_count,
          jabberjaw_count = EXCLUDED.jabberjaw_count,
          none_count = EXCLUDED.none_count,
          og_total_count = EXCLUDED.og_total_count,
          -- YOTR Collection
          yotr_underground_count = EXCLUDED.yotr_underground_count,
          yotr_outer_count = EXCLUDED.yotr_outer_count,
          yotr_motor_city_count = EXCLUDED.yotr_motor_city_count,
          yotr_neon_row_count = EXCLUDED.yotr_neon_row_count,
          yotr_city_gardens_count = EXCLUDED.yotr_city_gardens_count,
          yotr_stream_town_count = EXCLUDED.yotr_stream_town_count,
          yotr_jabberjaw_count = EXCLUDED.yotr_jabberjaw_count,
          yotr_nomad_count = EXCLUDED.yotr_nomad_count,
          yotr_total_count = EXCLUDED.yotr_total_count,
          -- Art and Pinups
          art_count = EXCLUDED.art_count,
          pinups_total_count = EXCLUDED.pinups_total_count,
          pinups_underground_count = EXCLUDED.pinups_underground_count,
          pinups_outer_count = EXCLUDED.pinups_outer_count,
          pinups_motor_city_count = EXCLUDED.pinups_motor_city_count,
          pinups_neon_row_count = EXCLUDED.pinups_neon_row_count,
          pinups_city_gardens_count = EXCLUDED.pinups_city_gardens_count,
          pinups_stream_town_count = EXCLUDED.pinups_stream_town_count,
          pinups_jabberjaw_count = EXCLUDED.pinups_jabberjaw_count,
          total_count = EXCLUDED.total_count,
          last_updated = NOW()
      `,
      [discordId, discordName]
    );

    // Counts are automatically updated by the INSERT above

    // Attach wallet ownership on token_holders (preserves existing balance if any)
    await dbPool.query(
      `
        INSERT INTO token_holders (wallet_address, owner_discord_id, owner_name, last_updated)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (wallet_address) DO UPDATE SET
          owner_discord_id = EXCLUDED.owner_discord_id,
          owner_name = EXCLUDED.owner_name,
          last_updated = NOW()
      `,
      [wallet_address, discordId, discordName]
    );

    // Update harvester flags based on collection_counts (1+ cNFT = eligible)
    // Ensure harvester columns exist
    const harvesterColumns = [
      'harvester_gold',
      'harvester_silver',
      'harvester_purple',
      'harvester_dark_green',
      'harvester_light_green'
    ];
    
    for (const col of harvesterColumns) {
      try {
        await dbPool.query(`ALTER TABLE user_roles ADD COLUMN IF NOT EXISTS ${col} BOOLEAN DEFAULT FALSE`);
      } catch (error) {
        if (error.code !== '42701') console.error(`Error adding ${col}:`, error.message);
      }
    }

    // Update harvester flags from collection_counts
    await dbPool.query(
      `
        INSERT INTO user_roles (discord_id, harvester_gold, harvester_silver, harvester_purple, harvester_dark_green, harvester_light_green)
        SELECT 
          $1::varchar,
          (cnft_gold_count > 0) AS harvester_gold,
          (cnft_silver_count > 0) AS harvester_silver,
          (cnft_purple_count > 0) AS harvester_purple,
          (cnft_dark_green_count > 0) AS harvester_dark_green,
          (cnft_light_green_count > 0) AS harvester_light_green
        FROM collection_counts
        WHERE discord_id = $1::varchar
        ON CONFLICT (discord_id) DO UPDATE SET
          harvester_gold = EXCLUDED.harvester_gold,
          harvester_silver = EXCLUDED.harvester_silver,
          harvester_purple = EXCLUDED.harvester_purple,
          harvester_dark_green = EXCLUDED.harvester_dark_green,
          harvester_light_green = EXCLUDED.harvester_light_green
      `,
      [discordId]
    );

    // Rebuild roles JSON from collection_counts + roles catalog (includes harvester flags)
    await dbPool.query('SELECT rebuild_user_roles($1::varchar)', [discordId]);

    // Automatically sync Discord roles after wallet link
    const { syncUserRoles } = await import('../integrations/discord/roles.js');
    const guildId = process.env.DISCORD_GUILD_ID;
    if (guildId) {
      syncUserRoles(discordId, guildId).catch(err => {
        console.error('[Wallet Link] Error syncing roles (non-blocking):', err);
      });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error adding user wallet:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default userWalletsRouter; 