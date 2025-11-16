import expressPkg from 'express';
import holdings from './holdings.js';
import claim from './claim.js';
import wallets from './wallets.js';
import balance from './balance.js';

const userIndexRouter = expressPkg.Router();

userIndexRouter.use('/holdings', holdings);
userIndexRouter.use('/claim', claim);
userIndexRouter.use('/wallets', wallets);
userIndexRouter.use('/balance', balance);

export default userIndexRouter; 