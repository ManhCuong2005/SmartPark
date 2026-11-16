import { vehicleKindLabel } from "../data/models";
import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Asset,
  Badge,
  Button,
  Dialog,
  Empty,
  Metric,
  PageHeading,
  Pagination,
  Panel,
  SearchField,
} from "../components/ui";
import { useAdmin, exportCsv } from "../data/store";
import { formatDateTime, formatDuration, money } from "../data/models";
import type { Booking } from "../data/models";

export function BookingsPage() {
  const { data, command, notice } = useAdmin();
  const [params] = useSearchParams();
  const [query, setQuery] = useState(params.get("q") ?? "");
  const [status, setStatus] = useState("");
  const [lotFilter, setLotFilter] = useState("");
  const [date, setDate] = useState("");
  const [page, setPage] = useState(1);
  const [detail, setDetail] = useState<Booking | null>(null);
  const [busy, setBusy] = useState(false);

  const q = query.toLocaleLowerCase("vi").trim();
  const rows = data.bookings.filter((b) => {
    const matchQ =
      !q ||
      `${b.id} ${b.customer} ${b.plate} ${b.slotCode}`
        .toLocaleLowerCase("vi")
        .includes(q);
    const matchStatus = !status || b.status === status;
    const matchLot = !lotFilter || b.lotId === lotFilter;
    const matchDate = !date || b.date === date;
    return matchQ && matchStatus && matchLot && matchDate;
  });

  const pageSize = 6;
  const totalPages = Math.max(1, Math.ceil(rows.length / pageSize));
  const safePage = Math.min(page, totalPages);
  const pageRows = rows.slice((safePage - 1) * pageSize, safePage * pageSize);

  const confirmedCount = data.bookings.filter(
    (b) => b.status === "Đã xác nhận",
  ).length;
  const parkedCount = data.bookings.filter(
    (b) => b.status === "Đang sử dụng",
  ).length;
  const completedCount = data.bookings.filter(
    (b) => b.status === "Hoàn thành",
  ).length;
  const totalCollected = data.bookings.reduce((s, b) => s + b.amount, 0);
  const hasFilters = Boolean(query || status || lotFilter || date);

  return (
    <>
      <PageHeading
        title="Quản lý đặt chỗ"
        subtitle="Theo dõi vé khách hàng đặt trước, trạng thái xe vào/ra và phương tiện theo thời gian thực."
        action={
          <Button
            secondary
            onClick={() => {
              exportCsv(
                "smartpark-dat-cho.csv",
                [
                  "Mã vé",
                  "Khách hàng",
                  "Biển số",
                  "Loại xe",
                  "Bãi đỗ",
                  "Vị trí",
                  "Ngày",
                  "Khung giờ",
                  "Trạng thái",
                  "Đã thu",
                ],
                rows.map((b) => [
                  b.id,
                  b.customer,
                  b.plate,
                  vehicleKindLabel(b.vehicleKind),
                  data.lots.find((l) => l.id === b.lotId)?.name ?? "",
                  b.slotCode,
                  b.date,
                  `${b.start}–${b.end}`,
                  b.status,
                  b.amount,
                ]),
              );
              notice(`Đã xuất ${rows.length} vé đặt chỗ ra tệp CSV.`);
            }}
          >
            Xuất CSV
          </Button>
        }
      />

      <div className="metrics three">
        <Metric
          label="Tổng vé đặt chỗ"
          value={data.bookings.length}
          detail={`${confirmedCount} chờ vào bãi · ${completedCount} hoàn thành`}
          icon="IconTicket1"
          tone="blue"
        />
        <Metric
          label="Xe đang gửi"
          value={parkedCount}
          detail="Đang chiếm chỗ đỗ thực tế"
          icon="IconCar1"
          tone="green"
          positive={parkedCount > 0}
        />
        <Metric
          label="Giá trị vé đã chốt"
          value={money(totalCollected)}
          detail={`Tổng hợp trên ${data.bookings.filter((b) => b.amount > 0).length} vé`}
          icon="IconClock"
          tone="purple"
        />
      </div>

      <Panel className="booking-filters">
        <div className="live-filters">
          <SearchField
            value={query}
            onChange={(v) => {
              setQuery(v);
              setPage(1);
            }}
            placeholder="Tìm mã vé, khách hoặc biển số"
          />
          <label className="select-icon">
            <Asset name="IconFilter" />
            <select
              aria-label="Trạng thái vé"
              value={status}
              onChange={(e) => {
                setStatus(e.target.value);
                setPage(1);
              }}
            >
              <option value="">Tất cả trạng thái</option>
              {[
                "Đã xác nhận",
                "Đang sử dụng",
                "Hoàn thành",
                "Đã hủy",
                "Hết hạn",
              ].map((s) => (
                <option key={s}>{s}</option>
              ))}
            </select>
          </label>
          <label className="select-icon">
            <Asset name="IconFilter" />
            <select
              aria-label="Lọc bãi đỗ đặt chỗ"
              value={lotFilter}
              onChange={(e) => {
                setLotFilter(e.target.value);
                setPage(1);
              }}
            >
              <option value="">Tất cả bãi đỗ</option>
              {data.lots.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name}
                </option>
              ))}
            </select>
          </label>
          <label className="date-filter">
            <Asset name="IconCalendar" />
            <input
              type="date"
              aria-label="Ngày đặt chỗ"
              value={date}
              onChange={(e) => {
                setDate(e.target.value);
                setPage(1);
              }}
            />
          </label>
          {hasFilters && (
            <Button
              type="button"
              secondary
              onClick={() => {
                setQuery("");
                setStatus("");
                setLotFilter("");
                setDate("");
                setPage(1);
              }}
            >
              Xóa lọc
            </Button>
          )}
        </div>
      </Panel>

      <Panel className="booking-table-panel">
        <div className="table-heading">
          <div>
            <h2>Danh sách vé đặt chỗ</h2>
            <p className="panel-sub">
              Hiển thị {rows.length} / {data.bookings.length} vé trên hệ thống
            </p>
          </div>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>MÃ VÉ</th>
                <th>KHÁCH HÀNG</th>
                <th>BIỂN SỐ</th>
                <th>BÃI ĐỖ</th>
                <th>THỜI GIAN</th>
                <th>TRẠNG THÁI</th>
                <th>ĐÃ THU</th>
                <th>CHI TIẾT</th>
              </tr>
            </thead>
            <tbody>
              {pageRows.map((b) => (
                <tr key={b.id}>
                  <td className="mono">#{b.id.slice(0, 8)}</td>
                  <td>{b.customer || "Khách đặt chỗ"}</td>
                  <td>
                    <span className="plate">{b.plate}</span>
                    <small className="cell-sub">
                      {vehicleKindLabel(b.vehicleKind)}
                    </small>
                  </td>
                  <td>
                    <span>
                      {data.lots.find((l) => l.id === b.lotId)?.name ?? "—"}
                    </span>
                    {b.slotCode && (
                      <small className="cell-sub">Ô {b.slotCode}</small>
                    )}
                  </td>
                  <td>
                    <span>{b.date}</span>
                    <small className="cell-sub">
                      {b.start}–{b.end}
                    </small>
                  </td>
                  <td>
                    <Badge>{b.status}</Badge>
                  </td>
                  <td>
                    <strong>{money(b.amount)}</strong>
                  </td>
                  <td>
                    <Button secondary onClick={() => setDetail(b)}>
                      Chi tiết
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && (
            <Empty
              message="Chưa có đặt chỗ phù hợp."
              hint="Thử thay đổi bộ lọc ngày, trạng thái hoặc từ khóa tìm kiếm."
            />
          )}
        </div>
        {rows.length > 0 && (
          <Pagination
            page={safePage}
            count={rows.length}
            pageSize={pageSize}
            onChange={setPage}
            noun="vé đặt chỗ"
          />
        )}
      </Panel>

      <Panel className="vehicles-panel">
        <div className="table-heading">
          <div>
            <h2>Phương tiện đã sử dụng bãi</h2>
            <p className="panel-sub">
              Khách quản lý biển số trong ứng dụng; camera tự quét khi xe
              vào/ra.
            </p>
          </div>
          <Badge tone="blue">{data.vehicles.length} phương tiện</Badge>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>TÊN PHƯƠNG TIỆN</th>
                <th>BIỂN SỐ</th>
                <th>LOẠI XE</th>
              </tr>
            </thead>
            <tbody>
              {data.vehicles.map((v) => (
                <tr key={v.id}>
                  <td>{v.label || "Xe cá nhân"}</td>
                  <td>
                    <span className="plate">{v.plate}</span>
                  </td>
                  <td>
                    <Badge tone={v.kind === "car" ? "blue" : "green"}>
                      {vehicleKindLabel(v.kind)}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!data.vehicles.length && (
            <Empty
              message="Chưa có phương tiện nào phát sinh giao dịch."
              hint="Phương tiện của khách sẽ xuất hiện khi có đơn đặt chỗ tại bãi."
            />
          )}
        </div>
      </Panel>

      {detail && (
        <Dialog
          title="Chi tiết vé"
          onClose={() => setDetail(null)}
          footer={
            <>
              <Button secondary onClick={() => setDetail(null)}>
                Đóng
              </Button>
              {detail.status === "Đã xác nhận" && (
                <Button
                  disabled={busy}
                  onClick={async () => {
                    if (!window.confirm("Hủy đặt chỗ này?")) return;
                    setBusy(true);
                    const ok = await command("apply_operation", {
                      p_operation_id: crypto.randomUUID(),
                      p_kind: "booking.cancel",
                      p_payload: {
                        booking_id: detail.id,
                        expected_version: detail.version,
                      },
                    });
                    setBusy(false);
                    if (ok) {
                      notice("Máy chủ đã hủy vé.");
                      setDetail(null);
                    }
                  }}
                >
                  Hủy đặt chỗ
                </Button>
              )}
            </>
          }
        >
          <dl className="receipt-dl">
            <div>
              <dt>Mã vé</dt>
              <dd className="mono">{detail.id}</dd>
            </div>
            <div>
              <dt>Khách hàng</dt>
              <dd>
                {detail.customer || "Khách đặt chỗ"}
                {detail.customerPhone ? ` (${detail.customerPhone})` : ""}
              </dd>
            </div>
            <div>
              <dt>Biển số & loại xe</dt>
              <dd>
                {detail.plate} · {vehicleKindLabel(detail.vehicleKind)}
                {detail.vehicleLabel ? ` (${detail.vehicleLabel})` : ""}
              </dd>
            </div>
            <div>
              <dt>Bãi đỗ & vị trí</dt>
              <dd>
                {data.lots.find((l) => l.id === detail.lotId)?.name ?? "—"}{" "}
                {detail.slotCode ? `· Ô ${detail.slotCode}` : ""}
              </dd>
            </div>
            <div>
              <dt>Khung giờ đặt</dt>
              <dd>
                {detail.date} · {detail.start} – {detail.end}
              </dd>
            </div>
            <div>
              <dt>Check-in thực tế</dt>
              <dd>{formatDateTime(detail.checkedIn)}</dd>
            </div>
            <div>
              <dt>Check-out thực tế</dt>
              <dd>{formatDateTime(detail.checkedOut)}</dd>
            </div>
            <div>
              <dt>Thời lượng</dt>
              <dd>{formatDuration(detail.checkedIn, detail.checkedOut)}</dd>
            </div>
            <div>
              <dt>Trạng thái</dt>
              <dd>{detail.status}</dd>
            </div>
            <div className="receipt-total-row">
              <dt>Đã thu</dt>
              <dd>{money(detail.amount)}</dd>
            </div>
          </dl>
        </Dialog>
      )}
    </>
  );
}
