/**
 * MCP Module exports for Electron main process
 *
 * This file provides CommonJS exports that Electron can use.
 * The actual implementation is in TypeScript files which are run with bun.
 *
 * For the CLI and MCP server, use: bun src/mcp/cli.ts or bun src/mcp/server.ts
 */

// Re-export the GoogleVoiceAPI class for Electron
const { BrowserWindow } = require('electron');

class GoogleVoiceAPI {
    constructor(win) {
        this.win = win;
    }

    async execute(script) {
        if (!this.win || this.win.isDestroyed()) {
            throw new Error('Browser window not available');
        }
        return await this.win.webContents.executeJavaScript(script);
    }

    async dumpDOM() {
        const script = `
            (function() {
                const gvRoot = document.querySelector('.gv_root');
                const interactiveElements = [];
                const selectors = 'button, a, input, textarea, [role="button"], [data-action], [aria-label]';

                document.querySelectorAll(selectors).forEach(el => {
                    const dataAttrs = {};
                    for (const attr of el.attributes) {
                        if (attr.name.startsWith('data-')) {
                            dataAttrs[attr.name] = attr.value;
                        }
                    }
                    interactiveElements.push({
                        tag: el.tagName.toLowerCase(),
                        id: el.id || '',
                        classes: Array.from(el.classList),
                        ariaLabel: el.getAttribute('aria-label'),
                        dataAttributes: dataAttrs,
                        text: (el.textContent || '').trim().substring(0, 50)
                    });
                });

                const navItems = [];
                document.querySelectorAll('nav a, [role="navigation"] a, .nav-item, .navListItem').forEach(el => {
                    navItems.push({
                        text: (el.textContent || '').trim(),
                        href: el.getAttribute('href'),
                        ariaLabel: el.getAttribute('aria-label')
                    });
                });

                const buttons = [];
                document.querySelectorAll('button, [role="button"]').forEach(el => {
                    buttons.push({
                        text: (el.textContent || '').trim().substring(0, 30),
                        ariaLabel: el.getAttribute('aria-label'),
                        classes: Array.from(el.classList).join(' ')
                    });
                });

                const inputs = [];
                document.querySelectorAll('input, textarea').forEach(el => {
                    inputs.push({
                        type: el.getAttribute('type') || el.tagName.toLowerCase(),
                        placeholder: el.getAttribute('placeholder'),
                        ariaLabel: el.getAttribute('aria-label'),
                        name: el.getAttribute('name')
                    });
                });

                return {
                    url: window.location.href,
                    title: document.title,
                    gvRootExists: !!gvRoot,
                    navItems,
                    buttons,
                    inputs,
                    interactiveElements: interactiveElements.slice(0, 100)
                };
            })()
        `;
        return await this.execute(script);
    }

    async getUnreadCount() {
        const script = `
            (function() {
                const badges = document.querySelectorAll('.gv_root .navListItem .navItemBadge');
                let total = 0;
                badges.forEach(badge => {
                    const count = parseInt(badge.textContent?.trim() || '0', 10);
                    if (!isNaN(count)) total += count;
                });
                return total;
            })()
        `;
        return await this.execute(script);
    }

    async getMessages(limit = 10) {
        const script = `
            (function() {
                const messages = [];
                const threads = document.querySelectorAll('.gv_root [data-thread-id], .gv_root .thread-item, .gv_root md-list-item');
                threads.forEach((thread, index) => {
                    if (index >= ${limit}) return;
                    const nameEl = thread.querySelector('.contact-name, .caller-name, [data-contact-name]');
                    const phoneEl = thread.querySelector('.phone-number, [data-phone-number]');
                    const previewEl = thread.querySelector('.message-preview, .snippet, .thread-snippet');
                    const timeEl = thread.querySelector('.timestamp, .time, [data-timestamp]');
                    const isUnread = thread.classList.contains('unread') || thread.querySelector('.unread') !== null;
                    messages.push({
                        name: nameEl?.textContent?.trim() || 'Unknown',
                        phone: phoneEl?.textContent?.trim() || '',
                        preview: previewEl?.textContent?.trim() || '',
                        timestamp: timeEl?.textContent?.trim() || '',
                        isUnread,
                        threadId: thread.getAttribute('data-thread-id') || null
                    });
                });
                return messages;
            })()
        `;
        return await this.execute(script);
    }

    async getContacts(limit = 20) {
        const script = `
            (function() {
                const contacts = [];
                const contactEls = document.querySelectorAll('.gv_root .contact-item, .gv_root [data-contact-id]');
                contactEls.forEach((el, index) => {
                    if (index >= ${limit}) return;
                    const nameEl = el.querySelector('.contact-name, .name');
                    const phoneEl = el.querySelector('.phone-number, .number');
                    contacts.push({
                        name: nameEl?.textContent?.trim() || 'Unknown',
                        phone: phoneEl?.textContent?.trim() || '',
                        contactId: el.getAttribute('data-contact-id') || null
                    });
                });
                return contacts;
            })()
        `;
        return await this.execute(script);
    }

    async navigateToMessages() {
        const script = `
            (function() {
                const messagesNav = document.querySelector('.gv_root [data-nav="messages"]') ||
                                   document.querySelector('.gv_root a[href*="messages"]') ||
                                   document.querySelector('.gv_root [aria-label*="Messages"]');
                if (messagesNav) { messagesNav.click(); return true; }
                return false;
            })()
        `;
        return await this.execute(script);
    }

    async navigateToCalls() {
        const script = `
            (function() {
                const callsNav = document.querySelector('.gv_root [data-nav="calls"]') ||
                                document.querySelector('.gv_root a[href*="calls"]') ||
                                document.querySelector('.gv_root [aria-label*="Calls"]');
                if (callsNav) { callsNav.click(); return true; }
                return false;
            })()
        `;
        return await this.execute(script);
    }

    async openDialpad() {
        const script = `
            (function() {
                const dialpadBtn = document.querySelector('.gv_root [data-action="dialpad"]') ||
                                  document.querySelector('.gv_root [aria-label*="dialpad"]') ||
                                  document.querySelector('.gv_root .dialpad-button') ||
                                  document.querySelector('.gv_root button[aria-label*="Dial"]');
                if (dialpadBtn) { dialpadBtn.click(); return true; }
                return false;
            })()
        `;
        return await this.execute(script);
    }

    async dialNumber(phoneNumber) {
        const script = `
            (function() {
                return new Promise((resolve) => {
                    const dialpadBtn = document.querySelector('.gv_root [data-action="dialpad"]') ||
                                      document.querySelector('.gv_root [aria-label*="dialpad"]') ||
                                      document.querySelector('.gv_root .dialpad-button');
                    if (dialpadBtn) {
                        dialpadBtn.click();
                        setTimeout(() => {
                            const phoneInput = document.querySelector('.gv_root input[type="tel"]') ||
                                              document.querySelector('.gv_root .dialpad-input') ||
                                              document.querySelector('.gv_root input[aria-label*="number"]');
                            if (phoneInput) {
                                phoneInput.value = '${phoneNumber}';
                                phoneInput.dispatchEvent(new Event('input', { bubbles: true }));
                                setTimeout(() => {
                                    const callBtn = document.querySelector('.gv_root [data-action="call"]') ||
                                                   document.querySelector('.gv_root button[aria-label*="Call"]') ||
                                                   document.querySelector('.gv_root .call-button');
                                    if (callBtn) { callBtn.click(); resolve({ success: true, message: 'Call initiated' }); }
                                    else { resolve({ success: false, message: 'Call button not found' }); }
                                }, 500);
                            } else { resolve({ success: false, message: 'Phone input not found' }); }
                        }, 500);
                    } else { resolve({ success: false, message: 'Dialpad button not found' }); }
                });
            })()
        `;
        return await this.execute(script);
    }

    async sendSMS(phoneNumber, message) {
        const escapedMessage = message.replace(/'/g, "\\'").replace(/\n/g, "\\n");
        const script = `
            (function() {
                return new Promise((resolve) => {
                    const composeBtn = document.querySelector('.gv_root [data-action="compose"]') ||
                                      document.querySelector('.gv_root [aria-label*="Send new message"]') ||
                                      document.querySelector('.gv_root .compose-button') ||
                                      document.querySelector('.gv_root button[aria-label*="new message"]');
                    if (composeBtn) {
                        composeBtn.click();
                        setTimeout(() => {
                            const toInput = document.querySelector('.gv_root input[aria-label*="To"]') ||
                                           document.querySelector('.gv_root input[placeholder*="name or number"]') ||
                                           document.querySelector('.gv_root .recipient-input');
                            if (toInput) {
                                toInput.value = '${phoneNumber}';
                                toInput.dispatchEvent(new Event('input', { bubbles: true }));
                                setTimeout(() => {
                                    toInput.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13 }));
                                    setTimeout(() => {
                                        const messageInput = document.querySelector('.gv_root textarea[aria-label*="message"]') ||
                                                            document.querySelector('.gv_root .message-input') ||
                                                            document.querySelector('.gv_root textarea');
                                        if (messageInput) {
                                            messageInput.value = '${escapedMessage}';
                                            messageInput.dispatchEvent(new Event('input', { bubbles: true }));
                                            setTimeout(() => {
                                                const sendBtn = document.querySelector('.gv_root [data-action="send"]') ||
                                                               document.querySelector('.gv_root [aria-label*="Send"]') ||
                                                               document.querySelector('.gv_root .send-button');
                                                if (sendBtn) { sendBtn.click(); resolve({ success: true, message: 'SMS sent' }); }
                                                else { resolve({ success: false, message: 'Send button not found' }); }
                                            }, 300);
                                        } else { resolve({ success: false, message: 'Message input not found' }); }
                                    }, 500);
                                }, 300);
                            } else { resolve({ success: false, message: 'To field not found' }); }
                        }, 500);
                    } else { resolve({ success: false, message: 'Compose button not found' }); }
                });
            })()
        `;
        return await this.execute(script);
    }

    async getCallHistory(limit = 10) {
        const script = `
            (function() {
                const calls = [];
                const callItems = document.querySelectorAll('.gv_root .call-item, .gv_root [data-call-id]');
                callItems.forEach((item, index) => {
                    if (index >= ${limit}) return;
                    calls.push({
                        name: item.querySelector('.caller-name, .contact-name')?.textContent?.trim() || 'Unknown',
                        phone: item.querySelector('.phone-number')?.textContent?.trim() || '',
                        timestamp: item.querySelector('.timestamp, .call-time')?.textContent?.trim() || '',
                        type: item.querySelector('.call-type, [data-call-type]')?.textContent?.trim() || 'unknown',
                        duration: item.querySelector('.call-duration, .duration')?.textContent?.trim() || ''
                    });
                });
                return calls;
            })()
        `;
        return await this.execute(script);
    }

    async getVoicemails(limit = 10) {
        const script = `
            (function() {
                const voicemails = [];
                const vmItems = document.querySelectorAll('.gv_root .voicemail-item, .gv_root [data-voicemail-id]');
                vmItems.forEach((item, index) => {
                    if (index >= ${limit}) return;
                    voicemails.push({
                        name: item.querySelector('.caller-name, .contact-name')?.textContent?.trim() || 'Unknown',
                        phone: item.querySelector('.phone-number')?.textContent?.trim() || '',
                        timestamp: item.querySelector('.timestamp')?.textContent?.trim() || '',
                        transcript: item.querySelector('.transcript, .voicemail-transcript')?.textContent?.trim() || '',
                        duration: item.querySelector('.duration')?.textContent?.trim() || ''
                    });
                });
                return voicemails;
            })()
        `;
        return await this.execute(script);
    }

    async search(query) {
        const escapedQuery = query.replace(/'/g, "\\'");
        const script = `
            (function() {
                return new Promise((resolve) => {
                    const searchInput = document.querySelector('.gv_root input[type="search"]') ||
                                       document.querySelector('.gv_root [aria-label*="Search"]') ||
                                       document.querySelector('.gv_root .search-input');
                    if (searchInput) {
                        searchInput.focus();
                        searchInput.value = '${escapedQuery}';
                        searchInput.dispatchEvent(new Event('input', { bubbles: true }));
                        setTimeout(() => { resolve({ success: true, message: 'Search executed' }); }, 1000);
                    } else { resolve({ success: false, message: 'Search input not found' }); }
                });
            })()
        `;
        return await this.execute(script);
    }

    async isLoggedIn() {
        const script = `
            (function() {
                const loggedInIndicators = document.querySelector('.gv_root .navListItem') ||
                                          document.querySelector('.gv_root [data-nav]') ||
                                          document.querySelector('.gv_root .user-info');
                return !!loggedInIndicators;
            })()
        `;
        return await this.execute(script);
    }

    async getCurrentUser() {
        const script = `
            (function() {
                const userEl = document.querySelector('.gv_root .user-name, .gv_root [data-user-email]');
                const phoneEl = document.querySelector('.gv_root .user-phone, .gv_root [data-user-phone]');
                return {
                    name: userEl?.textContent?.trim() || null,
                    phone: phoneEl?.textContent?.trim() || null
                };
            })()
        `;
        return await this.execute(script);
    }
}

// HTTP Bridge for local API
const http = require('http');
const url = require('url');

class HTTPBridge {
    constructor(googleVoiceAPI, port = 45677) {
        this.api = googleVoiceAPI;
        this.port = port;
        this.server = null;
    }

    start() {
        return new Promise((resolve, reject) => {
            this.server = http.createServer(async (req, res) => {
                res.setHeader('Access-Control-Allow-Origin', 'http://localhost');
                res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
                res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
                res.setHeader('Content-Type', 'application/json');

                if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

                const parsedUrl = url.parse(req.url || '', true);
                const pathname = parsedUrl.pathname || '';
                const query = parsedUrl.query;

                try {
                    let result;
                    switch (pathname) {
                        case '/status':
                            result = { isLoggedIn: await this.api.isLoggedIn(), user: await this.api.getCurrentUser(), status: (await this.api.isLoggedIn()) ? 'ready' : 'not_logged_in' };
                            break;
                        case '/unread': result = { count: await this.api.getUnreadCount() }; break;
                        case '/messages': result = await this.api.getMessages(parseInt(query.limit) || 10); break;
                        case '/contacts': result = await this.api.getContacts(parseInt(query.limit) || 20); break;
                        case '/calls': result = await this.api.getCallHistory(parseInt(query.limit) || 10); break;
                        case '/voicemails': result = await this.api.getVoicemails(parseInt(query.limit) || 10); break;
                        case '/search':
                            if (!query.q) { res.writeHead(400); res.end(JSON.stringify({ error: 'Missing query parameter: q' })); return; }
                            result = await this.api.search(query.q); break;
                        case '/dump-dom': result = await this.api.dumpDOM(); break;
                        case '/send-sms':
                            if (req.method !== 'POST') { res.writeHead(405); res.end(JSON.stringify({ error: 'Use POST' })); return; }
                            const smsBody = await this.readBody(req);
                            if (!smsBody.phone || !smsBody.message) { res.writeHead(400); res.end(JSON.stringify({ error: 'Missing phone/message' })); return; }
                            result = await this.api.sendSMS(smsBody.phone, smsBody.message); break;
                        case '/call':
                            if (req.method !== 'POST') { res.writeHead(405); res.end(JSON.stringify({ error: 'Use POST' })); return; }
                            const callBody = await this.readBody(req);
                            if (!callBody.phone) { res.writeHead(400); res.end(JSON.stringify({ error: 'Missing phone' })); return; }
                            result = await this.api.dialNumber(callBody.phone); break;
                        case '/navigate/messages': result = { success: await this.api.navigateToMessages() }; break;
                        case '/navigate/calls': result = { success: await this.api.navigateToCalls() }; break;
                        case '/dialpad': result = { success: await this.api.openDialpad() }; break;
                        default:
                            res.writeHead(404);
                            res.end(JSON.stringify({ error: 'Not found', endpoints: ['GET /status', 'GET /unread', 'GET /messages', 'GET /dump-dom', 'POST /send-sms', 'POST /call'] }));
                            return;
                    }
                    res.writeHead(200);
                    res.end(JSON.stringify(result));
                } catch (error) {
                    res.writeHead(500);
                    res.end(JSON.stringify({ error: error.message }));
                }
            });

            this.server.listen(this.port, '127.0.0.1', () => {
                console.log(`Google Voice HTTP Bridge running on http://127.0.0.1:${this.port}`);
                resolve(this.port);
            });

            this.server.on('error', (err) => {
                if (err.code === 'EADDRINUSE') { this.port++; this.server.listen(this.port, '127.0.0.1'); }
                else { reject(err); }
            });
        });
    }

    readBody(req) {
        return new Promise((resolve, reject) => {
            let body = '';
            req.on('data', chunk => { body += chunk; });
            req.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(new Error('Invalid JSON')); } });
            req.on('error', reject);
        });
    }

    stop() { if (this.server) { this.server.close(); this.server = null; } }
    getPort() { return this.port; }
}

module.exports = { GoogleVoiceAPI, HTTPBridge };
