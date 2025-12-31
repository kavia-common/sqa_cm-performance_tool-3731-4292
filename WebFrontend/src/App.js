import React, { useEffect, useMemo, useState } from "react";
import "./App.css";
import { loadRuntimeConfig } from "./runtimeConfig";
import { createApiClient } from "./services/apiClient";
import { createMetricsWsClient } from "./services/metricsWs";
import { StatusBadge } from "./components/StatusBadge";
import { GaugeTile } from "./components/GaugeTile";

// PUBLIC_INTERFACE
function App() {
  /** Main SPA: loads runtime config, shows wallboard dashboard, wires REST + WS. */
  const [theme, setTheme] = useState("dark");

  const [configState, setConfigState] = useState({
    loading: true,
    source: "defaults",
    config: null,
    error: null,
  });

  const [restHealth, setRestHealth] = useState({ status: "unknown", detail: "" });
  const [wsHealth, setWsHealth] = useState({ status: "unknown", detail: "" });

  const [metrics, setMetrics] = useState({
    downloadGbps: null,
    uploadGbps: null,
    lastSeq: null,
    updatedAt: null,
  });

  // Apply theme
  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  // Load runtime config once
  useEffect(() => {
    let mounted = true;
    (async () => {
      const result = await loadRuntimeConfig();
      if (!mounted) return;
      setConfigState({
        loading: false,
        source: result.source,
        config: result.config,
        error: result.error || null,
      });
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const api = useMemo(() => {
    if (!configState.config) return null;
    return createApiClient(configState.config.apiBase);
  }, [configState.config]);

  // REST health polling
  useEffect(() => {
    if (!api) return;
    let stopped = false;

    async function poll() {
      try {
        await api.getHealth();
        if (!stopped) setRestHealth({ status: "ok", detail: "healthy" });
      } catch (e) {
        if (!stopped)
          setRestHealth({
            status: "error",
            detail: e && e.message ? e.message : "error",
          });
      }
    }

    poll();
    const t = window.setInterval(poll, 5000);
    return () => {
      stopped = true;
      window.clearInterval(t);
    };
  }, [api]);

  // WebSocket wiring (metrics)
  useEffect(() => {
    if (!configState.config) return;

    const client = createMetricsWsClient(configState.config.wsUrl, {
      onStatus: (st) => {
        if (st.state === "open") setWsHealth({ status: "ok", detail: "connected" });
        else if (st.state === "connecting")
          setWsHealth({ status: "connecting", detail: "connecting" });
        else if (st.state === "reconnecting")
          setWsHealth({
            status: "warn",
            detail: `reconnecting in ${Math.ceil(st.waitMs / 1000)}s`,
          });
        else if (st.state === "stale")
          setWsHealth({ status: "warn", detail: `stale ${Math.ceil(st.silenceMs / 1000)}s` });
        else if (st.state === "error") setWsHealth({ status: "error", detail: "error" });
        else if (st.state === "closed") setWsHealth({ status: "warn", detail: "closed" });
        else if (st.state === "stopped") setWsHealth({ status: "unknown", detail: "stopped" });
      },
      onMessage: (msg) => {
        // Expected backend message shape is unknown; support a few common shapes:
        // { seq, downloadGbps, uploadGbps } OR { sequence, down_gbps, up_gbps } OR nested { metrics: {...} }
        const m = msg && msg.metrics ? msg.metrics : msg;
        const seq = m && (m.seq ?? m.sequence ?? m.sequenceNumber ?? null);

        const downloadGbps =
          m && (m.downloadGbps ?? m.downGbps ?? m.down_gbps ?? m.rxGbps ?? null);
        const uploadGbps =
          m && (m.uploadGbps ?? m.upGbps ?? m.up_gbps ?? m.txGbps ?? null);

        setMetrics((prev) => ({
          ...prev,
          downloadGbps:
            typeof downloadGbps === "number" ? downloadGbps : prev.downloadGbps,
          uploadGbps: typeof uploadGbps === "number" ? uploadGbps : prev.uploadGbps,
          lastSeq: seq !== null && seq !== undefined ? seq : prev.lastSeq,
          updatedAt: new Date().toISOString(),
        }));
      },
    });

    client.start();
    return () => {
      client.stop();
    };
  }, [configState.config]);

  // Controls visibility (public dashboard hides controls)
  const publicDashboard = configState.config ? configState.config.publicDashboard : true;
  const featureFlags = (configState.config && configState.config.featureFlags) || {};

  // PUBLIC_INTERFACE
  const toggleTheme = () => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  };

  if (configState.loading) {
    return (
      <div className="App">
        <div className="wallboard">
          <div className="topbar">
            <div className="brand">SQA CM Performance Tool</div>
          </div>
          <div className="loading">Loading runtime config…</div>
        </div>
      </div>
    );
  }

  return (
    <div className="App">
      <div className="wallboard">
        <header className="topbar">
          <div className="brand">
            SQA CM Performance Tool
            <span className="version">
              v{configState.config.appVersion} ({configState.source})
            </span>
          </div>

          <div className="topbar-right">
            <div className="badges">
              <StatusBadge
                label="REST"
                status={restHealth.status}
                detail={restHealth.detail}
              />
              <StatusBadge label="WS" status={wsHealth.status} detail={wsHealth.detail} />
            </div>

            <button
              className="theme-toggle"
              onClick={toggleTheme}
              aria-label={`Switch to ${theme === "light" ? "dark" : "light"} mode`}
            >
              {theme === "light" ? "Dark" : "Light"}
            </button>
          </div>
        </header>

        {configState.error ? (
          <div className="banner banner-warn" role="alert">
            Runtime config error: falling back to defaults. Check /config.json format.
          </div>
        ) : null}

        <main className="grid">
          <GaugeTile
            title="Download"
            valueGbps={metrics.downloadGbps}
            sublabel="RX Throughput"
            accent="blue"
          />
          <GaugeTile
            title="Upload"
            valueGbps={metrics.uploadGbps}
            sublabel="TX Throughput"
            accent="orange"
          />

          <section className="panel">
            <div className="panel-title">Status</div>
            <div className="panel-body">
              <div className="kv">
                <div className="k">Public dashboard</div>
                <div className="v">{publicDashboard ? "Yes" : "No"}</div>
              </div>
              <div className="kv">
                <div className="k">Last WS seq</div>
                <div className="v">{metrics.lastSeq ?? "--"}</div>
              </div>
              <div className="kv">
                <div className="k">Last update</div>
                <div className="v">{metrics.updatedAt ?? "--"}</div>
              </div>

              {!publicDashboard ? (
                <div className="controls">
                  <button className="btn" disabled>
                    Start Test (scaffold)
                  </button>
                  <button className="btn btn-secondary" disabled>
                    Stop (scaffold)
                  </button>
                </div>
              ) : (
                <div className="muted">
                  Controls hidden in public dashboard mode.
                </div>
              )}
            </div>
          </section>

          {featureFlags.alerts ? (
            <section className="panel">
              <div className="panel-title">Recent Alerts (scaffold)</div>
              <div className="panel-body muted">
                Will show last 5 minutes alerts timeline here.
              </div>
            </section>
          ) : null}
        </main>
      </div>
    </div>
  );
}

export default App;
