export type Row = Record<string, unknown>;
export type Snapshot = Record<string, Row[]> & { server_time?: never };

export type Lot = {
  id: string;
  name: string;
  area: string;
  capacity: number;
  carCapacity: number;
  motorcycleCapacity: number;
  carRemaining: number;
  motorcycleRemaining: number;
  enabledCapacity: number;
  occupied: number;
  availableSlots: number;
  enabled: boolean;
  version: number;
  latitude: number | null;
  longitude: number | null;
  createdAt: string;
};

export type BookingStatus =
  "Đã xác nhận" | "Đang sử dụng" | "Hoàn thành" | "Đã hủy" | "Hết hạn";

export type VehicleKind = "car" | "motorcycle" | "unknown";
export const vehicleKindLabel = (kind: VehicleKind) =>
  kind === "car" ? "Ô tô" : kind === "motorcycle" ? "Xe máy" : "Chưa xác định";

export type Booking = {
  id: string;
  customer: string;
  customerEmail: string;
  customerPhone: string;
  plate: string;
  vehicleId: string;
  vehicleKind: VehicleKind;
  vehicleLabel: string;
  lotId: string;
  slotId: string;
  slotCode: string;
  date: string;
  start: string;
  end: string;
  startsAt: string;
  endsAt: string;
  createdAt: string;
  status: BookingStatus;
  hourlyRate: number;
  freeMinutes: number;
  amount: number;
  version: number;
  prepaid?: boolean;
  checkedIn: string | null;
  checkedOut: string | null;
};

export type Staff = {
  id: string;
  userId: string;
  name: string;
  email: string;
  lotId: string;
  shift: "morning" | "afternoon" | "night";
  active: boolean;
};

export type Pricing = {
  car: number;
  motorcycle: number;
  freeMinutes: number;
  version: number;
};

export type Payment = {
  id: string;
  bookingId: string;
  amount: number;
  method: string;
  paidAt: string;
  receivedBy: string;
  receivedByName: string;
  lotId: string;
  lotName: string;
  plate: string;
  customerName: string;
  vehicleKind: VehicleKind;
  checkedInAt: string | null;
  checkedOutAt: string | null;
  hourlyRate: number;
  freeMinutes: number;
};

export type VehicleInfo = {
  id: string;
  userId: string;
  label: string;
  plate: string;
  kind: VehicleKind;
};

export type AdminNotification = {
  id: string;
  title: string;
  body: string;
  category: string;
  read: boolean;
  createdAt: string;
  bookingId: string | null;
};

export type AdminData = {
  reports: Row[];
  reportEvents: Row[];
  lots: Lot[];
  bookings: Booking[];
  staff: Staff[];
  pricing: Record<string, Pricing>;
  payments: Payment[];
  vehicles: VehicleInfo[];
  notifications: AdminNotification[];
};

export const emptyData: AdminData = {
  reports: [],
  reportEvents: [],
  lots: [],
  bookings: [],
  staff: [],
  pricing: {},
  payments: [],
  vehicles: [],
  notifications: [],
};

export const money = (n: number) =>
  new Intl.NumberFormat("vi-VN").format(Math.round(n)) + "đ";

export function compactMoney(n: number): string {
  const abs = Math.abs(n);
  if (abs >= 1_000_000_000)
    return `${(n / 1_000_000_000).toFixed(1).replace(".", ",")} tỷ`;
  if (abs >= 1_000_000)
    return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, "").replace(".", ",")} tr`;
  if (abs >= 1_000) return `${Math.round(n / 1_000)}k`;
  return `${Math.round(n)}đ`;
}

export const pad = (n: number) => String(n).padStart(2, "0");

export const shortLot = (lot?: Lot) => lot?.name ?? "Chưa phân công";

export const shifts = {
  morning: "Ca sáng",
  afternoon: "Ca chiều",
  night: "Ca đêm",
};

export const shiftTimes: Record<
  keyof typeof shifts,
  { label: string; time: string; color: string }
> = {
  morning: { label: "Ca sáng", time: "06:00 – 14:00", color: "#315fea" },
  afternoon: { label: "Ca chiều", time: "14:00 – 22:00", color: "#17b29a" },
  night: { label: "Ca đêm", time: "22:00 – 06:00", color: "#7b61da" },
};

export const localDate = (value: string | Date = new Date()) => {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

export function formatTime(value: string | Date | null | undefined): string {
  if (!value) return "—";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
}

export function formatDateTime(
  value: string | Date | null | undefined,
): string {
  if (!value) return "—";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function formatDuration(
  start: string | null | undefined,
  end: string | null | undefined,
): string {
  if (!start || !end) return "—";
  const a = new Date(start).getTime(),
    b = new Date(end).getTime();
  if (Number.isNaN(a) || Number.isNaN(b) || b < a) return "—";
  const totalMinutes = Math.max(1, Math.ceil((b - a) / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const mins = totalMinutes % 60;
  if (hours === 0) return `${mins} phút`;
  if (mins === 0) return `${hours} giờ`;
  return `${hours} giờ ${mins} phút`;
}

export function initials(name: string, fallback = "SP"): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return fallback;
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function estimateParkingFee(
  minutes: number,
  hourlyRate: number,
  _freeMinutes: number,
): number {
  return (
    Math.max(1, Math.ceil(Math.max(0, minutes) / 60)) * Math.max(0, hourlyRate)
  );
}

export const statusLabels: Record<string, BookingStatus> = {
  confirmed: "Đã xác nhận",
  parked: "Đang sử dụng",
  completed: "Hoàn thành",
  cancelled: "Đã hủy",
  expired: "Hết hạn",
};
