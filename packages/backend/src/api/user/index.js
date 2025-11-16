import express from 'express';
import holdings from './holdings.js';
import claim from './claim.js';
import wallets from './wallets.js';

const router = express.Router();

router.use('/holdings', holdings);
router.use('/claim', claim);
router.use('/wallets', wallets);

export default router; 