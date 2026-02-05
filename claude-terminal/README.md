# Claude Home Assistant — Addon

HA-expert Claude Code with MCP API tools, auto-discovery, and full Home Assistant integration.

![Claude Terminal Screenshot](screenshot.png)

## What Is This?

A Home Assistant addon that runs Claude Code in a web terminal — enhanced with:

- **13 MCP tools** for direct HA API access (entities, services, areas, devices, logs, templates, etc.)
- **CLAUDE.md** with deep HA expertise (YAML conventions, automation patterns, Jinja2, best practices)
- **Auto-discovery** that scans your installation and gives Claude context about your specific setup
- **API key auth** as an alternative to OAuth
- **Persistent packages** (APK + pip) that survive container restarts
- **Image paste support** for visual analysis

## Quick Start

1. Install the addon (see [main README](../README.md) for repo setup)
2. Set your `anthropic_api_key` in the addon configuration (or use OAuth)
3. Start the addon and open the web UI
4. Ask Claude to do things — it already knows your setup

```
> What lights do I have in the living room?
> Create an automation that notifies me when the dryer finishes
> Show me the last 24 hours of bathroom humidity
> Turn off all lights in the bedroom
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `anthropic_api_key` | password | `""` | Anthropic API key. Leave empty for OAuth. |
| `auto_discover` | bool | `true` | Scan HA setup on startup and generate context |
| `auto_launch_claude` | bool | `true` | Auto-start Claude or show session picker |
| `dangerously_skip_permissions` | bool | `false` | Skip all permission prompts (MCP, file edits, bash) |
| `persistent_apk_packages` | list | `[]` | System packages to auto-install on startup |
| `persistent_pip_packages` | list | `[]` | Python packages to auto-install on startup |

## MCP Tools Reference

All tools are available automatically — Claude uses them when relevant.

| Tool | Description |
|------|-------------|
| `ha_get_entities` | List entities with states. Filter by domain (light, sensor, etc.) |
| `ha_get_entity_state` | Detailed state + all attributes for one entity |
| `ha_call_service` | Call any HA service (light.turn_on, notify.send, etc.) |
| `ha_get_areas` | List all areas/rooms with entity counts |
| `ha_get_devices` | List devices, optionally filtered by area |
| `ha_get_automations` | List automations with on/off state and last triggered |
| `ha_get_integrations` | List all installed integrations |
| `ha_restart` | Restart HA Core (requires confirm=true) |
| `ha_reload_config` | Reload a YAML domain (automation, script, scene, etc.) |
| `ha_get_logs` | Recent HA logs for debugging |
| `ha_get_history` | Entity state history over a time period |
| `ha_fire_event` | Fire custom events for testing |
| `ha_render_template` | Render Jinja2 templates in HA context |

## How It Works

On startup, the addon:

1. **Deploys CLAUDE.md** to `/config/` — Claude Code auto-loads this as project instructions
2. **Runs auto-discovery** — queries your HA instance and writes `/config/.claude/ha_context.md` with your entities, areas, devices, integrations, and automations
3. **Registers the MCP server** — writes to `~/.claude.json` so Claude Code discovers the HA tools
4. **Starts the web terminal** — ttyd serves a bash session that launches Claude Code

## CLI Commands

```bash
claude                  # Start Claude Code (auto-launched by default)
claude -i               # Interactive mode
claude "your prompt"    # One-shot query
persist-install <pkg>   # Install a package persistently
ha core check           # Validate HA config before restart
```

## Troubleshooting

**MCP tools not showing up:**
- Check addon logs for "MCP server 'home-assistant' registered"
- Run `/mcp` inside Claude Code to list available tools
- Restart the addon to re-register

**Authentication issues:**
```bash
claude-auth debug       # Show credential status
claude-logout           # Clear credentials and re-authenticate
```

**Auto-discovery failed:**
- Check that `auto_discover` is `true` in config
- Run manually: `/opt/scripts/ha-discovery.sh`
- Check `/config/.claude/ha_context.md` was created

## Architecture

```
claude-terminal/
  config.yaml           # Addon manifest
  Dockerfile            # Container build
  run.sh                # Startup script (env, MCP registration, discovery)
  CLAUDE.md             # HA expert knowledge (deployed to /config/)
  ha-mcp-server/        # TypeScript MCP server
    src/
      index.ts          # 13 tool definitions
      ha-client.ts      # Shared HTTP client for HA API
  scripts/
    ha-discovery.sh     # Auto-discovery script
  image-service/        # Image upload/paste service
```

## Credits

Built on the excellent work of:

- **Tom Cassady** ([@heytcass](https://github.com/heytcass)) — Original [Claude Terminal addon](https://github.com/heytcass/home-assistant-addons)
- **Javier Santos** ([@ESJavadex](https://github.com/ESJavadex)) — Enhanced fork with persistent packages, image paste, session picker ([claude-code-ha](https://github.com/ESJavadex/claude-code-ha))

This addon adds MCP API tools, HA expert knowledge, auto-discovery, and API key authentication on top of their work.

## License

MIT License
