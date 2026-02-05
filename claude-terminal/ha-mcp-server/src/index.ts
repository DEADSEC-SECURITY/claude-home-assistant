#!/usr/bin/env node

/**
 * Home Assistant MCP Server for Claude Code.
 * Provides tools to interact with the HA REST API and Supervisor API.
 * Runs as a stdio MCP server spawned by Claude Code.
 *
 * IMPORTANT: Never use console.log() — stdout is reserved for MCP protocol.
 * Use console.error() for all logging.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { haApiRequest, supervisorApiRequest } from "./ha-client.js";

const server = new McpServer({
  name: "home-assistant",
  version: "1.0.0",
});

// ─── Tool 1: ha_get_entities ────────────────────────────────────────────────

server.tool(
  "ha_get_entities",
  "List Home Assistant entities with current states. Filter by domain (e.g. 'light', 'sensor', 'switch'). Returns entity_id, state, and friendly_name.",
  {
    domain: z
      .string()
      .optional()
      .describe(
        "Entity domain to filter (e.g. 'light', 'sensor', 'binary_sensor'). Omit for all."
      ),
    limit: z
      .number()
      .optional()
      .default(200)
      .describe("Max entities to return. Default 200."),
  },
  async ({ domain, limit }) => {
    const states = (await haApiRequest("/states")) as Array<{
      entity_id: string;
      state: string;
      attributes: Record<string, unknown>;
      last_changed: string;
    }>;

    let filtered = states;
    if (domain) {
      filtered = states.filter((s) =>
        s.entity_id.startsWith(`${domain}.`)
      );
    }

    const limited = filtered.slice(0, limit);
    const lines = limited.map((s) => {
      const name = s.attributes.friendly_name || s.entity_id;
      return `${s.entity_id} — ${s.state} (${name})`;
    });

    const header = domain
      ? `Found ${filtered.length} ${domain} entities`
      : `Found ${states.length} total entities`;
    const showing =
      limited.length < filtered.length
        ? ` (showing first ${limited.length})`
        : "";

    return {
      content: [
        {
          type: "text" as const,
          text: `${header}${showing}:\n\n${lines.join("\n")}`,
        },
      ],
    };
  }
);

// ─── Tool 2: ha_get_entity_state ────────────────────────────────────────────

server.tool(
  "ha_get_entity_state",
  "Get detailed state of a specific entity including all attributes, last_changed, and last_updated.",
  {
    entity_id: z
      .string()
      .describe("Entity ID (e.g. 'light.kitchen', 'sensor.temperature')"),
  },
  async ({ entity_id }) => {
    const state = (await haApiRequest(`/states/${entity_id}`)) as {
      entity_id: string;
      state: string;
      attributes: Record<string, unknown>;
      last_changed: string;
      last_updated: string;
    };

    const attrLines = Object.entries(state.attributes)
      .map(([k, v]) => `  ${k}: ${JSON.stringify(v)}`)
      .join("\n");

    return {
      content: [
        {
          type: "text" as const,
          text: `Entity: ${state.entity_id}\nState: ${state.state}\nLast Changed: ${state.last_changed}\nLast Updated: ${state.last_updated}\n\nAttributes:\n${attrLines}`,
        },
      ],
    };
  }
);

// ─── Tool 3: ha_call_service ────────────────────────────────────────────────

server.tool(
  "ha_call_service",
  "Call a Home Assistant service to control devices, trigger automations, send notifications, etc. Example: domain='light', service='turn_on', target={entity_id:'light.kitchen'}, data={brightness_pct:80}",
  {
    domain: z
      .string()
      .describe("Service domain (e.g. 'light', 'switch', 'automation', 'notify')"),
    service: z
      .string()
      .describe("Service name (e.g. 'turn_on', 'turn_off', 'trigger', 'reload')"),
    target: z
      .object({
        entity_id: z
          .union([z.string(), z.array(z.string())])
          .optional(),
        area_id: z
          .union([z.string(), z.array(z.string())])
          .optional(),
        device_id: z
          .union([z.string(), z.array(z.string())])
          .optional(),
      })
      .optional()
      .describe("Target entities, areas, or devices"),
    data: z
      .record(z.unknown())
      .optional()
      .describe("Service data payload (e.g. {brightness_pct: 80})"),
  },
  async ({ domain, service, target, data }) => {
    const body: Record<string, unknown> = {};
    if (target) {
      if (target.entity_id) body.entity_id = target.entity_id;
      if (target.area_id) body.area_id = target.area_id;
      if (target.device_id) body.device_id = target.device_id;
    }
    if (data) {
      Object.assign(body, data);
    }

    const result = await haApiRequest(`/services/${domain}/${service}`, {
      method: "POST",
      body: Object.keys(body).length > 0 ? body : undefined,
    });

    const changed = Array.isArray(result) ? result.length : 0;
    return {
      content: [
        {
          type: "text" as const,
          text: `Service ${domain}.${service} called successfully. ${changed} entity state(s) changed.`,
        },
      ],
    };
  }
);

// ─── Tool 4: ha_get_areas ───────────────────────────────────────────────────

server.tool(
  "ha_get_areas",
  "List all areas (rooms/zones) defined in Home Assistant with entity counts.",
  {},
  async () => {
    const template = `{% set result = [] %}{% for area_id in areas() %}{% set result = result + [area_id ~ ": " ~ area_name(area_id) ~ " (" ~ (area_entities(area_id) | length) ~ " entities)"] %}{% endfor %}{{ result | join("\\n") }}`;

    const rendered = (await haApiRequest("/template", {
      method: "POST",
      body: { template },
    })) as string;

    return {
      content: [
        {
          type: "text" as const,
          text: `Areas:\n\n${rendered || "No areas defined."}`,
        },
      ],
    };
  }
);

// ─── Tool 5: ha_get_devices ─────────────────────────────────────────────────

server.tool(
  "ha_get_devices",
  "List devices registered in Home Assistant. Can filter by area.",
  {
    area_id: z
      .string()
      .optional()
      .describe("Filter devices by area ID"),
  },
  async ({ area_id }) => {
    let template: string;
    if (area_id) {
      template = `{% for device_id in area_devices('${area_id}') %}{{ device_id }}: {{ device_attr(device_id, 'name') or 'Unknown' }} ({{ device_attr(device_id, 'manufacturer') or '?' }} {{ device_attr(device_id, 'model') or '' }})
{% endfor %}`;
    } else {
      // Get devices via all areas + unassigned
      template = `{% set seen = [] %}{% for area_id in areas() %}{% for device_id in area_devices(area_id) %}{% if device_id not in seen %}{% set seen = seen + [device_id] %}{{ device_id }}: {{ device_attr(device_id, 'name') or 'Unknown' }} [{{ area_name(area_id) }}] ({{ device_attr(device_id, 'manufacturer') or '?' }})
{% endif %}{% endfor %}{% endfor %}`;
    }

    const rendered = (await haApiRequest("/template", {
      method: "POST",
      body: { template },
    })) as string;

    const label = area_id ? `Devices in area '${area_id}'` : "Devices";
    return {
      content: [
        {
          type: "text" as const,
          text: `${label}:\n\n${rendered.trim() || "No devices found."}`,
        },
      ],
    };
  }
);

// ─── Tool 6: ha_get_automations ─────────────────────────────────────────────

server.tool(
  "ha_get_automations",
  "List all automations with their state (on/off), last triggered time, and friendly name.",
  {},
  async () => {
    const states = (await haApiRequest("/states")) as Array<{
      entity_id: string;
      state: string;
      attributes: Record<string, unknown>;
    }>;

    const automations = states.filter((s) =>
      s.entity_id.startsWith("automation.")
    );

    if (automations.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No automations found." }],
      };
    }

    const lines = automations.map((a) => {
      const name = a.attributes.friendly_name || a.entity_id;
      const lastTriggered = a.attributes.last_triggered || "never";
      return `${a.entity_id} — ${a.state} — "${name}" (last triggered: ${lastTriggered})`;
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `Found ${automations.length} automations:\n\n${lines.join("\n")}`,
        },
      ],
    };
  }
);

// ─── Tool 7: ha_get_integrations ────────────────────────────────────────────

server.tool(
  "ha_get_integrations",
  "List all installed integrations/components in Home Assistant.",
  {},
  async () => {
    const config = (await haApiRequest("/config")) as {
      components: string[];
      version: string;
    };

    // Deduplicate by base domain (before the first dot)
    const baseDomains = new Set<string>();
    for (const component of config.components) {
      baseDomains.add(component.split(".")[0]);
    }

    const sorted = [...baseDomains].sort();
    return {
      content: [
        {
          type: "text" as const,
          text: `HA Version: ${config.version}\n${sorted.length} integrations installed:\n\n${sorted.join(", ")}`,
        },
      ],
    };
  }
);

// ─── Tool 8: ha_restart ─────────────────────────────────────────────────────

server.tool(
  "ha_restart",
  "Restart Home Assistant Core. Causes brief downtime. Only use when necessary (after configuration.yaml changes, custom component updates). Always run config check first with `ha core check`.",
  {
    confirm: z
      .boolean()
      .describe("Must be true to confirm restart. Prevents accidents."),
  },
  async ({ confirm }) => {
    if (!confirm) {
      return {
        content: [
          {
            type: "text" as const,
            text: "Restart cancelled. Set confirm=true to proceed. Consider running `ha core check` first to validate configuration.",
          },
        ],
      };
    }

    await haApiRequest("/services/homeassistant/restart", {
      method: "POST",
    });

    return {
      content: [
        {
          type: "text" as const,
          text: "Home Assistant restart initiated. It will be unavailable briefly. Check logs after restart with ha_get_logs.",
        },
      ],
    };
  }
);

// ─── Tool 9: ha_reload_config ───────────────────────────────────────────────

const RELOAD_MAP: Record<string, string> = {
  automation: "automation/reload",
  script: "script/reload",
  scene: "scene/reload",
  group: "group/reload",
  input_boolean: "input_boolean/reload",
  input_number: "input_number/reload",
  input_select: "input_select/reload",
  input_datetime: "input_datetime/reload",
  input_text: "input_text/reload",
  input_button: "input_button/reload",
  timer: "timer/reload",
  counter: "counter/reload",
  schedule: "schedule/reload",
  zone: "zone/reload",
  template: "template/reload",
  person: "person/reload",
  core: "homeassistant/reload_core_config",
};

server.tool(
  "ha_reload_config",
  `Reload a config domain without restarting. Supported: ${Object.keys(RELOAD_MAP).join(", ")}. Use after editing YAML files.`,
  {
    domain: z
      .string()
      .describe(
        `Domain to reload: ${Object.keys(RELOAD_MAP).join(", ")}`
      ),
  },
  async ({ domain }) => {
    const endpoint = RELOAD_MAP[domain];
    if (!endpoint) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Unknown domain '${domain}'. Supported: ${Object.keys(RELOAD_MAP).join(", ")}`,
          },
        ],
      };
    }

    await haApiRequest(`/services/${endpoint}`, { method: "POST" });

    return {
      content: [
        {
          type: "text" as const,
          text: `Reloaded '${domain}' configuration successfully.`,
        },
      ],
    };
  }
);

// ─── Tool 10: ha_get_logs ───────────────────────────────────────────────────

server.tool(
  "ha_get_logs",
  "Get recent Home Assistant logs. Useful for debugging after config changes.",
  {
    lines: z
      .number()
      .optional()
      .default(100)
      .describe("Number of log lines to return. Default 100."),
  },
  async ({ lines }) => {
    // Use the Supervisor API endpoint for logs (plain text response)
    const logs = (await supervisorApiRequest("/core/logs", {
      rawResponse: true,
    })) as string;

    // Take last N lines
    const allLines = logs.split("\n");
    const lastLines = allLines.slice(-lines).join("\n");

    return {
      content: [
        {
          type: "text" as const,
          text: `Home Assistant logs (last ${lines} lines):\n\n${lastLines}`,
        },
      ],
    };
  }
);

// ─── Tool 11: ha_get_history ────────────────────────────────────────────────

server.tool(
  "ha_get_history",
  "Get state history for an entity over a time period.",
  {
    entity_id: z.string().describe("Entity ID to get history for"),
    hours: z
      .number()
      .optional()
      .default(24)
      .describe("Hours of history to retrieve. Default 24."),
  },
  async ({ entity_id, hours }) => {
    const now = new Date();
    const start = new Date(now.getTime() - hours * 60 * 60 * 1000);
    const startISO = start.toISOString();

    const result = (await haApiRequest(
      `/history/period/${startISO}?filter_entity_id=${entity_id}&no_attributes&minimal_response`
    )) as Array<Array<{ state: string; last_changed: string }>>;

    if (!result || result.length === 0 || result[0].length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: `No history found for ${entity_id} in the last ${hours} hours.`,
          },
        ],
      };
    }

    const changes = result[0];
    const lines = changes.map(
      (c) => `${c.last_changed} — ${c.state}`
    );

    return {
      content: [
        {
          type: "text" as const,
          text: `History for ${entity_id} (last ${hours}h, ${changes.length} changes):\n\n${lines.join("\n")}`,
        },
      ],
    };
  }
);

// ─── Tool 12: ha_fire_event ─────────────────────────────────────────────────

server.tool(
  "ha_fire_event",
  "Fire a custom event in Home Assistant. Events can trigger automations.",
  {
    event_type: z
      .string()
      .describe("Event type to fire (e.g. 'custom_event')"),
    event_data: z
      .record(z.unknown())
      .optional()
      .describe("Event data payload"),
  },
  async ({ event_type, event_data }) => {
    await haApiRequest(`/events/${event_type}`, {
      method: "POST",
      body: event_data || {},
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `Event '${event_type}' fired successfully.${event_data ? ` Data: ${JSON.stringify(event_data)}` : ""}`,
        },
      ],
    };
  }
);

// ─── Tool 13: ha_render_template ────────────────────────────────────────────

server.tool(
  "ha_render_template",
  "Render a Jinja2 template in HA context. Test templates before using in automations. Has access to states(), is_state(), area functions, etc.",
  {
    template: z
      .string()
      .describe(
        'Jinja2 template (e.g. \'{{ states("sensor.temperature") }}\')'
      ),
  },
  async ({ template }) => {
    const result = (await haApiRequest("/template", {
      method: "POST",
      body: { template },
    })) as string;

    return {
      content: [
        {
          type: "text" as const,
          text: `Template result:\n\n${result}`,
        },
      ],
    };
  }
);

// ─── Start Server ───────────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Home Assistant MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
