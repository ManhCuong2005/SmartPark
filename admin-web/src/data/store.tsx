import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import type { ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { emptyData, localDate, statusLabels } from "./models";
import type { AdminData, Row } from "./models";
import { AdminLogin } from "../components/admin-auth";

type Store = {
  data: AdminData;
  profile: Row;
  notice: (text: string) => void;
  refresh: () => Promise<void>;
  command: (name: string, params: Row) => Promise<boolean>;
  signOut: () => Promise<void>;
  online: boolean;
  lastUpdated: string;
};
const Context = createContext<Store | null>(null);
function normalize(raw: Record<string, Row[]>, userId: string): AdminData {
  const profiles = raw.profiles ?? [],
    own = (raw.lots ?? []).filter((l) => l.owner_id === userId),
    ids = new Set(own.map((l) => l.id)),
    slots = (raw.slots ?? []).filter((s) => ids.has(s.lot_id)),
    bookings = (raw.bookings ?? []).filter((b) => ids.has(b.lot_id));
  return {
    lots: own.map((l) => ({
      id: String(l.id),
      name: String(l.name),
      area: String(l.area),
      enabled: l.enabled === true,
      capacity: slots.filter((s) => s.lot_id === l.id).length,
      occupied: bookings.filter(
        (b) => b.lot_id === l.id && b.status === "parked",
      ).length,
      version: Number(l.version),
      latitude: l.latitude == null ? null : Number(l.latitude),
      longitude: l.longitude == null ? null : Number(l.longitude),
    })),
    bookings: bookings.map((b) => ({
      id: String(b.id),
      customer: String(
        profiles.find((p) => p.id === b.customer_id)?.name ?? "",
      ),
      plate: String(b.plate),
      lotId: String(b.lot_id),
      date: localDate(String(b.starts_at)),
      start: new Date(String(b.starts_at)).toLocaleTimeString("vi-VN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
      end: new Date(String(b.ends_at)).toLocaleTimeString("vi-VN", {
        hour: "2-digit",
        minute: "2-digit",
      }),
      status: statusLabels[String(b.status)],
      amount: Number(b.amount),
      version: Number(b.version),
      checkedIn: b.checked_in_at == null ? null : String(b.checked_in_at),
      checkedOut: b.checked_out_at == null ? null : String(b.checked_out_at),
    })),
    staff: (raw.memberships ?? [])
      .filter((s) => ids.has(s.lot_id))
      .map((s) => ({
        id: `${s.lot_id}:${s.user_id}`,
        userId: String(s.user_id),
        lotId: String(s.lot_id),
        name: String(profiles.find((p) => p.id === s.user_id)?.name ?? ""),
        email: String(profiles.find((p) => p.id === s.user_id)?.email ?? ""),
        shift: s.shift as "morning" | "afternoon" | "night",
        active: s.active === true,
      })),
    pricing: Object.fromEntries(
      own.map((l) => [
        String(l.id),
        {
          car: Number(l.car_rate),
          motorcycle: Number(l.motorcycle_rate),
          freeMinutes: Number(l.free_minutes),
          version: Number(l.version),
        },
      ]),
    ),
    payments: (raw.payments ?? [])
      .filter((p) => bookings.some((b) => b.id === p.booking_id))
      .map((p) => ({
        id: String(p.id),
        bookingId: String(p.booking_id),
        amount: Number(p.amount),
        paidAt: String(p.paid_at),
      })),
    slots: slots.map((s) => ({
      id: String(s.id),
      lotId: String(s.lot_id),
      code: String(s.code),
      enabled: s.enabled === true,
      occupied: s.occupied === true,
    })),
    vehicles: (raw.vehicles ?? []).filter((v) =>
      bookings.some((b) => b.vehicle_id === v.id),
    ),
  };
}
export function AdminProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null),
    [ready, setReady] = useState(false),
    [profile, setProfile] = useState<Row>({}),
    [data, setData] = useState(emptyData),
    [toast, setToast] = useState(""),
    [online, setOnline] = useState(false),
    [lastUpdated, setLastUpdated] = useState(""),
    [busy, setBusy] = useState(false),
    [recovery, setRecovery] = useState(false),
    [newPassword, setNewPassword] = useState("");
  const generation = useRef(0),
    refreshing = useRef(false),
    currentUser = useRef<string | null>(null);
  useEffect(() => {
    let active = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (active) {
        setSession(data.session);
        setReady(true);
      }
    });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, next) => {
      if (event === "PASSWORD_RECOVERY") setRecovery(true);
      if (currentUser.current !== (next?.user.id ?? null)) {
        generation.current++;
        refreshing.current = false;
        setData(emptyData);
        setProfile({});
        setOnline(false);
        currentUser.current = next?.user.id ?? null;
      }
      setSession(next);
      setReady(true);
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);
  const refresh = useCallback(async () => {
    if (!session || refreshing.current) return;
    refreshing.current = true;
    const requestGeneration = generation.current;
    try {
      const { data: raw, error } = await supabase.rpc("park_snapshot");
      if (error) throw error;
      if (generation.current !== requestGeneration) return;
      const rows = raw as Record<string, Row[]>;
      setProfile(
        (rows.profiles ?? []).find((p) => p.id === session.user.id) ?? {},
      );
      setData(normalize(rows, session.user.id));
      setOnline(true);
      setLastUpdated(new Date().toLocaleString("vi-VN"));
    } catch (e) {
      if (generation.current === requestGeneration) {
        setOnline(false);
        setToast(message(e));
      }
    } finally {
      if (generation.current === requestGeneration) refreshing.current = false;
    }
  }, [session]);
  useEffect(() => {
    if (!session) return;
    void refresh();
    let timer: ReturnType<typeof setTimeout>;
    const update = () => {
      clearTimeout(timer);
      timer = setTimeout(() => void refresh(), 350);
    };
    const channel = supabase.channel(`admin:${session.user.id}`);
    for (const table of [
      "parking_lots",
      "parking_slots",
      "lot_staff",
      "bookings",
      "vehicles",
      "payments",
      "notifications",
    ]) {
      channel.on(
        "postgres_changes",
        { event: "*", schema: "public", table },
        update,
      );
    }
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") update();
    });
    const interval = setInterval(() => void refresh(), 30000);
    window.addEventListener("online", update);
    window.addEventListener("focus", update);
    return () => {
      clearTimeout(timer);
      clearInterval(interval);
      window.removeEventListener("online", update);
      window.removeEventListener("focus", update);
      void supabase.removeChannel(channel);
    };
  }, [session, refresh]);
  async function command(name: string, params: Row) {
    try {
      const { error } = await supabase.rpc(name, params);
      if (error) throw error;
      await refresh();
      return true;
    } catch (e) {
      setToast(message(e));
      return false;
    }
  }
  async function signOut() {
    const { error } = await supabase.auth.signOut({ scope: "local" });
    if (error) setToast(error.message);
  }
  if (recovery && session)
    return (
      <main className="auth-page">
        <form
          className="panel auth-panel"
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            try {
              const { error } = await supabase.auth.updateUser({
                password: newPassword,
              });
              if (error) throw error;
              await signOut();
              setRecovery(false);
              setNewPassword("");
              setToast("Đã đổi mật khẩu. Có thể đăng nhập lại trong app.");
            } catch (e) {
              setToast(message(e));
            } finally {
              setBusy(false);
            }
          }}
        >
          <h1>Đặt mật khẩu mới</h1>
          <label>
            Mật khẩu mới
            <input
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
            />
          </label>
          <button className="button" disabled={busy}>
            Lưu mật khẩu
          </button>
          <p role="status">{toast}</p>
        </form>
      </main>
    );
  if (!ready)
    return <main className="auth-page">Đang khôi phục phiên đăng nhập…</main>;
  if (!session)
    return (
      <AdminLogin
        notice={toast}
        onSignIn={async (email, password) => {
          setToast("");
          const { error } = await supabase.auth.signInWithPassword({
            email,
            password,
          });
          if (error) throw error;
        }}
        onResetPassword={async (email) => {
          const { error } = await supabase.auth.resetPasswordForEmail(email);
          if (error) throw error;
        }}
      />
    );
  if (profile.role !== "owner")
    return (
      <main className="auth-page">
        <section className="panel auth-panel">
          <h1>SmartPark</h1>
          <p role="alert">
            {toast ||
              "Tài khoản chưa có quyền chủ bãi hoặc backend chưa được thiết lập."}
          </p>
          <button className="button" onClick={() => void refresh()}>
            Tải lại
          </button>
          <button className="button secondary" onClick={() => void signOut()}>
            Đăng xuất
          </button>
        </section>
      </main>
    );
  return (
    <Context.Provider
      value={{
        data,
        profile,
        notice: setToast,
        refresh,
        command,
        signOut,
        online,
        lastUpdated,
      }}
    >
      {children}
      {toast && (
        <div className="toast" role="status">
          <span>{toast}</span>
          <button onClick={() => setToast("")} aria-label="Đóng thông báo">
            ×
          </button>
        </div>
      )}
    </Context.Provider>
  );
}
function message(e: unknown) {
  const text =
    e && typeof e === "object" && "message" in e
      ? String(e.message)
      : String(e);
  if (text.includes("park_snapshot") || text.includes("schema cache"))
    return "Chưa có backend SmartPark. Chạy migration trong Supabase SQL Editor rồi tải lại.";
  if (text.includes("VERSION_CONFLICT"))
    return "Dữ liệu đã thay đổi trên thiết bị khác. Tải lại trước khi sửa.";
  if (text.includes("USER_MUST_REGISTER_FIRST"))
    return "Nhân viên cần đăng ký tài khoản trong app trước khi phân công.";
  return text;
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
