#!/usr/bin/env bun
/**
 * Google Voice CLI - Test tool for the HTTP bridge
 *
 * Usage:
 *   bun src/mcp/cli.ts status
 *   bun src/mcp/cli.ts unread
 *   bun src/mcp/cli.ts messages [limit]
 *   bun src/mcp/cli.ts calls [limit]
 *   bun src/mcp/cli.ts voicemails [limit]
 *   bun src/mcp/cli.ts contacts [limit]
 *   bun src/mcp/cli.ts search <query>
 *   bun src/mcp/cli.ts send <phone> <message>
 *   bun src/mcp/cli.ts call <phone>
 *   bun src/mcp/cli.ts dump-dom
 *   bun src/mcp/cli.ts endpoints
 */

import * as http from 'http';

const PORT = parseInt(process.env.GV_PORT || '45677', 10);
const BASE_URL = `http://127.0.0.1:${PORT}`;

interface RequestResult {
    status: number;
    data: unknown;
}

interface RequestBody {
    phone?: string;
    message?: string;
}

function request(path: string, method: string = 'GET', body: RequestBody | null = null): Promise<RequestResult> {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(path, BASE_URL);
        const options: http.RequestOptions = {
            hostname: '127.0.0.1',
            port: PORT,
            path: urlObj.pathname + urlObj.search,
            method,
            headers: { 'Content-Type': 'application/json' },
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk: Buffer) => { data += chunk.toString(); });
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode || 500, data: JSON.parse(data) });
                } catch (e) {
                    resolve({ status: res.statusCode || 500, data: data });
                }
            });
        });

        req.on('error', (e) => {
            reject(new Error(`Connection failed: ${e.message}\n\nMake sure the Google Voice Desktop app is running!`));
        });

        if (body) req.write(JSON.stringify(body));
        req.end();
    });
}

async function main(): Promise<void> {
    const args = process.argv.slice(2);
    const command = args[0];

    if (!command) {
        console.log(`
Google Voice CLI - Test tool for the HTTP bridge

Usage:
  bun src/mcp/cli.ts <command> [args]

Commands:
  status              Check if app is running and user is logged in
  unread              Get unread count
  messages [limit]    Get recent messages (default: 10)
  calls [limit]       Get call history (default: 10)
  voicemails [limit]  Get voicemails (default: 10)
  contacts [limit]    Get contacts (default: 20)
  search <query>      Search for contacts/messages
  send <phone> <msg>  Send an SMS
  call <phone>        Make a call
  dump-dom            Dump DOM structure for debugging selectors
  endpoints           List all available API endpoints

Environment:
  GV_PORT=45677       Port for the HTTP bridge (default: 45677)
`);
        process.exit(0);
    }

    try {
        let result: RequestResult;

        switch (command) {
            case 'status':
                result = await request('/status');
                break;

            case 'unread':
                result = await request('/unread');
                break;

            case 'messages': {
                const msgLimit = args[1] || '10';
                result = await request(`/messages?limit=${msgLimit}`);
                break;
            }

            case 'calls': {
                const callLimit = args[1] || '10';
                result = await request(`/calls?limit=${callLimit}`);
                break;
            }

            case 'voicemails': {
                const vmLimit = args[1] || '10';
                result = await request(`/voicemails?limit=${vmLimit}`);
                break;
            }

            case 'contacts': {
                const contactLimit = args[1] || '20';
                result = await request(`/contacts?limit=${contactLimit}`);
                break;
            }

            case 'search':
                if (!args[1]) {
                    console.error('Error: search requires a query');
                    process.exit(1);
                }
                result = await request(`/search?q=${encodeURIComponent(args[1])}`);
                break;

            case 'send':
                if (!args[1] || !args[2]) {
                    console.error('Error: send requires <phone> <message>');
                    process.exit(1);
                }
                result = await request('/send-sms', 'POST', {
                    phone: args[1],
                    message: args.slice(2).join(' ')
                });
                break;

            case 'call':
                if (!args[1]) {
                    console.error('Error: call requires <phone>');
                    process.exit(1);
                }
                result = await request('/call', 'POST', { phone: args[1] });
                break;

            case 'dump-dom':
                result = await request('/dump-dom');
                break;

            case 'endpoints':
                result = await request('/');
                break;

            default:
                console.error(`Unknown command: ${command}`);
                process.exit(1);
        }

        console.log(JSON.stringify(result.data, null, 2));

    } catch (error) {
        console.error('Error:', (error as Error).message);
        process.exit(1);
    }
}

main();
