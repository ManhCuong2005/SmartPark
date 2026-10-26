import { useState, useId } from "react";
import { Link, useSearchParams } from "react-router-dom";
import {
  Asset,
  Panel,
  PageHeading,
  Metric,
  Badge,
  BarChart,
  SearchField,
  Pagination,
  Dialog,
  Button,
  Empty,
  Progress,
} from "../components/ui";
import { useAdmin } from "../data/store";
import type { Lot } from "../data/mock";
import { pad } from "../data/mock";

export function OverviewPage() {
  const { data } = useAdmin();
  const [date, setDate] = useState("2026-10-22");
  const used = data.lots.reduce((sum, l) => sum + l.occupied, 0),
    capacity = data.lots.reduce((sum, l) => sum + l.capacity, 0),
    percentage = capacity ? Math.round((used / capacity) * 100) : 0;
  const rows = data.bookings.filter((b) => b.date === date).slice(0, 3);
  return (
    <>
      <PageHeading
        title="Tổng quan hệ thống"
        subtitle="Theo dõi hiệu suất vận hành SmartPark theo thời gian thực (dữ liệu demo)."
        action={
          <label className="date-filter">
            <Asset name="IconCalendar" />
            <input
              aria-label="Ngày tổng quan"
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </label>
        }
      />
      <div className="metrics four">
        <Metric
          label="Bãi đỗ đang hoạt động"
          value={pad(data.lots.filter((l) => l.enabled).length)}
          detail="Tất cả đều hoạt động"
          icon="IconBuilding1"
        />
        <Metric
          label="Xe đang trong bãi"
          value={used}
          detail="+12 xe so với hôm qua"
          icon="IconCar1"
          tone="green"
          positive
        />
        <Metric
          label="Chỗ đỗ còn trống"
          value={capacity - used}
          detail={`Tỷ lệ sử dụng ${percentage}%`}
          icon="IconMapPin"
        />
        <Metric
          label="Doanh thu hôm nay"
          value={date === "2026-10-22" ? "8,45 tr" : "0đ"}
          detail="+14,2% so với hôm qua"
          icon="IconChart1"
          tone="green"
          positive
        />
      </div>
      <div className="overview-charts">
        <Panel className="traffic-panel">
          <div className="panel-heading">
            <div>
              <h2>Lượt xe ra vào</h2>
              <p>7 ngày gần nhất</p>
            </div>
            <Badge tone="green">+ 12,4% tuần này</Badge>
          </div>
          <BarChart />
        </Panel>
        <Panel className="occupancy-panel">
          <h2>Tình trạng chỗ đỗ</h2>
          <p className="panel-subtitle">Toàn bộ {data.lots.length} bãi</p>
          <div className="donut">
            <Asset name="DonutBase" />
            <Asset name="DonutForeground" />
            <Asset name="DonutCutout" />
            <div>
              <strong>{percentage}%</strong>
              <small>Đã dùng</small>
            </div>
          </div>
          <div className="donut-legend">
            <span>
              <Asset name="LegendBusy" />
              Đang dùng · {used}
            </span>
            <span>
              <Asset name="LegendFree" />
              Còn trống · {capacity - used}
            </span>
          </div>
        </Panel>
      </div>
      <Panel className="recent-panel">
        <div className="panel-heading">
          <h2>Đặt chỗ gần đây</h2>
          <Link className="text-link" to="/bookings">
            Xem tất cả →
          </Link>
        </div>
        <div className="table-scroll">
          <table className="recent-table">
            <thead>
              <tr>
                <th>MÃ ĐƠN</th>
                <th>KHÁCH HÀNG</th>
                <th>BÃI ĐỖ</th>
                <th>THỜI GIAN</th>
                <th>TRẠNG THÁI</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((b) => (
                <tr key={b.id}>
                  <td>
                    <Link to={"/bookings?q=" + b.id}>{b.id}</Link>
                  </td>
                  <td>{b.customer}</td>
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
          {!rows.length && <Empty message="Ngày này chưa có đặt chỗ demo." />}
        </div>
      </Panel>
    </>
  );
}

function LotEditor({ lot, onClose }: { lot: Lot | null; onClose: () => void }) {
  const { data, change, notice } = useAdmin(),
    id = useId();
  const [name, setName] = useState(lot?.name ?? ""),
    [area, setArea] = useState(lot?.area ?? ""),
    [capacity, setCapacity] = useState(lot?.capacity ?? 40),
    [occupied, setOccupied] = useState(lot?.occupied ?? 0),
    [enabled, setEnabled] = useState(lot?.enabled ?? true),
    [error, setError] = useState("");
  function save() {
    if (
      !Number.isInteger(capacity) ||
      capacity < 1 ||
      capacity > 10000 ||
      !Number.isInteger(occupied) ||
      occupied < 0 ||
      occupied > capacity
    ) {
      setError("Sức chứa từ 1–10.000 và số xe phải nằm trong sức chứa.");
      return;
    }
    if (
      data.lots.some(
        (l) =>
          l.id !== lot?.id &&
          l.name.toLocaleLowerCase("vi") ===
            name.trim().toLocaleLowerCase("vi"),
      )
    ) {
      setError("Tên bãi đỗ đã tồn tại.");
      return;
    }
    const item: Lot = {
      id: lot?.id ?? crypto.randomUUID(),
      name: name.trim(),
      area: area.trim(),
      capacity,
      occupied,
      enabled,
    };
    change((d) => ({
      ...d,
      lots: lot
        ? d.lots.map((l) => (l.id === lot.id ? item : l))
        : [item, ...d.lots],
      pricing: lot
        ? d.pricing
        : {
            ...d.pricing,
            [item.id]: {
              car: 15000,
              motorcycle: 5000,
              overnight: 80000,
              freeMinutes: 10,
              advance: true,
              qr: true,
              cash: true,
              autoCancel: false,
            },
          },
    }));
    notice(`${lot ? "Đã cập nhật" : "Đã thêm"} bãi đỗ trong dữ liệu demo.`);
    onClose();
  }
  return (
    <Dialog
      title={lot ? "Sửa bãi đỗ" : "Thêm bãi đỗ"}
      onClose={onClose}
      footer={
        <>
          <Button secondary onClick={onClose}>
            Hủy
          </Button>
          <Button type="submit" form={id}>
            Lưu bãi đỗ demo
          </Button>
        </>
      }
    >
      <form
        id={id}
        className="edit-form"
        onSubmit={(e) => {
          e.preventDefault();
          save();
        }}
      >
        <label>
          Tên bãi đỗ
          <input
            autoFocus
            required
            maxLength={100}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label>
          Địa điểm
          <input
            required
            maxLength={150}
            value={area}
            onChange={(e) => setArea(e.target.value)}
          />
        </label>
        <div className="form-grid">
          <label>
            Sức chứa
            <input
              required
              type="number"
              min={1}
              max={10000}
              value={capacity}
              onChange={(e) => setCapacity(Number(e.target.value))}
            />
          </label>
          <label>
            Xe đang trong bãi
            <input
              required
              type="number"
              min={0}
              max={capacity}
              value={occupied}
              onChange={(e) => setOccupied(Number(e.target.value))}
            />
          </label>
        </div>
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => setEnabled(e.target.checked)}
          />
          Bãi đỗ đang hoạt động
        </label>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <p className="muted">
          Chỉ cập nhật dữ liệu local, chưa kết nối thiết bị hoặc backend.
        </p>
      </form>
    </Dialog>
  );
}
export function ParkingPage() {
  const { data } = useAdmin(),
    [params] = useSearchParams();
  const [query, setQuery] = useState(params.get("q") ?? ""),
    [status, setStatus] = useState("all"),
    [page, setPage] = useState(1),
    [editor, setEditor] = useState<Lot | null | undefined>(undefined);
  const filtered = data.lots.filter(
    (l) =>
      (l.name + " " + l.area)
        .toLocaleLowerCase("vi")
        .includes(query.toLocaleLowerCase("vi")) &&
      (status === "all" || (status === "active" ? l.enabled : !l.enabled)),
  );
  const count = data.lots.reduce((n, l) => n + l.capacity, 0),
    used = data.lots.reduce((n, l) => n + l.occupied, 0),
    safePage = Math.min(page, Math.max(1, Math.ceil(filtered.length / 5)));
  return (
    <>
      <PageHeading
        title="Quản lý bãi đỗ"
        subtitle="Theo dõi bãi đỗ, công suất và tình trạng vận hành tại từng địa điểm."
        action={<Button onClick={() => setEditor(null)}>+ Thêm bãi đỗ</Button>}
      />
      <div className="metrics three">
        <Metric
          label="Tổng số bãi đỗ"
          value={pad(data.lots.length)}
          detail={`${pad(data.lots.filter((l) => l.enabled).length)} bãi đang hoạt động`}
          icon="IconBuilding1"
        />
        <Metric
          label="Tổng sức chứa"
          value={`${count} chỗ`}
          detail={`${used} đã sử dụng`}
          icon="IconCar1"
        />
        <Metric
          label="Số chỗ còn trống"
          value={`${count - used} chỗ`}
          detail="Cập nhật theo lượt vào / ra"
          icon="IconMapPin"
          tone="green"
        />
      </div>
      <Panel className="parking-table-panel">
        <div className="panel-heading table-heading">
          <h2>Danh sách bãi đỗ</h2>
          <div className="table-tools">
            <SearchField
              value={query}
              onChange={(v) => {
                setQuery(v);
                setPage(1);
              }}
              placeholder="Tìm tên bãi đỗ hoặc địa điểm"
            />
            <label className="select-icon">
              <Asset name="IconFilter" />
              <select
                aria-label="Trạng thái bãi đỗ"
                value={status}
                onChange={(e) => {
                  setStatus(e.target.value);
                  setPage(1);
                }}
              >
                <option value="all">Tất cả trạng thái</option>
                <option value="active">Hoạt động</option>
                <option value="paused">Tạm ngưng</option>
              </select>
            </label>
          </div>
        </div>
        <div className="table-scroll">
          <table className="parking-table">
            <thead>
              <tr>
                <th>BÃI ĐỖ</th>
                <th>SỨC CHỨA</th>
                <th>CÔNG SUẤT</th>
                <th>TRẠNG THÁI</th>
                <th>THAO TÁC</th>
              </tr>
            </thead>
            <tbody>
              {filtered.slice((safePage - 1) * 5, safePage * 5).map((l) => {
                const pct = Math.round((l.occupied / l.capacity) * 100),
                  state = !l.enabled
                    ? "Tạm ngưng"
                    : pct >= 85
                      ? "Sắp đầy"
                      : "Hoạt động";
                return (
                  <tr key={l.id}>
                    <td>
                      <div className="cell-with-icon">
                        <span className="lot-icon">
                          <Asset name="IconBuilding2" />
                        </span>
                        <div>
                          <button
                            className="table-name"
                            onClick={() => setEditor(l)}
                          >
                            {l.name}
                          </button>
                          <small>{l.area}</small>
                        </div>
                      </div>
                    </td>
                    <td>
                      {l.occupied} / {l.capacity}
                    </td>
                    <td>
                      <div className="capacity-cell">
                        <Progress
                          value={pct}
                          tone={pct >= 85 ? "amber" : "blue"}
                        />
                        <span>{pct}%</span>
                      </div>
                    </td>
                    <td>
                      <Badge>{state}</Badge>
                    </td>
                    <td>
                      <button
                        className="icon-button"
                        aria-label={`Sửa ${l.name}`}
                        onClick={() => setEditor(l)}
                      >
                        <Asset name="IconMore" />
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {!filtered.length && <Empty />}
        </div>
        <Pagination
          page={safePage}
          count={filtered.length}
          onChange={setPage}
          noun="bãi đỗ"
        />
      </Panel>
      {editor !== undefined && (
        <LotEditor lot={editor} onClose={() => setEditor(undefined)} />
      )}
    </>
  );
}
