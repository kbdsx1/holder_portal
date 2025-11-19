import expressPkg from 'express';
import nacl from 'tweetnacl';
import { handleCommand } from './commands.js';

// Discord interaction types
const InteractionType = {
  PING: 1,
  APPLICATION_COMMAND: 2,
  MESSAGE_COMPONENT: 3,
  APPLICATION_COMMAND_AUTOCOMPLETE: 4,
  MODAL_SUBMIT: 5
};

const InteractionResponseType = {
  PONG: 1,
  CHANNEL_MESSAGE_WITH_SOURCE: 4,
  DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE: 5,
  DEFERRED_UPDATE_MESSAGE: 6,
  UPDATE_MESSAGE: 7,
  APPLICATION_COMMAND_AUTOCOMPLETE_RESULT: 8,
  MODAL: 9
};

const interactionsRouter = expressPkg.Router();

// Middleware to capture raw body for signature verification
// Must be before JSON parser
interactionsRouter.use(expressPkg.raw({ 
  type: 'application/json',
  verify: (req, res, buf) => {
    req.rawBody = buf;
  }
}));

// Parse JSON after capturing raw body
interactionsRouter.use(expressPkg.json());

// Verify Discord request signature
function verifySignature(req) {
  const signature = req.get('X-Signature-Ed25519');
  const timestamp = req.get('X-Signature-Timestamp');
  
  if (!signature || !timestamp) {
    console.warn('Missing signature headers');
    return false;
  }
  
  const publicKey = process.env.DISCORD_PUBLIC_KEY;
  if (!publicKey) {
    console.warn('DISCORD_PUBLIC_KEY not set, skipping signature verification');
    // In production, we should require the key, but allow in dev for testing
    return process.env.NODE_ENV !== 'production';
  }
  
  try {
    // Discord signature verification: timestamp + raw body
    const bodyString = req.rawBody?.toString() || '';
    const message = Buffer.from(timestamp + bodyString);
    const sig = Buffer.from(signature, 'hex');
    const pubKey = Buffer.from(publicKey, 'hex');
    
    const isValid = nacl.sign.detached.verify(message, sig, pubKey);
    if (!isValid) {
      console.warn('Signature verification failed');
    }
    return isValid;
  } catch (error) {
    console.error('Signature verification error:', error);
    return false;
  }
}

// Handle Discord interactions
interactionsRouter.post('/', async (req, res) => {
  try {
    // Parse interaction from raw body (not parsed by global JSON middleware)
    let interaction;
    try {
      const rawBodyString = req.rawBody?.toString() || '{}';
      interaction = JSON.parse(rawBodyString);
    } catch (parseError) {
      console.error('Error parsing interaction body:', parseError);
      return res.status(400).json({ error: 'Invalid JSON' });
    }
    
    // Handle ping (Discord verification) - must respond immediately, no signature check needed
    // Discord sends PING without signature headers for endpoint verification
    if (interaction.type === InteractionType.PING) {
      console.log('Received PING, responding with PONG');
      res.setHeader('Content-Type', 'application/json');
      return res.status(200).json({
        type: InteractionResponseType.PONG
      });
    }
    
    // Verify signature for all other interaction types
    // Skip verification in development if key not set
    const publicKey = process.env.DISCORD_PUBLIC_KEY;
    if (publicKey && process.env.NODE_ENV === 'production') {
      if (!verifySignature(req)) {
        console.warn('Invalid signature or missing headers');
        return res.status(401).json({ error: 'Unauthorized' });
      }
    } else if (!publicKey) {
      console.warn('DISCORD_PUBLIC_KEY not set - signature verification disabled');
    }
    
    // Handle application commands
    if (interaction.type === InteractionType.APPLICATION_COMMAND) {
      const response = await handleCommand(interaction);
      return res.json(response);
    }
    
    // Unknown interaction type
    return res.status(400).json({ error: 'Unknown interaction type' });
  } catch (error) {
    console.error('Error handling Discord interaction:', error);
    return res.status(500).json({
      type: InteractionResponseType.CHANNEL_MESSAGE_WITH_SOURCE,
      data: {
        content: '❌ An error occurred processing your command.',
        flags: 64 // Ephemeral
      }
    });
  }
});

export default interactionsRouter;

