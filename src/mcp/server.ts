#!/usr/bin/env bun
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
 *   bun src/mcp/server.ts [--port=45677]
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import * as http from 'http';

// Default port for the HTTP bridge
const DEFAULT_PORT = 45677;

interface ToolArgs {
    limit?: number;
    phone_number?: string;
    message?: string;
    query?: string;
}

interface UnreadResponse {
    count: number;
}

class GoogleVoiceHTTPClient {
    private port: number;
    private baseUrl: string;

    constructor(port: number = DEFAULT_PORT) {
        this.port = port;
        this.baseUrl = `http://127.0.0.1:${port}`;
    }

    async request<T>(path: string, method: string = 'GET', body: Record<string, string> | null = null): Promise<T> {
        return new Promise((resolve, reject) => {
            const urlObj = new URL(path, this.baseUrl);
            const options: http.RequestOptions = {
                hostname: '127.0.0.1',
                port: this.port,
                path: urlObj.pathname + urlObj.search,
                method,
                headers: {
                    'Content-Type': 'application/json',
                },
            };

            const req = http.request(options, (res) => {
                let data = '';
                res.on('data', (chunk: Buffer) => { data += chunk.toString(); });
                res.on('end', () => {
                    try {
                        resolve(JSON.parse(data) as T);
                    } catch (e) {
                        resolve({ error: 'Invalid response', raw: data } as T);
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

    async getStatus(): Promise<unknown> {
        return this.request('/status');
    }

    async getUnreadCount(): Promise<number> {
        const result = await this.request<UnreadResponse>('/unread');
        return result.count;
    }

    async getMessages(limit: number = 10): Promise<unknown> {
        return this.request(`/messages?limit=${limit}`);
    }

    async getContacts(limit: number = 20): Promise<unknown> {
        return this.request(`/contacts?limit=${limit}`);
    }

    async getCallHistory(limit: number = 10): Promise<unknown> {
        return this.request(`/calls?limit=${limit}`);
    }

    async getVoicemails(limit: number = 10): Promise<unknown> {
        return this.request(`/voicemails?limit=${limit}`);
    }

    async search(query: string): Promise<unknown> {
        return this.request(`/search?q=${encodeURIComponent(query)}`);
    }

    async sendSMS(phone: string, message: string): Promise<unknown> {
        return this.request('/send-sms', 'POST', { phone, message });
    }

    async makeCall(phone: string): Promise<unknown> {
        return this.request('/call', 'POST', { phone });
    }

    async dumpDOM(): Promise<unknown> {
        return this.request('/dump-dom');
    }
}

/**
 * Create and configure the MCP server
 */
function createMCPServer(port: number = DEFAULT_PORT): Server {
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
                        type: 'object' as const,
                        properties: {},
                        required: [],
                    },
                },
                {
                    name: 'gv_get_unread_count',
                    description: 'Get the number of unread messages and missed calls in Google Voice',
                    inputSchema: {
                        type: 'object' as const,
                        properties: {},
                        required: [],
                    },
                },
                {
                    name: 'gv_get_messages',
                    description: 'Get recent messages/conversations from Google Voice',
                    inputSchema: {
                        type: 'object' as const,
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
                        type: 'object' as const,
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
                        type: 'object' as const,
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
                        type: 'object' as const,
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
                        type: 'object' as const,
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
                        type: 'object' as const,
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
                        type: 'object' as const,
                        properties: {
                            limit: {
                                type: 'number',
                                description: 'Maximum number of contacts to retrieve (default: 20)',
                            },
                        },
                        required: [],
                    },
                },
                {
                    name: 'gv_dump_dom',
                    description: 'Dump the DOM structure for debugging selectors. Use this to find the correct CSS selectors if other tools are not working.',
                    inputSchema: {
                        type: 'object' as const,
                        properties: {},
                        required: [],
                    },
                },
            ],
        };
    });

    // Handle tool calls
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        const typedArgs = args as ToolArgs | undefined;

        try {
            let result: unknown;

            switch (name) {
                case 'gv_check_status':
                    result = await client.getStatus();
                    break;

                case 'gv_get_unread_count':
                    result = { unreadCount: await client.getUnreadCount() };
                    break;

                case 'gv_get_messages':
                    result = await client.getMessages(typedArgs?.limit || 10);
                    break;

                case 'gv_send_sms':
                    if (!typedArgs?.phone_number || !typedArgs?.message) {
                        throw new Error('phone_number and message are required');
                    }
                    result = await client.sendSMS(typedArgs.phone_number, typedArgs.message);
                    break;

                case 'gv_make_call':
                    if (!typedArgs?.phone_number) {
                        throw new Error('phone_number is required');
                    }
                    result = await client.makeCall(typedArgs.phone_number);
                    break;

                case 'gv_get_call_history':
                    result = await client.getCallHistory(typedArgs?.limit || 10);
                    break;

                case 'gv_get_voicemails':
                    result = await client.getVoicemails(typedArgs?.limit || 10);
                    break;

                case 'gv_search':
                    if (!typedArgs?.query) {
                        throw new Error('query is required');
                    }
                    result = await client.search(typedArgs.query);
                    break;

                case 'gv_get_contacts':
                    result = await client.getContacts(typedArgs?.limit || 20);
                    break;

                case 'gv_dump_dom':
                    result = await client.dumpDOM();
                    break;

                default:
                    throw new Error(`Unknown tool: ${name}`);
            }

            return {
                content: [
                    {
                        type: 'text' as const,
                        text: JSON.stringify(result, null, 2),
                    },
                ],
            };
        } catch (error) {
            return {
                content: [
                    {
                        type: 'text' as const,
                        text: JSON.stringify({
                            error: (error as Error).message,
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
async function main(): Promise<void> {
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
