#!/usr/bin/with-contenv bashio

# ha-discovery.sh — Auto-discover Home Assistant setup and generate context file.
# Generates /config/.claude/ha_context.md with the user's specific HA configuration.
# Called at addon startup and can be re-run on demand.

set -e

CONTEXT_FILE="/config/.claude/ha_context.md"
API_BASE="http://supervisor/core/api"

bashio::log.info "Running Home Assistant auto-discovery..."

mkdir -p /config/.claude

# Helper: GET request to HA REST API
api_get() {
    curl -s -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
         -H "Content-Type: application/json" \
         "${API_BASE}${1}" 2>/dev/null
}

# Helper: POST request to HA REST API
api_post() {
    curl -s -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
         -H "Content-Type: application/json" \
         -X POST -d "$2" \
         "${API_BASE}${1}" 2>/dev/null
}

# ── Gather system config ──
bashio::log.info "  Querying HA configuration..."
CONFIG_JSON=$(api_get "/config")
HA_VERSION=$(echo "$CONFIG_JSON" | jq -r '.version // "unknown"')
LOCATION=$(echo "$CONFIG_JSON" | jq -r '.location_name // "unknown"')

# ── Gather entity states ──
bashio::log.info "  Querying entities..."
STATES_JSON=$(api_get "/states")
TOTAL_ENTITIES=$(echo "$STATES_JSON" | jq 'length')

DOMAIN_COUNTS=$(echo "$STATES_JSON" | jq -r '
  group_by(.entity_id | split(".")[0]) |
  map({domain: .[0].entity_id | split(".")[0], count: length}) |
  sort_by(-.count) |
  .[] | "- **\(.domain)**: \(.count) entities"
')

# ── Gather areas ──
bashio::log.info "  Querying areas..."
AREAS_DETAIL=$(api_post "/template" '{"template": "{% for area_id in areas() %}{{ area_id }}: {{ area_name(area_id) }} ({{ area_entities(area_id) | length }} entities)\n{% endfor %}"}' 2>/dev/null || echo "Could not query areas")

# ── Gather integrations ──
bashio::log.info "  Querying integrations..."
INTEGRATIONS=$(echo "$CONFIG_JSON" | jq -r '
  .components // [] |
  map(split(".")[0]) |
  unique |
  sort |
  .[]
')
INTEGRATION_COUNT=$(echo "$INTEGRATIONS" | grep -c . || echo "0")

# ── Gather custom components ──
bashio::log.info "  Checking custom components..."
CUSTOM_COMPONENTS=""
if [ -d "/config/custom_components" ]; then
    CUSTOM_COMPONENTS=$(ls -1 /config/custom_components/ 2>/dev/null | sort)
fi

# ── Gather automations ──
bashio::log.info "  Querying automations..."
AUTOMATIONS=$(echo "$STATES_JSON" | jq -r '
  [.[] | select(.entity_id | startswith("automation."))] |
  .[] | "- **\(.attributes.friendly_name // .entity_id)** (\(.entity_id)) — \(.state)"
')
AUTOMATION_COUNT=$(echo "$STATES_JSON" | jq '[.[] | select(.entity_id | startswith("automation."))] | length')

# ── Gather addons ──
bashio::log.info "  Querying addons..."
ADDONS=$(curl -s -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    http://supervisor/addons 2>/dev/null | jq -r '.data.addons[]? | "- **\(.name)** (\(.slug)) — \(.state)"' 2>/dev/null || echo "Could not query addons")

# ── Write context file ──
bashio::log.info "  Writing context file..."
cat > "${CONTEXT_FILE}" << CONTEXT_EOF
# Home Assistant Installation Context
# Auto-generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Re-run: /opt/scripts/ha-discovery.sh

## System
- **HA Version**: ${HA_VERSION}
- **Location**: ${LOCATION}
- **Total Entities**: ${TOTAL_ENTITIES}
- **Integrations**: ${INTEGRATION_COUNT}
- **Automations**: ${AUTOMATION_COUNT}

## Entities by Domain
${DOMAIN_COUNTS}

## Areas
${AREAS_DETAIL}

## Automations
${AUTOMATIONS}

## Integrations
$(echo "$INTEGRATIONS" | sed 's/^/- /')

## Custom Components
$(if [ -n "$CUSTOM_COMPONENTS" ]; then echo "$CUSTOM_COMPONENTS" | sed 's/^/- /'; else echo "None"; fi)

## Installed Add-ons
${ADDONS}

## Config Files
$(ls -la /config/*.yaml 2>/dev/null | awk '{print "- " $NF " (" $5 " bytes)"}')
CONTEXT_EOF

chmod 644 "${CONTEXT_FILE}"
bashio::log.info "Auto-discovery complete. Written to ${CONTEXT_FILE}"
