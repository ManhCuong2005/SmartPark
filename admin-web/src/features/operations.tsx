import { useState, useId } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Asset,
  Panel,
  PageHeading,
  Metric,
  Badge,
  SearchField,
  Pagination,
  Dialog,
  Button,
  Empty,
} from "../components/ui";
import { useAdmin, exportCsv } from "../data/store";
import { money, pad, shifts, shortLot } from "../data/mock";
import type { Booking, Staff } from "../data/mock";

export function BookingsPage() {
  const { data, change, notice } = useAdmin(),
    [params] = useSearchParams();
  const [query, setQuery] = useState(params.get("q") ?? ""),
    [status, setStatus] = useState("all"),
    [date, setDate] = useState("2026-10-22"),
    [applied, setApplied] = useState({
      q: params.get("q") ?? "",
      s: "all",
      d: "2026-10-22",
    }),
    [page, setPage] = useState(1),
    [detail, setDetail] = useState<Booking | null>(null);
  const today = data.bookings.filter((b) => b.date === "2026-10-22");
  const filtered = data.bookings.filter(
    (b) =>
      (b.id + " " + b.customer + " " + b.plate)
        .toLocaleLowerCase("vi")
        .includes(applied.q.toLocaleLowerCase("vi")) &&
      (applied.s === "all" || b.status === applied.s) &&
      (!applied.d || b.date === applied.d),
  );
  const safePage = Math.min(page, Math.max(1, Math.ceil(filtered.length / 5)));
  function csv() {
    exportCsv(
      "smartpark-dat-cho-demo.csv",
      [
        "Mã vé",
        "Khách hàng",
        "Biển số",
        "Bãi đỗ",
        "Ngày",
        "Giờ vào",
        "Giờ ra",
        "Trạng thái",
        "Số tiền (VND)",
      ],
      filtered.map((b) => [
        b.id,
        b.customer,
        b.plate,
        data.lots.find((l) => l.id === b.lotId)?.name ?? "",
        b.date,
        b.start,
        b.end,
        b.status,
        b.amount,
      ]),
    );
    notice("Đã xuất danh sách đặt chỗ demo theo bộ lọc hiện tại.");
  }
  return (
    <>
      <PageHeading
        title="Quản lý đặt chỗ"
        subtitle="Tra cứu và kiểm soát trạng thái đặt chỗ trên toàn bộ hệ thống."
        action={
          <Button secondary onClick={csv}>
            Xuất danh sách
          </Button>
        }
      />
      <form
        className="booking-filters panel"
        onSubmit={(e) => {
          e.preventDefault();
          setApplied({ q: query, s: status, d: date });
          setPage(1);
        }}
      >
        <SearchField
          value={query}
          onChange={setQuery}
          placeholder="Tìm theo mã vé, biển số, khách hàng"
        />
        <label className="select-icon">
          <Asset name="IconFilter" />
          <select
            aria-label="Trạng thái đặt chỗ"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="all">Tất cả trạng thái</option>
            {[
              "Đã xác nhận",
              "Đang sử dụng",
              "Hoàn thành",
              "Chờ đến",
              "Đã hủy",
            ].map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
        <label className="date-filter">
          <Asset name="IconCalendar" />
          <input
            aria-label="Ngày đặt chỗ"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        </label>
        <Button type="submit">Lọc dữ liệu</Button>
      </form>
      <div className="metrics three">
        <Metric
          label="Đặt chỗ hôm nay"
          value={today.length}
          detail="+9 so với hôm qua"
          icon="IconTicket1"
        />
        <Metric
          label="Đang sử dụng"
          value={today.filter((b) => b.status === "Đang sử dụng").length}
          detail="Đã xác nhận xe vào"
          icon="IconCar1"
          tone="green"
        />
        <Metric
          label="Chờ nhận xe"
          value={today.filter((b) => b.status === "Đã xác nhận").length}
          detail="Sắp tới giờ đặt"
          icon="IconClock"
          tone="amber"
        />
      </div>
      <Panel className="booking-table-panel">
        <div className="panel-heading">
          <h2>Danh sách đặt chỗ</h2>
          <Badge tone="blue">
            {filtered.length} đơn{" "}
            {applied.d === "2026-10-22" ? "hôm nay" : "phù hợp"}
          </Badge>
        </div>
        <div className="table-scroll">
          <table className="bookings-table">
            <thead>
              <tr>
                <th>MÃ VÉ</th>
                <th>KHÁCH HÀNG</th>
                <th>BIỂN SỐ</th>
                <th>BÃI ĐỖ</th>
                <th>THỜI GIAN</th>
                <th>TRẠNG THÁI</th>
              </tr>
            </thead>
            <tbody>
              {filtered.slice((safePage - 1) * 5, safePage * 5).map((b) => (
                <tr key={b.id}>
                  <td>
                    <button className="table-link" onClick={() => setDetail(b)}>
                      {b.id}
                    </button>
                  </td>
                  <td>{b.customer}</td>
                  <td>{b.plate}</td>
                  <td>{data.lots.find((l) => l.id === b.lotId)?.name}</td>
                  <td className="muted">
                    {b.start} - {b.end}
                  </td>
                  <td>
                    <Badge>{b.status}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!filtered.length && <Empty />}
        </div>
        <Pagination
          page={safePage}
          count={filtered.length}
          onChange={setPage}
          noun="đặt chỗ"
        />
      </Panel>
      {detail && (
        <Dialog
          title={`Chi tiết vé ${detail.id}`}
          onClose={() => setDetail(null)}
          footer={
            <>
              <Button secondary onClick={() => setDetail(null)}>
                Đóng
              </Button>
              {["Đã xác nhận", "Chờ đến"].includes(detail.status) && (
                <Button
                  onClick={() => {
                    change((d) => ({
                      ...d,
                      bookings: d.bookings.map((b) =>
                        b.id === detail.id ? { ...b, status: "Đã hủy" } : b,
                      ),
                    }));
                    notice(
                      "Đã hủy đặt chỗ trong dữ liệu demo. Không phát sinh hoàn tiền thực tế.",
                    );
                    setDetail(null);
                  }}
                >
                  Hủy đặt chỗ demo
                </Button>
              )}
            </>
          }
        >
          <dl className="details">
            <dt>Khách hàng</dt>
            <dd>{detail.customer}</dd>
            <dt>Biển số</dt>
            <dd>{detail.plate}</dd>
            <dt>Bãi đỗ</dt>
            <dd>{data.lots.find((l) => l.id === detail.lotId)?.name}</dd>
            <dt>Thời gian</dt>
            <dd>
              {detail.date} · {detail.start}–{detail.end}
            </dd>
            <dt>Giá trị demo</dt>
            <dd>{money(detail.amount)}</dd>
            <dt>Trạng thái</dt>
            <dd>
              <Badge>{detail.status}</Badge>
            </dd>
          </dl>
          <p className="info-note">
            Vé và thanh toán là dữ liệu minh họa. Không xác thực QR hoặc cập
            nhật cổng ra/vào từ màn này.
          </p>
        </Dialog>
      )}
    </>
  );
}

function StaffEditor({
  staff,
  onClose,
}: {
  staff: Staff | null;
  onClose: () => void;
}) {
  const { data, change, notice } = useAdmin(),
    formId = useId();
  const [name, setName] = useState(staff?.name ?? ""),
    [email, setEmail] = useState(staff?.email ?? ""),
    [lotId, setLotId] = useState(staff?.lotId ?? data.lots[0].id),
    [shift, setShift] = useState<Staff["shift"]>(staff?.shift ?? "morning"),
    [status, setStatus] = useState<Staff["status"]>(
      staff?.status ?? "Sắp vào ca",
    ),
    [error, setError] = useState("");
  function save() {
    if (!name.trim()) {
      setError("Vui lòng nhập họ tên.");
      return;
    }
    if (
      data.staff.some(
        (s) =>
          s.id !== staff?.id &&
          s.email.toLowerCase() === email.trim().toLowerCase(),
      )
    ) {
      setError("Email nhân viên đã tồn tại.");
      return;
    }
    const nextId =
      Math.max(
        0,
        ...data.staff.map((s) => Number(s.id.replace("NV", "")) || 0),
      ) + 1;
    const words = name.trim().split(/\s+/);
    const item: Staff = {
      id: staff?.id ?? `NV${String(nextId).padStart(3, "0")}`,
      name: name.trim(),
      email: email.trim(),
      initials: words
        .slice(-2)
        .map((w) => w[0])
        .join("")
        .toUpperCase(),
      lotId,
      shift,
      status,
    };
    change((d) => ({
      ...d,
      staff: staff
        ? d.staff.map((s) => (s.id === staff.id ? item : s))
        : [item, ...d.staff],
    }));
    notice(
      "Đã lưu thông tin và phân ca demo. Chưa tạo tài khoản Firebase hoặc gửi email.",
    );
    onClose();
  }
  return (
    <Dialog
      title={staff ? "Thông tin & phân ca nhân viên" : "Thêm nhân viên"}
      onClose={onClose}
      footer={
        <>
          <Button secondary onClick={onClose}>
            Hủy
          </Button>
          <Button type="submit" form={formId}>
            Lưu nhân viên demo
          </Button>
        </>
      }
    >
      <form
        id={formId}
        className="edit-form"
        onSubmit={(e) => {
          e.preventDefault();
          save();
        }}
      >
        <label>
          Họ tên
          <input
            autoFocus
            required
            maxLength={100}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label>
          Email nhân viên
          <input
            required
            type="email"
            maxLength={150}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label>
          Bãi đỗ được phân công
          <select value={lotId} onChange={(e) => setLotId(e.target.value)}>
            {data.lots.map((l) => (
              <option value={l.id} key={l.id}>
                {l.name}
              </option>
            ))}
          </select>
        </label>
        <div className="form-grid">
          <label>
            Ca làm việc
            <select
              aria-label="Ca làm việc"
              value={shift}
              onChange={(e) => setShift(e.target.value as Staff["shift"])}
            >
              {Object.entries(shifts).map(([k, v]) => (
                <option key={k} value={k}>
                  {v.label} · {v.time}
                </option>
              ))}
            </select>
          </label>
          <label>
            Trạng thái
            <select
              aria-label="Trạng thái nhân viên"
              value={status}
              onChange={(e) => setStatus(e.target.value as Staff["status"])}
            >
              {["Đang trực", "Sắp vào ca", "Nghỉ ca"].map((s) => (
                <option key={s}>{s}</option>
              ))}
            </select>
          </label>
        </div>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <p className="muted">Phân ca chỉ lưu trên trình duyệt này.</p>
      </form>
    </Dialog>
  );
}
export function StaffPage() {
  const { data } = useAdmin(),
    [params] = useSearchParams(),
    [query, setQuery] = useState(params.get("q") ?? ""),
    [page, setPage] = useState(1),
    [editor, setEditor] = useState<Staff | null | undefined>(undefined);
  const filtered = data.staff.filter((s) =>
      (s.name + " " + s.id)
        .toLocaleLowerCase("vi")
        .includes(query.toLocaleLowerCase("vi")),
    ),
    safePage = Math.min(page, Math.max(1, Math.ceil(filtered.length / 5)));
  return (
    <>
      <PageHeading
        title="Quản lý nhân viên"
        subtitle="Quản lý tài khoản nhân viên, ca trực và phân công theo từng bãi đỗ."
        action={
          <Button onClick={() => setEditor(null)}>+ Thêm nhân viên</Button>
        }
      />
      <div className="metrics three">
        <Metric
          label="Tổng nhân viên"
          value={data.staff.length}
          detail="Đã tạo tài khoản"
          icon="IconUsers1"
        />
        <Metric
          label="Đang trong ca"
          value={pad(data.staff.filter((s) => s.status === "Đang trực").length)}
          detail="Có mặt tại bãi đỗ"
          icon="IconClock"
          tone="green"
          positive
        />
        <Metric
          label="Chờ nhận ca"
          value={pad(data.staff.filter((s) => s.status !== "Đang trực").length)}
          detail="Ở các ca tiếp theo"
          icon="IconCalendar"
          tone="amber"
        />
      </div>
      <div className="staff-grid">
        <Panel className="staff-table-panel">
          <div className="panel-heading table-heading">
            <h2>Danh sách nhân viên</h2>
            <SearchField
              value={query}
              onChange={(v) => {
                setQuery(v);
                setPage(1);
              }}
              placeholder="Tìm tên nhân viên"
            />
          </div>
          <div className="table-scroll">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>NHÂN VIÊN</th>
                  <th>BÃI ĐỖ</th>
                  <th>CA LÀM VIỆC</th>
                  <th>TRẠNG THÁI</th>
                </tr>
              </thead>
              <tbody>
                {filtered
                  .slice((safePage - 1) * 5, safePage * 5)
                  .map((s, i) => (
                    <tr key={s.id}>
                      <td>
                        <div className="cell-with-icon">
                          <span
                            className={`staff-initials ${i % 2 ? "green" : ""}`}
                          >
                            {s.initials}
                          </span>
                          <div>
                            <button
                              className="table-name"
                              onClick={() => setEditor(s)}
                            >
                              {s.name}
                            </button>
                            <small>{s.id}</small>
                          </div>
                        </div>
                      </td>
                      <td>
                        {shortLot(data.lots.find((l) => l.id === s.lotId))}
                      </td>
                      <td>{shifts[s.shift].time}</td>
                      <td>
                        <Badge>{s.status}</Badge>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
            {!filtered.length && <Empty />}
          </div>
          <Pagination
            page={safePage}
            count={filtered.length}
            onChange={setPage}
            noun="nhân viên"
          />
        </Panel>
        <Panel className="shift-panel">
          <h2>Phân bổ ca trực</h2>
          <p className="panel-subtitle">Hôm nay, 22 tháng 10</p>
          <div className="shift-list">
            {Object.entries(shifts).map(([key, s]) => (
              <button
                key={key}
                className="shift-card"
                style={{ borderLeftColor: s.color }}
                onClick={() => {
                  setQuery("");
                  setPage(1);
                  setEditor(data.staff.find((p) => p.shift === key) ?? null);
                }}
              >
                <div>
                  <strong>{s.label}</strong>
                  <small>{s.time.replace("–", " – ")}</small>
                </div>
                <span>
                  {pad(data.staff.filter((p) => p.shift === key).length)} nhân
                  viên
                </span>
              </button>
            ))}
          </div>
          <div className="info-note">
            <Asset name="IconInfo" />
            <span>Theo dõi và điều chỉnh theo từng ca.</span>
          </div>
        </Panel>
      </div>
      {editor !== undefined && (
        <StaffEditor staff={editor} onClose={() => setEditor(undefined)} />
      )}
    </>
  );
}
