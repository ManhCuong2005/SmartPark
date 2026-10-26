export type Lot = {
  id: string;
  name: string;
  area: string;
  capacity: number;
  occupied: number;
  enabled: boolean;
};
export type BookingStatus =
  "Đã xác nhận" | "Đang sử dụng" | "Hoàn thành" | "Chờ đến" | "Đã hủy";
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
};
export type Staff = {
  id: string;
  name: string;
  initials: string;
  email: string;
  lotId: string;
  shift: "morning" | "afternoon" | "night";
  status: "Đang trực" | "Sắp vào ca" | "Nghỉ ca";
};
export type Pricing = {
  car: number;
  motorcycle: number;
  overnight: number;
  freeMinutes: number;
  advance: boolean;
  qr: boolean;
  cash: boolean;
  autoCancel: boolean;
};
export type AdminData = {
  lots: Lot[];
  bookings: Booking[];
  staff: Staff[];
  pricing: Record<string, Pricing>;
};
export const shifts = {
  morning: { label: "Ca sáng", time: "07:00–15:00", color: "#315fea" },
  afternoon: { label: "Ca chiều", time: "15:00–23:00", color: "#17b29a" },
  night: { label: "Ca đêm", time: "23:00–07:00", color: "#7b61da" },
};
export const money = (n: number) =>
  new Intl.NumberFormat("vi-VN").format(n) + "đ";
export const pad = (n: number) => String(n).padStart(2, "0");
export const shortLot = (lot: Lot | undefined) =>
  lot?.name.replace("Bãi xe ", "") ?? "Chưa phân công";
export function createSeed(): AdminData {
  const lots: Lot[] = [
    {
      id: "lot-1",
      name: "Bãi xe Trung tâm",
      area: "Hải Châu, Đà Nẵng",
      capacity: 40,
      occupied: 28,
      enabled: true,
    },
    {
      id: "lot-2",
      name: "Bãi xe Sông Hàn",
      area: "Sơn Trà, Đà Nẵng",
      capacity: 50,
      occupied: 32,
      enabled: true,
    },
    {
      id: "lot-3",
      name: "Bãi xe Vincom",
      area: "Ngô Quyền, Đà Nẵng",
      capacity: 50,
      occupied: 42,
      enabled: true,
    },
    {
      id: "lot-4",
      name: "Bãi xe Sân bay",
      area: "Hải Châu, Đà Nẵng",
      capacity: 30,
      occupied: 18,
      enabled: true,
    },
    {
      id: "lot-5",
      name: "Bãi xe Hòa Xuân",
      area: "Cẩm Lệ, Đà Nẵng",
      capacity: 25,
      occupied: 22,
      enabled: true,
    },
    {
      id: "lot-6",
      name: "Bãi xe Biển Đông",
      area: "Sơn Trà, Đà Nẵng",
      capacity: 15,
      occupied: 14,
      enabled: true,
    },
    {
      id: "lot-7",
      name: "Bãi xe Nguyễn Văn Linh",
      area: "Hải Châu, Đà Nẵng",
      capacity: 15,
      occupied: 13,
      enabled: true,
    },
    {
      id: "lot-8",
      name: "Bãi xe Liên Chiểu",
      area: "Liên Chiểu, Đà Nẵng",
      capacity: 15,
      occupied: 13,
      enabled: true,
    },
  ];
  const bookings: Booking[] = [
    {
      id: "SP-1022-007",
      customer: "Nguyễn Văn A",
      plate: "43A-123.45",
      lotId: "lot-1",
      date: "2026-10-22",
      start: "14:30",
      end: "16:30",
      status: "Đã xác nhận",
      amount: 30000,
    },
    {
      id: "SP-1022-006",
      customer: "Trần Minh Hà",
      plate: "43D1-567.89",
      lotId: "lot-2",
      date: "2026-10-22",
      start: "14:15",
      end: "15:15",
      status: "Đang sử dụng",
      amount: 12000,
    },
    {
      id: "SP-1022-005",
      customer: "Lê Quốc Hưng",
      plate: "43A-339.18",
      lotId: "lot-3",
      date: "2026-10-22",
      start: "13:00",
      end: "16:00",
      status: "Hoàn thành",
      amount: 60000,
    },
    {
      id: "SP-1022-004",
      customer: "Phạm Nhật Duy",
      plate: "43B-072.25",
      lotId: "lot-1",
      date: "2026-10-22",
      start: "15:00",
      end: "17:00",
      status: "Chờ đến",
      amount: 30000,
    },
    {
      id: "SP-1022-003",
      customer: "Vũ Thanh Thảo",
      plate: "43C-228.18",
      lotId: "lot-4",
      date: "2026-10-22",
      start: "12:00",
      end: "14:00",
      status: "Hoàn thành",
      amount: 30000,
    },
  ];
  for (let i = 0; i < 43; i++)
    bookings.push({
      id: `SP-1022-${pad(i + 8).padStart(3, "0")}`,
      customer: [
        "Hoàng Minh",
        "Nguyễn Thu Trang",
        "Lê Anh Tuấn",
        "Trần Ngọc Lan",
      ][i % 4],
      plate: `43A-${200 + i}.0${i % 10}`,
      lotId: lots[i % 8].id,
      date: "2026-10-22",
      start: "14:00",
      end: "16:00",
      status: i < 25 ? "Đang sử dụng" : i < 38 ? "Đã xác nhận" : "Hoàn thành",
      amount: 30000,
    });
  const staff: Staff[] = [
    {
      id: "NV001",
      name: "Nguyễn Minh Anh",
      initials: "MA",
      email: "minhanh@smartpark.vn",
      lotId: "lot-1",
      shift: "morning",
      status: "Đang trực",
    },
    {
      id: "NV002",
      name: "Trần Quốc Bình",
      initials: "QB",
      email: "quocbinh@smartpark.vn",
      lotId: "lot-2",
      shift: "morning",
      status: "Đang trực",
    },
    {
      id: "NV003",
      name: "Lê Văn Nam",
      initials: "VN",
      email: "vannam@smartpark.vn",
      lotId: "lot-3",
      shift: "afternoon",
      status: "Sắp vào ca",
    },
    {
      id: "NV004",
      name: "Phạm Thùy Linh",
      initials: "TL",
      email: "thuylinh@smartpark.vn",
      lotId: "lot-4",
      shift: "morning",
      status: "Đang trực",
    },
    {
      id: "NV005",
      name: "Đỗ Thanh Tùng",
      initials: "TT",
      email: "thanhtung@smartpark.vn",
      lotId: "lot-5",
      shift: "night",
      status: "Nghỉ ca",
    },
  ];
  for (let i = 0; i < 11; i++)
    staff.push({
      id: `NV${String(i + 6).padStart(3, "0")}`,
      name: [
        "Nguyễn Hoàng Long",
        "Lê Thị Mai",
        "Trần Đức Anh",
        "Phạm Quang Huy",
        "Vũ Minh Châu",
        "Đặng Thanh Sơn",
        "Bùi Ngọc Ánh",
        "Đỗ Anh Khoa",
        "Hoàng Thị Hoa",
        "Lý Tuấn Kiệt",
        "Ngô Bảo Trâm",
      ][i],
      initials: [
        "HL",
        "TM",
        "ĐA",
        "QH",
        "MC",
        "TS",
        "NÁ",
        "AK",
        "TH",
        "TK",
        "BT",
      ][i],
      email: `nhanvien${i + 6}@smartpark.vn`,
      lotId: lots[i % 8].id,
      shift: i < 6 ? "morning" : i < 9 ? "afternoon" : "night",
      status: i < 6 ? "Đang trực" : i < 9 ? "Sắp vào ca" : "Nghỉ ca",
    });
  const pricing = Object.fromEntries(
    lots.map((l) => [
      l.id,
      {
        car: 15000,
        motorcycle: 5000,
        overnight: 80000,
        freeMinutes: 10,
        advance: true,
        qr: true,
        cash: true,
        autoCancel: false,
      },
    ]),
  );
  return { lots, bookings, staff, pricing };
}
