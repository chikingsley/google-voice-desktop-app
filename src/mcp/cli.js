#!/usr/bin/env node
/**
 * Google Voice CLI - Test tool for the HTTP bridge
 *
 * Usage:
 *   node src/mcp/cli.js status
 *   node src/mcp/cli.js unread
 *   node src/mcp/cli.js messages [limit]
 *   node src/mcp/cli.js calls [limit]
 *   node src/mcp/cli.js voicemails [limit]
 *   node src/mcp/cli.js contacts [limit]
 *   node src/mcp/cli.js search <query>
 *   node src/mcp/cli.js send <phone> <message>
 *   node src/mcp/cli.js call <phone>
 *   node src/mcp/cli.js endpoints
 */

const http = require('http');

const PORT = process.env.GV_PORT || 45677;
const BASE_URL = `http://127.0.0.1:${PORT}`;

function request(path, method = 'GET', body = null) {
    return new Promise((resolve, reject) => {
        const url = new URL(path, BASE_URL);
        const options = {
            hostname: '127.0.0.1',
            port: PORT,
            path: url.pathname + url.search,
            method,
            headers: { 'Content-Type': 'application/json' },
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => { data += chunk; });
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, data: JSON.parse(data) });
                } catch (e) {
                    resolve({ status: res.statusCode, data: data });
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

async function main() {
    const args = process.argv.slice(2);
    const command = args[0];

    if (!command) {
        console.log(`
Google Voice CLI - Test tool for the HTTP bridge

Usage:
  node src/mcp/cli.js <command> [args]

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
  endpoints           List all available API endpoints

Environment:
  GV_PORT=45677       Port for the HTTP bridge (default: 45677)
`);
        process.exit(0);
    }

    try {
        let result;

        switch (command) {
            case 'status':
                result = await request('/status');
                break;

            case 'unread':
                result = await request('/unread');
                break;

            case 'messages':
                const msgLimit = args[1] || 10;
                result = await request(`/messages?limit=${msgLimit}`);
                break;

            case 'calls':
                const callLimit = args[1] || 10;
                result = await request(`/calls?limit=${callLimit}`);
                break;

            case 'voicemails':
                const vmLimit = args[1] || 10;
                result = await request(`/voicemails?limit=${vmLimit}`);
                break;

            case 'contacts':
                const contactLimit = args[1] || 20;
                result = await request(`/contacts?limit=${contactLimit}`);
                break;

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

            case 'endpoints':
                result = await request('/');
                break;

            default:
                console.error(`Unknown command: ${command}`);
                process.exit(1);
        }

        console.log(JSON.stringify(result.data, null, 2));

    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

main();
