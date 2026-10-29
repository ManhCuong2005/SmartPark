import { useState } from "react";
import { Link } from "react-router-dom";
import {
  Panel,
  PageHeading,
  Metric,
  Badge,
  Button,
  Dialog,
  Empty,
  SearchField,
} from "../components/ui";
import { LiveBars } from "../components/live-charts";
import { useAdmin } from "../data/store";
import { localDate, money } from "../data/models";
import type { Lot } from "../data/models";

export function OverviewPage() {
  const { data } = useAdmin(),
    [date, setDate] = useState(localDate());
  const used = data.lots.reduce((n, l) => n + l.occupied, 0),
    capacity = data.slots.filter((s) => s.enabled).length;
  const paid = data.payments.filter((p) => localDate(p.paidAt) === date),
    revenue = paid.reduce((n, p) => n + p.amount, 0);
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(`${date}T12:00:00`);
    d.setDate(d.getDate() - 6 + i);
    return localDate(d);
  });
  return (
    <>
      <PageHeading
        title="Tổng quan hệ thống"
        subtitle="Dữ liệu vận hành từ Supabase Cloud."
        action={
          <input
            aria-label="Ngày tổng quan"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        }
      />
      <div className="metrics four">
        <Metric
          label="Bãi đỗ đang hoạt động"
          value={data.lots.filter((l) => l.enabled).length}
          detail="Bãi thuộc quyền quản lý"
          icon="IconBuilding1"
        />
        <Metric
          label="Xe đang trong bãi"
          value={used}
          detail="Vé có trạng thái đang sử dụng"
          icon="IconCar1"
          tone="green"
        />
        <Metric
          label="Chỗ khả dụng hiện tại"
          value={data.slots.filter((s) => s.enabled && !s.occupied).length}
          detail={`Tổng ${capacity} vị trí đang mở`}
          icon="IconMapPin"
        />
        <Metric
          label="Doanh thu ngày đã chọn"
          value={money(revenue)}
          detail={`${paid.length} giao dịch tiền mặt đã xác nhận`}
          icon="IconChart1"
          tone="green"
        />
      </div>
      <div className="overview-charts">
        <Panel className="traffic-panel">
          <h2>Lượt xe vào · 7 ngày</h2>
          <LiveBars
            points={days.map((d) => ({
              label: d.slice(5),
              value: data.bookings.filter(
                (b) => b.checkedIn && localDate(b.checkedIn) === d,
              ).length,
            }))}
          />
        </Panel>
        <Panel className="occupancy-panel">
          <h2>Tình trạng chỗ đỗ</h2>
          <div
            className="live-donut"
            style={{
              background: `conic-gradient(#315fea ${capacity ? (used / capacity) * 100 : 0}%, #e8edf4 0)`,
            }}
          >
            <div>
              <strong>
                {capacity ? Math.round((used / capacity) * 100) : 0}%
              </strong>
              <p>Đang sử dụng</p>
            </div>
          </div>
          <p>
            {used} xe / {capacity} vị trí đang mở
          </p>
        </Panel>
      </div>
      <Panel className="recent-panel">
        <div className="panel-heading">
          <h2>Đặt chỗ gần đây</h2>
          <Link to="/bookings">Xem tất cả →</Link>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>MÃ VÉ</th>
                <th>KHÁCH HÀNG</th>
                <th>BIỂN SỐ</th>
                <th>BÃI ĐỖ</th>
                <th>TRẠNG THÁI</th>
              </tr>
            </thead>
            <tbody>
              {data.bookings.slice(0, 5).map((b) => (
                <tr key={b.id}>
                  <td>
                    <Link to={"/bookings?q=" + b.id}>{b.id.slice(0, 8)}</Link>
                  </td>
                  <td>{b.customer}</td>
                  <td>{b.plate}</td>
                  <td>{data.lots.find((l) => l.id === b.lotId)?.name}</td>
                  <td>
                    <Badge>{b.status}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!data.bookings.length && <Empty message="Chưa có đặt chỗ." />}
        </div>
      </Panel>
    </>
  );
}
export function ParkingPage() {
  const { data } = useAdmin(),
    [query, setQuery] = useState(""),
    [editor, setEditor] = useState<Lot | null | undefined>(),
    [selected, setSelected] = useState("");
  const filtered = data.lots.filter((l) =>
    (l.name + " " + l.area)
      .toLocaleLowerCase("vi")
      .includes(query.toLocaleLowerCase("vi")),
  );
  const current = data.lots.some((l) => l.id === selected)
    ? selected
    : (data.lots[0]?.id ?? "");
  return (
    <>
      <PageHeading
        title="Quản lý bãi đỗ"
        subtitle="Bãi đỗ, vị trí và tình trạng xe trong hệ thống."
        action={<Button onClick={() => setEditor(null)}>+ Thêm bãi đỗ</Button>}
      />
      <div className="metrics three">
        <Metric
          label="Tổng bãi đỗ"
          value={data.lots.length}
          detail="Thuộc chủ bãi hiện tại"
          icon="IconBuilding1"
        />
        <Metric
          label="Tổng vị trí"
          value={data.slots.length}
          detail="Bao gồm vị trí tạm ngưng"
          icon="IconMapPin"
        />
        <Metric
          label="Xe trong bãi"
          value={
            data.bookings.filter((b) => b.status === "Đang sử dụng").length
          }
          detail="Trạng thái từ máy chủ"
          icon="IconCar1"
        />
      </div>
      <Panel>
        <SearchField
          value={query}
          onChange={setQuery}
          placeholder="Tìm bãi đỗ"
        />
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>BÃI ĐỖ</th>
                <th>KHU VỰC</th>
                <th>VỊ TRÍ</th>
                <th>XE ĐANG GỬI</th>
                <th>TRẠNG THÁI</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {filtered.map((l) => (
                <tr key={l.id}>
                  <td>{l.name}</td>
                  <td>{l.area}</td>
                  <td>{l.capacity}</td>
                  <td>{l.occupied}</td>
                  <td>
                    <Badge>{l.enabled ? "Hoạt động" : "Tạm ngưng"}</Badge>
                  </td>
                  <td>
                    <Button secondary onClick={() => setEditor(l)}>
                      Sửa
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!filtered.length && <Empty message="Chưa có bãi đỗ phù hợp." />}
        </div>
      </Panel>
      <SlotManager lotId={current} onLotChange={setSelected} />
      {editor !== undefined && (
        <LotEditor lot={editor} onClose={() => setEditor(undefined)} />
      )}
    </>
  );
}
function LotEditor({ lot, onClose }: { lot: Lot | null; onClose: () => void }) {
  const { command, notice } = useAdmin(),
    [name, setName] = useState(lot?.name ?? ""),
    [area, setArea] = useState(lot?.area ?? ""),
    [capacity, setCapacity] = useState(lot?.capacity ?? 16),
    [enabled, setEnabled] = useState(lot?.enabled ?? true),
    [lat, setLat] = useState(lot?.latitude?.toString() ?? ""),
    [lng, setLng] = useState(lot?.longitude?.toString() ?? ""),
    [busy, setBusy] = useState(false);
  return (
    <Dialog
      title={lot ? "Sửa bãi đỗ" : "Thêm bãi đỗ"}
      onClose={onClose}
      footer={
        <>
          <Button secondary onClick={onClose}>
            Hủy
          </Button>
          <Button form="lot-editor" disabled={busy}>
            Lưu bãi đỗ
          </Button>
        </>
      }
    >
      <form
        id="lot-editor"
        className="live-form"
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
        <p>
          Vị trí tạo theo mã A001, A002… Muốn giảm sức chứa, tạm ngưng vị trí
          trống ở bảng phía dưới.
        </p>
        <label>
          Vĩ độ
          <input
            aria-label="Vĩ độ"
            type="number"
            step="any"
            min={-90}
            max={90}
            value={lat}
            onChange={(e) => setLat(e.target.value)}
          />
        </label>
        <label>
          Kinh độ
          <input
            aria-label="Kinh độ"
            type="number"
            step="any"
            min={-180}
            max={180}
            value={lng}
            onChange={(e) => setLng(e.target.value)}
          />
        </label>
        <label>
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => setEnabled(e.target.checked)}
          />{" "}
          Bãi đang hoạt động
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
  const { data, command } = useAdmin(),
    [busy, setBusy] = useState(false);
  return (
    <Panel>
      <h2>Quản lý vị trí đỗ</h2>
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
      <div className="slot-grid">
        {data.slots
          .filter((s) => s.lotId === lotId)
          .map((s) => (
            <button
              key={s.id}
              disabled={busy || s.occupied}
              className={
                "slot-cell " +
                (!s.enabled ? "disabled" : s.occupied ? "occupied" : "")
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
              <strong>{s.code}</strong>
              <small>
                {s.occupied
                  ? "Đã giữ / đang dùng"
                  : s.enabled
                    ? "Đang mở · bấm để ngưng"
                    : "Tạm ngưng · bấm để mở"}
              </small>
            </button>
          ))}
      </div>
      <p>Máy chủ từ chối tạm ngưng vị trí còn vé đang hoạt động.</p>
    </Panel>
  );
}
