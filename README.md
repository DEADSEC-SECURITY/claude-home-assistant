# Claude Home Assistant

An HA-expert Claude Code addon for Home Assistant with MCP API tools, auto-discovery, and deep Home Assistant knowledge.

Claude Code running inside Home Assistant — but with full awareness of your setup, the ability to control devices via API, and expert knowledge of HA conventions.

## What Makes This Different

Most AI integrations for Home Assistant give you a chatbot. This gives you **Claude Code** — a full AI coding agent — with:

| Feature | Description |
|---------|-------------|
| **13 MCP API Tools** | Claude can query entities, call services, control devices, check logs, render templates, and more — all through structured tool calls |
| **HA Expert Knowledge** | Pre-loaded CLAUDE.md with HA YAML conventions, automation patterns, Jinja2 templates, service call syntax, and best practices |
| **Auto-Discovery** | On startup, scans your HA instance and generates context about your specific entities, areas, devices, integrations, and automations |
| **Full File Access** | Read/write access to `/config` — edit automations.yaml, scripts.yaml, configuration.yaml, custom components, and more |
| **API Key Auth** | Use your own Anthropic API key (no OAuth required) |

## MCP Tools

Claude has direct access to your Home Assistant through these tools:

| Tool | What It Does |
|------|-------------|
| `ha_get_entities` | List entities with states, filter by domain |
| `ha_get_entity_state` | Detailed state + attributes of any entity |
| `ha_call_service` | Control devices, trigger automations, send notifications |
| `ha_get_areas` | List all rooms/areas with entity counts |
| `ha_get_devices` | List devices, filter by area |
| `ha_get_automations` | List automations with status and last triggered |
| `ha_get_integrations` | List all installed integrations |
| `ha_restart` | Restart Home Assistant (with confirmation) |
| `ha_reload_config` | Reload YAML domains (automation, script, scene, etc.) |
| `ha_get_logs` | Get recent logs for debugging |
| `ha_get_history` | Entity state history over time |
| `ha_fire_event` | Fire custom events |
| `ha_render_template` | Test Jinja2 templates in HA context |

## Installation

1. Go to **Settings > Add-ons > Add-on Store**
2. Click the three dots menu (top right) > **Repositories**
3. Add: `https://github.com/DEADSEC-SECURITY/claude-home-assistant`
4. Click **Add**, then find and install **Claude Home Assistant**
5. In the addon config, set your `anthropic_api_key` (or use OAuth)
6. Start the addon and open the web UI

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `anthropic_api_key` | `""` | Your Anthropic API key (masked in UI). Leave empty for OAuth. |
| `auto_discover` | `true` | Auto-scan your HA setup on startup |
| `auto_launch_claude` | `true` | Auto-start Claude or show session picker |
| `dangerously_skip_permissions` | `false` | Skip all permission prompts |
| `persistent_apk_packages` | `[]` | System packages to auto-install |
| `persistent_pip_packages` | `[]` | Python packages to auto-install |

## Example Usage

Ask Claude things like:

- *"Create an automation that turns on the hallway light when motion is detected after sunset"*
- *"What's the current state of my washing machine?"*
- *"Show me the bathroom humidity history for the last 24 hours"*
- *"Add a notification when the 3D printer finishes"*
- *"Debug why my kitchen exhaust automation isn't triggering"*

Claude will use the MCP tools to inspect your setup, write correct YAML with the right entity IDs, reload the config, and verify it works.

## Architecture

- **Base**: Alpine Linux container with ttyd web terminal
- **Claude Code CLI**: Pre-installed via npm (`@anthropic-ai/claude-code`)
- **MCP Server**: Node.js/TypeScript server providing 13 HA API tools
- **CLAUDE.md**: Expert knowledge base auto-loaded by Claude Code
- **Auto-Discovery**: Bash script generating `/config/.claude/ha_context.md`
- **APIs**: HA REST API + Supervisor API via `SUPERVISOR_TOKEN`

## Credits

This project builds on the work of:

- **Tom Cassady** ([@heytcass](https://github.com/heytcass)) — Created the original [Claude Terminal addon](https://github.com/heytcass/home-assistant-addons)
- **Javier Santos** ([@ESJavadex](https://github.com/ESJavadex)) — Enhanced fork with persistent packages, image paste, and session picker ([claude-code-ha](https://github.com/ESJavadex/claude-code-ha))

This addon extends their foundation with MCP API tools, HA expert knowledge, auto-discovery, and API key authentication.

## License

MIT License — see [LICENSE](LICENSE) for details.
