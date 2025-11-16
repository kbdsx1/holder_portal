import { loadProjectConfig } from './project.js';

function safeDomain(url) {
  try {
    const parsed = new URL(url);
    return parsed.hostname;
  } catch {
    return undefined;
  }
}

export function getRuntimeConfig() {
  const project = loadProjectConfig();
  const frontendUrl = process.env.FRONTEND_URL || project.frontend?.appUrl || 'http://localhost:5173';
  const apiBaseUrl = process.env.API_BASE_URL || project.frontend?.apiBaseUrl || 'http://localhost:3001';

  return {
    project,
    frontendUrl,
    apiBaseUrl,
    cookies: {
      domain: process.env.COOKIE_DOMAIN || safeDomain(frontendUrl),
      secure: process.env.NODE_ENV === 'production'
    },
    discord: {
      clientId: process.env.DISCORD_CLIENT_ID,
      clientSecret: process.env.DISCORD_CLIENT_SECRET,
      botToken: process.env.DISCORD_BOT_TOKEN,
      guildId: project.discord?.guildId,
      holderRoleId: project.discord?.holderRoleId,
      verifiedRoleIds: project.discord?.verifiedRoleIds || [],
      announcementChannelId: project.discord?.announcementChannelId
    },
    solana: {
      rpcUrl: process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
      treasurySecret: process.env.TREASURY_WALLET_SECRET_KEY,
      claimProgramId: process.env.CLAIM_PROGRAM_ID || project.rewards?.claimProgramId,
      tokenMint: project.rewards?.tokenMint
    },
    rewards: {
      currency: project.rewards?.currency || 'TOKEN',
      treasuryWallet: project.rewards?.treasuryWallet,
      dailyEmission: project.rewards?.dailyEmission,
      cooldownHours: project.rewards?.cooldownHours
    }
  };
}
