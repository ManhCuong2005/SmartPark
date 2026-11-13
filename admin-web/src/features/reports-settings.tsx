import { vehicleKindLabel } from "../data/models";
import { useMemo, useState } from "react";
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
  Progress,
  SearchField,
  UiIcon,
} from "../components/ui";
import { LiveBars } from "../components/live-charts";
import type { ChartPoint } from "../components/live-charts";
import { useAdmin, exportCsv } from "../data/store";
import {
  compactMoney,
  estimateParkingFee,
  formatDateTime,
  formatDuration,
  formatTime,
  localDate,
  money,
  pad,
} from "../data/models";
import type { Payment, Pricing } from "../data/models";

type PeriodMode = "today" | "7days" | "month" | "6months" | "all";

function paymentMethodLabel(method: string): string {
  const labels: Record<string, string> = {
    cash: "Tiền mặt", wallet: "Số dư gửi xe", qr: "QR payOS", wallet_refund: "Hoàn vào số dư",
  };
  return labels[method] ?? method;
}

function shiftLocalDate(baseYmd: string, deltaDays: number): string {
  const [y, m, d] = baseYmd.split("-").map(Number);
  const dt = new Date(y, (m || 1) - 1, (d || 1) + deltaDays);
  return localDate(dt);
}

function shiftYearMonth(ym: string, deltaMonths: number): string {
  const [y, m] = ym.split("-").map(Number);
  const dt = new Date(y, (m || 1) - 1 + deltaMonths, 1);
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}`;
}

function formatMonthVi(ym: string): string {
  const [y, m] = ym.split("-");
  return `Tháng ${Number(m)}/${y}`;
}

function formatShortDateVi(ymd: string): string {
  const parts = ymd.split("-");
  return parts.length === 3 ? `${parts[2]}/${parts[1]}` : ymd;
}

export function ReportsPage() {
  const { data, notice, refresh, syncing } = useAdmin();
  const [searchParams] = useSearchParams();
  const today = localDate();
  const currentYm = today.slice(0, 7);

  const [period, setPeriod] = useState<PeriodMode>("month");
  const [month, setMonth] = useState(currentYm);
  const [lotFilter, setLotFilter] = useState("all");
  const [query, setQuery] = useState(() => searchParams.get("q") ?? "");
  const [page, setPage] = useState(1);
  const [detailPayment, setDetailPayment] = useState<Payment | null>(null);

  const lotScopedPayments = useMemo(
    () =>
      lotFilter === "all"
        ? data.payments
        : data.payments.filter((p) => p.lotId === lotFilter),
    [data.payments, lotFilter],
  );

  const lotScopedBookings = useMemo(
    () =>
      lotFilter === "all"
        ? data.bookings
        : data.bookings.filter((b) => b.lotId === lotFilter),
    [data.bookings, lotFilter],
  );

  const { paid, prevPaid, periodLabel } = useMemo(() => {
    const day7Start = shiftLocalDate(today, -6);
    const prev7Start = shiftLocalDate(today, -13);
    const prev7End = shiftLocalDate(today, -7);
    const yesterday = shiftLocalDate(today, -1);
    const prevYm = shiftYearMonth(month, -1);
    const sixMonthStart = shiftYearMonth(currentYm, -5);

    if (period === "today") {
      return {
        paid: lotScopedPayments.filter((p) => localDate(p.paidAt) === today),
        prevPaid: lotScopedPayments.filter(
          (p) => localDate(p.paidAt) === yesterday,
        ),
        periodLabel: `Hôm nay (${formatShortDateVi(today)})`,
      };
    }
    if (period === "7days") {
      return {
        paid: lotScopedPayments.filter((p) => {
          const d = localDate(p.paidAt);
          return d >= day7Start && d <= today;
        }),
        prevPaid: lotScopedPayments.filter((p) => {
          const d = localDate(p.paidAt);
          return d >= prev7Start && d <= prev7End;
        }),
        periodLabel: `7 ngày (${formatShortDateVi(day7Start)} – ${formatShortDateVi(today)})`,
      };
    }
    if (period === "month") {
      return {
        paid: lotScopedPayments.filter((p) =>
          localDate(p.paidAt).startsWith(month),
        ),
        prevPaid: lotScopedPayments.filter((p) =>
          localDate(p.paidAt).startsWith(prevYm),
        ),
        periodLabel: formatMonthVi(month),
      };
    }
    if (period === "6months") {
      return {
        paid: lotScopedPayments.filter(
          (p) => localDate(p.paidAt).slice(0, 7) >= sixMonthStart,
        ),
        prevPaid: null,
        periodLabel: `6 tháng gần nhất (${formatMonthVi(sixMonthStart)} – ${formatMonthVi(currentYm)})`,
      };
    }
    return {
      paid: lotScopedPayments,
      prevPaid: null,
      periodLabel: "Toàn bộ thời gian",
    };
  }, [currentYm, lotScopedPayments, month, period, today]);

  const revenue = paid.reduce((sum, p) => sum + p.amount, 0);
  const prevRevenue = prevPaid
    ? prevPaid.reduce((sum, p) => sum + p.amount, 0)
    : null;
  const avgTicket = paid.length ? Math.round(revenue / paid.length) : 0;

  let deltaText = periodLabel;
  let deltaPositive = revenue > 0;
  if (prevRevenue !== null) {
    if (prevRevenue > 0) {
      const pct = Math.round(((revenue - prevRevenue) / prevRevenue) * 100);
      deltaText = `${pct >= 0 ? "+" : ""}${pct}% so với kỳ trước`;
      deltaPositive = pct >= 0;
    } else if (revenue > 0) {
      deltaText = "Phát sinh mới (kỳ trước 0đ)";
      deltaPositive = true;
    } else {
      deltaText = `${periodLabel} · Kỳ trước 0đ`;
      deltaPositive = false;
    }
  }

  const activeParked = lotScopedBookings.filter(
    (b) => b.status === "Đang sử dụng",
  );
  const confirmedBookings = lotScopedBookings.filter(
    (b) => b.status === "Đã xác nhận",
  );
  const activeEstimatedValue = activeParked.reduce((sum, b) => {
    if (b.prepaid) return sum;
    const startMs = b.checkedIn
      ? new Date(b.checkedIn).getTime()
      : new Date(b.startsAt).getTime();
    const elapsedMin = Number.isNaN(startMs)
      ? 0
      : Math.max(1, Math.ceil((Date.now() - startMs) / 60000));
    return (
      sum +
      Math.max(
        b.amount,
        estimateParkingFee(elapsedMin, b.hourlyRate, b.freeMinutes),
      )
    );
  }, 0);

  const chartPoints: ChartPoint[] = useMemo(() => {
    if (period === "today") {
      return Array.from({ length: 12 }, (_, idx) => {
        const hStart = idx * 2;
        const hEnd = hStart + 2;
        const items = paid.filter((p) => {
          const hr = new Date(p.paidAt).getHours();
          return hr >= hStart && hr < hEnd;
        });
        return {
          label: `${pad(hStart)}h`,
          fullLabel: `${pad(hStart)}:00 – ${pad(hEnd)}:00 hôm nay`,
          value: items.reduce((s, p) => s + p.amount, 0),
          detail: `${items.length} giao dịch`,
          count: items.length,
        };
      });
    }

    if (period === "7days") {
      return Array.from({ length: 7 }, (_, idx) => {
        const ymd = shiftLocalDate(today, idx - 6);
        const items = paid.filter((p) => localDate(p.paidAt) === ymd);
        return {
          label: formatShortDateVi(ymd),
          fullLabel: `Ngày ${formatShortDateVi(ymd)}/${ymd.slice(0, 4)}`,
          value: items.reduce((s, p) => s + p.amount, 0),
          detail: `${items.length} lượt thu`,
          count: items.length,
        };
      });
    }

    if (period === "month") {
      const yearNum = Number(month.slice(0, 4));
      const monthNum = Number(month.slice(5, 7));
      const daysInMonth =
        yearNum && monthNum ? new Date(yearNum, monthNum, 0).getDate() : 30;
      return Array.from({ length: daysInMonth }, (_, idx) => {
        const dayNum = idx + 1;
        const ymd = `${month}-${pad(dayNum)}`;
        const items = paid.filter((p) => localDate(p.paidAt) === ymd);
        return {
          label: String(dayNum),
          fullLabel: `Ngày ${pad(dayNum)}/${pad(monthNum)}/${yearNum}`,
          value: items.reduce((s, p) => s + p.amount, 0),
          detail: `${items.length} lượt thu`,
          count: items.length,
        };
      });
    }

    if (period === "6months") {
      return Array.from({ length: 6 }, (_, idx) => {
        const ym = shiftYearMonth(currentYm, idx - 5);
        const items = paid.filter((p) => localDate(p.paidAt).startsWith(ym));
        return {
          label: `${ym.slice(5, 7)}/${ym.slice(2, 4)}`,
          fullLabel: formatMonthVi(ym),
          value: items.reduce((s, p) => s + p.amount, 0),
          detail: `${items.length} giao dịch`,
          count: items.length,
        };
      });
    }

    // "all": show chronological months covering existing data (at least last 6 months up to currentYm)
    const monthSet = new Set<string>();
    for (let i = 5; i >= 0; i--) monthSet.add(shiftYearMonth(currentYm, -i));
    for (const p of paid) {
      const ym = localDate(p.paidAt).slice(0, 7);
      if (ym) monthSet.add(ym);
    }
    const sortedMonths = [...monthSet].sort().slice(-12);
    return sortedMonths.map((ym) => {
      const items = paid.filter((p) => localDate(p.paidAt).startsWith(ym));
      return {
        label: `${ym.slice(5, 7)}/${ym.slice(2, 4)}`,
        fullLabel: formatMonthVi(ym),
        value: items.reduce((s, p) => s + p.amount, 0),
        detail: `${items.length} giao dịch`,
        count: items.length,
      };
    });
  }, [currentYm, month, paid, period, today]);

  const peakPoint = useMemo(
    () =>
      chartPoints.reduce<ChartPoint | null>(
        (best, p) =>
          p.value > 0 && (!best || p.value > best.value) ? p : best,
        null,
      ),
    [chartPoints],
  );

  const carPayments = paid.filter((p) => p.vehicleKind === "car");
  const motoPayments = paid.filter((p) => p.vehicleKind === "motorcycle");
  const carRevenue = carPayments.reduce((s, p) => s + p.amount, 0);
  const motoRevenue = motoPayments.reduce((s, p) => s + p.amount, 0);
  const carPct = revenue > 0 ? Math.max(0, Math.min(100, Math.round((carRevenue / revenue) * 100))) : 0;
  const motoPct = revenue > 0 ? Math.max(0, Math.min(100, Math.round((motoRevenue / revenue) * 100))) : 0;
  const unknownPayments = paid.filter((p) => p.vehicleKind === "unknown");

  const collectorSummary = useMemo(() => {
    const map = new Map<
      string,
      { name: string; count: number; amount: number }
    >();
    for (const p of paid) {
      const key = p.receivedBy || "unknown";
      const cur = map.get(key) ?? {
        name: p.receivedByName || "Nhân viên bãi",
        count: 0,
        amount: 0,
      };
      cur.count += 1;
      cur.amount += p.amount;
      map.set(key, cur);
    }
    return [...map.values()].sort((a, b) => b.amount - a.amount).slice(0, 3);
  }, [paid]);

  const allPaymentsRevenue = data.payments.reduce((s, p) => s + p.amount, 0);
  const ranking = useMemo(() => {
    // Use period-matched payments across all lots for ranking comparison
    const day7Start = shiftLocalDate(today, -6);
    const sixMonthStart = shiftYearMonth(currentYm, -5);
    const periodAllLots = data.payments.filter((p) => {
      const d = localDate(p.paidAt);
      if (period === "today") return d === today;
      if (period === "7days") return d >= day7Start && d <= today;
      if (period === "month") return d.startsWith(month);
      if (period === "6months") return d.slice(0, 7) >= sixMonthStart;
      return true;
    });
    const periodTotal = periodAllLots.reduce((s, p) => s + p.amount, 0);
    return data.lots
      .map((l) => {
        const items = periodAllLots.filter((p) => p.lotId === l.id);
        const val = items.reduce((s, p) => s + p.amount, 0);
        const share =
          periodTotal > 0 ? Math.round((val / periodTotal) * 100) : 0;
        return {
          id: l.id,
          label: l.name,
          area: l.area,
          value: val,
          count: items.length,
          share,
          occupied: l.occupied,
          capacity: l.capacity,
          enabled: l.enabled,
        };
      })
      .sort((a, b) => b.value - a.value);
  }, [currentYm, data.lots, data.payments, month, period, today]);

  const normalizedQuery = query.toLocaleLowerCase("vi").trim();
  const filteredPaid = useMemo(() => {
    if (!normalizedQuery) return paid;
    return paid.filter((p) =>
      `${p.id} ${p.bookingId} ${p.plate} ${p.customerName} ${p.lotName} ${p.receivedByName}`
        .toLocaleLowerCase("vi")
        .includes(normalizedQuery),
    );
  }, [normalizedQuery, paid]);

  const pageSize = 6;
  const totalPages = Math.max(1, Math.ceil(filteredPaid.length / pageSize));
  const safePage = Math.min(page, totalPages);
  const pagePayments = filteredPaid.slice(
    (safePage - 1) * pageSize,
    safePage * pageSize,
  );

  const latestScopedPayment = lotScopedPayments[0] ?? data.payments[0];
  const latestPaymentMonth = latestScopedPayment
    ? localDate(latestScopedPayment.paidAt).slice(0, 7)
    : "";

  const handleExport = () => {
    if (!filteredPaid.length) {
      notice("Không có giao dịch nào trong bộ lọc hiện tại để xuất CSV.");
      return;
    }
    const suffix =
      period === "month" ? month : period === "today" ? today : period;
    exportCsv(
      `smartpark-doanh-thu-${suffix}.csv`,
      [
        "Mã thanh toán",
        "Mã vé",
        "Bãi đỗ",
        "Khách hàng",
        "Biển số",
        "Loại xe",
        "Check-in",
        "Check-out",
        "Thời lượng",
        "Nhân viên thu",
        "Phương thức",
        "Ngày thanh toán",
        "Số tiền (VND)",
      ],
      filteredPaid.map((p) => [
        p.id,
        p.bookingId,
        p.lotName,
        p.customerName || "Khách vãng lai",
        p.plate,
        vehicleKindLabel(p.vehicleKind),
        formatDateTime(p.checkedInAt),
        formatDateTime(p.checkedOutAt),
        formatDuration(p.checkedInAt, p.checkedOutAt),
        p.receivedByName || p.receivedBy,
        paymentMethodLabel(p.method),
        formatDateTime(p.paidAt),
        p.amount,
      ]),
    );
    notice(`Đã xuất ${filteredPaid.length} giao dịch ra tệp CSV.`);
  };

  const tabs: { key: PeriodMode; label: string }[] = [
    { key: "today", label: "Hôm nay" },
    { key: "7days", label: "7 ngày" },
    { key: "month", label: "Theo tháng" },
    { key: "6months", label: "6 tháng" },
    { key: "all", label: "Tất cả" },
  ];

  return (
    <>
      <PageHeading
        title="Báo cáo & doanh thu"
        subtitle="Tổng hợp thời gian thực từ khoản thu tiền mặt do nhân viên xác nhận check-out."
        action={
          <div className="heading-action-group">
            <Button secondary disabled={syncing} onClick={() => void refresh()}>
              <UiIcon
                name="refresh"
                size={15}
                className={syncing ? "spin" : ""}
              />
              <span>{syncing ? "Đang đồng bộ..." : "Làm mới"}</span>
            </Button>
            <Button onClick={handleExport}>
              <UiIcon name="download" size={15} />
              <span>Xuất báo cáo</span>
            </Button>
          </div>
        }
      />

      <Panel className="report-toolbar">
        <div className="segmented-tabs" role="tablist" aria-label="Kỳ báo cáo">
          {tabs.map((tab) => (
            <button
              type="button"
              role="tab"
              aria-selected={period === tab.key}
              key={tab.key}
              className={period === tab.key ? "tab-btn active" : "tab-btn"}
              onClick={() => {
                setPeriod(tab.key);
                setPage(1);
              }}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="report-filters">
          {period === "month" && (
            <div className="month-stepper">
              <button
                type="button"
                className="step-btn"
                aria-label="Tháng trước"
                onClick={() => {
                  setMonth((m) => shiftYearMonth(m, -1));
                  setPage(1);
                }}
              >
                <UiIcon name="chevron-left" size={16} />
              </button>
              <label className="month-input-wrap">
                <span className="sr-only">Tháng báo cáo</span>
                <input
                  aria-label="Tháng báo cáo"
                  type="month"
                  value={month}
                  onChange={(e) => {
                    if (e.target.value) {
                      setMonth(e.target.value);
                      setPage(1);
                    }
                  }}
                />
              </label>
              <button
                type="button"
                className="step-btn"
                aria-label="Tháng sau"
                onClick={() => {
                  setMonth((m) => shiftYearMonth(m, 1));
                  setPage(1);
                }}
              >
                <UiIcon name="chevron-right" size={16} />
              </button>
            </div>
          )}

          <label className="select-pill">
            <UiIcon name="lot" size={15} />
            <select
              aria-label="Lọc theo bãi đỗ"
              value={lotFilter}
              onChange={(e) => {
                setLotFilter(e.target.value);
                setPage(1);
              }}
            >
              <option value="all">Tất cả bãi đỗ ({data.lots.length})</option>
              {data.lots.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.name}
                </option>
              ))}
            </select>
          </label>
        </div>
      </Panel>

      {paid.length === 0 && (
        <div className="report-guidance-banner" role="status">
          <div className="guidance-text">
            <UiIcon name="alert" size={18} />
            <div>
              <strong>
                Chưa có khoản thu nào trong {periodLabel.toLowerCase()}
              </strong>
              <p>
                {latestScopedPayment
                  ? `Giao dịch gần nhất được ghi nhận ngày ${formatDateTime(latestScopedPayment.paidAt)} (${money(latestScopedPayment.amount)}). `
                  : "Doanh thu sẽ tự động đồng bộ ngay khi nhân viên thu tiền và check-out trên ứng dụng Staff. "}
                {activeParked.length > 0 || confirmedBookings.length > 0
                  ? `Hiện có ${activeParked.length} xe đang đỗ và ${confirmedBookings.length} vé chờ vào bãi.`
                  : ""}
              </p>
            </div>
          </div>
          <div className="guidance-actions">
            {latestPaymentMonth &&
              (period !== "month" || month !== latestPaymentMonth) && (
                <Button
                  secondary
                  onClick={() => {
                    setPeriod("month");
                    setMonth(latestPaymentMonth);
                    setPage(1);
                  }}
                >
                  Xem tháng {latestPaymentMonth.slice(5, 7)}/
                  {latestPaymentMonth.slice(0, 4)}
                </Button>
              )}
            {period !== "all" && data.payments.length > 0 && (
              <Button
                secondary
                onClick={() => {
                  setPeriod("all");
                  setLotFilter("all");
                  setPage(1);
                }}
              >
                Xem tất cả ({money(allPaymentsRevenue)})
              </Button>
            )}
          </div>
        </div>
      )}

      <div className="metrics four">
        <Metric
          label={period === "month" ? "Doanh thu tháng" : "Tổng doanh thu kỳ"}
          value={money(revenue)}
          detail={deltaText}
          icon="IconChart1"
          tone="green"
          positive={deltaPositive}
        />
        <Metric
          label="Lượt đã thanh toán"
          value={paid.length}
          detail={
            paid.length
              ? `Ô tô: ${carPayments.length} · Xe máy: ${motoPayments.length}`
              : "Mỗi vé tối đa một khoản thu"
          }
          icon="IconTicket1"
          tone="blue"
        />
        <Metric
          label="Trung bình / lượt"
          value={money(avgTicket)}
          detail={
            peakPoint
              ? `Cao điểm: ${peakPoint.label} (${compactMoney(peakPoint.value)})`
              : "Thanh toán tiền mặt tại bãi"
          }
          icon="IconCredit"
          tone="purple"
        />
        <Metric
          label="Phiên đang hoạt động"
          value={`${activeParked.length} đỗ · ${confirmedBookings.length} chờ`}
          detail={
            activeParked.length > 0
              ? `Chưa thu (vé cũ): ${money(activeEstimatedValue)}`
              : "Chờ khách check-in / check-out"
          }
          uiIcon="clock"
          tone="amber"
        />
      </div>

      <div className="report-charts">
        <Panel className="revenue-panel">
          <div className="panel-head-inline">
            <div>
              <h2>
                {period === "today"
                  ? "Doanh thu theo khung giờ"
                  : period === "6months" || period === "all"
                    ? "Doanh thu theo tháng"
                    : "Doanh thu theo ngày"}
              </h2>
              <p className="panel-sub">{periodLabel}</p>
            </div>
            {peakPoint && (
              <Badge tone="green">
                Đỉnh: {peakPoint.label} · {money(peakPoint.value)}
              </Badge>
            )}
          </div>
          <LiveBars
            points={chartPoints}
            formatValue={(v) => money(v)}
            ariaLabel={`Biểu đồ doanh thu ${periodLabel}`}
            emptyMessage={`Chưa phát sinh khoản thu nào trong ${periodLabel.toLowerCase()}.`}
            emptyAction={
              latestPaymentMonth &&
              (period !== "month" || month !== latestPaymentMonth) ? (
                <Button
                  secondary
                  onClick={() => {
                    setPeriod("month");
                    setMonth(latestPaymentMonth);
                    setPage(1);
                  }}
                >
                  Chuyển sang tháng {latestPaymentMonth.slice(5, 7)}/
                  {latestPaymentMonth.slice(0, 4)}
                </Button>
              ) : undefined
            }
          />
        </Panel>

        <Panel className="payment-panel">
          <div className="panel-head-inline">
            <div>
              <h2>Phương thức & loại xe</h2>
              <p className="panel-sub">Cơ cấu khoản thu đã xác nhận</p>
            </div>
            <Badge tone="blue">Đã trừ hoàn tiền</Badge>
          </div>

          <div className="method-highlight">
            <div className="method-row-top">
              <span className="method-name">
                <Asset name="LegendDot" />
                <strong>Tổng thu sau hoàn tiền</strong>
              </span>
              <strong>{money(revenue)}</strong>
            </div>
            <p>
              {paid.length} giao dịch đã xác nhận · tiền mặt, QR và số dư gửi xe.
            </p>
            {(["cash", "qr", "wallet", "wallet_refund"] as const).map((method) => {
              const total = paid.filter((p) => p.method === method).reduce((sum, p) => sum + p.amount, 0);
              return total !== 0 ? <div className="breakdown-head" key={method}>
                <span>{paymentMethodLabel(method)}</span><strong>{money(total)}</strong>
              </div> : null;
            })}
          </div>

          <div className="vehicle-breakdown">
            <div className="breakdown-item">
              <div className="breakdown-head">
                <span className="breakdown-label">
                  <UiIcon name="car" size={16} />
                  <span>
                    Ô tô ({carPayments.length} lượt · {carPct}%)
                  </span>
                </span>
                <strong>{money(carRevenue)}</strong>
              </div>
              <Progress value={carPct} tone="blue" />
            </div>

            <div className="breakdown-item">
              <div className="breakdown-head">
                <span className="breakdown-label">
                  <UiIcon name="motorcycle" size={16} />
                  <span>
                    Xe máy ({motoPayments.length} lượt · {motoPct}%)
                  </span>
                </span>
                <strong>{money(motoRevenue)}</strong>
              </div>
              <Progress value={motoPct} tone="green" />
            </div>
          </div>

          {unknownPayments.length > 0 && (
            <p className="panel-sub">
              Chưa xác định loại xe: {unknownPayments.length} lượt ·{" "}
              {money(unknownPayments.reduce((sum, p) => sum + p.amount, 0))}.
              Khoản thu vẫn được cộng vào tổng doanh thu.
            </p>
          )}
          {collectorSummary.length > 0 && (
            <div className="collector-list">
              <span className="collector-title">Nhân viên thu gần đây</span>
              {collectorSummary.map((c) => (
                <div className="collector-row" key={c.name}>
                  <span>
                    {c.name} ({c.count} vé)
                  </span>
                  <strong>{money(c.amount)}</strong>
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>

      <Panel className="ranking-panel">
        <div className="panel-head-inline">
          <div>
            <h2>Doanh thu theo bãi</h2>
            <p className="panel-sub">
              Nhấn vào từng bãi để lọc nhanh biểu đồ và lịch sử giao dịch
            </p>
          </div>
          {lotFilter !== "all" && (
            <Button
              secondary
              onClick={() => {
                setLotFilter("all");
                setPage(1);
              }}
            >
              Bỏ lọc bãi
            </Button>
          )}
        </div>

        {ranking.length ? (
          <div className="ranking-grid">
            {ranking.map((l, i) => {
              const selected = lotFilter === l.id;
              return (
                <button
                  type="button"
                  key={l.id}
                  className={`rank-card ${selected ? "selected" : ""}`}
                  onClick={() => {
                    setLotFilter(selected ? "all" : l.id);
                    setPage(1);
                  }}
                >
                  <div className="rank-card-top">
                    <b>#{i + 1}</b>
                    <Badge tone={l.enabled ? "green" : "gray"}>
                      {l.enabled
                        ? `${l.occupied}/${l.capacity} xe`
                        : "Tạm khóa"}
                    </Badge>
                  </div>
                  <strong>{l.label}</strong>
                  <small className="rank-area">{l.area}</small>
                  <div className="rank-money-row">
                    <span className="rank-amount">{money(l.value)}</span>
                    <small>
                      {l.count} lượt · {l.share}%
                    </small>
                  </div>
                  <Progress value={l.share} tone={i === 0 ? "green" : "blue"} />
                </button>
              );
            })}
          </div>
        ) : (
          <Empty
            message="Chưa có bãi đỗ."
            hint="Thêm bãi đỗ ở mục Quản lý bãi đỗ để theo dõi doanh thu."
          />
        )}
      </Panel>

      <Panel className="ledger-panel">
        <div className="table-heading">
          <div>
            <h2>Lịch sử thu tiền & đối soát</h2>
            <p className="panel-sub">
              {filteredPaid.length} giao dịch đã hoàn tất trong{" "}
              {periodLabel.toLowerCase()}
            </p>
          </div>
          <div className="table-controls">
            <SearchField
              icon="IconSearch"
              value={query}
              onChange={(v) => {
                setQuery(v);
                setPage(1);
              }}
              placeholder="Tìm biển số, khách hàng, người thu..."
            />
          </div>
        </div>

        {pagePayments.length ? (
          <>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>THỜI GIAN THU</th>
                    <th>BÃI ĐỖ</th>
                    <th>BIỂN SỐ / XE</th>
                    <th>KHÁCH HÀNG</th>
                    <th>NHÂN VIÊN THU</th>
                    <th>SỐ TIỀN</th>
                    <th>BIÊN LAI</th>
                  </tr>
                </thead>
                <tbody>
                  {pagePayments.map((p) => (
                    <tr key={p.id}>
                      <td>
                        <strong>{formatTime(p.paidAt)}</strong>
                        <small className="cell-sub">
                          {formatDateTime(p.paidAt).split(" ")[0]}
                        </small>
                      </td>
                      <td>{p.lotName || "Bãi đỗ"}</td>
                      <td>
                        <span className="plate">{p.plate || "—"}</span>
                        <small className="cell-sub">
                          {vehicleKindLabel(p.vehicleKind)} ·{" "}
                          {formatDuration(p.checkedInAt, p.checkedOutAt)}
                        </small>
                      </td>
                      <td>{p.customerName || "Khách đặt chỗ"}</td>
                      <td>
                        <span>{p.receivedByName || "Nhân viên"}</span>
                        <small className="cell-sub">{paymentMethodLabel(p.method)}</small>
                      </td>
                      <td>
                        <strong className="money-positive">
                          {money(p.amount)}
                        </strong>
                      </td>
                      <td>
                        <button
                          type="button"
                          className="link"
                          onClick={() => setDetailPayment(p)}
                        >
                          Chi tiết
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pagination
              page={safePage}
              count={filteredPaid.length}
              pageSize={pageSize}
              onChange={setPage}
              noun="giao dịch"
            />
          </>
        ) : (
          <Empty
            message="Không có giao dịch nào phù hợp."
            hint={
              normalizedQuery
                ? "Thử xóa từ khóa tìm kiếm hoặc chọn kỳ báo cáo rộng hơn."
                : "Các khoản thu sẽ tự động hiển thị sau khi nhân viên xác nhận check-out."
            }
          />
        )}
      </Panel>

      {detailPayment && (
        <Dialog
          title="Chi tiết biên lai thu tiền"
          onClose={() => setDetailPayment(null)}
          footer={<Button onClick={() => setDetailPayment(null)}>Đóng</Button>}
        >
          <dl className="receipt-dl">
            <div>
              <dt>Mã giao dịch</dt>
              <dd className="mono">{detailPayment.id}</dd>
            </div>
            <div>
              <dt>Mã vé đặt chỗ</dt>
              <dd className="mono">{detailPayment.bookingId}</dd>
            </div>
            <div>
              <dt>Bãi đỗ</dt>
              <dd>{detailPayment.lotName}</dd>
            </div>
            <div>
              <dt>Khách hàng</dt>
              <dd>{detailPayment.customerName || "Khách SmartPark"}</dd>
            </div>
            <div>
              <dt>Biển số & loại xe</dt>
              <dd>
                {detailPayment.plate} ·{" "}
                {vehicleKindLabel(detailPayment.vehicleKind)}
              </dd>
            </div>
            <div>
              <dt>Giờ vào (Check-in)</dt>
              <dd>{formatDateTime(detailPayment.checkedInAt)}</dd>
            </div>
            <div>
              <dt>Giờ ra (Check-out)</dt>
              <dd>{formatDateTime(detailPayment.checkedOutAt)}</dd>
            </div>
            <div>
              <dt>Thời gian gửi</dt>
              <dd>
                {formatDuration(
                  detailPayment.checkedInAt,
                  detailPayment.checkedOutAt,
                )}
              </dd>
            </div>
            <div>
              <dt>Đơn giá vé đã chốt</dt>
              <dd>
                {money(detailPayment.hourlyRate)}/giờ (miễn phí{" "}
                {detailPayment.freeMinutes} phút)
              </dd>
            </div>
            <div>
              <dt>Người xác nhận giao dịch</dt>
              <dd>
                {detailPayment.receivedByName || detailPayment.receivedBy}
              </dd>
            </div>
            <div>
              <dt>Thời điểm thanh toán</dt>
              <dd>{formatDateTime(detailPayment.paidAt)}</dd>
            </div>
            <div className="receipt-total-row">
              <dt>{paymentMethodLabel(detailPayment.method)}</dt>
              <dd>{money(detailPayment.amount)}</dd>
            </div>
          </dl>
        </Dialog>
      )}
    </>
  );
}

export function SettingsPage() {
  const { data } = useAdmin();
  const [selected, setSelected] = useState("");
  const lot = data.lots.find((l) => l.id === selected) ?? data.lots[0];

  if (!lot)
    return (
      <>
        <PageHeading
          title="Cài đặt & giá vé"
          subtitle="Tạo bãi đỗ trước khi cấu hình giá."
        />
        <Empty
          message="Chưa có bãi đỗ."
          hint="Vào Quản lý bãi đỗ để thêm bãi đầu tiên."
        />
      </>
    );

  const initial: Pricing = data.pricing[lot.id] ?? {
    car: 0,
    motorcycle: 0,
    freeMinutes: 0,
    version: 0,
  };

  return (
    <>
      <PageHeading
        title="Cài đặt & giá vé"
        subtitle="Giá mới đồng bộ tức thời sang ứng dụng Khách hàng; vé đã đặt trước giữ nguyên đơn giá đã chốt."
      />

      <div className="lot-select">
        <span className="lot-select-label">
          <Asset name="IconBuilding1" />
          <span>Bãi đỗ áp dụng giá vé</span>
        </span>
        <div className="select-wrap">
          <select
            aria-label="Bãi đỗ áp dụng giá vé"
            value={lot.id}
            onChange={(e) => setSelected(e.target.value)}
          >
            {data.lots.map((l) => (
              <option value={l.id} key={l.id}>
                {l.name} — {l.area}
              </option>
            ))}
          </select>
          <Asset name="IconDown" />
        </div>
      </div>

      <PricingEditor
        key={`${lot.id}:${initial.version}`}
        id={lot.id}
        lotName={lot.name}
        initial={initial}
      />

      <Panel className="security-panel">
        <div className="panel-head-inline">
          <div>
            <h2>Bảo mật & đồng bộ hệ thống</h2>
            <p className="panel-sub">
              Quy tắc thực thi trực tiếp trên Supabase Cloud cho cả Web Admin,
              App Khách hàng và App Nhân viên
            </p>
          </div>
        </div>
        <div className="security-grid">
          <div className="security-card">
            <span className="security-icon">
              <Asset name="IconShield" />
            </span>
            <div>
              <h3>Phân quyền Row-Level Security</h3>
              <p>
                Chỉ tài khoản Chủ bãi sở hữu mới có quyền chỉnh giá vé, khóa bãi
                hoặc cấp quyền nhân viên. Nhân viên chỉ thao tác trên bãi được
                phân công.
              </p>
            </div>
          </div>
          <div className="security-card">
            <span className="security-icon">
              <Asset name="IconRefresh" />
            </span>
            <div>
              <h3>Kiểm soát phiên bản (v{initial.version})</h3>
              <p>
                Mỗi lần cập nhật bảng giá kiểm tra phiên bản đồng thời để tránh
                ghi đè dữ liệu từ thiết bị khác và đồng bộ Realtime xuống ứng
                dụng Khách hàng.
              </p>
            </div>
          </div>
        </div>
      </Panel>
    </>
  );
}

function PricingEditor({
  id,
  lotName,
  initial,
}: {
  id: string;
  lotName: string;
  initial: Pricing;
}) {
  const { command, notice } = useAdmin();
  const [draft, setDraft] = useState(initial);
  const [busy, setBusy] = useState(false);

  const fields = [
    ["car", "Phí ô tô / giờ", "VND / giờ", 10000000],
    ["motorcycle", "Phí xe máy / giờ", "VND / giờ", 10000000],
  ] as const;

  const isDirty =
    draft.car !== initial.car || draft.motorcycle !== initial.motorcycle;

  const car2h = estimateParkingFee(120, draft.car, draft.freeMinutes);
  const moto2h = estimateParkingFee(120, draft.motorcycle, draft.freeMinutes);

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
          p_free_minutes: 0,
          p_expected_version: initial.version,
        });
        setBusy(false);
        if (ok) notice("Đã lưu bảng giá trên Supabase.");
      }}
    >
      <Panel className="pricing-panel">
        <div className="panel-head-inline">
          <div>
            <h2>Cấu hình giá vé · {lotName}</h2>
            <p className="panel-sub">Đơn vị tính tiền: Đồng Việt Nam (VND)</p>
          </div>
          <Badge tone={isDirty ? "amber" : "blue"}>
            {isDirty ? "Chưa lưu thay đổi" : `Phiên bản v${initial.version}`}
          </Badge>
        </div>

        <div className="price-fields">
          {fields.map(([key, label, unit, max]) => (
            <label key={key}>
              {label}
              <span>
                <input
                  aria-label={label}
                  type="number"
                  required
                  min={0}
                  max={max}
                  step={1}
                  value={draft[key]}
                  onChange={(e) =>
                    setDraft({ ...draft, [key]: Number(e.target.value) })
                  }
                />
                <em>{unit}</em>
              </span>
            </label>
          ))}
        </div>

        <div className="info-note">
          <Asset name="IconInfo" />
          <div>
            <strong>
              Ước tính gửi 2 giờ: Ô tô {money(car2h)} · Xe máy {money(moto2h)}
            </strong>
            <p>
              Thu từ phút đầu, tối thiểu 1 giờ; các giờ tiếp theo làm tròn lên.
              Chỉ ghi doanh thu sau khi nhân viên xác nhận đã thu tiền và xe ra.
            </p>
          </div>
        </div>

        <div className="form-actions">
          <Button disabled={busy}>
            {busy ? "Đang lưu..." : "Lưu thay đổi"}
          </Button>
          {isDirty && (
            <Button
              type="button"
              secondary
              disabled={busy}
              onClick={() => setDraft(initial)}
            >
              Khôi phục gốc
            </Button>
          )}
        </div>
      </Panel>

      <Panel className="rules-panel">
        <h2>Quy tắc vận hành</h2>
        <div className="rule">
          <div>
            <strong>Đặt trước cần máy chủ xác nhận</strong>
            <p>
              Vé chỉ được phát hành khi Supabase xác nhận còn chỗ trống khả dụng
              trong khung giờ khách chọn.
            </p>
          </div>
          <Asset name="SwitchChoPhepDtTrc" />
        </div>
        <div className="rule">
          <div>
            <strong>Check-out & thu tiền mặt tại cổng</strong>
            <p>
              Nhân viên nhận diện và xác nhận biển số trên app Staff, hệ thống
              chốt phí theo thời gian gửi thực tế và tạo phiếu thu ngay.
            </p>
          </div>
          <Badge tone="green">Bắt buộc</Badge>
        </div>
        <div className="rule compact">
          <div>
            <strong>Giá vé theo từng bãi riêng biệt</strong>
            <p>
              Thay đổi tại đây áp dụng ngay cho các đặt chỗ mới của{" "}
              <b>{lotName}</b>, không làm thay đổi giá các vé đã đặt trước đó.
            </p>
          </div>
          <Badge tone="green">Đang bật</Badge>
        </div>
      </Panel>
    </form>
  );
}
