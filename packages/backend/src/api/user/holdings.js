import { pool } from '../config/database.js';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!req.session?.user?.discord_id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }

  try {
    const client = await pool.connect();

    try {
      const discordId = req.session.user.discord_id;

      const [countsResult, walletsResult] = await Promise.all([
        client.query(
          `
            SELECT COALESCE(total_count, 0) as total_count
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

      const totalCount = countsResult.rows[0]?.total_count || 0;
      const walletAddresses = walletsResult.rows.map(row => row.wallet_address).filter(Boolean);

      let nfts = [];
      if (walletAddresses.length > 0) {
        const nftResult = await client.query(
          `
            SELECT mint_address, name, image_url
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
          count: totalCount,
          daily_yield: 0
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
