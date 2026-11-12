import { useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
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
  Progress,
  SearchField,
} from "../components/ui";
import { DonutRing, LiveBars } from "../components/live-charts";
import { useAdmin } from "../data/store";
import { localDate, money } from "../data/models";
import type { Lot } from "../data/models";

export function OverviewPage() {
  const { data } = useAdmin();
  const [date, setDate] = useState(localDate());

  const enabledLots = data.lots.filter((l) => l.enabled);
  const used = data.lots.reduce((n, l) => n + l.occupied, 0);
  const capacity = data.slots.filter((s) => s.enabled).length;
  const available = data.slots.filter((s) => s.enabled && !s.occupied).length;
  const pendingCheckin = data.bookings.filter(
    (b) => b.status === "Đã xác nhận",
  ).length;

  const paid = data.payments.filter((p) => localDate(p.paidAt) === date);
  const revenue = paid.reduce((n, p) => n + p.amount, 0);

  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(`${date}T12:00:00`);
    d.setDate(d.getDate() - 6 + i);
    return localDate(d);
  });

  const trafficPoints = days.map((d) => {
    const count = data.bookings.filter(
      (b) => b.checkedIn && localDate(b.checkedIn) === d,
    ).length;
    return {
      label: `${d.slice(8, 10)}/${d.slice(5, 7)}`,
      fullLabel: `Ngày ${d.slice(8, 10)}/${d.slice(5, 7)}/${d.slice(0, 4)}`,
      value: count,
      detail: `${count} lượt check-in`,
    };
  });
  const weekTotal = trafficPoints.reduce((s, p) => s + p.value, 0);

  return (
    <>
      <PageHeading
        title="Tổng quan hệ thống"
        subtitle="Theo dõi công suất, vé đặt chỗ và doanh thu đồng bộ từ Supabase Cloud."
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
          value={enabledLots.length}
          detail={`Trong tổng số ${data.lots.length} bãi quản lý`}
          icon="IconBuilding1"
          tone="blue"
        />
        <Metric
          label="Xe đang trong bãi"
          value={used}
          detail={`${pendingCheckin} vé đã đặt chờ vào`}
          icon="IconCar1"
          tone="green"
          positive={used > 0}
        />
        <Metric
          label="Chỗ khả dụng hiện tại"
          value={available}
          detail={`Tổng ${capacity} vị trí đang mở`}
          icon="IconMapPin"
          tone="blue"
        />
        <Metric
          label="Doanh thu ngày đã chọn"
          value={money(revenue)}
          detail={`${paid.length} giao dịch tiền mặt đã xác nhận`}
          icon="IconChart1"
          tone="green"
          positive={revenue > 0}
        />
      </div>

      <div className="overview-charts">
        <Panel className="traffic-panel">
          <div className="panel-head-inline">
            <div>
              <h2>Lượt xe vào · 7 ngày</h2>
              <p className="panel-sub">Tính đến {date.slice(8, 10)}/{date.slice(5, 7)}/{date.slice(0, 4)}</p>
            </div>
            <Badge tone="blue">{weekTotal} lượt xe</Badge>
          </div>
          <LiveBars
            points={trafficPoints}
            formatValue={(v) => `${v} lượt xe`}
            formatAxisValue={(v) => String(Math.round(v))}
            ariaLabel="Biểu đồ lượt xe vào 7 ngày"
            emptyMessage="Chưa có lượt check-in nào trong 7 ngày qua."
          />
        </Panel>

        <Panel className="occupancy-panel">
          <div>
            <h2>Tình trạng chỗ đỗ</h2>
            <p className="panel-sub">Công suất toàn bộ vị trí đang mở</p>
          </div>
          <DonutRing occupied={used} capacity={capacity} label="Đang sử dụng" />
          <div className="donut-legend">
            <div>
              <Asset name="LegendBusy" />
              <span>Xe đang đỗ</span>
              <strong>{used} chỗ</strong>
            </div>
            <div>
              <Asset name="LegendFree" />
              <span>Chỗ còn trống</span>
              <strong>{available} chỗ</strong>
            </div>
          </div>
        </Panel>
      </div>

      <Panel className="recent-panel">
        <div className="panel-heading">
          <div>
            <h2>Đặt chỗ gần đây</h2>
            <p className="panel-sub">Đồng bộ thời gian thực từ ứng dụng Khách hàng & Nhân viên</p>
          </div>
          <Link to="/bookings">Xem tất cả →</Link>
        </div>
        <div className="table-scroll">
          <table className="recent-table">
            <thead>
              <tr>
                <th>MÃ VÉ</th>
                <th>KHÁCH HÀNG</th>
                <th>BIỂN SỐ</th>
                <th>BÃI ĐỖ</th>
                <th>KHUNG GIỜ</th>
                <th>TRẠNG THÁI</th>
              </tr>
            </thead>
            <tbody>
              {data.bookings.slice(0, 5).map((b) => (
                <tr key={b.id}>
                  <td>
                    <Link
                      className="mono link-ticket"
                      to={"/bookings?q=" + encodeURIComponent(b.id)}
                    >
                      #{b.id.slice(0, 8)}
                    </Link>
                  </td>
                  <td>{b.customer || "Khách đặt chỗ"}</td>
                  <td>
                    <span className="plate">{b.plate}</span>
                  </td>
                  <td>{data.lots.find((l) => l.id === b.lotId)?.name ?? "—"}</td>
                  <td>
                    {b.start} – {b.end}
                  </td>
                  <td>
                    <Badge>{b.status}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!data.bookings.length && (
            <Empty
              message="Chưa có đặt chỗ."
              hint="Khi khách hàng đặt chỗ trên ứng dụng di động, vé sẽ xuất hiện tại đây."
            />
          )}
        </div>
      </Panel>
    </>
  );
}

export function ParkingPage() {
  const { data } = useAdmin();
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState(() => searchParams.get("q") ?? "");
  const [statusFilter, setStatusFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [editor, setEditor] = useState<Lot | null | undefined>();
  const [selected, setSelected] = useState("");

  const q = query.toLocaleLowerCase("vi").trim();
  const filtered = data.lots.filter((l) => {
    const matchQ =
      !q || `${l.name} ${l.area}`.toLocaleLowerCase("vi").includes(q);
    const matchStatus =
      statusFilter === "all" ||
      (statusFilter === "enabled" && l.enabled) ||
      (statusFilter === "disabled" && !l.enabled);
    return matchQ && matchStatus;
  });

  const pageSize = 6;
  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const safePage = Math.min(page, totalPages);
  const pageLots = filtered.slice(
    (safePage - 1) * pageSize,
    safePage * pageSize,
  );

  const current = data.lots.some((l) => l.id === selected)
    ? selected
    : (data.lots[0]?.id ?? "");

  const enabledLots = data.lots.filter((l) => l.enabled).length;
  const enabledSlots = data.slots.filter((s) => s.enabled).length;
  const totalUsed = data.bookings.filter(
    (b) => b.status === "Đang sử dụng",
  ).length;
  const occPct = enabledSlots ? Math.round((totalUsed / enabledSlots) * 100) : 0;

  return (
    <>
      <PageHeading
        title="Quản lý bãi đỗ"
        subtitle="Quản lý danh sách bãi, giá niêm yết, sức chứa và trạng thái từng ô đỗ xe."
        action={
          <Button onClick={() => setEditor(null)}>+ Thêm bãi đỗ</Button>
        }
      />

      <div className="metrics three">
        <Metric
          label="Tổng bãi đỗ"
          value={data.lots.length}
          detail={`${enabledLots} đang mở · ${data.lots.length - enabledLots} tạm ngưng`}
          icon="IconBuilding1"
          tone="blue"
        />
        <Metric
          label="Tổng vị trí"
          value={data.slots.length}
          detail={`${enabledSlots} vị trí đang khả dụng`}
          icon="IconMapPin"
          tone="purple"
        />
        <Metric
          label="Xe trong bãi"
          value={totalUsed}
          detail={`Tỷ lệ lấp đầy ${occPct}% toàn hệ thống`}
          icon="IconCar1"
          tone="green"
          positive={totalUsed > 0}
        />
      </div>

      <Panel className="parking-table-panel">
        <div className="table-heading">
          <div>
            <h2>Danh sách bãi đỗ</h2>
            <p className="panel-sub">
              Thay đổi tại đây đồng bộ trực tiếp sang màn hình tìm bãi của Khách
              hàng
            </p>
          </div>
          <div className="table-controls">
            <SearchField
              value={query}
              onChange={(v) => {
                setQuery(v);
                setPage(1);
              }}
              placeholder="Tìm tên bãi hoặc khu vực..."
            />
            <label className="select-icon">
              <Asset name="IconFilter" />
              <select
                aria-label="Lọc trạng thái bãi đỗ"
                value={statusFilter}
                onChange={(e) => {
                  setStatusFilter(e.target.value);
                  setPage(1);
                }}
              >
                <option value="all">Tất cả trạng thái</option>
                <option value="enabled">Đang hoạt động</option>
                <option value="disabled">Tạm ngưng</option>
              </select>
            </label>
          </div>
        </div>

        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>BIỂU TƯỢNG</th>
                <th>BÃI ĐỖ</th>
                <th>KHU VỰC</th>
                <th>CÔNG SUẤT</th>
                <th>GIÁ Ô TÔ</th>
                <th>TRẠNG THÁI</th>
                <th>THAO TÁC</th>
              </tr>
            </thead>
            <tbody>
              {pageLots.map((l) => {
                const rate = l.enabledCapacity
                  ? Math.round((l.occupied / l.enabledCapacity) * 100)
                  : 0;
                const price = data.pricing[l.id];
                return (
                  <tr
                    key={l.id}
                    className={current === l.id ? "row-selected" : ""}
                  >
                    <td>
                      <span className="lot-icon">
                        <Asset name="IconBuilding2" />
                      </span>
                    </td>
                    <td>{l.name}</td>
                    <td>{l.area}</td>
                    <td>
                      <div className="capacity-cell">
                        <span>
                          {l.occupied}/{l.capacity} chỗ ({rate}%)
                        </span>
                        <Progress
                          value={rate}
                          tone={rate >= 85 ? "amber" : "blue"}
                        />
                      </div>
                    </td>
                    <td>{price ? money(price.car) + "/h" : "—"}</td>
                    <td>
                      <Badge>{l.enabled ? "Hoạt động" : "Tạm ngưng"}</Badge>
                    </td>
                    <td>
                      <div className="row-actions">
                        <Button secondary onClick={() => setEditor(l)}>
                          Sửa
                        </Button>
                        <button
                          type="button"
                          className="link"
                          onClick={() => setSelected(l.id)}
                        >
                          Vị trí
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {!filtered.length && (
            <Empty
              message="Chưa có bãi đỗ phù hợp."
              hint="Thử xóa bộ lọc hoặc nhấn + Thêm bãi đỗ để tạo bãi mới."
            />
          )}
        </div>

        {filtered.length > 0 && (
          <Pagination
            page={safePage}
            count={filtered.length}
            pageSize={pageSize}
            onChange={setPage}
            noun="bãi đỗ"
          />
        )}
      </Panel>

      <SlotManager lotId={current} onLotChange={setSelected} />

      {editor !== undefined && (
        <LotEditor lot={editor} onClose={() => setEditor(undefined)} />
      )}
    </>
  );
}

function LotEditor({ lot, onClose }: { lot: Lot | null; onClose: () => void }) {
  const { command, notice } = useAdmin();
  const [name, setName] = useState(lot?.name ?? "");
  const [area, setArea] = useState(lot?.area ?? "");
  const [capacity, setCapacity] = useState(lot?.capacity ?? 16);
  const [enabled, setEnabled] = useState(lot?.enabled ?? true);
  const [lat, setLat] = useState(lot?.latitude?.toString() ?? "");
  const [lng, setLng] = useState(lot?.longitude?.toString() ?? "");
  const [busy, setBusy] = useState(false);

  return (
    <Dialog
      title={lot ? "Sửa thông tin bãi đỗ" : "Thêm bãi đỗ mới"}
      onClose={onClose}
      footer={
        <>
          <Button secondary onClick={onClose}>
            Hủy
          </Button>
          <Button form="lot-editor" disabled={busy}>
            {busy ? "Đang lưu..." : "Lưu bãi đỗ"}
          </Button>
        </>
      }
    >
      <form
        id="lot-editor"
        className="edit-form"
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          const ok = await command("manage_lot", {
            p_id: lot?.id ?? crypto.randomUUID(),
            p_name: name.trim(),
            p_area: area.trim(),
            p_enabled: enabled,
            p_capacity: capacity,
            p_latitude: lat === "" ? null : Number(lat),
            p_longitude: lng === "" ? null : Number(lng),
            p_expected_version: lot?.version ?? 0,
          });
          setBusy(false);
          if (ok) {
            notice("Đã lưu bãi đỗ trên Supabase.");
            onClose();
          }
        }}
      >
        <label>
          Tên bãi
          <input
            aria-label="Tên bãi"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="VD: Bãi xe Trung tâm Q1"
            required
            maxLength={150}
          />
        </label>
        <label>
          Địa chỉ / khu vực
          <input
            aria-label="Địa chỉ"
            value={area}
            onChange={(e) => setArea(e.target.value)}
            placeholder="VD: 12 Nguyễn Huệ, Quận 1"
            required
          />
        </label>
        <label>
          Số vị trí
          <input
            aria-label="Số vị trí"
            type="number"
            min={lot?.capacity ?? 1}
            max={500}
            value={capacity}
            onChange={(e) => setCapacity(Number(e.target.value))}
            required
          />
        </label>
        <p className="form-hint">
          Các ô đỗ tạo tự động theo mã A001, A002… Nếu muốn giảm sức chứa khả
          dụng, hãy tạm ngưng từng vị trí trống ở sơ đồ bên dưới.
        </p>
        <div className="form-row-2">
          <label>
            Vĩ độ (tùy chọn)
            <input
              aria-label="Vĩ độ"
              type="number"
              step="any"
              min={-90}
              max={90}
              value={lat}
              placeholder="10.7769"
              onChange={(e) => setLat(e.target.value)}
            />
          </label>
          <label>
            Kinh độ (tùy chọn)
            <input
              aria-label="Kinh độ"
              type="number"
              step="any"
              min={-180}
              max={180}
              value={lng}
              placeholder="106.7009"
              onChange={(e) => setLng(e.target.value)}
            />
          </label>
        </div>
        <label className="checkbox-field">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => setEnabled(e.target.checked)}
          />
          <span>Bãi đang hoạt động (cho phép khách đặt chỗ)</span>
        </label>
      </form>
    </Dialog>
  );
}

function SlotManager({
  lotId,
  onLotChange,
}: {
  lotId: string;
  onLotChange: (id: string) => void;
}) {
  const { data, command } = useAdmin();
  const [busy, setBusy] = useState(false);

  const lotSlots = data.slots.filter((s) => s.lotId === lotId);
  const openCount = lotSlots.filter((s) => s.enabled && !s.occupied).length;
  const occupiedCount = lotSlots.filter((s) => s.occupied).length;
  const disabledCount = lotSlots.filter((s) => !s.enabled).length;

  return (
    <Panel className="slot-panel">
      <div className="table-heading">
        <div>
          <h2>Quản lý vị trí đỗ</h2>
          <p className="panel-sub">
            Nhấn trực tiếp vào ô trống để mở hoặc tạm ngưng bảo trì
          </p>
        </div>
        <div className="slot-toolbar">
          <select
            aria-label="Bãi quản lý vị trí"
            value={lotId}
            onChange={(e) => onLotChange(e.target.value)}
          >
            {data.lots.map((l) => (
              <option value={l.id} key={l.id}>
                {l.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="slot-summary-bar">
        <span className="slot-stat open">
          <i /> Trống / sẵn sàng: <strong>{openCount}</strong>
        </span>
        <span className="slot-stat busy">
          <i /> Đã giữ / đang dùng: <strong>{occupiedCount}</strong>
        </span>
        <span className="slot-stat off">
          <i /> Đang tạm ngưng: <strong>{disabledCount}</strong>
        </span>
      </div>

      {lotSlots.length ? (
        <div className="slot-grid">
          {lotSlots.map((s) => (
            <button
              type="button"
              key={s.id}
              disabled={busy || s.occupied}
              className={
                "slot-cell " +
                (!s.enabled ? "disabled" : s.occupied ? "occupied" : "open")
              }
              onClick={async () => {
                setBusy(true);
                await command("manage_slot", {
                  p_id: s.id,
                  p_enabled: !s.enabled,
                });
                setBusy(false);
              }}
            >
              <div className="slot-cell-head">
                <strong>{s.code}</strong>
                <span className="slot-dot" />
              </div>
              <small>
                {s.occupied
                  ? "Đã giữ / đang dùng"
                  : s.enabled
                    ? "Đang mở · bấm ngưng"
                    : "Tạm ngưng · bấm mở"}
              </small>
            </button>
          ))}
        </div>
      ) : (
        <Empty
          message="Bãi này chưa có vị trí đỗ."
          hint="Chọn bãi khác hoặc chỉnh sửa sức chứa của bãi."
        />
      )}

      <p className="slot-footnote">
        Máy chủ bảo vệ tự động: từ chối tạm ngưng các vị trí đang có xe đỗ hoặc
        vé đã đặt trước chưa kết thúc.
      </p>
    </Panel>
  );
}
