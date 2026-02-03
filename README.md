# Voice Desktop - Native macOS App for Google Voice

A native macOS application that wraps Google Voice with custom themes, notifications, and agent automation capabilities.

![Voice Desktop](screenshots/dracula.png)

## Features

- **Native macOS App**: Built with SwiftUI targeting macOS 14+
- **Custom Themes**: Dracula, Solar, Minty, Cerulean, DarkPlus, or default Google Voice theme
- **Menu Bar Integration**: Quick access via menu bar with notification indicator
- **Dock Badge**: Shows unread notification count
- **Notification Support**: Desktop notifications with dock icon bounce
- **Launch at Login**: Start the app automatically when you log in
- **Agent API**: REST API for programmatic control (make calls, send SMS)
- **Keyboard Shortcuts**: Cmd+R to reload, Cmd+Shift+O to open in browser, Cmd+, for settings

## Installation

### Option 1: Build from Source

1. Open `VoiceDesktop.xcworkspace` in Xcode
2. Select the VoiceDesktop scheme
3. Build and run (Cmd+R)

### Option 2: Download Release

Download the latest release from the [Releases](https://github.com/Jerrkawz/google-voice-desktop-app/releases) page.

## Themes

Choose from several built-in themes:

| Theme | Description |
|-------|-------------|
| Default | Original Google Voice appearance |
| Dracula | Popular dark theme with purple accents |
| Solar | Solarized dark color scheme |
| Minty | Light and refreshing green tones |
| Cerulean | Blue-themed interface |
| DarkPlus | VS Code inspired dark theme |

Access themes via **Settings → Appearance**.

## Agent API

Voice Desktop includes a built-in REST API server for programmatic control. This enables AI agents and automation scripts to interact with Google Voice.

### Endpoints

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| GET | `/health` | Health check | - |
| GET | `/status` | Get app status (notifications, theme) | - |
| POST | `/call` | Initiate a phone call | `{"number": "+15551234567"}` |
| POST | `/sms` | Send an SMS message | `{"number": "+15551234567", "text": "Hello"}` |
| POST | `/reload` | Reload the web view | - |
| POST | `/theme` | Change the theme | `{"theme": "dracula"}` |

### Example Usage

```bash
# Check health
curl http://localhost:3000/health

# Get status
curl http://localhost:3000/status

# Make a call
curl -X POST http://localhost:3000/call \
  -H "Content-Type: application/json" \
  -d '{"number": "+15551234567"}'

# Send SMS
curl -X POST http://localhost:3000/sms \
  -H "Content-Type: application/json" \
  -d '{"number": "+15551234567", "text": "Hello from Voice Desktop!"}'
```

The default port is 3000. Configure it in **Settings → Agent**.

## Settings

Access settings via **Voice Desktop → Settings** (Cmd+,):

### General

- **Start at Login**: Automatically launch when you log in
- **Start Minimized**: Start hidden in the menu bar
- **Exit on Close**: Quit the app when window is closed

### Appearance

- **Theme**: Select your preferred color scheme
- **Hide Dialer Sidebar**: Hide the sidebar in dialer view
- **Zoom**: Adjust the zoom level (50% - 200%)

### Agent

- **WebSocket Port**: Configure the REST API server port

## Project Structure

```text
VoiceDesktop/
├── VoiceDesktop.xcworkspace/     # Open this in Xcode
├── VoiceDesktop/                  # Main app target
│   ├── VoiceDesktopApp.swift     # App entry point with scenes
│   └── Assets.xcassets/          # App icons
├── VoiceDesktopPackage/          # Feature code (SPM)
│   ├── Sources/VoiceDesktopFeature/
│   │   ├── Models/               # AppState, ThemeManager, NotificationObserver
│   │   ├── Views/                # ContentView, GoogleVoiceWebView, SettingsView
│   │   ├── Agent/                # AgentBridge REST API
│   │   └── Services/             # LaunchAtLoginManager
│   └── Package.swift             # Dependencies (FlyingFox)
└── Config/                        # Build configuration
    └── VoiceDesktop.entitlements # Permissions
```

## Requirements

- macOS 14.0 or later
- Xcode 16+ (for building)

## Dependencies

- [FlyingFox](https://github.com/swhitty/FlyingFox) - Lightweight HTTP server for the Agent API

## Privacy & Security

This app:

- Loads Google Voice in a WKWebView
- Requires network access for Google Voice and the Agent API
- Requests microphone permission for voice calls
- Stores preferences locally via UserDefaults
- Does not collect or transmit any personal data

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details.

## Credits

- Original Electron version by [Jerrkawz](https://github.com/Jerrkawz)
- Native macOS conversion using modern SwiftUI and Swift 6
