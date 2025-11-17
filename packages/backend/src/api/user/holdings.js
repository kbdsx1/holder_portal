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
              COALESCE(gold_count, 0) as gold_count,
              COALESCE(silver_count, 0) as silver_count,
              COALESCE(purple_count, 0) as purple_count,
              COALESCE(dark_green_count, 0) as dark_green_count,
              COALESCE(light_green_count, 0) as light_green_count,
              COALESCE(og420_count, 0) as og420_count,
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

      // Daily yield rates per NFT
      const yieldRates = {
        og420: 50,
        gold: 30,
        silver: 25,
        purple: 20,
        dark_green: 15,
        light_green: 10
      };

      // Calculate daily yield for each color
      const dailyYields = {
        og420: (counts.og420_count || 0) * yieldRates.og420,
        gold: (counts.gold_count || 0) * yieldRates.gold,
        silver: (counts.silver_count || 0) * yieldRates.silver,
        purple: (counts.purple_count || 0) * yieldRates.purple,
        dark_green: (counts.dark_green_count || 0) * yieldRates.dark_green,
        light_green: (counts.light_green_count || 0) * yieldRates.light_green
      };

      // Total daily yield
      const totalDailyYield = Object.values(dailyYields).reduce((sum, dailyYield) => sum + dailyYield, 0);

      let nfts = [];
      if (walletAddresses.length > 0) {
        const nftResult = await client.query(
          `
            SELECT mint_address, name, image_url, leaf_colour, og420
            FROM nft_metadata
            WHERE owner_wallet = ANY($1::text[])
            ORDER BY name NULLS LAST
          `,
          [walletAddresses]
        );
        nfts = nftResult.rows;
      }

      return res.json({
        collection: {
          name: 'CannaSolz',
          count: counts.total_count || 0,
          daily_yield: totalDailyYield
        },
        counts: {
          og420: counts.og420_count || 0,
          gold: counts.gold_count || 0,
          silver: counts.silver_count || 0,
          purple: counts.purple_count || 0,
          dark_green: counts.dark_green_count || 0,
          light_green: counts.light_green_count || 0,
          total: counts.total_count || 0
        },
        daily_yields: {
          og420: dailyYields.og420,
          gold: dailyYields.gold,
          silver: dailyYields.silver,
          purple: dailyYields.purple,
          dark_green: dailyYields.dark_green,
          light_green: dailyYields.light_green,
          total: totalDailyYield
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
