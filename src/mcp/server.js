#!/usr/bin/env node
/**
 * Google Voice MCP Server
 *
 * This MCP server exposes Google Voice functionality as tools that can be
 * used by AI assistants like Claude.
 *
 * The server connects to the Google Voice Desktop app's HTTP bridge to
 * execute operations.
 *
 * Usage:
 *   node src/mcp/server.js [--port=45677]
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} = require('@modelcontextprotocol/sdk/types.js');
const http = require('http');

// Default port for the HTTP bridge
const DEFAULT_PORT = 45677;

class GoogleVoiceHTTPClient {
    constructor(port = DEFAULT_PORT) {
        this.port = port;
        this.baseUrl = `http://127.0.0.1:${port}`;
    }

    async request(path, method = 'GET', body = null) {
        return new Promise((resolve, reject) => {
            const url = new URL(path, this.baseUrl);
            const options = {
                hostname: '127.0.0.1',
                port: this.port,
                path: url.pathname + url.search,
                method,
                headers: {
                    'Content-Type': 'application/json',
                },
            };

            const req = http.request(options, (res) => {
                let data = '';
                res.on('data', chunk => { data += chunk; });
                res.on('end', () => {
                    try {
                        resolve(JSON.parse(data));
                    } catch (e) {
                        resolve({ error: 'Invalid response', raw: data });
                    }
                });
            });

            req.on('error', (e) => {
                reject(new Error(`Failed to connect to Google Voice Desktop app: ${e.message}. Make sure the app is running.`));
            });

            if (body) {
                req.write(JSON.stringify(body));
            }
            req.end();
        });
    }

    async getStatus() {
        return this.request('/status');
    }

    async getUnreadCount() {
        const result = await this.request('/unread');
        return result.count;
    }

    async getMessages(limit = 10) {
        return this.request(`/messages?limit=${limit}`);
    }

    async getContacts(limit = 20) {
        return this.request(`/contacts?limit=${limit}`);
    }

    async getCallHistory(limit = 10) {
        return this.request(`/calls?limit=${limit}`);
    }

    async getVoicemails(limit = 10) {
        return this.request(`/voicemails?limit=${limit}`);
    }

    async search(query) {
        return this.request(`/search?q=${encodeURIComponent(query)}`);
    }

    async sendSMS(phone, message) {
        return this.request('/send-sms', 'POST', { phone, message });
    }

    async makeCall(phone) {
        return this.request('/call', 'POST', { phone });
    }
}

/**
 * Create and configure the MCP server
 */
function createMCPServer(port = DEFAULT_PORT) {
    const client = new GoogleVoiceHTTPClient(port);

    const server = new Server(
        {
            name: 'google-voice-mcp',
            version: '1.0.0',
        },
        {
            capabilities: {
                tools: {},
            },
        }
    );

    // Define available tools
    server.setRequestHandler(ListToolsRequestSchema, async () => {
        return {
            tools: [
                {
                    name: 'gv_check_status',
                    description: 'Check if Google Voice Desktop app is running and user is logged in',
                    inputSchema: {
                        type: 'object',
                        properties: {},
                        required: [],
                    },
                },
                {
                    name: 'gv_get_unread_count',
                    description: 'Get the number of unread messages and missed calls in Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {},
                        required: [],
                    },
                },
                {
                    name: 'gv_get_messages',
                    description: 'Get recent messages/conversations from Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Maximum number of messages to retrieve (default: 10)',
                            },
                        },
                        required: [],
                    },
                },
                {
                    name: 'gv_send_sms',
                    description: 'Send an SMS text message via Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            phone_number: {
                                type: 'string',
                                description: 'The phone number to send the message to (e.g., "+1234567890" or "123-456-7890")',
                            },
                            message: {
                                type: 'string',
                                description: 'The text message to send',
                            },
                        },
                        required: ['phone_number', 'message'],
                    },
                },
                {
                    name: 'gv_make_call',
                    description: 'Initiate a phone call via Google Voice. The call will ring on your linked devices.',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            phone_number: {
                                type: 'string',
                                description: 'The phone number to call (e.g., "+1234567890" or "123-456-7890")',
                            },
                        },
                        required: ['phone_number'],
                    },
                },
                {
                    name: 'gv_get_call_history',
                    description: 'Get recent call history from Google Voice (incoming, outgoing, missed calls)',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Maximum number of calls to retrieve (default: 10)',
                            },
                        },
                        required: [],
                    },
                },
                {
                    name: 'gv_get_voicemails',
                    description: 'Get voicemail messages with transcripts from Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Maximum number of voicemails to retrieve (default: 10)',
                            },
                        },
                        required: [],
                    },
                },
                {
                    name: 'gv_search',
                    description: 'Search for contacts or messages in Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            query: {
                                type: 'string',
                                description: 'The search query (name, phone number, or message content)',
                            },
                        },
                        required: ['query'],
                    },
                },
                {
                    name: 'gv_get_contacts',
                    description: 'Get recent contacts from Google Voice',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Maximum number of contacts to retrieve (default: 20)',
                            },
                        },
                        required: [],
                    },
                },
            ],
        };
    });

    // Handle tool calls
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;

        try {
            let result;

            switch (name) {
                case 'gv_check_status':
                    result = await client.getStatus();
                    break;

                case 'gv_get_unread_count':
                    result = { unreadCount: await client.getUnreadCount() };
                    break;

                case 'gv_get_messages':
                    result = await client.getMessages(args?.limit || 10);
                    break;

                case 'gv_send_sms':
                    if (!args?.phone_number || !args?.message) {
                        throw new Error('phone_number and message are required');
                    }
                    result = await client.sendSMS(args.phone_number, args.message);
                    break;

                case 'gv_make_call':
                    if (!args?.phone_number) {
                        throw new Error('phone_number is required');
                    }
                    result = await client.makeCall(args.phone_number);
                    break;

                case 'gv_get_call_history':
                    result = await client.getCallHistory(args?.limit || 10);
                    break;

                case 'gv_get_voicemails':
                    result = await client.getVoicemails(args?.limit || 10);
                    break;

                case 'gv_search':
                    if (!args?.query) {
                        throw new Error('query is required');
                    }
                    result = await client.search(args.query);
                    break;

                case 'gv_get_contacts':
                    result = await client.getContacts(args?.limit || 20);
                    break;

                default:
                    throw new Error(`Unknown tool: ${name}`);
            }

            return {
                content: [
                    {
                        type: 'text',
                        text: JSON.stringify(result, null, 2),
                    },
                ],
            };
        } catch (error) {
            return {
                content: [
                    {
                        type: 'text',
                        text: JSON.stringify({
                            error: error.message,
                            tool: name,
                            hint: 'Make sure the Google Voice Desktop app is running.',
                        }),
                    },
                ],
            };
        }
    });

    return server;
}

/**
 * Run the MCP server
 */
async function main() {
    // Parse command line arguments
    let port = DEFAULT_PORT;
    for (const arg of process.argv.slice(2)) {
        if (arg.startsWith('--port=')) {
            port = parseInt(arg.split('=')[1], 10);
        }
    }

    const server = createMCPServer(port);
    const transport = new StdioServerTransport();

    await server.connect(transport);
    console.error(`Google Voice MCP Server running (connecting to HTTP bridge on port ${port})`);
}

// Run the server
main().catch((error) => {
    console.error('Failed to start MCP server:', error);
    process.exit(1);
});
