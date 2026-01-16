/**********************************************************************************************************************
 * Preload script for the main application window.  Contains all code
 * that needs to execute before the window's web content begins loading.
 **********************************************************************************************************************/

const {ipcRenderer} = require('electron');
const constants = require('./constants');

(async() => {
    // Get this application's execution path.
    const appPath = await ipcRenderer.invoke('get-appPath');

    // Modify JavaScript's "Notification" class such that all notifications that get generated will have a
    // click handler attached to them which fires a "notification-clicked" event back at the main process.
    const {notificationShim} = require('./utils/notificationShim');
    notificationShim(appPath);

    // MCP Action Handler
    ipcRenderer.on('mcp-action', (event, action) => {
        console.log('Received MCP action:', action);
        handleMcpAction(action);
    });
})();

function handleMcpAction(action) {
    if (action.type === 'call') {
        performCall(action.number);
    } else if (action.type === 'sms') {
        performSms(action.number, action.text);
    }
}

function performCall(number) {
    console.log(`Attempting to call ${number}`);
    // Strategy:
    // 1. Find the "Make a call" button or input.
    // 2. This is tricky without selectors.
    //    We can try to find the input with placeholder "Enter a name or number"

    // Note: These selectors are hypothetical and need verification against live Google Voice.
    // Google Voice uses dynamic class names often, but sometimes aria-labels stay consistent.

    // Try to find the input field for dialing
    const input = document.querySelector(`input[placeholder="${constants.SELECTOR_INPUT_PLACEHOLDER}"]`) ||
                  document.querySelector(`input[aria-label="${constants.SELECTOR_INPUT_ARIA_LABEL}"]`);

    if (input) {
        input.focus();

        // Simulate typing (React-compatible)
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
        nativeInputValueSetter.call(input, number);

        input.dispatchEvent(new Event('input', { bubbles: true }));

        // Wait a bit then look for call button
        setTimeout(() => {
            // This is a guess. Often the autocomplete shows up.
            // We might need to hit "Enter".
            input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true }));

            // Or look for a "Call" button that appears.
            // const callBtn = document.querySelector('button[aria-label="Call"]');
        }, 500);
    } else {
        console.error('Could not find dial input');
        // Fallback: Try to find a "Make a call" button to open the dial pad/input
        const makeCallBtn = document.querySelector(constants.SELECTOR_MAKE_CALL_BUTTON);
        if (makeCallBtn) {
            makeCallBtn.click();
            setTimeout(() => performCall(number), 500); // Retry after clicking
        }
    }
}

function performSms(number, text) {
    console.log(`Attempting to sms ${number}: ${text}`);
    // Strategy: similar to call, but select the SMS tab or button first?
    // Usually typing a number in the main search bar allows you to select "Send message"

    // For now, logging.
    alert(`MCP Action: SMS to ${number}\nMessage: ${text}\n(Automation to be implemented)`);
}