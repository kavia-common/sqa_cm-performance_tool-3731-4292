/**
 * WebSocket client with reconnect backoff and optional heartbeat.
 * The backend is expected to push metrics frames with sequence numbers.
 */

// PUBLIC_INTERFACE
export function createMetricsWsClient(wsUrl, handlers = {}) {
  /** Create a WS client that connects to wsUrl and emits events to handlers. */
  let ws = null;
  let stopped = false;

  let attempt = 0;
  let heartbeatTimer = null;
  let lastMessageAt = 0;

  const {
    onOpen = () => {},
    onClose = () => {},
    onError = () => {},
    onMessage = () => {},
    onStatus = () => {},
  } = handlers;

  function clearHeartbeat() {
    if (heartbeatTimer) {
      window.clearInterval(heartbeatTimer);
      heartbeatTimer = null;
    }
  }

  function startHeartbeat() {
    clearHeartbeat();
    // App-level heartbeat: if no messages arrive for a while, we reconnect.
    heartbeatTimer = window.setInterval(() => {
      if (stopped) return;
      const now = Date.now();
      const silenceMs = now - lastMessageAt;
      if (lastMessageAt !== 0 && silenceMs > 15_000) {
        onStatus({ state: "stale", silenceMs });
        try {
          ws && ws.close();
        } catch {
          // ignore
        }
      }
    }, 5_000);
  }

  function computeBackoffMs() {
    // Exponential backoff with jitter, capped.
    const base = Math.min(10_000, 500 * Math.pow(2, attempt));
    const jitter = Math.floor(Math.random() * 250);
    return base + jitter;
  }

  function connect() {
    if (stopped) return;
    try {
      ws = new WebSocket(wsUrl);
    } catch (error) {
      onError(error);
      scheduleReconnect();
      return;
    }

    onStatus({ state: "connecting" });

    ws.onopen = () => {
      attempt = 0;
      lastMessageAt = Date.now();
      onStatus({ state: "open" });
      onOpen();
      startHeartbeat();
    };

    ws.onmessage = (event) => {
      lastMessageAt = Date.now();
      let data = event.data;
      try {
        if (typeof data === "string") {
          data = JSON.parse(data);
        }
      } catch {
        // keep raw if not JSON
      }
      onMessage(data);
    };

    ws.onerror = (event) => {
      onStatus({ state: "error" });
      onError(event);
    };

    ws.onclose = () => {
      clearHeartbeat();
      onStatus({ state: "closed" });
      onClose();
      scheduleReconnect();
    };
  }

  function scheduleReconnect() {
    if (stopped) return;
    attempt += 1;
    const waitMs = computeBackoffMs();
    onStatus({ state: "reconnecting", waitMs, attempt });
    window.setTimeout(() => {
      if (!stopped) connect();
    }, waitMs);
  }

  return {
    // PUBLIC_INTERFACE
    start() {
      stopped = false;
      connect();
    },
    // PUBLIC_INTERFACE
    stop() {
      stopped = true;
      clearHeartbeat();
      try {
        ws && ws.close();
      } catch {
        // ignore
      }
      ws = null;
      onStatus({ state: "stopped" });
    },
    // PUBLIC_INTERFACE
    send(payload) {
      if (!ws || ws.readyState !== WebSocket.OPEN) return false;
      ws.send(typeof payload === "string" ? payload : JSON.stringify(payload));
      return true;
    },
  };
}
