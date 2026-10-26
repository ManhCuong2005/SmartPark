import { useEffect, useState } from "react";
import {
  Asset,
  Panel,
  PageHeading,
  Metric,
  Badge,
  BarChart,
  Button,
  Progress,
  Dialog,
} from "../components/ui";
import { useAdmin, exportCsv } from "../data/store";
import { money, shortLot } from "../data/mock";
import type { Pricing } from "../data/mock";

export function ReportsPage() {
  const { notice } = useAdmin();
  const shares = [
    { label: "VNPAY QR", pct: 52, color: "#315fea", asset: "LegendDot" },
    { label: "Ví điện tử", pct: 28, color: "#17b29a", asset: "LegendDot1" },
    { label: "Thẻ ngân hàng", pct: 14, color: "#7b61da", asset: "LegendDot2" },
    { label: "Tiền mặt", pct: 6, color: "#cb8720", asset: "LegendDot3" },
  ];
  function csv() {
    exportCsv(
      "smartpark-bao-cao-demo-thang-10.csv",
      ["Chỉ tiêu demo", "Giá trị", "Đơn vị"],
      [
        ["Doanh thu tháng 10/2026", 246800000, "VND"],
        ["Lượt đặt thành công", 3420, "lượt"],
        ["Giá trị trung bình", 72100, "VND"],
        ...shares.map((s) => [s.label, s.pct, "%"]),
      ],
    );
    notice(
      "Đã xuất báo cáo mẫu tháng 10/2026. Đây không phải báo cáo giao dịch thực tế.",
    );
  }
  return (
    <>
      <PageHeading
        title="Báo cáo & doanh thu"
        subtitle="Theo dõi tổng doanh thu, hiệu suất kinh doanh và hình thức thanh toán."
        action={
          <Button secondary onClick={csv}>
            Xuất báo cáo
          </Button>
        }
      />
      <div className="metrics three">
        <Metric
          label="Tổng doanh thu tháng"
          value="246,8 tr"
          detail="+18,6% so với tháng trước"
          icon="IconChart1"
          tone="green"
          positive
        />
        <Metric
          label="Số lượt đặt thành công"
          value="3.420"
          detail="+13,4% so với tháng trước"
          icon="IconTicket1"
          positive
        />
        <Metric
          label="Giá trị trung bình / lượt"
          value="72.100đ"
          detail="+6,2% so với tháng trước"
          icon="IconCredit"
          tone="green"
          positive
        />
      </div>
      <div className="report-charts">
        <Panel className="revenue-panel">
          <div className="panel-heading">
            <h2>Doanh thu theo tháng</h2>
            <Badge tone="green">↑ Tăng trưởng 18,6%</Badge>
          </div>
          <BarChart revenue />
        </Panel>
        <Panel className="payment-panel">
          <h2>Phương thức thanh toán</h2>
          <p className="panel-subtitle">Tỷ trọng giao dịch trong tháng</p>
          <div className="payment-shares">
            {shares.map((s) => (
              <div key={s.label}>
                <div>
                  <span>
                    <Asset name={s.asset} />
                    {s.label}
                  </span>
                  <strong>{s.pct}%</strong>
                </div>
                <div className="progress">
                  <span style={{ width: `${s.pct}%`, background: s.color }} />
                </div>
              </div>
            ))}
          </div>
        </Panel>
      </div>
      <Panel className="ranking-panel">
        <h2>Bãi đỗ có doanh thu cao nhất</h2>
        <div className="ranking-grid">
          {[
            { name: "Bãi xe Trung tâm", revenue: "78,5 triệu · 32%" },
            { name: "Bãi xe Vincom", revenue: "61,2 triệu · 25%" },
            { name: "Bãi xe Sông Hàn", revenue: "46,8 triệu · 19%" },
          ].map((l, i) => (
            <div className="rank-card" key={l.name}>
              <b>0{i + 1}</b>
              <div>
                <strong>{l.name}</strong>
                <small>{l.revenue}</small>
              </div>
            </div>
          ))}
        </div>
      </Panel>
    </>
  );
}
const ruleItems = [
  {
    key: "advance",
    label: "Cho phép đặt trước",
    help: "Khách có thể giữ chỗ từ xa",
  },
  { key: "qr", label: "Xác nhận bằng mã QR", help: "Bắt buộc khi xe vào bãi" },
  {
    key: "cash",
    label: "Cho phép thanh toán tiền mặt",
    help: "Tại quầy thu ngân",
  },
  {
    key: "autoCancel",
    label: "Tự động hủy khi quá giờ",
    help: "Sau thời gian chờ cấu hình",
  },
] as const;
export function SettingsPage() {
  const { data, change, notice } = useAdmin();
  const [lotId, setLotId] = useState(data.lots[0].id),
    [draft, setDraft] = useState<Pricing>(data.pricing[data.lots[0].id]),
    [error, setError] = useState(""),
    [info, setInfo] = useState<"access" | "backup" | null>(null);
  const lot = data.lots.find((l) => l.id === lotId)!;
  useEffect(() => {
    setDraft(data.pricing[lotId]);
    setError("");
  }, [lotId, data.pricing]);
  const numeric = [
    { key: "car", label: "Phí ô tô / giờ", suffix: "đ" },
    { key: "motorcycle", label: "Phí xe máy / giờ", suffix: "đ" },
    { key: "overnight", label: "Phí qua đêm", suffix: "đ" },
    { key: "freeMinutes", label: "Thời gian miễn phí", suffix: "phút" },
  ] as const;
  function save() {
    if (
      numeric.some(
        ({ key }) =>
          !Number.isInteger(draft[key]) ||
          draft[key] < 0 ||
          draft[key] > (key === "freeMinutes" ? 1440 : 100000000),
      )
    ) {
      setError(
        "Mức phí phải là số nguyên không âm tối đa 100.000.000đ; thời gian miễn phí tối đa 1.440 phút.",
      );
      return;
    }
    change((d) => ({ ...d, pricing: { ...d.pricing, [lotId]: { ...draft } } }));
    notice(
      "Đã lưu giá vé và quy tắc demo trên trình duyệt. Chưa áp dụng cho hệ thống thực tế.",
    );
    setError("");
  }
  return (
    <>
      <PageHeading
        title="Cài đặt & giá vé"
        subtitle="Thiết lập mức phí, quy tắc đặt chỗ và chính sách vận hành bãi đỗ."
        action={
          <Button type="submit" form="pricing-form">
            Lưu thay đổi
          </Button>
        }
      />
      <form
        id="pricing-form"
        className="settings-grid"
        onSubmit={(e) => {
          e.preventDefault();
          save();
        }}
      >
        <Panel className="pricing-panel">
          <h2>Cấu hình giá vé</h2>
          <p className="panel-subtitle">Áp dụng cho {lot.name}</p>
          <label className="lot-select">
            <Asset name="IconBuilding1" />
            <select
              aria-label="Bãi đỗ áp dụng giá vé"
              value={lotId}
              onChange={(e) => setLotId(e.target.value)}
            >
              {data.lots.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name} — {l.area}
                </option>
              ))}
            </select>
            <Asset name="IconDown" />
          </label>
          <div className="price-fields">
            {numeric.map((f) => (
              <label key={f.key}>
                {f.label}
                <span>
                  <input
                    aria-label={f.label}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9. ]+"
                    required
                    min={0}
                    max={f.key === "freeMinutes" ? 1440 : 100000000}
                    step={1}
                    value={
                      Number.isFinite(draft[f.key])
                        ? draft[f.key].toLocaleString("vi-VN")
                        : ""
                    }
                    onChange={(e) =>
                      setDraft((d) => ({
                        ...d,
                        [f.key]:
                          e.target.value === ""
                            ? NaN
                            : Number(e.target.value.replace(/[.\s]/g, "")),
                      }))
                    }
                  />
                  <em>{f.suffix}</em>
                </span>
              </label>
            ))}
          </div>
          <div className="info-note">
            <Asset name="IconInfo" />
            <span>
              Ước tính: ô tô đỗ 2 giờ ={" "}
              {Number.isFinite(draft.car)
                ? money(
                    Math.max(0, draft.car) *
                      Math.ceil(Math.max(0, 120 - draft.freeMinutes) / 60),
                  )
                : "—"}
            </span>
          </div>
          {error && (
            <p className="form-error" role="alert">
              {error}
            </p>
          )}
        </Panel>
        <Panel className="rules-panel">
          <h2>Quy tắc đặt chỗ</h2>
          {ruleItems.map((r) => (
            <div className="rule" key={r.key}>
              <div>
                <strong>{r.label}</strong>
                <small>{r.help}</small>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={draft[r.key]}
                aria-label={r.label}
                onClick={() => setDraft((d) => ({ ...d, [r.key]: !d[r.key] }))}
              >
                <Asset
                  name={
                    draft[r.key] ? "SwitchChoPhepDtTrc" : "SwitchTDngHyKhiQuaGi"
                  }
                />
              </button>
            </div>
          ))}
        </Panel>
      </form>
      <Panel className="security-panel">
        <h2>Vận hành & bảo mật</h2>
        <div className="security-grid">
          <button className="security-card" onClick={() => setInfo("access")}>
            <span className="security-icon green">
              <Asset name="IconShield" />
            </span>
            <span>
              <strong>Quản lý quyền truy cập</strong>
              <small>Phân quyền rõ cho nhân viên và quản lý.</small>
            </span>
          </button>
          <button className="security-card" onClick={() => setInfo("backup")}>
            <span className="security-icon blue">
              <Asset name="IconRefresh" />
            </span>
            <span>
              <strong>Sao lưu dữ liệu định kỳ</strong>
              <small>Bảo đảm dữ liệu bãi đỗ luôn nhất quán.</small>
            </span>
          </button>
        </div>
      </Panel>
      {info && (
        <Dialog
          title={
            info === "access"
              ? "Quản lý quyền truy cập"
              : "Sao lưu dữ liệu demo"
          }
          onClose={() => setInfo(null)}
          footer={<Button onClick={() => setInfo(null)}>Đã hiểu</Button>}
        >
          <p>
            {info === "access"
              ? "Bản demo chưa có backend xác thực hoặc kiểm tra quyền. Việc phân công nhân viên chỉ cập nhật dữ liệu local; chưa cấp quyền truy cập thực tế."
              : "Dữ liệu demo được lưu trong localStorage của trình duyệt này, không có tác vụ sao lưu định kỳ. Bạn có thể xuất báo cáo và danh sách đặt chỗ thành CSV."}
          </p>
        </Dialog>
      )}
    </>
  );
}
