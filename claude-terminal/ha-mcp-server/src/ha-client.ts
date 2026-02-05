/**
 * Shared HTTP client for Home Assistant API communication.
 * Uses SUPERVISOR_TOKEN from environment for authentication.
 *
 * Two API bases:
 * - HA REST API: http://supervisor/core/api/* (entity states, services, templates, etc.)
 * - Supervisor API: http://supervisor/* (addon management, system info, logs)
 */

const SUPERVISOR_TOKEN = process.env.SUPERVISOR_TOKEN;
const HA_API_BASE = "http://supervisor/core/api";
const SUPERVISOR_API_BASE = "http://supervisor";

if (!SUPERVISOR_TOKEN) {
  console.error(
    "WARNING: SUPERVISOR_TOKEN not set. HA API calls will fail."
  );
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  timeout?: number;
  rawResponse?: boolean;
}

export async function haApiRequest(
  endpoint: string,
  options: RequestOptions = {}
): Promise<unknown> {
  const { method = "GET", body, timeout = 30000 } = options;
  const url = `${HA_API_BASE}${endpoint}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${SUPERVISOR_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });

    if (!response.ok) {
      const text = await response.text().catch(() => "");
      throw new Error(
        `HA API ${method} ${endpoint} failed (${response.status}): ${text}`
      );
    }

    const contentType = response.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      return await response.json();
    }
    return await response.text();
  } finally {
    clearTimeout(timer);
  }
}

export async function supervisorApiRequest(
  endpoint: string,
  options: RequestOptions = {}
): Promise<unknown> {
  const { method = "GET", body, timeout = 30000, rawResponse = false } =
    options;
  const url = `${SUPERVISOR_API_BASE}${endpoint}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${SUPERVISOR_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });

    if (!response.ok) {
      const text = await response.text().catch(() => "");
      throw new Error(
        `Supervisor API ${method} ${endpoint} failed (${response.status}): ${text}`
      );
    }

    if (rawResponse) {
      return await response.text();
    }

    const contentType = response.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      return await response.json();
    }
    return await response.text();
  } finally {
    clearTimeout(timer);
  }
}

export { HA_API_BASE, SUPERVISOR_API_BASE };
