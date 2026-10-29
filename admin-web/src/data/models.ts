export type Row = Record<string, unknown>;
export type Snapshot = Record<string, Row[]> & { server_time?: never };
export type Lot = {
  id: string;
  name: string;
  area: string;
  capacity: number;
  occupied: number;
  enabled: boolean;
  version: number;
  latitude: number | null;
  longitude: number | null;
};
export type BookingStatus =
  "Đã xác nhận" | "Đang sử dụng" | "Hoàn thành" | "Đã hủy";
export type Booking = {
  id: string;
  customer: string;
  plate: string;
  lotId: string;
  date: string;
  start: string;
  end: string;
  status: BookingStatus;
  amount: number;
  version: number;
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
  paidAt: string;
};
export type Slot = {
  id: string;
  lotId: string;
  code: string;
  enabled: boolean;
  occupied: boolean;
};
export type AdminData = {
  lots: Lot[];
  bookings: Booking[];
  staff: Staff[];
  pricing: Record<string, Pricing>;
  payments: Payment[];
  slots: Slot[];
  vehicles: Row[];
};
export const emptyData: AdminData = {
  lots: [],
  bookings: [],
  staff: [],
  pricing: {},
  payments: [],
  slots: [],
  vehicles: [],
};
export const money = (n: number) =>
  new Intl.NumberFormat("vi-VN").format(n) + "đ";
export const pad = (n: number) => String(n).padStart(2, "0");
export const shortLot = (lot?: Lot) => lot?.name ?? "Chưa phân công";
export const shifts = {
  morning: "Ca sáng",
  afternoon: "Ca chiều",
  night: "Ca đêm",
};
export const localDate = (value: string | Date = new Date()) => {
  const d = new Date(value);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};
export const statusLabels: Record<string, BookingStatus> = {
  confirmed: "Đã xác nhận",
  parked: "Đang sử dụng",
  completed: "Hoàn thành",
  cancelled: "Đã hủy",
};
