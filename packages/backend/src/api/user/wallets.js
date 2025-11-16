import express from 'express';
import { pool } from '../config/database.js';

const router = express.Router();

// GET /api/user/wallets - returns all wallets linked to the current Discord user
router.get('/', async (req, res) => {
  if (!req.session?.user?.discord_id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  try {
    const result = await pool.query(
      'SELECT wallet_address FROM user_wallets WHERE discord_id = $1',
      [req.session.user.discord_id]
    );
    const wallets = result.rows.map(row => row.wallet_address);
    res.json({ wallets });
  } catch (error) {
    console.error('Error fetching user wallets:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/user/wallets - add a new wallet for the current Discord user
router.post('/', async (req, res) => {
  if (!req.session?.user?.discord_id) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  const { wallet_address } = req.body;
  if (!wallet_address) {
    return res.status(400).json({ error: 'Missing wallet_address' });
  }
  try {
    // Insert wallet if not already present
    await pool.query(
      `INSERT INTO user_wallets (discord_id, wallet_address)
       VALUES ($1, $2)
       ON CONFLICT (discord_id, wallet_address) DO NOTHING`,
      [req.session.user.discord_id, wallet_address]
    );
    res.json({ success: true });
  } catch (error) {
    console.error('Error adding user wallet:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router; 