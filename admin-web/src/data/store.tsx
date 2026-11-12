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
import {
  emptyData,
  formatTime,
  localDate,
  statusLabels,
} from "./models";
import type {
  AdminData,
  AdminNotification,
  Row,
  VehicleKind,
} from "./models";
import { AdminLogin } from "../components/admin-auth";

type Store = {
  data: AdminData;
  profile: Row;
  notice: (text: string) => void;
  refresh: () => Promise<void>;
  command: (name: string, params: Row) => Promise<boolean>;
  signOut: () => Promise<void>;
  online: boolean;
  syncing: boolean;
  lastUpdated: string;
};

const Context = createContext<Store | null>(null);

function normalizeKind(raw: unknown): VehicleKind {
  return raw === "motorcycle" ? "motorcycle" : "car";
}

function normalize(raw: Record<string, Row[]>, userId: string): AdminData {
  const profiles = raw.profiles ?? [];
  const profileById = new Map<string, Row>(
    profiles.map((p) => [String(p.id), p]),
  );

  const own = (raw.lots ?? []).filter((l) => l.owner_id === userId);
  const lotById = new Map<string, Row>(own.map((l) => [String(l.id), l]));

  const slots = (raw.slots ?? []).filter((s) => lotById.has(String(s.lot_id)));
  const slotById = new Map<string, Row>(slots.map((s) => [String(s.id), s]));

  const bookings = (raw.bookings ?? []).filter((b) =>
    lotById.has(String(b.lot_id)),
  );
  const bookingById = new Map<string, Row>(
    bookings.map((b) => [String(b.id), b]),
  );

  const usedVehicleIds = new Set(
    bookings.map((b) => String(b.vehicle_id ?? "")).filter(Boolean),
  );
  const rawVehicles = (raw.vehicles ?? []).filter((v) =>
    usedVehicleIds.has(String(v.id)),
  );
  const vehicleById = new Map<string, Row>(
    rawVehicles.map((v) => [String(v.id), v]),
  );

  const lots = own.map((l) => {
    const lid = String(l.id);
    const lotSlots = slots.filter((s) => String(s.lot_id) === lid);
    const occupied = bookings.filter(
      (b) => String(b.lot_id) === lid && b.status === "parked",
    ).length;
    return {
      id: lid,
      name: String(l.name ?? ""),
      area: String(l.area ?? ""),
      enabled: l.enabled === true,
      capacity: lotSlots.length,
      enabledCapacity: lotSlots.filter((s) => s.enabled === true).length,
      occupied,
      availableSlots: lotSlots.filter(
        (s) => s.enabled === true && s.occupied !== true,
      ).length,
      version: Number(l.version ?? 0),
      latitude: l.latitude == null ? null : Number(l.latitude),
      longitude: l.longitude == null ? null : Number(l.longitude),
      createdAt: String(l.created_at ?? ""),
    };
  });

  const normalizedBookings = bookings.map((b) => {
    const customerProfile = profileById.get(String(b.customer_id ?? ""));
    const vehicle = vehicleById.get(String(b.vehicle_id ?? ""));
    const slot = slotById.get(String(b.slot_id ?? ""));
    const startsAt = String(b.starts_at ?? "");
    const endsAt = String(b.ends_at ?? "");
    return {
      id: String(b.id),
      customer: String(customerProfile?.name ?? ""),
      customerEmail: String(customerProfile?.email ?? ""),
      customerPhone: String(customerProfile?.phone ?? ""),
      plate: String(b.plate ?? ""),
      vehicleId: String(b.vehicle_id ?? ""),
      vehicleKind: normalizeKind(vehicle?.kind),
      vehicleLabel: String(vehicle?.label ?? ""),
      lotId: String(b.lot_id),
      slotId: String(b.slot_id ?? ""),
      slotCode: String(slot?.code ?? ""),
      date: localDate(startsAt),
      start: formatTime(startsAt),
      end: formatTime(endsAt),
      startsAt,
      endsAt,
      createdAt: String(b.created_at ?? ""),
      status: statusLabels[String(b.status)] ?? "Đã xác nhận",
      hourlyRate: Number(b.hourly_rate ?? 0),
      freeMinutes: Number(b.free_minutes ?? 0),
      amount: Number(b.amount ?? 0),
      version: Number(b.version ?? 0),
      checkedIn: b.checked_in_at == null ? null : String(b.checked_in_at),
      checkedOut: b.checked_out_at == null ? null : String(b.checked_out_at),
    };
  });

  const staff = (raw.memberships ?? [])
    .filter((s) => lotById.has(String(s.lot_id)))
    .map((s) => {
      const p = profileById.get(String(s.user_id ?? ""));
      return {
        id: `${s.lot_id}:${s.user_id}`,
        userId: String(s.user_id),
        lotId: String(s.lot_id),
        name: String(p?.name ?? ""),
        email: String(p?.email ?? ""),
        shift: s.shift as "morning" | "afternoon" | "night",
        active: s.active === true,
      };
    });

  const pricing = Object.fromEntries(
    own.map((l) => [
      String(l.id),
      {
        car: Number(l.car_rate ?? 0),
        motorcycle: Number(l.motorcycle_rate ?? 0),
        freeMinutes: Number(l.free_minutes ?? 0),
        version: Number(l.version ?? 0),
      },
    ]),
  );

  const payments = (raw.payments ?? [])
    .filter((p) => bookingById.has(String(p.booking_id)))
    .map((p) => {
      const booking = bookingById.get(String(p.booking_id));
      const lid = String(booking?.lot_id ?? "");
      const lot = lotById.get(lid);
      const vehicle = vehicleById.get(String(booking?.vehicle_id ?? ""));
      const customer = profileById.get(String(booking?.customer_id ?? ""));
      const collectorId = String(p.received_by ?? "");
      const collector = profileById.get(collectorId);
      return {
        id: String(p.id),
        bookingId: String(p.booking_id),
        amount: Number(p.amount ?? 0),
        method: String(p.method ?? "cash"),
        paidAt: String(p.paid_at ?? ""),
        receivedBy: collectorId,
        receivedByName: String(collector?.name ?? collector?.email ?? ""),
        lotId: lid,
        lotName: String(lot?.name ?? ""),
        plate: String(booking?.plate ?? ""),
        customerName: String(customer?.name ?? ""),
        vehicleKind: normalizeKind(vehicle?.kind),
        checkedInAt:
          booking?.checked_in_at == null ? null : String(booking.checked_in_at),
        checkedOutAt:
          booking?.checked_out_at == null
            ? null
            : String(booking.checked_out_at),
        hourlyRate: Number(booking?.hourly_rate ?? 0),
        freeMinutes: Number(booking?.free_minutes ?? 0),
      };
    })
    .sort((a, b) => b.paidAt.localeCompare(a.paidAt));

  const normalizedSlots = slots.map((s) => ({
    id: String(s.id),
    lotId: String(s.lot_id),
    code: String(s.code ?? ""),
    enabled: s.enabled === true,
    occupied: s.occupied === true,
  }));

  const vehicles = rawVehicles.map((v) => ({
    id: String(v.id),
    userId: String(v.user_id ?? ""),
    label: String(v.label ?? ""),
    plate: String(v.plate ?? ""),
    kind: normalizeKind(v.kind),
  }));

  const notifications: AdminNotification[] = (raw.notifications ?? [])
    .filter((n) => n.user_id == null || String(n.user_id) === userId)
    .map((n) => ({
      id: String(n.id),
      title: String(n.title ?? ""),
      body: String(n.body ?? ""),
      category: String(n.category ?? "system"),
      read: n.read === true,
      createdAt: String(n.created_at ?? ""),
      bookingId: n.booking_id == null ? null : String(n.booking_id),
    }))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  return {
    lots,
    bookings: normalizedBookings,
    staff,
    pricing,
    payments,
    slots: normalizedSlots,
    vehicles,
    notifications,
  };
}

export function AdminProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null),
    [ready, setReady] = useState(false),
    [profile, setProfile] = useState<Row>({}),
    [data, setData] = useState(emptyData),
    [toast, setToast] = useState(""),
    [online, setOnline] = useState(false),
    [syncing, setSyncing] = useState(false),
    [lastUpdated, setLastUpdated] = useState(""),
    [busy, setBusy] = useState(false),
    [recovery, setRecovery] = useState(false),
    [newPassword, setNewPassword] = useState("");
  const generation = useRef(0),
    refreshing = useRef(false),
    queuedRefresh = useRef(false),
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
        queuedRefresh.current = false;
        setSyncing(false);
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
    if (!session) return;
    if (refreshing.current) {
      queuedRefresh.current = true;
      return;
    }
    refreshing.current = true;
    setSyncing(true);
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
      if (generation.current === requestGeneration) {
        refreshing.current = false;
        setSyncing(false);
        if (queuedRefresh.current) {
          queuedRefresh.current = false;
          void refresh();
        }
      }
    }
  }, [session]);

  useEffect(() => {
    if (!session) return;
    void refresh();
    let timer: ReturnType<typeof setTimeout>;
    const update = () => {
      clearTimeout(timer);
      timer = setTimeout(() => void refresh(), 300);
    };
    const onVisibilityChange = () => {
      if (document.visibilityState === "visible") update();
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
    const interval = setInterval(() => void refresh(), 25000);
    window.addEventListener("online", update);
    window.addEventListener("focus", update);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      clearTimeout(timer);
      clearInterval(interval);
      window.removeEventListener("online", update);
      window.removeEventListener("focus", update);
      document.removeEventListener("visibilitychange", onVisibilityChange);
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
        syncing,
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
  if (text.includes("USER_EMAIL_NOT_CONFIRMED"))
    return "Tài khoản này chưa xác nhận email. Hãy xác nhận email trước khi cấp quyền nhân viên.";
  if (text.includes("FORBIDDEN"))
    return "Bạn chỉ có thể cấp hoặc thu hồi quyền nhân viên tại bãi do mình quản lý.";
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
