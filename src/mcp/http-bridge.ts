/**
 * HTTP Bridge for Google Voice MCP
 *
 * This module creates a local HTTP server inside the Electron app
 * that exposes the Google Voice API. The MCP server can then connect
 * to this HTTP API to control Google Voice.
 */

import * as http from 'http';
import * as url from 'url';
import type { GoogleVoiceAPI } from './google-voice-api';

const DEFAULT_PORT = 45677;

interface RequestBody {
    phone?: string;
    message?: string;
}

export class HTTPBridge {
    private api: GoogleVoiceAPI;
    private port: number;
    private server: http.Server | null = null;

    constructor(googleVoiceAPI: GoogleVoiceAPI, port: number = DEFAULT_PORT) {
        this.api = googleVoiceAPI;
        this.port = port;
    }

    start(): Promise<number> {
        return new Promise((resolve, reject) => {
            this.server = http.createServer(async (req, res) => {
                // Set CORS headers for local development
                res.setHeader('Access-Control-Allow-Origin', 'http://localhost');
                res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
                res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
                res.setHeader('Content-Type', 'application/json');

                if (req.method === 'OPTIONS') {
                    res.writeHead(200);
                    res.end();
                    return;
                }

                const parsedUrl = url.parse(req.url || '', true);
                const pathname = parsedUrl.pathname || '';
                const query = parsedUrl.query as Record<string, string>;

                try {
                    let result: unknown;

                    switch (pathname) {
                        case '/status': {
                            const isLoggedIn = await this.api.isLoggedIn();
                            const user = await this.api.getCurrentUser();
                            result = { isLoggedIn, user, status: isLoggedIn ? 'ready' : 'not_logged_in' };
                            break;
                        }

                        case '/unread':
                            result = { count: await this.api.getUnreadCount() };
                            break;

                        case '/messages': {
                            const msgLimit = parseInt(query.limit) || 10;
                            result = await this.api.getMessages(msgLimit);
                            break;
                        }

                        case '/contacts': {
                            const contactLimit = parseInt(query.limit) || 20;
                            result = await this.api.getContacts(contactLimit);
                            break;
                        }

                        case '/calls': {
                            const callLimit = parseInt(query.limit) || 10;
                            result = await this.api.getCallHistory(callLimit);
                            break;
                        }

                        case '/voicemails': {
                            const vmLimit = parseInt(query.limit) || 10;
                            result = await this.api.getVoicemails(vmLimit);
                            break;
                        }

                        case '/search':
                            if (!query.q) {
                                res.writeHead(400);
                                res.end(JSON.stringify({ error: 'Missing query parameter: q' }));
                                return;
                            }
                            result = await this.api.search(query.q);
                            break;

                        case '/dump-dom':
                            result = await this.api.dumpDOM();
                            break;

                        case '/send-sms': {
                            if (req.method !== 'POST') {
                                res.writeHead(405);
                                res.end(JSON.stringify({ error: 'Method not allowed. Use POST.' }));
                                return;
                            }
                            const smsBody = await this.readBody(req);
                            if (!smsBody.phone || !smsBody.message) {
                                res.writeHead(400);
                                res.end(JSON.stringify({ error: 'Missing required fields: phone, message' }));
                                return;
                            }
                            result = await this.api.sendSMS(smsBody.phone, smsBody.message);
                            break;
                        }

                        case '/call': {
                            if (req.method !== 'POST') {
                                res.writeHead(405);
                                res.end(JSON.stringify({ error: 'Method not allowed. Use POST.' }));
                                return;
                            }
                            const callBody = await this.readBody(req);
                            if (!callBody.phone) {
                                res.writeHead(400);
                                res.end(JSON.stringify({ error: 'Missing required field: phone' }));
                                return;
                            }
                            result = await this.api.dialNumber(callBody.phone);
                            break;
                        }

                        case '/navigate/messages':
                            result = { success: await this.api.navigateToMessages() };
                            break;

                        case '/navigate/calls':
                            result = { success: await this.api.navigateToCalls() };
                            break;

                        case '/dialpad':
                            result = { success: await this.api.openDialpad() };
                            break;

                        default:
                            res.writeHead(404);
                            res.end(JSON.stringify({
                                error: 'Not found',
                                availableEndpoints: [
                                    'GET /status',
                                    'GET /unread',
                                    'GET /messages?limit=10',
                                    'GET /contacts?limit=20',
                                    'GET /calls?limit=10',
                                    'GET /voicemails?limit=10',
                                    'GET /search?q=query',
                                    'GET /dump-dom',
                                    'POST /send-sms { phone, message }',
                                    'POST /call { phone }',
                                    'GET /navigate/messages',
                                    'GET /navigate/calls',
                                    'GET /dialpad'
                                ]
                            }));
                            return;
                    }

                    res.writeHead(200);
                    res.end(JSON.stringify(result));

                } catch (error) {
                    console.error('HTTP Bridge error:', error);
                    res.writeHead(500);
                    res.end(JSON.stringify({ error: (error as Error).message }));
                }
            });

            this.server.listen(this.port, '127.0.0.1', () => {
                console.log(`Google Voice HTTP Bridge running on http://127.0.0.1:${this.port}`);
                resolve(this.port);
            });

            this.server.on('error', (err: NodeJS.ErrnoException) => {
                if (err.code === 'EADDRINUSE') {
                    // Try next port
                    this.port++;
                    this.server?.listen(this.port, '127.0.0.1');
                } else {
                    reject(err);
                }
            });
        });
    }

    private readBody(req: http.IncomingMessage): Promise<RequestBody> {
        return new Promise((resolve, reject) => {
            let body = '';
            req.on('data', (chunk: Buffer) => { body += chunk.toString(); });
            req.on('end', () => {
                try {
                    resolve(JSON.parse(body) as RequestBody);
                } catch (e) {
                    reject(new Error('Invalid JSON body'));
                }
            });
            req.on('error', reject);
        });
    }

    stop(): void {
        if (this.server) {
            this.server.close();
            this.server = null;
        }
    }

    getPort(): number {
        return this.port;
    }
}

export default HTTPBridge;
