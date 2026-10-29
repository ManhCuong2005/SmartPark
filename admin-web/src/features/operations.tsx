import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Panel,
  PageHeading,
  Badge,
  Button,
  Dialog,
  Empty,
  SearchField,
} from "../components/ui";
import { useAdmin, exportCsv } from "../data/store";
import { money, shifts } from "../data/models";
import type { Booking, Staff } from "../data/models";

export function BookingsPage() {
  const { data, command, notice } = useAdmin(),
    [params] = useSearchParams(),
    [query, setQuery] = useState(params.get("q") ?? ""),
    [status, setStatus] = useState(""),
    [date, setDate] = useState(""),
    [detail, setDetail] = useState<Booking | null>(null),
    [busy, setBusy] = useState(false);
  const rows = data.bookings.filter(
    (b) =>
      (b.id + " " + b.customer + " " + b.plate)
        .toLowerCase()
        .includes(query.toLowerCase()) &&
      (!status || b.status === status) &&
      (!date || b.date === date),
  );
  return (
    <>
      <PageHeading
        title="Quản lý đặt chỗ"
        subtitle="Vé khách hàng, phương tiện và trạng thái từ máy chủ."
        action={
          <Button
            secondary
            onClick={() =>
              exportCsv(
                "smartpark-dat-cho.csv",
                [
                  "Mã vé",
                  "Khách",
                  "Biển số",
                  "Bãi",
                  "Ngày",
                  "Trạng thái",
                  "Đã thu",
                ],
                rows.map((b) => [
                  b.id,
                  b.customer,
                  b.plate,
                  data.lots.find((l) => l.id === b.lotId)?.name ?? "",
                  b.date,
                  b.status,
                  b.amount,
                ]),
              )
            }
          >
            Xuất CSV
          </Button>
        }
      />
      <Panel>
        <div className="live-filters">
          <SearchField
            value={query}
            onChange={setQuery}
            placeholder="Tìm mã vé, khách hoặc biển số"
          />
          <select
            aria-label="Trạng thái vé"
            value={status}
            onChange={(e) => setStatus(e.target.value)}
          >
            <option value="">Tất cả trạng thái</option>
            {["Đã xác nhận", "Đang sử dụng", "Hoàn thành", "Đã hủy"].map(
              (s) => (
                <option key={s}>{s}</option>
              ),
            )}
          </select>
          <input
            type="date"
            aria-label="Ngày đặt chỗ"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
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
                <th />
              </tr>
            </thead>
            <tbody>
              {rows.map((b) => (
                <tr key={b.id}>
                  <td>{b.id.slice(0, 8)}</td>
                  <td>{b.customer}</td>
                  <td>{b.plate}</td>
                  <td>{data.lots.find((l) => l.id === b.lotId)?.name}</td>
                  <td>
                    {b.date}
                    <br />
                    {b.start}–{b.end}
                  </td>
                  <td>
                    <Badge>{b.status}</Badge>
                  </td>
                  <td>{money(b.amount)}</td>
                  <td>
                    <Button secondary onClick={() => setDetail(b)}>
                      Chi tiết
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <Empty message="Chưa có đặt chỗ phù hợp." />}
        </div>
      </Panel>
      <Panel>
        <h2>Phương tiện đã sử dụng bãi</h2>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>TÊN PHƯƠNG TIỆN</th>
                <th>BIỂN SỐ</th>
                <th>LOẠI</th>
              </tr>
            </thead>
            <tbody>
              {data.vehicles.map((v) => (
                <tr key={String(v.id)}>
                  <td>{String(v.label)}</td>
                  <td>{String(v.plate)}</td>
                  <td>{v.kind === "car" ? "Ô tô" : "Xe máy"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          Khách quản lý biển số trong ứng dụng. Nhân viên kiểm tra biển số thực
          tế khi xe vào/ra.
        </p>
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
          <dl className="details">
            <dt>Mã vé</dt>
            <dd>{detail.id}</dd>
            <dt>Khách hàng</dt>
            <dd>{detail.customer}</dd>
            <dt>Biển số</dt>
            <dd>{detail.plate}</dd>
            <dt>Trạng thái</dt>
            <dd>{detail.status}</dd>
            <dt>Đã thu</dt>
            <dd>{money(detail.amount)}</dd>
          </dl>
        </Dialog>
      )}
    </>
  );
}
export function StaffPage() {
  const { data } = useAdmin(),
    [query, setQuery] = useState(""),
    [editor, setEditor] = useState<Staff | null | undefined>();
  const rows = data.staff.filter((s) =>
    (s.name + " " + s.email).toLowerCase().includes(query.toLowerCase()),
  );
  return (
    <>
      <PageHeading
        title="Quản lý nhân viên"
        subtitle="Cấp quyền theo bãi. Nhân viên phải đăng ký tài khoản trước."
        action={
          <Button disabled={!data.lots.length} onClick={() => setEditor(null)}>
            + Phân công nhân viên
          </Button>
        }
      />
      <Panel>
        <SearchField
          value={query}
          onChange={setQuery}
          placeholder="Tìm nhân viên"
        />
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>NHÂN VIÊN</th>
                <th>EMAIL</th>
                <th>BÃI ĐỖ</th>
                <th>CA</th>
                <th>QUYỀN TRUY CẬP</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {rows.map((s) => (
                <tr key={s.id}>
                  <td>{s.name}</td>
                  <td>{s.email}</td>
                  <td>{data.lots.find((l) => l.id === s.lotId)?.name}</td>
                  <td>{shifts[s.shift]}</td>
                  <td>
                    <Badge>{s.active ? "Hoạt động" : "Tạm ngưng"}</Badge>
                  </td>
                  <td>
                    <Button secondary onClick={() => setEditor(s)}>
                      Phân công
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <Empty message="Chưa có nhân viên phù hợp." />}
        </div>
      </Panel>
      {editor !== undefined && (
        <StaffEditor staff={editor} onClose={() => setEditor(undefined)} />
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
  const { data, command, notice } = useAdmin(),
    [email, setEmail] = useState(staff?.email ?? ""),
    [lot, setLot] = useState(staff?.lotId ?? data.lots[0]?.id ?? ""),
    [shift, setShift] = useState(staff?.shift ?? "morning"),
    [active, setActive] = useState(staff?.active ?? true),
    [busy, setBusy] = useState(false);
  return (
    <Dialog
      title="Phân công nhân viên"
      onClose={onClose}
      footer={
        <>
          <Button secondary onClick={onClose}>
            Hủy
          </Button>
          <Button disabled={busy || !lot} form="staff-editor">
            Lưu phân công
          </Button>
        </>
      }
    >
      <form
        id="staff-editor"
        className="live-form"
        onSubmit={async (e) => {
          e.preventDefault();
          setBusy(true);
          const ok = await command("manage_staff", {
            p_lot_id: lot,
            p_email: email.trim(),
            p_shift: shift,
            p_active: active,
          });
          setBusy(false);
          if (ok) {
            notice("Đã cập nhật quyền nhân viên trên máy chủ.");
            onClose();
          }
        }}
      >
        <label>
          Email đã đăng ký
          <input
            aria-label="Email nhân viên"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            readOnly={!!staff}
          />
        </label>
        <label>
          Bãi đỗ
          <select
            aria-label="Bãi phân công"
            value={lot}
            onChange={(e) => setLot(e.target.value)}
            disabled={!!staff}
          >
            {data.lots.map((l) => (
              <option value={l.id} key={l.id}>
                {l.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Ca làm việc
          <select
            value={shift}
            onChange={(e) => setShift(e.target.value as Staff["shift"])}
          >
            {Object.entries(shifts).map(([key, label]) => (
              <option value={key} key={key}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label>
          <input
            type="checkbox"
            checked={active}
            onChange={(e) => setActive(e.target.checked)}
          />{" "}
          Cấp quyền truy cập bãi
        </label>
        <p>
          Tên và email lấy từ tài khoản thật. Thu hồi quyền tại đây sẽ ngăn các
          thao tác tiếp theo trên máy chủ, kể cả thao tác offline gửi lên sau
          đó.
        </p>
      </form>
    </Dialog>
  );
}
