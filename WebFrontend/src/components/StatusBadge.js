import React from "react";

// PUBLIC_INTERFACE
export function StatusBadge({ label, status, detail }) {
  /** A small badge showing status: ok/warn/error/unknown/connecting. */
  const cls =
    status === "ok"
      ? "badge badge-ok"
      : status === "warn"
        ? "badge badge-warn"
        : status === "error"
          ? "badge badge-error"
          : status === "connecting"
            ? "badge badge-connecting"
            : "badge badge-unknown";

  return (
    <div className={cls} role="status" aria-label={`${label} status ${status}`}>
      <span className="badge-label">{label}</span>
      <span className="badge-status">{status}</span>
      {detail ? <span className="badge-detail">{detail}</span> : null}
    </div>
  );
}
