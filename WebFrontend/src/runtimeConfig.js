import { z } from "zod";

/**
 * Runtime config contract per OpenAPI.
 * We validate at runtime because /config.json is loaded after build to support env changes without rebuild.
 */
const AppRuntimeConfigSchema = z.object({
  appVersion: z.string(),
  apiBase: z.string(),
  wsUrl: z.string(),
  publicDashboard: z.boolean(),
  featureFlags: z.record(z.boolean()),
  sentryDsn: z.string().nullable().optional(),
});

// PUBLIC_INTERFACE
export function getBuildTimeDefaults() {
  /** Build-time defaults from CRA env vars (REACT_APP_* only). */
  const apiBase =
    process.env.REACT_APP_API_BASE ||
    process.env.REACT_APP_BACKEND_URL ||
    "http://localhost:8000";

  const wsUrl =
    process.env.REACT_APP_WS_URL ||
    (apiBase.startsWith("https://")
      ? apiBase.replace(/^https:/, "wss:")
      : apiBase.replace(/^http:/, "ws:")) + "/v1/ws/metrics";

  let featureFlags = {};
  try {
    // Optional convenience: allow JSON string in REACT_APP_FEATURE_FLAGS
    if (process.env.REACT_APP_FEATURE_FLAGS) {
      const parsed = JSON.parse(process.env.REACT_APP_FEATURE_FLAGS);
      if (parsed && typeof parsed === "object") featureFlags = parsed;
    }
  } catch {
    // ignore
  }

  const publicDashboard =
    (process.env.REACT_APP_EXPERIMENTS_ENABLED || "").toLowerCase() === "true"
      ? true
      : true;

  return {
    appVersion: process.env.REACT_APP_APP_VERSION || "0.1.0",
    apiBase,
    wsUrl,
    publicDashboard,
    featureFlags,
    sentryDsn: null,
  };
}

// PUBLIC_INTERFACE
export async function loadRuntimeConfig() {
  /**
   * Loads runtime config from /config.json (served from public/) and merges over build-time defaults.
   * Returns { config, source } where source indicates if runtime config was used.
   */
  const defaults = getBuildTimeDefaults();

  try {
    const res = await fetch("/config.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`Failed to load /config.json: HTTP ${res.status}`);
    const json = await res.json();

    const parsed = AppRuntimeConfigSchema.safeParse({
      ...defaults,
      ...json,
      featureFlags: { ...(defaults.featureFlags || {}), ...(json.featureFlags || {}) },
    });

    if (!parsed.success) {
      // If runtime config is malformed, fall back to defaults to keep UI usable.
      // We keep the error for diagnostics.
      return { config: defaults, source: "defaults", error: parsed.error };
    }

    return { config: parsed.data, source: "runtime" };
  } catch (error) {
    return { config: defaults, source: "defaults", error };
  }
}
