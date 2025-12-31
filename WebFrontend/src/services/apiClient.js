/**
 * Minimal REST client for Backend/API endpoints.
 * Uses fetch to keep dependencies minimal.
 */

// PUBLIC_INTERFACE
export function createApiClient(apiBase) {
  /** Create an API client bound to a base URL. */
  const base = (apiBase || "").replace(/\/+$/, "");

  async function request(path, options = {}) {
    const url = `${base}${path.startsWith("/") ? "" : "/"}${path}`;
    const res = await fetch(url, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
    });

    if (!res.ok) {
      const text = await res.text().catch(() => "");
      const err = new Error(`API ${res.status} ${res.statusText}: ${text}`);
      err.status = res.status;
      throw err;
    }
    // allow empty responses
    const contentType = res.headers.get("content-type") || "";
    if (contentType.includes("application/json")) return res.json();
    return res.text();
  }

  return {
    // PUBLIC_INTERFACE
    getHealth: () => request("/v1/health"),
    // PUBLIC_INTERFACE
    getCurrentMetrics: () => request("/v1/metrics/current"),
  };
}
