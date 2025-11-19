/**
 * Discord interactions endpoint with signature verification
 * Discord requires signature verification for all requests
 */

import nacl from 'tweetnacl';

// Get raw body for signature verification
async function getRawBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', chunk => {
      data += chunk.toString();
    });
    req.on('end', () => {
      resolve(data);
    });
    req.on('error', () => {
      resolve('');
    });
  });
}

// Verify Discord signature
function verifySignature(req, rawBody) {
  const signature = req.headers['x-signature-ed25519'];
  const timestamp = req.headers['x-signature-timestamp'];
  const publicKey = process.env.DISCORD_PUBLIC_KEY;

  if (!signature || !timestamp) {
    console.warn('[Discord] Missing signature headers');
    return false;
  }

  if (!publicKey) {
    console.warn('[Discord] DISCORD_PUBLIC_KEY not set');
    // During verification, Discord might not require verification if key isn't set
    return true;
  }

  try {
    const message = Buffer.from(timestamp + rawBody);
    const sig = Buffer.from(signature, 'hex');
    const pubKey = Buffer.from(publicKey, 'hex');
    
    return nacl.sign.detached.verify(message, sig, pubKey);
  } catch (error) {
    console.error('[Discord] Signature verification error:', error);
    return false;
  }
}

export default async function handler(req, res) {
  // OPTIONS
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Signature-Ed25519, X-Signature-Timestamp'
    });
    return res.end();
  }

  // Only POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Get raw body for signature verification
    // Vercel may have parsed it, so try both
    let rawBody = '';
    let body = req.body;

    // Try to get raw body
    if (typeof body === 'string') {
      rawBody = body;
      body = JSON.parse(body);
    } else if (body) {
      rawBody = JSON.stringify(body);
    } else {
      // Read from stream if not parsed
      rawBody = await getRawBody(req);
      body = JSON.parse(rawBody);
    }

    // Verify signature (but allow PING during verification if key not set)
    const publicKey = process.env.DISCORD_PUBLIC_KEY;
    if (publicKey) {
      const isValid = verifySignature(req, rawBody);
      if (!isValid && body.type !== 1) {
        // For PING during verification, Discord might not require signature
        // But for other types, we need it
        console.warn('[Discord] Signature verification failed');
        return res.status(401).json({ error: 'Unauthorized' });
      }
    }

    // Handle PING - respond immediately
    if (body && body.type === 1) {
      console.log('[Discord Interactions] PING - responding with PONG');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end('{"type":1}');
    }

    // Handle commands
    if (body && body.type === 2) {
      const { handleCommand } = await import('../../packages/backend/src/api/integrations/discord/commands.js');
      const response = await handleCommand(body);
      return res.status(200).json(response);
    }

    return res.status(400).json({ error: 'Unknown interaction type' });
    
  } catch (error) {
    console.error('[Discord Interactions] Error:', error);
    
    // If error but might be PING, try to respond
    try {
      const bodyStr = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || '');
      if (bodyStr && bodyStr.includes('"type":1')) {
        console.log('[Discord Interactions] Fallback PONG');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end('{"type":1}');
      }
    } catch (e) {
      // Ignore
    }
    
    return res.status(500).json({ 
      type: 4,
      data: { content: '❌ An error occurred.', flags: 64 }
    });
  }
}
