/**
 * Google Voice DOM API
 *
 * This module provides functions to interact with the Google Voice web interface
 * by executing JavaScript in the Electron BrowserWindow context.
 *
 * Note: These selectors may break if Google updates their UI.
 * If things stop working, inspect the Google Voice page and update selectors.
 */

import type { BrowserWindow } from 'electron';

export interface Message {
    name: string;
    phone: string;
    preview: string;
    timestamp: string;
    isUnread: boolean;
    threadId: string | null;
}

export interface Contact {
    name: string;
    phone: string;
    contactId: string | null;
}

export interface CallRecord {
    name: string;
    phone: string;
    timestamp: string;
    type: string;
    duration: string;
}

export interface Voicemail {
    name: string;
    phone: string;
    timestamp: string;
    transcript: string;
    duration: string;
}

export interface ActionResult {
    success: boolean;
    message: string;
}

export interface UserInfo {
    name: string | null;
    phone: string | null;
}

export interface DOMDump {
    url: string;
    title: string;
    gvRootExists: boolean;
    navItems: string[];
    buttons: string[];
    inputs: string[];
    interactiveElements: Array<{
        tag: string;
        id: string;
        classes: string[];
        ariaLabel: string | null;
        dataAttributes: Record<string, string>;
        text: string;
    }>;
}

export class GoogleVoiceAPI {
    private win: BrowserWindow;

    constructor(win: BrowserWindow) {
        this.win = win;
    }

    /**
     * Execute JavaScript in the browser context
     */
    private async execute<T>(script: string): Promise<T> {
        if (!this.win || this.win.isDestroyed()) {
            throw new Error('Browser window not available');
        }
        return await this.win.webContents.executeJavaScript(script);
    }

    /**
     * Dump DOM structure for debugging selectors
     */
    async dumpDOM(): Promise<DOMDump> {
        const script = `
            (function() {
                const gvRoot = document.querySelector('.gv_root');

                // Get all interactive elements
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

                // Get nav items
                const navItems = [];
                document.querySelectorAll('nav a, [role="navigation"] a, .nav-item, .navListItem').forEach(el => {
                    navItems.push({
                        text: (el.textContent || '').trim(),
                        href: el.getAttribute('href'),
                        ariaLabel: el.getAttribute('aria-label')
                    });
                });

                // Get all buttons
                const buttons = [];
                document.querySelectorAll('button, [role="button"]').forEach(el => {
                    buttons.push({
                        text: (el.textContent || '').trim().substring(0, 30),
                        ariaLabel: el.getAttribute('aria-label'),
                        classes: Array.from(el.classList).join(' ')
                    });
                });

                // Get all inputs
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
                    interactiveElements: interactiveElements.slice(0, 100) // Limit to first 100
                };
            })()
        `;
        return await this.execute<DOMDump>(script);
    }

    /**
     * Get unread message count
     */
    async getUnreadCount(): Promise<number> {
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
        return await this.execute<number>(script);
    }

    /**
     * Get recent messages/conversations
     */
    async getMessages(limit: number = 10): Promise<Message[]> {
        const script = `
            (function() {
                const messages = [];
                const threads = document.querySelectorAll('.gv_root [data-thread-id], .gv_root .thread-item, .gv_root md-list-item');

                threads.forEach((thread, index) => {
                    if (index >= ${limit}) return;

                    const nameEl = thread.querySelector('.contact-name, .caller-name, [data-contact-name]');
                    const name = nameEl?.textContent?.trim() || 'Unknown';

                    const phoneEl = thread.querySelector('.phone-number, [data-phone-number]');
                    const phone = phoneEl?.textContent?.trim() || '';

                    const previewEl = thread.querySelector('.message-preview, .snippet, .thread-snippet');
                    const preview = previewEl?.textContent?.trim() || '';

                    const timeEl = thread.querySelector('.timestamp, .time, [data-timestamp]');
                    const timestamp = timeEl?.textContent?.trim() || '';

                    const isUnread = thread.classList.contains('unread') ||
                                     thread.querySelector('.unread') !== null;

                    messages.push({
                        name,
                        phone,
                        preview,
                        timestamp,
                        isUnread,
                        threadId: thread.getAttribute('data-thread-id') || null
                    });
                });

                return messages;
            })()
        `;
        return await this.execute<Message[]>(script);
    }

    /**
     * Get contacts/recent numbers
     */
    async getContacts(limit: number = 20): Promise<Contact[]> {
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
        return await this.execute<Contact[]>(script);
    }

    /**
     * Navigate to messages tab
     */
    async navigateToMessages(): Promise<boolean> {
        const script = `
            (function() {
                const messagesNav = document.querySelector('.gv_root [data-nav="messages"]') ||
                                   document.querySelector('.gv_root a[href*="messages"]') ||
                                   document.querySelector('.gv_root [aria-label*="Messages"]');
                if (messagesNav) {
                    messagesNav.click();
                    return true;
                }
                return false;
            })()
        `;
        return await this.execute<boolean>(script);
    }

    /**
     * Navigate to calls tab
     */
    async navigateToCalls(): Promise<boolean> {
        const script = `
            (function() {
                const callsNav = document.querySelector('.gv_root [data-nav="calls"]') ||
                                document.querySelector('.gv_root a[href*="calls"]') ||
                                document.querySelector('.gv_root [aria-label*="Calls"]');
                if (callsNav) {
                    callsNav.click();
                    return true;
                }
                return false;
            })()
        `;
        return await this.execute<boolean>(script);
    }

    /**
     * Open the dialpad
     */
    async openDialpad(): Promise<boolean> {
        const script = `
            (function() {
                const dialpadBtn = document.querySelector('.gv_root [data-action="dialpad"]') ||
                                  document.querySelector('.gv_root [aria-label*="dialpad"]') ||
                                  document.querySelector('.gv_root .dialpad-button') ||
                                  document.querySelector('.gv_root button[aria-label*="Dial"]');
                if (dialpadBtn) {
                    dialpadBtn.click();
                    return true;
                }
                return false;
            })()
        `;
        return await this.execute<boolean>(script);
    }

    /**
     * Dial a phone number
     */
    async dialNumber(phoneNumber: string): Promise<ActionResult> {
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

                                    if (callBtn) {
                                        callBtn.click();
                                        resolve({ success: true, message: 'Call initiated' });
                                    } else {
                                        resolve({ success: false, message: 'Call button not found' });
                                    }
                                }, 500);
                            } else {
                                resolve({ success: false, message: 'Phone input not found' });
                            }
                        }, 500);
                    } else {
                        resolve({ success: false, message: 'Dialpad button not found' });
                    }
                });
            })()
        `;
        return await this.execute<ActionResult>(script);
    }

    /**
     * Send an SMS message
     */
    async sendSMS(phoneNumber: string, message: string): Promise<ActionResult> {
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

                                                if (sendBtn) {
                                                    sendBtn.click();
                                                    resolve({ success: true, message: 'SMS sent' });
                                                } else {
                                                    resolve({ success: false, message: 'Send button not found' });
                                                }
                                            }, 300);
                                        } else {
                                            resolve({ success: false, message: 'Message input not found' });
                                        }
                                    }, 500);
                                }, 300);
                            } else {
                                resolve({ success: false, message: 'To field not found' });
                            }
                        }, 500);
                    } else {
                        resolve({ success: false, message: 'Compose button not found' });
                    }
                });
            })()
        `;
        return await this.execute<ActionResult>(script);
    }

    /**
     * Get call history
     */
    async getCallHistory(limit: number = 10): Promise<CallRecord[]> {
        const script = `
            (function() {
                const calls = [];
                const callItems = document.querySelectorAll('.gv_root .call-item, .gv_root [data-call-id]');

                callItems.forEach((item, index) => {
                    if (index >= ${limit}) return;

                    const nameEl = item.querySelector('.caller-name, .contact-name');
                    const phoneEl = item.querySelector('.phone-number');
                    const timeEl = item.querySelector('.timestamp, .call-time');
                    const typeEl = item.querySelector('.call-type, [data-call-type]');
                    const durationEl = item.querySelector('.call-duration, .duration');

                    calls.push({
                        name: nameEl?.textContent?.trim() || 'Unknown',
                        phone: phoneEl?.textContent?.trim() || '',
                        timestamp: timeEl?.textContent?.trim() || '',
                        type: typeEl?.textContent?.trim() || typeEl?.getAttribute('data-call-type') || 'unknown',
                        duration: durationEl?.textContent?.trim() || ''
                    });
                });

                return calls;
            })()
        `;
        return await this.execute<CallRecord[]>(script);
    }

    /**
     * Get voicemails
     */
    async getVoicemails(limit: number = 10): Promise<Voicemail[]> {
        const script = `
            (function() {
                const voicemails = [];
                const vmItems = document.querySelectorAll('.gv_root .voicemail-item, .gv_root [data-voicemail-id]');

                vmItems.forEach((item, index) => {
                    if (index >= ${limit}) return;

                    const nameEl = item.querySelector('.caller-name, .contact-name');
                    const phoneEl = item.querySelector('.phone-number');
                    const timeEl = item.querySelector('.timestamp');
                    const transcriptEl = item.querySelector('.transcript, .voicemail-transcript');
                    const durationEl = item.querySelector('.duration');

                    voicemails.push({
                        name: nameEl?.textContent?.trim() || 'Unknown',
                        phone: phoneEl?.textContent?.trim() || '',
                        timestamp: timeEl?.textContent?.trim() || '',
                        transcript: transcriptEl?.textContent?.trim() || '',
                        duration: durationEl?.textContent?.trim() || ''
                    });
                });

                return voicemails;
            })()
        `;
        return await this.execute<Voicemail[]>(script);
    }

    /**
     * Search for a contact or message
     */
    async search(query: string): Promise<ActionResult> {
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

                        setTimeout(() => {
                            resolve({ success: true, message: 'Search executed' });
                        }, 1000);
                    } else {
                        resolve({ success: false, message: 'Search input not found' });
                    }
                });
            })()
        `;
        return await this.execute<ActionResult>(script);
    }

    /**
     * Check if user is logged in
     */
    async isLoggedIn(): Promise<boolean> {
        const script = `
            (function() {
                const loggedInIndicators = document.querySelector('.gv_root .navListItem') ||
                                          document.querySelector('.gv_root [data-nav]') ||
                                          document.querySelector('.gv_root .user-info');
                return !!loggedInIndicators;
            })()
        `;
        return await this.execute<boolean>(script);
    }

    /**
     * Get current user info
     */
    async getCurrentUser(): Promise<UserInfo> {
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
        return await this.execute<UserInfo>(script);
    }
}

export default GoogleVoiceAPI;
