import { createContext, useContext, useState } from "react";
import type { ReactNode } from "react";
import { createSeed } from "./mock";
import type { AdminData } from "./mock";
const KEY = "smartpark-admin-demo-v1";
function load(): AdminData {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const d = JSON.parse(raw);
      if (
        Array.isArray(d.lots) &&
        d.lots.length &&
        Array.isArray(d.bookings) &&
        Array.isArray(d.staff) &&
        d.pricing &&
        d.lots.every(
          (l: unknown) =>
            typeof l === "object" &&
            l !== null &&
            "id" in l &&
            "capacity" in l &&
            typeof l.capacity === "number",
        )
      )
        return d;
    }
  } catch {
    /* Invalid or unavailable storage falls back to a usable demo. */
  }
  return createSeed();
}
type Store = {
  data: AdminData;
  change: (fn: (data: AdminData) => AdminData) => void;
  notice: (text: string) => void;
  reset: () => void;
};
const Context = createContext<Store | null>(null);
export function AdminProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AdminData>(load),
    [toast, setToast] = useState("");
  const notice = (text: string) => {
    setToast(text);
  };
  const change = (fn: (d: AdminData) => AdminData) =>
    setData((prev) => {
      const next = fn(prev);
      try {
        localStorage.setItem(KEY, JSON.stringify(next));
      } catch {
        setToast(
          "Không lưu được bộ nhớ trình duyệt. Thay đổi vẫn có trong phiên demo.",
        );
      }
      return next;
    });
  const reset = () => {
    const next = createSeed();
    setData(next);
    try {
      localStorage.removeItem(KEY);
    } catch {}
    notice("Đã khôi phục dữ liệu demo ban đầu.");
  };
  return (
    <Context.Provider value={{ data, change, notice, reset }}>
      {children}
      {toast && (
        <div className="toast" role="status">
          <span>{toast}</span>
          <button aria-label="Đóng thông báo" onClick={() => setToast("")}>
            ×
          </button>
        </div>
      )}
    </Context.Provider>
  );
}
export function useAdmin() {
  const value = useContext(Context);
  if (!value) throw new Error("AdminProvider is required");
  return value;
}
export function exportCsv(
  filename: string,
  headers: string[],
  rows: (string | number)[][],
) {
  const cell = (value: string | number) => {
    let s = String(value);
    if (/^[=+@-]/.test(s)) s = "'" + s;
    return '"' + s.replaceAll('"', '""') + '"';
  };
  const blob = new Blob(
    [
      "\uFEFF" +
        [headers, ...rows].map((r) => r.map(cell).join(",")).join("\r\n"),
    ],
    { type: "text/csv;charset=utf-8" },
  );
  const url = URL.createObjectURL(blob),
    a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
