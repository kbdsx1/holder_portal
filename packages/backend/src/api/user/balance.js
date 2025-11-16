import expressPkg from 'express';
import dbPool from '../config/database.js';
import { parse } from 'cookie';

const userBalanceRouter = expressPkg.Router();

// GET /api/user/balance - sum token balance from token_holders for current user
userBalanceRouter.get('/', async (req, res) => {
  try {
    // Hydrate session from cookie if needed
    if (!req.session?.user) {
      const cookies = parse(req.headers.cookie || '');
      if (cookies.discord_user) {
        try {
          const user = JSON.parse(cookies.discord_user);
          req.session = req.session || {};
          req.session.user = {
            discord_id: user.id || user.discord_id
          };
        } catch {
          // ignore
        }
      }
    }
    if (!req.session?.user?.discord_id) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    // First try to get balance by owner_discord_id
    let { rows } = await dbPool.query(
      `SELECT COALESCE(SUM(balance),0) AS balance
       FROM token_holders
       WHERE owner_discord_id = $1`,
      [req.session.user.discord_id]
    );
    
    let balance = Number(rows[0]?.balance || 0);
    
    // Fallback: if no balance found by owner_discord_id, check wallets from user_wallets
    if (balance === 0) {
      const walletRows = await dbPool.query(
        `SELECT wallet_address FROM user_wallets WHERE discord_id = $1`,
        [req.session.user.discord_id]
      );
      
      if (walletRows.rows.length > 0) {
        const walletAddresses = walletRows.rows.map(r => r.wallet_address);
        const balanceRows = await dbPool.query(
          `SELECT COALESCE(SUM(balance),0) AS balance
           FROM token_holders
           WHERE wallet_address = ANY($1::text[])`,
          [walletAddresses]
        );
        balance = Number(balanceRows.rows[0]?.balance || 0);
        
        // If we found a balance but owner_discord_id is missing, restore it
        if (balance > 0 && walletAddresses.length > 0) {
          await dbPool.query(
            `UPDATE token_holders 
             SET owner_discord_id = $1, owner_name = $2
             WHERE wallet_address = ANY($3::text[]) AND owner_discord_id IS NULL`,
            [req.session.user.discord_id, req.session.user.discord_username || req.session.user.discord_name || null, walletAddresses]
          );
        }
      }
    }
    
    return res.json({ balance });
  } catch (error) {
    console.error('Error fetching user balance:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

export default userBalanceRouter; 