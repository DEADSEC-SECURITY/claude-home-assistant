# Claude Terminal Pro for Home Assistant

An enhanced Home Assistant add-on that integrates Anthropic's Claude Code CLI with persistent package management and advanced features.

## Recommended Plugins

For an enhanced Claude Code experience with Home Assistant, we recommend installing the **Claude Home Assistant Plugins**:

**[https://github.com/ESJavadex/claude-homeassistant-plugins](https://github.com/ESJavadex/claude-homeassistant-plugins)**

These plugins provide Claude Code with specialized tools and context for Home Assistant development, including entity management, automation helpers, and more.

### Installation

Run this command inside Claude Terminal Pro:

```bash
npx claude-plugins install @ESJavadex/claude-homeassistant-plugins/homeassistant-config
```

This creates a `CLAUDE.md` file in your Home Assistant config directory with context and instructions tailored for Home Assistant development.

## Fork Attribution

This project is a fork of [heytcass/home-assistant-addons](https://github.com/heytcass/home-assistant-addons) created by Tom Cassady.

**Original project:** [https://github.com/heytcass/home-assistant-addons](https://github.com/heytcass/home-assistant-addons)
**Maintained by:** Javier Santos ([@esjavadex](https://github.com/esjavadex))

### What's Enhanced in This Fork

- **Image Paste Support**: Upload images via paste (Ctrl+V), drag-drop, or upload button for Claude analysis
- **Persistent Package Management**: Install system and Python packages that survive reboots
- **Auto-install Configuration**: Configure packages to auto-install on startup
- **Improved Credential Handling**: Enhanced authentication persistence
- **Additional Documentation**: Comprehensive guides for development and usage

This project maintains the same MIT license as the original.

## Installation

To add this repository to your Home Assistant instance:

1. Go to **Settings** → **Add-ons** → **Add-on Store**
2. Click the three dots menu in the top right corner
3. Select **Repositories**
4. Add the URL: `https://github.com/esjavadex/claude-code-ha`
5. Click **Add**

## Add-ons

### Claude Terminal Pro

A web-based terminal interface with Claude Code CLI pre-installed and enhanced package management. This add-on provides a terminal environment directly in your Home Assistant dashboard, allowing you to use Claude's powerful AI capabilities for coding, automation, and configuration tasks.

#### Core Features
- Web terminal access through your Home Assistant UI
- Pre-installed Claude Code CLI that launches automatically
- Direct access to your Home Assistant config directory
- No configuration needed (uses OAuth)
- Access to Claude's complete capabilities including:
  - Code generation and explanation
  - Debugging assistance
  - Home Assistant automation help
  - Learning resources

#### Enhanced Features (Pro)
- **Image Paste Support**: Paste (Ctrl+V), drag-drop, or upload images for Claude analysis
  - Lightweight service (~10MB RAM, ARM-compatible)
  - Supports JPEG, PNG, GIF, WebP, SVG (10MB limit)
  - Persistent storage in `/data/images/`
  - Perfect for OCR, image analysis, screenshot debugging
- **Persistent Package Management**: Install packages that survive container restarts
- **Auto-install Packages**: Configure APK and pip packages to auto-install on startup
- **Python Virtual Environment**: Isolated Python environment for packages
- **Simple Commands**: Use `persist-install` for easy package management
- **Unrestricted Mode**: Option to run Claude with `--dangerously-skip-permissions` for full file access

#### Configuration Options
- `auto_launch_claude`: Auto-start Claude or show session picker (default: true)
- `dangerously_skip_permissions`: Enable unrestricted file access (default: false)
- `persistent_apk_packages`: System packages to auto-install
- `persistent_pip_packages`: Python packages to auto-install

[Documentation](claude-terminal/DOCS.md)

## Community Tools

Tools built by the community to enhance Claude Terminal:

- **[ha-ws-client-go](https://github.com/schoolboyqueue/home-assistant-blueprints/tree/main/scripts/ha-ws-client-go)** by [@schoolboyqueue](https://github.com/schoolboyqueue) - Lightweight Go CLI for Home Assistant WebSocket API. Gives Claude direct access to entity states, service calls, automation traces, and real-time monitoring. Single binary, no dependencies.

## Support

If you have any questions or issues with this add-on, please create an issue in this repository.

## Credits

**Original Creator:** Tom Cassady ([@heytcass](https://github.com/heytcass)) - Created the initial Claude Terminal add-on
**Fork Maintainer:** Javier Santos ([@esjavadex](https://github.com/esjavadex)) - Added persistent package management and enhancements

This add-on was created and enhanced with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities.

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
