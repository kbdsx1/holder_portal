/**
 * Discord interactions endpoint - minimal implementation
 */

export default function handler(req, res) {
  console.log('[Discord Interactions Standalone] Request received:', req.method, req.url);
  
  // OPTIONS
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Signature-Ed25519, X-Signature-Timestamp'
    });
    res.end();
    return;
  }

  // Only POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Get body
    let body = req.body;
    if (typeof body === 'string') {
      body = JSON.parse(body);
    }
    
    console.log('[Discord Interactions Standalone] Body:', JSON.stringify(body));
    
    if (!body || typeof body !== 'object') {
      res.status(400).json({ error: 'Invalid request body' });
      return;
    }

    // Handle PING - respond immediately and synchronously
    if (body.type === 1) {
      console.log('[Discord Interactions Standalone] PING detected - responding with PONG');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"type":1}');
      return;
    }

    // Handle commands - async
    if (body.type === 2) {
      (async () => {
        try {
          const { handleCommand } = await import('../packages/backend/src/api/integrations/discord/commands.js');
          const response = await handleCommand(body);
          res.status(200).json(response);
        } catch (error) {
          console.error('[Discord Interactions] Command error:', error);
          res.status(500).json({ 
            type: 4,
            data: { content: '❌ An error occurred.', flags: 64 }
          });
        }
      })();
      return;
    }

    res.status(400).json({ error: 'Unknown interaction type' });
    
  } catch (error) {
    console.error('[Discord Interactions] Error:', error);
    res.status(500).json({ 
      type: 4,
      data: { content: '❌ An error occurred.', flags: 64 }
    });
  }
}
