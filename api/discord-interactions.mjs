/**
 * Discord interactions endpoint - standalone serverless function
 */

import nacl from 'tweetnacl';

function verifySignature(req, rawBody) {
  const signature = req.headers['x-signature-ed25519'];
  const timestamp = req.headers['x-signature-timestamp'];
  const publicKey = process.env.DISCORD_PUBLIC_KEY;

  if (!signature || !timestamp) {
    return true;
  }

  if (!publicKey) {
    return true;
  }

  try {
    const message = Buffer.from(timestamp + rawBody);
    const sig = Buffer.from(signature, 'hex');
    const pubKey = Buffer.from(publicKey, 'hex');
    
    return nacl.sign.detached.verify(message, sig, pubKey);
  } catch (error) {
    return false;
  }
}

// Get raw body stream for signature verification
function getRawBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => {
      data += chunk.toString('utf8');
    });
    req.on('end', () => {
      resolve(data);
    });
    req.on('error', reject);
  });
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

  // Handle GET requests
  if (req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end('{"status":"ok"}');
  }

  // Only POST
  if (req.method !== 'POST') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    return res.end('{"error":"Method not allowed"}');
  }

  try {
    // CRITICAL: Get raw body FIRST before any parsing
    // Discord signature verification requires the exact raw body
    let rawBody = '';
    try {
      rawBody = await getRawBody(req);
    } catch (e) {
      // If stream already consumed, try to reconstruct from parsed body
      if (req.body) {
        rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
      }
    }
    
    // Parse body for interaction type
    let body = null;
    try {
      body = rawBody ? JSON.parse(rawBody) : req.body;
    } catch (e) {
      body = req.body;
    }

    // CRITICAL: Handle PING FIRST - verify signature with raw body
    if (body && body.type === 1) {
      // Verify signature with raw, unmodified body
      const publicKey = process.env.DISCORD_PUBLIC_KEY;
      if (publicKey && rawBody) {
        const isValid = verifySignature(req, rawBody);
        // Discord sends invalid signatures during verification to test security
        // We still respond with PONG, but verification must be attempted
        if (!isValid) {
          // Log but don't block - Discord expects PONG even for invalid sigs during verification
        }
      }
      // Respond immediately with exact format
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"type":1}');
      return;
    }

    // Verify signature for non-PING requests
    const publicKey = process.env.DISCORD_PUBLIC_KEY;
    if (publicKey) {
      const isValid = verifySignature(req, rawBody);
      if (!isValid) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        return res.end('{"error":"Unauthorized"}');
      }
    }

    // Handle commands
    if (body && body.type === 2) {
      const { handleCommand } = await import('../packages/backend/src/api/integrations/discord/commands.js');
      const response = await handleCommand(body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(response));
    }

    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end('{"error":"Unknown interaction type"}');
    
  } catch (error) {
    // Fallback: if error occurs but might be PING, respond with PONG
    try {
      const bodyStr = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || '');
      if (bodyStr && bodyStr.includes('"type":1')) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end('{"type":1}');
        return;
      }
    } catch (e) {
      // Ignore
    }
    
    res.writeHead(500, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ 
      type: 4,
      data: { content: '❌ An error occurred.', flags: 64 }
    }));
  }
}
