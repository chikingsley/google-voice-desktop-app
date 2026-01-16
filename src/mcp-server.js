const Fastify = require('fastify');
const ip = require('ip');
const { ipcMain } = require('electron');

/**
 * Starts the MCP server.
 * @param {function} getWindow - A function that returns the current BrowserWindow instance.
 */
function startServer(getWindow) {
    const fastify = Fastify({ logger: true });

    fastify.post('/mcp/call', async (request, reply) => {
        const { number } = request.body;
        if (!number) {
            return reply.code(400).send({ error: 'Number is required' });
        }

        console.log(`Received call request for: ${number}`);
        const win = getWindow();
        if (win && !win.isDestroyed() && win.webContents) {
            win.webContents.send('mcp-action', { type: 'call', number });
            return { status: 'initiated', action: 'call', number };
        } else {
            return reply.code(503).send({ error: 'Window not available' });
        }
    });

    fastify.post('/mcp/sms', async (request, reply) => {
        const { number, text } = request.body;
        if (!number || !text) {
            return reply.code(400).send({ error: 'Number and text are required' });
        }

        console.log(`Received sms request for: ${number}`);
        const win = getWindow();
        if (win && !win.isDestroyed() && win.webContents) {
            win.webContents.send('mcp-action', { type: 'sms', number, text });
            return { status: 'initiated', action: 'sms', number };
        } else {
            return reply.code(503).send({ error: 'Window not available' });
        }
    });

    // Add a status endpoint
    fastify.get('/mcp/status', async (request, reply) => {
        return { status: 'running', ip: ip.address() };
    });

    const start = async () => {
        try {
            const port = process.env.MCP_PORT || 3000;
            // Bind to localhost only for security.
            // Note: This is a REST API implementation of the "MCP" concept (programmatic control).
            // It allows external agents to control the app via HTTP requests.
            await fastify.listen({ port, host: '127.0.0.1' });
            console.log(`MCP Server listening on 127.0.0.1:${port}`);
        } catch (err) {
            fastify.log.error(err);
            // process.exit(1); // Don't kill the app if server fails
        }
    };

    start();
}

module.exports = { startServer };
