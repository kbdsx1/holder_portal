import pkg from 'discord.js';
const { Client, GatewayIntentBits, Partials } = pkg;
import pkg2 from 'pg';
const { Pool } = pkg2;

const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: {
    rejectUnauthorized: false,
    sslmode: 'require'
  }
});

// Cache roles data
let rolesCache = null;
let rolesCacheTimestamp = null;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

let discordClient = null;

// Function to get or initialize Discord client
async function getDiscordClient() {
  if (!discordClient) {
    try {
      console.log('Initializing Discord client...');
      discordClient = new Client({
        intents: [
          GatewayIntentBits.Guilds,
          GatewayIntentBits.GuildMembers,
          GatewayIntentBits.GuildPresences,
          GatewayIntentBits.GuildMessages
        ],
        partials: [
          Partials.User,
          Partials.GuildMember,
          Partials.Message
        ]
      });

      // Set up event handlers
      discordClient.on('ready', () => {
        console.log(`Logged in as ${discordClient.user.tag}`);
      });

      discordClient.on('error', (error) => {
        console.error('Discord client error:', error);
        discordClient = null;
      });

      // Login
      await discordClient.login(process.env.DISCORD_BOT_TOKEN);
      console.log('Discord client login successful');
    } catch (error) {
      console.error('Failed to initialize Discord client:', error);
      discordClient = null;
      return null;
    }
  }
  return discordClient;
}

// Function to get roles from database
async function getRoles() {
  // Check cache first
  const now = Date.now();
  if (rolesCache && rolesCacheTimestamp && (now - rolesCacheTimestamp < CACHE_DURATION)) {
    return rolesCache;
  }

  const client = await pool.connect();
  try {
    const result = await client.query('SELECT * FROM roles ORDER BY type, collection');
    rolesCache = result.rows;
    rolesCacheTimestamp = now;
    return result.rows;
  } finally {
    client.release();
  }
}

// Function to sync user roles
export async function syncUserRoles(discordId, guildId) {
  console.log(`Syncing roles for user ${discordId} in guild ${guildId}`);
  
  const client = await pool.connect();
  try {
    // Get user's role flags from user_roles
    const userResult = await client.query(
      `SELECT * FROM user_roles WHERE discord_id = $1`,
      [discordId]
    );

    if (userResult.rowCount === 0) {
      console.log(`No user_roles entry found for Discord ID: ${discordId}`);
      return false;
    }

    const userRoles = userResult.rows[0];
    console.log('User roles from database:', userRoles);
    
    const roles = await getRoles();
    console.log('Available roles:', roles);
    
    // Get Discord client
    const discord = await getDiscordClient();
    if (!discord) {
      console.error('Discord client unavailable - skipping role sync');
      return false;
    }
    
    // Get Discord guild and member
    try {
      console.log('Fetching guild...');
      const guild = await discord.guilds.fetch(guildId);
      console.log('Guild fetched:', guild.name);
      
      console.log('Fetching member...');
      const member = await guild.members.fetch(discordId);
      console.log('Member fetched:', member.user.tag);
      
      if (!member) {
        console.log(`Member ${discordId} not found in guild ${guildId}`);
        return false;
      }

      // --- Update discord_name in user_roles and claim_accounts if changed ---
      if (member && member.user && member.user.username) {
        const newDiscordName = member.user.username;
        if (userRoles.discord_name !== newDiscordName) {
          await client.query(
            'UPDATE user_roles SET discord_name = $1 WHERE discord_id = $2',
            [newDiscordName, discordId]
          );
          // Optionally update in claim_accounts as well
          await client.query(
            'UPDATE claim_accounts SET discord_name = $1 WHERE discord_id = $2',
            [newDiscordName, discordId]
          );
          console.log(`Updated discord_name for ${discordId} to ${newDiscordName}`);
        }
      }
      // --- Fetch user's avatar URL for use in embeds ---
      // const avatarUrl = member.user.displayAvatarURL();

      // Track role changes
      const rolesToAdd = [];
      const rolesToRemove = [];

      // Get the list of role IDs we manage from the roles table
      const managedRoleIds = roles.map(r => r.discord_role_id);

      // Check each role
      for (const role of roles) {
        const shouldHaveRole = checkRoleEligibility(userRoles, role);
        const hasRole = member.roles.cache.has(role.discord_role_id);
        console.log(`Role ${role.name}: Should have - ${shouldHaveRole}, Has role - ${hasRole}`);

        if (shouldHaveRole && !hasRole) {
          rolesToAdd.push(role.discord_role_id);
        } else if (!shouldHaveRole && hasRole) {
          // Only remove roles that we manage
          if (managedRoleIds.includes(role.discord_role_id)) {
            rolesToRemove.push(role.discord_role_id);
          }
        }
      }

      console.log('Roles to add:', rolesToAdd);
      console.log('Roles to remove:', rolesToRemove);

      // Apply role changes
      if (rolesToAdd.length > 0) {
        try {
          await member.roles.add(rolesToAdd);
          console.log(`Added roles for ${discordId}:`, rolesToAdd);
        } catch (error) {
          console.error('Error adding roles:', error);
        }
      }

      if (rolesToRemove.length > 0) {
        try {
          await member.roles.remove(rolesToRemove);
          console.log(`Removed roles for ${discordId}:`, rolesToRemove);
        } catch (error) {
          console.error('Error removing roles:', error);
        }
      }

      return true;
    } catch (error) {
      console.error('Discord API error:', error);
      return false;
    }
  } catch (error) {
    console.error('Error syncing user roles:', error);
    return false;
  } finally {
    client.release();
  }
}

// Helper function to check if user should have a role
function checkRoleEligibility(userRoles, role) {
  let isEligible = false;
  
  switch (role.type) {
    case 'holder':
      switch (role.collection) {
        case 'fcked_catz':
          isEligible = userRoles.fcked_catz_holder;
          break;
        case 'money_monsters':
          isEligible = userRoles.money_monsters_holder;
          break;
        case 'ai_bitbots':
          isEligible = userRoles.ai_bitbots_holder;
          break;
        case 'moneymonsters3d':
          isEligible = userRoles.moneymonsters3d_holder;
          break;
        case 'celebcatz':
          isEligible = userRoles.celebcatz_holder;
          break;
      }
      break;

    case 'whale':
      switch (role.collection) {
        case 'fcked_catz':
          isEligible = userRoles.fcked_catz_whale;
          break;
        case 'money_monsters':
          isEligible = userRoles.money_monsters_whale;
          break;
        case 'ai_bitbots':
          isEligible = userRoles.ai_bitbots_whale;
          break;
        case 'moneymonsters3d':
          isEligible = userRoles.moneymonsters3d_whale;
          break;
      }
      break;

    case 'token':
      if (role.collection === 'bux') {
        switch (role.name) {
          case 'BUX Beginner':
            isEligible = userRoles.bux_beginner;
            break;
          case 'BUX Builder':
            isEligible = userRoles.bux_builder;
            break;
          case 'BUX Saver':
            isEligible = userRoles.bux_saver;
            break;
          case 'BUX Banker':
            isEligible = userRoles.bux_banker;
            break;
        }
      }
      break;

    case 'special':
      if (role.name === 'BUXDAO 5') {
        isEligible = userRoles.buxdao_5;
      }
      break;

    case 'collab':
      switch (role.collection) {
        case 'shxbb':
          isEligible = userRoles.shxbb_holder;
          break;
        case 'ausqrl':
          isEligible = userRoles.ausqrl_holder;
          break;
        case 'aelxaibb':
          isEligible = userRoles.aelxaibb_holder;
          break;
        case 'airb':
          isEligible = userRoles.airb_holder;
          break;
        case 'clb':
          isEligible = userRoles.clb_holder;
          break;
        case 'ddbot':
          isEligible = userRoles.ddbot_holder;
          break;
      }
      break;

    case 'top10':
      if (role.collection === 'money_monsters') {
        isEligible = userRoles.money_monsters_top_10 > 0;
      } else if (role.collection === 'moneymonsters3d') {
        isEligible = userRoles.money_monsters_3d_top_10 > 0;
      }
      break;
  }

  console.log(`Checking eligibility for ${role.name}: ${isEligible}`);
  return isEligible;
} 