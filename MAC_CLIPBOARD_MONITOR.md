# Mac Clipboard Monitor for Claude Terminal Pro

Automatically upload images from your Mac clipboard to Claude Terminal Pro running on your Raspberry Pi.

## How It Works

1. **You copy an image** on your Mac (Cmd+C from anywhere)
2. **Monitor detects it** and automatically uploads to your Raspberry Pi
3. **Path is copied to clipboard** - ready to paste into Claude Code CLI
4. **Use with Claude** - just paste the path: `analyze /data/images/clipboard-123.png`

## Installation

### 1. Install Python Dependencies

```bash
# Install required packages
pip3 install pillow requests pasteboard
```

### 2. Find Your Add-on URL

**Option A: Via Home Assistant Ingress (recommended)**
```bash
# If you access HA at homeassistant.local:8123
http://homeassistant.local:8123

# Or with IP address
http://192.168.1.XXX:8123
```

**Option B: Direct Port Access**
```bash
# If you know your Raspberry Pi IP
http://192.168.1.XXX:7680
```

### 3. Run the Monitor

```bash
cd /path/to/claude-code-ha
python3 mac-clipboard-monitor.py http://homeassistant.local:8123
```

## Usage

Once running, the monitor will:

```
✓ Connected to Claude Terminal Pro at http://homeassistant.local:8123

Clipboard monitor started. Press Ctrl+C to stop.
Monitoring clipboard for images...
Images will be uploaded to: http://homeassistant.local:8123/upload

[14:23:45] ✓ Uploaded: clipboard-20250123_142345_789.png (234.5 KB)
    Path copied to clipboard: /data/images/clipboard-20250123_142345_789.png
    Ready to paste into Claude Code CLI!
```

### Workflow

1. **Copy any image** (screenshot, file, web image) with **Cmd+C**
2. **Monitor uploads it** automatically to your Raspberry Pi
3. **Path is in your clipboard** - switch to Claude Terminal
4. **Paste** (Cmd+V) into Claude: `/data/images/clipboard-123.png`
5. **Ask Claude** to analyze it!

Example Claude commands:
```bash
# Analyze an image
analyze /data/images/clipboard-20250123_142345_789.png

# Extract text from screenshot
read the text from /data/images/clipboard-20250123_142345_789.png

# Describe what's in the image
what do you see in /data/images/clipboard-20250123_142345_789.png
```

## Running in Background

### Option 1: Keep Terminal Open
```bash
# Just leave the script running in a terminal window
python3 mac-clipboard-monitor.py http://homeassistant.local:8123
```

### Option 2: Background Process
```bash
# Run in background (output to log file)
nohup python3 mac-clipboard-monitor.py http://homeassistant.local:8123 > clipboard-monitor.log 2>&1 &

# Check if it's running
ps aux | grep mac-clipboard-monitor

# Stop it
pkill -f mac-clipboard-monitor
```

### Option 3: Launch Agent (Auto-start on Login)

Create `~/Library/LaunchAgents/com.claude.clipboard-monitor.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.clipboard-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>/path/to/claude-code-ha/mac-clipboard-monitor.py</string>
        <string>http://homeassistant.local:8123</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-clipboard-monitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-clipboard-monitor.error.log</string>
</dict>
</plist>
```

Then:
```bash
# Load the launch agent
launchctl load ~/Library/LaunchAgents/com.claude.clipboard-monitor.plist

# Check status
launchctl list | grep claude

# Stop it
launchctl unload ~/Library/LaunchAgents/com.claude.clipboard-monitor.plist
```

## Troubleshooting

### "Could not connect to server"

**Check your URL**:
```bash
# Test with curl
curl http://homeassistant.local:8123/health

# Should return: {"status":"ok","uploadDir":"/data/images"}
```

**If using ingress**, the path might need `/api/hassio_ingress/<TOKEN>/`:
- The monitor will still work, just update the URL
- Or use direct port access: `http://raspberry-pi-ip:7680`

### "Module not found: pasteboard"

```bash
# Reinstall dependencies
pip3 install --upgrade pillow requests pasteboard
```

### "Permission denied"

The script needs clipboard access permissions on macOS:
- System Preferences → Security & Privacy → Privacy → Accessibility
- Add Terminal or your terminal app

### Images not uploading

```bash
# Test clipboard manually
python3 -c "import pasteboard; print(pasteboard.Pasteboard().get_contents())"

# Should show clipboard contents when you have an image copied
```

## Features

- ✅ **Automatic detection** - no manual uploads needed
- ✅ **Fast** - checks clipboard every 500ms
- ✅ **Smart** - only uploads new images (hash-based deduplication)
- ✅ **Clipboard integration** - path automatically copied for pasting
- ✅ **Cross-platform paths** - works with Home Assistant ingress or direct access
- ✅ **Error handling** - continues running even if upload fails
- ✅ **Lightweight** - minimal CPU/memory usage

## Comparison with Web Interface

| Method | Pros | Cons |
|--------|------|------|
| **Mac Monitor Script** | • Truly automatic (Cmd+C anywhere)<br>• No browser needed<br>• Works with any clipboard source | • Requires Python setup<br>• Must run script<br>• Mac only |
| **Web Interface Upload** | • No setup required<br>• Works on any OS<br>• Built into add-on | • Manual upload button<br>• Must open browser<br>• Paste detection limited |

## Security Note

The monitor sends images over HTTP to your local network. If you need encryption:

```bash
# Use HTTPS if your Home Assistant has SSL
python3 mac-clipboard-monitor.py https://homeassistant.local:8123
```

## Stopping the Monitor

```bash
# Press Ctrl+C in the terminal, or:
pkill -f mac-clipboard-monitor
```

---

**Enjoy seamless image uploads to Claude Code!** 🎉
