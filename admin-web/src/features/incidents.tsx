import { useRef, useState } from "react";
import { useAdmin } from "../data/store";
import { formatDateTime } from "../data/models";
import type { Row } from "../data/models";
import { Button, Panel } from "../components/ui";

const labels: Record<string, string> = {
  open: "Mới gửi",
  move_requested: "Đã yêu cầu di chuyển",
  assigned: "Đã tiếp nhận",
  in_progress: "Đang xử lý",
  resolved: "Đã giải quyết",
  rejected: "Đã từ chối",
};

export function IncidentsPage() {
  const { data, command } = useAdmin();
  const [busy, setBusy] = useState(false);
  const attempts = useRef(new Map<string, string>());
  async function act(r: Row, kind: string, extra: Row = {}) {
    const payload = { report_id: r.id, expected_version: r.version, ...extra };
    const key = JSON.stringify({ kind, payload });
    const id = attempts.current.get(key) ?? crypto.randomUUID();
    attempts.current.set(key, id);
    setBusy(true);
    try {
      if (
        await command("apply_operation", {
          p_operation_id: id,
          p_kind: kind,
          p_payload: payload,
        })
      )
        attempts.current.delete(key);
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <div className="page-heading">
        <div>
          <h1>Báo cáo đỗ sai</h1>
          <p>
            Theo dõi báo cáo, yêu cầu chủ xe di chuyển và cập nhật kết quả xử
            lý.
          </p>
        </div>
      </div>
      {!data.reports.length && (
        <Panel>
          <p>Chưa có báo cáo.</p>
        </Panel>
      )}
      {data.reports.map((r) => (
        <Panel key={String(r.id)} className="incident-panel">
          <h2>
            {String(r.plate)} · {labels[String(r.status)]}
          </h2>
          <p>
            {data.lots.find((l) => l.id === r.lot_id)?.name} ·{" "}
            {formatDateTime(String(r.created_at))}
          </p>
          <p>{String(r.description)}</p>
          {!["resolved", "rejected"].includes(String(r.status)) && (
            <div className="report-actions">
              <Button
                disabled={busy}
                onClick={() => void act(r, "report.request_move")}
              >
                Yêu cầu chủ xe di chuyển
              </Button>
              <Button
                secondary
                disabled={busy}
                onClick={() =>
                  void act(r, "report.progress", { status: "in_progress" })
                }
              >
                Bắt đầu xử lý
              </Button>
              <Button
                secondary
                disabled={busy}
                onClick={() =>
                  void act(r, "report.progress", { status: "resolved" })
                }
              >
                Đã giải quyết
              </Button>
              <Button
                secondary
                disabled={busy}
                onClick={() =>
                  void act(r, "report.progress", { status: "rejected" })
                }
              >
                Từ chối báo cáo
              </Button>
            </div>
          )}
          <details>
            <summary>Lịch sử xử lý</summary>
            <ol>
              {data.reportEvents
                .filter((e) => e.report_id === r.id)
                .map((e) => (
                  <li key={String(e.id)}>
                    {formatDateTime(String(e.created_at))} ·{" "}
                    {labels[String(e.status)]} {String(e.note ?? "")}
                  </li>
                ))}
            </ol>
          </details>
        </Panel>
      ))}
    </>
  );
}
