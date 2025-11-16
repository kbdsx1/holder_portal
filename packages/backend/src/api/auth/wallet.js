import express from 'express';
import { PublicKey, Connection } from '@solana/web3.js';
import { parse } from 'cookie';
import pkg from 'pg';
const { Pool } = pkg;
import { pool } from '../config/database.js';

const router = express.Router();

const DISCORD_GUILD_ID = process.env.DISCORD_GUILD_ID;
const RPC_URL = process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';

router.post('/', async (req, res) => {
  try {
    // Check for discord_user cookie
    const cookies = req.headers.cookie ? parse(req.headers.cookie) : {};
    const discordUser = cookies.discord_user ? JSON.parse(cookies.discord_user) : null;

    if (!discordUser || !discordUser.discord_id) {
      console.error('Session validation failed:', {
        cookies: !!cookies,
        discordUser: !!discordUser,
        sessionID: req.sessionID
      });
      return res.status(401).json({ 
        success: false,
        error: 'Not authenticated' 
      });
    }

    const { wallet_address } = req.body;
    if (!wallet_address) {
      return res.status(400).json({ 
        success: false,
        error: 'Wallet address is required' 
      });
    }

    // Validate Solana address
    try {
      new PublicKey(wallet_address);
    } catch (err) {
      return res.status(400).json({ 
        success: false,
        error: 'Invalid wallet address' 
      });
    }

    // Create database client
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // Check if wallet already exists for this user
      const existingWallet = await client.query(
        'SELECT * FROM user_wallets WHERE wallet_address = $1 AND discord_id = $2',
        [wallet_address, discordUser.discord_id]
      );

      if (existingWallet.rows.length === 0) {
        // Insert new wallet for this user
        await client.query(
          'INSERT INTO user_wallets (wallet_address, discord_id, discord_username) VALUES ($1, $2, $3)',
          [wallet_address, discordUser.discord_id, discordUser.discord_username]
        );
      }

      await client.query('COMMIT');

      res.json({ 
        success: true,
        message: 'Wallet verified successfully'
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Wallet verification error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

export default router; 