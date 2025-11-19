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

// Handle OPTIONS requests (CORS preflight)
interactionsRouter.options('/', (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Signature-Ed25519, X-Signature-Timestamp');
  res.status(200).end();
});

// CRITICAL: Handle PING immediately before any middleware
// Discord verification requires immediate response
interactionsRouter.post('/', (req, res, next) => {
  // Read body synchronously for PING check only
  let bodyData = '';
  req.on('data', chunk => { bodyData += chunk.toString(); });
  req.on('end', () => {
    try {
      const parsed = JSON.parse(bodyData);
      if (parsed.type === 1 || parsed.type === InteractionType.PING) {
        // Store raw body for later use
        req.rawBody = Buffer.from(bodyData, 'utf8');
        // Respond immediately with exact format Discord expects
        res.setHeader('Content-Type', 'application/json');
        res.status(200).end('{"type":1}');
        return;
      }
      // Not a PING, restore body and continue
      req.body = parsed;
      req.rawBody = Buffer.from(bodyData, 'utf8');
      next();
    } catch (e) {
      // If parsing fails, continue to main handler
      req.rawBody = Buffer.from(bodyData, 'utf8');
      next();
    }
  });
});

// Middleware to capture raw body for other requests
interactionsRouter.use(expressPkg.raw({ 
  type: 'application/json',
  limit: '1mb',
  verify: (req, res, buf) => {
    if (!req.rawBody) {
      req.rawBody = buf;
    }
  }
}));

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
    // Get raw body - handle both Buffer and string
    let rawBodyString = '';
    if (req.rawBody) {
      rawBodyString = Buffer.isBuffer(req.rawBody) ? req.rawBody.toString('utf8') : String(req.rawBody);
    } else if (req.body && typeof req.body === 'object' && Object.keys(req.body).length > 0) {
      // Fallback: if body was already parsed, stringify it back
      rawBodyString = JSON.stringify(req.body);
    } else {
      // Last resort: try to read from request stream
      rawBodyString = '{}';
    }
    
    // Parse interaction
    let interaction;
    try {
      interaction = JSON.parse(rawBodyString);
    } catch (parseError) {
      console.error('Error parsing interaction body:', parseError, 'Raw body:', rawBodyString.substring(0, 100));
      return res.status(400).json({ error: 'Invalid JSON' });
    }
    
    // Handle ping (Discord verification) - CRITICAL: respond immediately with exact format
    // Discord sends PING for endpoint verification - must respond within 3 seconds
    if (interaction.type === InteractionType.PING || interaction.type === 1) {
      console.log('Received PING, responding with PONG');
      // Discord requires EXACT response: {"type": 1} with Content-Type: application/json
      // Use res.end() to ensure no extra processing
      res.setHeader('Content-Type', 'application/json');
      res.status(200);
      res.end('{"type":1}');
      return;
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

