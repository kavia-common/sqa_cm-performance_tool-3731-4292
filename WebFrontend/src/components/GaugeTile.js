import React from "react";

// PUBLIC_INTERFACE
export function GaugeTile({ title, valueGbps, sublabel, accent = "blue" }) {
  /** Wallboard gauge tile (visual placeholder). valueGbps is a number. */
  const value =
    typeof valueGbps === "number" && Number.isFinite(valueGbps)
      ? valueGbps
      : null;

  return (
    <section className={`gauge gauge-${accent}`} aria-label={`${title} gauge`}>
      <div className="gauge-ring" aria-hidden="true" />
      <div className="gauge-content">
        <div className="gauge-title">{title}</div>
        <div className="gauge-value">
          {value === null ? "--" : value.toFixed(2)}
          <span className="gauge-unit">Gbps</span>
        </div>
        <div className="gauge-sublabel">{sublabel}</div>
      </div>
    </section>
  );
}
