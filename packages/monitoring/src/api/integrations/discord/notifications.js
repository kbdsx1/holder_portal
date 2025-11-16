import { Client, GatewayIntentBits } from 'discord.js';
import axios from 'axios';

let discordClient = null;

// Function to get or initialize Discord client
async function getDiscordClient() {
  if (discordClient) return discordClient;

  // Log token presence and format
  const token = process.env.DISCORD_BOT_TOKEN;
  console.log('Bot token present:', !!token);
  console.log('Token format:', token ? `${token.substring(0, 10)}...` : 'missing');

  discordClient = new Client({
    intents: [
      GatewayIntentBits.Guilds,
      GatewayIntentBits.GuildMessages,
      GatewayIntentBits.GuildMembers,
      GatewayIntentBits.GuildPresences,
      GatewayIntentBits.DirectMessages,
      GatewayIntentBits.MessageContent
    ],
    rest: {
      retries: 3,
      timeout: 10000
    }
  });

  discordClient.on('ready', () => {
    console.log('Discord client ready');
    console.log('Bot user:', discordClient.user.tag);
  });

  discordClient.on('error', (error) => {
    console.error('Discord client error:', error);
    console.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack
    });
  });

  try {
    await discordClient.login(token);
    console.log('Discord client logged in successfully');
    return discordClient;
  } catch (error) {
    console.error('Discord client login error:', error);
    console.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack
    });
    discordClient = null;
    throw error;
  }
}

// Function to get bot token with correct prefix
function getBotToken() {
  const token = process.env.DISCORD_BOT_TOKEN;
  if (!token) return null;
  return token.startsWith('Bot ') ? token : `Bot ${token}`;
}

// Function to send activity notification
async function sendActivityNotification(message) {
  try {
    const channelId = process.env.DISCORD_ACTIVITY_CHANNEL_ID;
    if (!channelId) {
      throw new Error('DISCORD_ACTIVITY_CHANNEL_ID environment variable not set');
    }

    const token = getBotToken();
    if (!token) {
      throw new Error('DISCORD_BOT_TOKEN environment variable not set');
    }

    // Send message using Discord API directly
    const response = await axios.post(
      `https://discord.com/api/v10/channels/${channelId}/messages`,
      {
        content: message.content || "",
        embeds: message.embeds || [],
        tts: false,
        allowed_mentions: { parse: [] }
      },
      {
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('Discord notification sent successfully');
    return true;
  } catch (error) {
    console.error('Error sending activity notification:', error.response?.data || error.message);
    console.error('Error details:', {
      status: error.response?.status,
      data: error.response?.data,
      headers: error.response?.headers
    });
    return false;
  }
}

// Function to send message to any channel
async function sendChannelMessage(channelId, message) {
  try {
    const token = getBotToken();
    if (!token) {
      throw new Error('DISCORD_BOT_TOKEN environment variable not set');
    }

    // Send message using Discord API directly
    const response = await axios.post(
      `https://discord.com/api/v10/channels/${channelId}/messages`,
      {
        content: message,
        tts: false,
        allowed_mentions: { parse: [] }
      },
      {
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('Channel message sent successfully');
    return true;
  } catch (error) {
    console.error('Error sending channel message:', error.response?.data || error.message);
    console.error('Error details:', {
      status: error.response?.status,
      data: error.response?.data,
      headers: error.response?.headers
    });
    return false;
  }
}

export {
  getDiscordClient,
  sendActivityNotification,
  sendChannelMessage
}; 