import dbPool from '../config/database.js';
import { parse } from 'cookie';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

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
    const client = await dbPool.connect();

    try {
      const discordId = req.session.user.discord_id;

      const [countsResult, walletsResult] = await Promise.all([
        client.query(
          `
            SELECT 
              -- OG Collection burrow counts
              COALESCE(underground_count, 0) as underground_count,
              COALESCE(outer_count, 0) as outer_count,
              COALESCE(motor_city_count, 0) as motor_city_count,
              COALESCE(neon_row_count, 0) as neon_row_count,
              COALESCE(city_gardens_count, 0) as city_gardens_count,
              COALESCE(stream_town_count, 0) as stream_town_count,
              COALESCE(jabberjaw_count, 0) as jabberjaw_count,
              COALESCE(none_count, 0) as none_count,
              COALESCE(og_total_count, 0) as og_total_count,
              -- YOTR Collection burrow counts
              COALESCE(yotr_underground_count, 0) as yotr_underground_count,
              COALESCE(yotr_outer_count, 0) as yotr_outer_count,
              COALESCE(yotr_motor_city_count, 0) as yotr_motor_city_count,
              COALESCE(yotr_neon_row_count, 0) as yotr_neon_row_count,
              COALESCE(yotr_city_gardens_count, 0) as yotr_city_gardens_count,
              COALESCE(yotr_stream_town_count, 0) as yotr_stream_town_count,
              COALESCE(yotr_jabberjaw_count, 0) as yotr_jabberjaw_count,
              COALESCE(yotr_nomad_count, 0) as yotr_nomad_count,
              COALESCE(yotr_total_count, 0) as yotr_total_count,
              -- Art and Pinups
              COALESCE(art_count, 0) as art_count,
              COALESCE(pinups_total_count, 0) as pinups_total_count,
              COALESCE(pinups_underground_count, 0) as pinups_underground_count,
              COALESCE(pinups_outer_count, 0) as pinups_outer_count,
              COALESCE(pinups_motor_city_count, 0) as pinups_motor_city_count,
              COALESCE(pinups_neon_row_count, 0) as pinups_neon_row_count,
              COALESCE(pinups_city_gardens_count, 0) as pinups_city_gardens_count,
              COALESCE(pinups_stream_town_count, 0) as pinups_stream_town_count,
              COALESCE(pinups_jabberjaw_count, 0) as pinups_jabberjaw_count,
              COALESCE(total_count, 0) as total_count
            FROM collection_counts
            WHERE discord_id = $1
          `,
          [discordId]
        ),
        client.query(
          `
            SELECT wallet_address
            FROM user_wallets
            WHERE discord_id = $1
          `,
          [discordId]
        )
      ]);

      const counts = countsResult.rows[0] || {};
      const walletAddresses = walletsResult.rows.map(row => row.wallet_address).filter(Boolean);
      
      // Daily yield rates (placeholder - update with actual rates)
      const yieldRates = {
        underground: 1,
        outer: 1,
        motor_city: 1,
        neon_row: 1,
        city_gardens: 1,
        stream_town: 1,
        jabberjaw: 1,
        none: 1,
        nomad: 1,
        art: 1,
        pinups: 1
      };

      // Calculate daily yields for OG burrows
      const ogDailyYields = {
        underground: (counts.underground_count || 0) * yieldRates.underground,
        outer: (counts.outer_count || 0) * yieldRates.outer,
        motor_city: (counts.motor_city_count || 0) * yieldRates.motor_city,
        neon_row: (counts.neon_row_count || 0) * yieldRates.neon_row,
        city_gardens: (counts.city_gardens_count || 0) * yieldRates.city_gardens,
        stream_town: (counts.stream_town_count || 0) * yieldRates.stream_town,
        jabberjaw: (counts.jabberjaw_count || 0) * yieldRates.jabberjaw,
        none: (counts.none_count || 0) * yieldRates.none
      };

      // Calculate daily yields for YOTR burrows
      const yotrDailyYields = {
        underground: (counts.yotr_underground_count || 0) * yieldRates.underground,
        outer: (counts.yotr_outer_count || 0) * yieldRates.outer,
        motor_city: (counts.yotr_motor_city_count || 0) * yieldRates.motor_city,
        neon_row: (counts.yotr_neon_row_count || 0) * yieldRates.neon_row,
        city_gardens: (counts.yotr_city_gardens_count || 0) * yieldRates.city_gardens,
        stream_town: (counts.yotr_stream_town_count || 0) * yieldRates.stream_town,
        jabberjaw: (counts.yotr_jabberjaw_count || 0) * yieldRates.jabberjaw,
        nomad: (counts.yotr_nomad_count || 0) * yieldRates.nomad
      };

      // Calculate daily yields for Pinups burrows
      const pinupsDailyYields = {
        underground: (counts.pinups_underground_count || 0) * yieldRates.underground,
        outer: (counts.pinups_outer_count || 0) * yieldRates.outer,
        motor_city: (counts.pinups_motor_city_count || 0) * yieldRates.motor_city,
        neon_row: (counts.pinups_neon_row_count || 0) * yieldRates.neon_row,
        city_gardens: (counts.pinups_city_gardens_count || 0) * yieldRates.city_gardens,
        stream_town: (counts.pinups_stream_town_count || 0) * yieldRates.stream_town,
        jabberjaw: (counts.pinups_jabberjaw_count || 0) * yieldRates.jabberjaw
      };

      // Art and Pinups totals
      const artDailyYield = (counts.art_count || 0) * yieldRates.art;
      const pinupsDailyYield = (counts.pinups_total_count || 0) * yieldRates.pinups;

      let nfts = [];
      if (walletAddresses.length > 0) {
        const nftResult = await client.query(
          `
            SELECT mint_address, name, image_url, symbol, burrows
            FROM nft_metadata
            WHERE owner_wallet = ANY($1::text[])
            AND symbol IN ('KBDS_OG', 'KBDS_YOTR', 'KBDS_ART', 'KBDS_PINUPS')
            ORDER BY symbol, name NULLS LAST
          `,
          [walletAddresses]
        );
        nfts = nftResult.rows;
      }

      // Calculate total daily yield
      const totalDailyYield = 
        Object.values(ogDailyYields).reduce((sum, y) => sum + y, 0) +
        Object.values(yotrDailyYields).reduce((sum, y) => sum + y, 0) +
        artDailyYield +
        pinupsDailyYield;
      
      return res.json({
        collection: {
          name: 'Knuckle Bunny Death Squad',
          count: counts.total_count || 0,
          daily_yield: totalDailyYield
        },
        counts: {
          // OG burrows (used by OGs tab)
          underground: counts.underground_count || 0,
          outer: counts.outer_count || 0,
          motor_city: counts.motor_city_count || 0,
          neon_row: counts.neon_row_count || 0,
          city_gardens: counts.city_gardens_count || 0,
          stream_town: counts.stream_town_count || 0,
          jabberjaw: counts.jabberjaw_count || 0,
          none: counts.none_count || 0,
          // YOTR burrows (used by YOTR tab)
          yotr_underground: counts.yotr_underground_count || 0,
          yotr_outer: counts.yotr_outer_count || 0,
          yotr_motor_city: counts.yotr_motor_city_count || 0,
          yotr_neon_row: counts.yotr_neon_row_count || 0,
          yotr_city_gardens: counts.yotr_city_gardens_count || 0,
          yotr_stream_town: counts.yotr_stream_town_count || 0,
          yotr_jabberjaw: counts.yotr_jabberjaw_count || 0,
          nomad: counts.yotr_nomad_count || 0,
          // Others
          art: counts.art_count || 0,
          pinups: counts.pinups_total_count || 0,
          // Pinups burrows
          pinups_underground: counts.pinups_underground_count || 0,
          pinups_outer: counts.pinups_outer_count || 0,
          pinups_motor_city: counts.pinups_motor_city_count || 0,
          pinups_neon_row: counts.pinups_neon_row_count || 0,
          pinups_city_gardens: counts.pinups_city_gardens_count || 0,
          pinups_stream_town: counts.pinups_stream_town_count || 0,
          pinups_jabberjaw: counts.pinups_jabberjaw_count || 0
        },
        daily_yields: {
          // OG burrows
          underground: ogDailyYields.underground,
          outer: ogDailyYields.outer,
          motor_city: ogDailyYields.motor_city,
          neon_row: ogDailyYields.neon_row,
          city_gardens: ogDailyYields.city_gardens,
          stream_town: ogDailyYields.stream_town,
          jabberjaw: ogDailyYields.jabberjaw,
          none: ogDailyYields.none,
          // YOTR burrows
          yotr_underground: yotrDailyYields.underground,
          yotr_outer: yotrDailyYields.outer,
          yotr_motor_city: yotrDailyYields.motor_city,
          yotr_neon_row: yotrDailyYields.neon_row,
          yotr_city_gardens: yotrDailyYields.city_gardens,
          yotr_stream_town: yotrDailyYields.stream_town,
          yotr_jabberjaw: yotrDailyYields.jabberjaw,
          nomad: yotrDailyYields.nomad,
          // Others
          art: artDailyYield,
          pinups: pinupsDailyYield,
          // Pinups burrows
          pinups_underground: pinupsDailyYields.underground,
          pinups_outer: pinupsDailyYields.outer,
          pinups_motor_city: pinupsDailyYields.motor_city,
          pinups_neon_row: pinupsDailyYields.neon_row,
          pinups_city_gardens: pinupsDailyYields.city_gardens,
          pinups_stream_town: pinupsDailyYields.stream_town,
          pinups_jabberjaw: pinupsDailyYields.jabberjaw
        },
        nfts
      });
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Error fetching user holdings:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}
