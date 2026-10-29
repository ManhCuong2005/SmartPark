import { useState } from "react";
import { Panel, PageHeading, Metric, Button, Empty } from "../components/ui";
import { LiveBars } from "../components/live-charts";
import { useAdmin, exportCsv } from "../data/store";
import { localDate, money } from "../data/models";
import type { Pricing } from "../data/models";

export function ReportsPage() {
  const { data } = useAdmin(),
    [month, setMonth] = useState(localDate().slice(0, 7));
  const paid = data.payments.filter((p) =>
      localDate(p.paidAt).startsWith(month),
    ),
    revenue = paid.reduce((n, p) => n + p.amount, 0);
  const ranking = data.lots
    .map((l) => ({
      label: l.name,
      value: paid
        .filter((p) =>
          data.bookings.some((b) => b.id === p.bookingId && b.lotId === l.id),
        )
        .reduce((n, p) => n + p.amount, 0),
    }))
    .sort((a, b) => b.value - a.value);
  return (
    <>
      <PageHeading
        title="Báo cáo & doanh thu"
        subtitle="Chỉ tổng hợp các khoản tiền mặt đã được máy chủ ghi nhận."
        action={
          <Button
            secondary
            onClick={() =>
              exportCsv(
                "smartpark-doanh-thu.csv",
                ["Mã giao dịch", "Mã vé", "Ngày thu", "Số tiền"],
                paid.map((p) => [p.id, p.bookingId, p.paidAt, p.amount]),
              )
            }
          >
            Xuất báo cáo
          </Button>
        }
      />
      <label>
        Tháng báo cáo{" "}
        <input
          aria-label="Tháng báo cáo"
          type="month"
          value={month}
          onChange={(e) => setMonth(e.target.value)}
        />
      </label>
      <div className="metrics three">
        <Metric
          label="Doanh thu tháng"
          value={money(revenue)}
          detail={month}
          icon="IconChart1"
          tone="green"
        />
        <Metric
          label="Lượt đã thanh toán"
          value={paid.length}
          detail="Mỗi vé tối đa một khoản thu"
          icon="IconTicket1"
        />
        <Metric
          label="Trung bình / lượt"
          value={money(paid.length ? Math.round(revenue / paid.length) : 0)}
          detail="Thanh toán tiền mặt tại bãi"
          icon="IconCredit"
        />
      </div>
      <div className="report-charts">
        <Panel className="revenue-panel">
          <h2>Doanh thu theo ngày</h2>
          <LiveBars
            points={Array.from(
              {
                length: new Date(
                  Number(month.slice(0, 4)),
                  Number(month.slice(5, 7)),
                  0,
                ).getDate(),
              },
              (_, i) => ({
                label: String(i + 1),
                value: paid
                  .filter((p) => new Date(p.paidAt).getDate() === i + 1)
                  .reduce((n, p) => n + p.amount, 0),
              }),
            )}
          />
        </Panel>
        <Panel className="payment-panel">
          <h2>Phương thức thanh toán</h2>
          <p>
            Tiền mặt: {paid.length} giao dịch · {money(revenue)}
          </p>
        </Panel>
      </div>
      <Panel>
        <h2>Doanh thu theo bãi</h2>
        {ranking.length ? (
          ranking.map((l, i) => (
            <div className="rank-card" key={l.label}>
              <b>{i + 1}</b>
              <strong>{l.label}</strong>
              <span>{money(l.value)}</span>
            </div>
          ))
        ) : (
          <Empty message="Chưa có bãi đỗ." />
        )}
      </Panel>
    </>
  );
}
export function SettingsPage() {
  const { data } = useAdmin(),
    [selected, setSelected] = useState("");
  const id = data.lots.some((l) => l.id === selected)
    ? selected
    : data.lots[0]?.id;
  if (!id)
    return (
      <>
        <PageHeading
          title="Cài đặt & giá vé"
          subtitle="Tạo bãi đỗ trước khi cấu hình giá."
        />
        <Empty message="Chưa có bãi đỗ." />
      </>
    );
  return (
    <>
      <PageHeading
        title="Cài đặt & giá vé"
        subtitle="Giá mới áp dụng cho vé tạo sau khi lưu; vé hiện có giữ bảng giá đã chốt."
      />
      <select
        aria-label="Bãi đỗ áp dụng giá vé"
        value={id}
        onChange={(e) => setSelected(e.target.value)}
      >
        {data.lots.map((l) => (
          <option value={l.id} key={l.id}>
            {l.name}
          </option>
        ))}
      </select>
      <PricingEditor
        key={id + ":" + data.pricing[id].version}
        id={id}
        initial={data.pricing[id]}
      />
    </>
  );
}
function PricingEditor({ id, initial }: { id: string; initial: Pricing }) {
  const { command, notice } = useAdmin(),
    [draft, setDraft] = useState(initial),
    [busy, setBusy] = useState(false);
  const fields = [
    ["car", "Phí ô tô / giờ"],
    ["motorcycle", "Phí xe máy / giờ"],
    ["freeMinutes", "Số phút miễn phí"],
  ] as const;
  return (
    <form
      className="settings-grid"
      onSubmit={async (e) => {
        e.preventDefault();
        setBusy(true);
        const ok = await command("set_pricing", {
          p_lot_id: id,
          p_car: draft.car,
          p_motorcycle: draft.motorcycle,
          p_free_minutes: draft.freeMinutes,
          p_expected_version: initial.version,
        });
        setBusy(false);
        if (ok) notice("Đã lưu bảng giá trên Supabase.");
      }}
    >
      <Panel className="pricing-panel">
        <h2>Cấu hình giá vé</h2>
        <div className="price-fields">
          {fields.map(([key, label]) => (
            <label key={key}>
              {label}
              <input
                aria-label={label}
                type="number"
                required
                min={0}
                max={key === "freeMinutes" ? 120 : 10000000}
                step={1}
                value={draft[key]}
                onChange={(e) =>
                  setDraft({ ...draft, [key]: Number(e.target.value) })
                }
              />
            </label>
          ))}
        </div>
        <p>
          Trong thời gian miễn phí: 0đ. Sau đó tính tròn lên mỗi giờ từ lúc
          check-in, không trừ phút miễn phí khỏi thời gian tính tiền.
        </p>
        <Button disabled={busy}>Lưu thay đổi</Button>
      </Panel>
      <Panel className="rules-panel">
        <h2>Quy tắc vận hành</h2>
        <p>
          Đặt trước cần máy chủ xác nhận. Vé QR được kiểm tra khi xe vào/ra.
          Thanh toán tiền mặt khi check-out.
        </p>
        <p>
          Đơn vị giá là VND. Phiên bản dữ liệu bảo vệ thay đổi đồng thời từ
          nhiều thiết bị.
        </p>
        <h2>Phân quyền và sao lưu</h2>
        <p>
          Nhân viên được cấp quyền theo bãi. Quản lý sao lưu và khôi phục tại
          Supabase Dashboard theo gói dịch vụ của project.
        </p>
      </Panel>
    </form>
  );
}
