import { useCallback, useEffect, useRef, useState } from "react";
import {
  Button,
  Dialog,
  Empty,
  PageHeading,
  Pagination,
  Panel,
  SearchField,
} from "../components/ui";
import { formatDateTime, money } from "../data/models";
import { supabase } from "../data/supabase";
import { useAdmin } from "../data/store";

type Account = {
  id: string;
  email: string;
  name: string;
  role: string;
  balance: number;
};
type Adjustment = {
  id: string;
  customer_email: string;
  actor_email: string;
  amount: number;
  reason: string;
  balance_after: number;
  created_at: string;
};
type Pending = { id: string; account: Account; amount: number; reason: string };
type Editor = {
  account: Account;
  direction: 1 | -1;
  amount: string;
  reason: string;
};

function errorMessage(error: unknown): string {
  const code =
    error && typeof error === "object" && "message" in error
      ? String(error.message)
      : String(error);
  if (code.includes("INSUFFICIENT_BALANCE"))
    return "Số dư hiện tại không đủ để trừ khoản này. Không có tiền nào bị trừ.";
  if (code.includes("INVALID_WALLET_ADJUSTMENT"))
    return "Nhập số tiền nguyên từ 1đ đến 5.000.000đ và lý do từ 3 đến 500 ký tự.";
  if (code.includes("ACCOUNT_NOT_FOUND"))
    return "Tài khoản không còn tồn tại. Hãy tải lại danh sách.";
  if (code.includes("FORBIDDEN"))
    return "Chỉ quản trị viên được phép điều chỉnh số dư.";
  if (code.includes("OPERATION_ID_REUSED"))
    return "Mã giao dịch đã được sử dụng với nội dung khác. Giữ lại mã này để kiểm tra lịch sử.";
  if (code.includes("schema cache") || code.includes("admin_wallet_accounts"))
    return "Backend chưa cập nhật quản lý số dư. Cần chạy migration 015 rồi tải lại.";
  return "Chưa xác nhận được kết quả. Thử lại cùng giao dịch để tránh cộng/trừ lặp.";
}

export function WalletsPage() {
  const { profile, notice, refresh } = useAdmin();
  const actor = String(profile.id);
  const storageKey = `smartpark:wallet-adjustment:${actor}`;
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [history, setHistory] = useState<Adjustment[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [editor, setEditor] = useState<Editor | null>(null);
  const [pending, setPending] = useState<Pending | null>(null);
  const [storageError, setStorageError] = useState(false);
  const sending = useRef(false),
    generation = useRef(0),
    active = useRef(true),
    currentActor = useRef(actor);
  currentActor.current = actor;
  useEffect(() => {
    active.current = true;
    return () => {
      active.current = false;
      generation.current++;
    };
  }, []);

  const load = useCallback(async () => {
    const request = ++generation.current;
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_wallet_accounts", {
        p_query: query.trim(),
        p_offset: (page - 1) * 25,
        p_limit: 25,
      });
      if (error) throw error;
      if (request !== generation.current) return;
      setAccounts(data.accounts ?? []);
      setHistory(data.adjustments ?? []);
      setTotal(Number(data.total ?? 0));
      setError("");
    } catch (error) {
      if (request === generation.current) setError(errorMessage(error));
    } finally {
      if (request === generation.current) setLoading(false);
    }
  }, [query, page]);

  useEffect(() => {
    const timer = setTimeout(() => void load(), 200);
    const focus = () => void load();
    window.addEventListener("focus", focus);
    return () => {
      clearTimeout(timer);
      generation.current++;
      window.removeEventListener("focus", focus);
    };
  }, [load]);
  useEffect(() => {
    try {
      const raw = localStorage.getItem(storageKey);
      if (!raw) return;
      const saved = JSON.parse(raw) as Pending;
      if (
        typeof saved.id !== "string" ||
        typeof saved.account?.id !== "string" ||
        !Number.isSafeInteger(saved.amount) ||
        saved.amount === 0 ||
        Math.abs(saved.amount) > 5000000 ||
        typeof saved.reason !== "string" ||
        saved.reason.trim().length < 3 ||
        saved.reason.length > 500
      )
        throw new Error("Invalid pending adjustment");
      setPending(saved);
      setEditor({
        account: saved.account,
        direction: saved.amount > 0 ? 1 : -1,
        amount: String(Math.abs(saved.amount)),
        reason: saved.reason,
      });
      setError(
        "Có giao dịch chưa xác nhận từ lần trước. Thử lại cùng giao dịch để lấy kết quả.",
      );
    } catch {
      setStorageError(true);
      setError(
        "Không đọc được yêu cầu điều chỉnh đã lưu. Cần kiểm tra bộ nhớ và lịch sử giao dịch trước khi tạo yêu cầu mới.",
      );
    }
  }, [storageKey]);

  async function submit() {
    if (!editor || sending.current || storageError) return;
    const amount = Number(editor.amount),
      reason = editor.reason.trim();
    if (
      !Number.isSafeInteger(amount) ||
      amount < 1 ||
      amount > 5000000 ||
      reason.length < 3 ||
      reason.length > 500
    ) {
      setError(
        "Nhập số tiền nguyên từ 1đ đến 5.000.000đ và lý do từ 3 đến 500 ký tự.",
      );
      return;
    }
    const request: Pending = pending ?? {
      id: crypto.randomUUID(),
      account: editor.account,
      amount: amount * editor.direction,
      reason,
    };
    sending.current = true;
    setBusy(true);
    setError("");
    try {
      // Store before sending; a timeout/reload must use the same operation ID.
      localStorage.setItem(storageKey, JSON.stringify(request));
      setPending(request);
      const { data: auth } = await supabase.auth.getSession();
      if (!active.current || auth.session?.user.id !== actor) return;
      const { data, error } = await supabase.rpc("admin_adjust_wallet", {
        p_operation_id: request.id,
        p_customer_id: request.account.id,
        p_amount: request.amount,
        p_reason: request.reason,
      });
      if (error) {
        if (
          ["P0001", "42501", "22003", "22P02"].includes(error.code) &&
          error.message !== "OPERATION_ID_REUSED"
        ) {
          localStorage.removeItem(storageKey);
          if (active.current && currentActor.current === actor)
            setPending(null);
        }
        throw error;
      }
      localStorage.removeItem(storageKey);
      if (!active.current || currentActor.current !== actor) return;
      setPending(null);
      setEditor(null);
      notice(
        `Đã ${request.amount > 0 ? "cộng" : "trừ"} ${money(Math.abs(request.amount))} cho ${request.account.email}. Số dư: ${money(Number(data.balance_after))}.`,
      );
      await Promise.all([load(), refresh()]);
    } catch (error) {
      if (active.current && currentActor.current === actor)
        setError(errorMessage(error));
    } finally {
      sending.current = false;
      if (active.current && currentActor.current === actor) setBusy(false);
    }
  }

  function open(account: Account, direction: 1 | -1) {
    setError("");
    setEditor({ account, direction, amount: "", reason: "" });
  }
  const amount = editor ? Number(editor.amount) : 0;
  const validAmount =
    Number.isSafeInteger(amount) && amount > 0 && amount <= 5000000;
  const delta = editor ? editor.direction * amount : 0;
  const locked = busy || pending !== null;

  return (
    <>
      <PageHeading
        title="Số dư tài khoản"
        subtitle="Quản trị viên cộng/trừ số dư trực tiếp. Mọi điều chỉnh đều lưu người thực hiện và lý do."
        action={
          <Button
            secondary
            disabled={loading || busy}
            onClick={() => void load()}
          >
            Tải lại số dư
          </Button>
        }
      />
      {!editor && error && (
        <p role="alert" className="wallet-error">
          {error}
        </p>
      )}
      <Panel>
        <div className="panel-heading">
          <h2>Tài khoản ({total})</h2>
          <SearchField
            value={query}
            onChange={(value) => {
              setQuery(value.slice(0, 200));
              setPage(1);
            }}
            placeholder="Tìm tên hoặc email tài khoản"
          />
        </div>
        {loading && <p role="status">Đang tải số dư…</p>}
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>TÀI KHOẢN</th>
                <th>EMAIL</th>
                <th>SỐ DƯ</th>
                <th>ĐIỀU CHỈNH</th>
              </tr>
            </thead>
            <tbody>
              {accounts.map((account) => (
                <tr key={account.id}>
                  <td>
                    <strong>{account.name || "Chưa đặt tên"}</strong>
                    <small>
                      {account.role === "owner"
                        ? "Quản trị viên"
                        : "Khách hàng"}
                    </small>
                  </td>
                  <td>{account.email}</td>
                  <td className="money-cell">
                    {money(Number(account.balance))}
                  </td>
                  <td>
                    <div className="wallet-actions">
                      <Button
                        disabled={busy || loading || !!pending || storageError}
                        onClick={() => open(account, 1)}
                      >
                        Cộng tiền
                      </Button>
                      <Button
                        secondary
                        disabled={busy || loading || !!pending || storageError}
                        onClick={() => open(account, -1)}
                      >
                        Trừ tiền
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!loading && accounts.length === 0 && (
          <Empty
            message="Không tìm thấy tài khoản."
            hint="Thử tên hoặc email khác."
          />
        )}
        <Pagination
          page={page}
          count={total}
          pageSize={25}
          onChange={setPage}
          noun="tài khoản"
        />
      </Panel>
      <Panel className="wallet-history">
        <div className="panel-heading">
          <h2>Lịch sử điều chỉnh thủ công</h2>
          <span>20 giao dịch gần nhất theo bộ lọc</span>
        </div>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>THỜI GIAN</th>
                <th>TÀI KHOẢN</th>
                <th>THAY ĐỔI</th>
                <th>SỐ DƯ SAU</th>
                <th>LÝ DO</th>
                <th>QUẢN TRỊ VIÊN</th>
              </tr>
            </thead>
            <tbody>
              {history.map((item) => (
                <tr key={item.id}>
                  <td>{formatDateTime(item.created_at)}</td>
                  <td>{item.customer_email}</td>
                  <td
                    className={
                      item.amount > 0 ? "wallet-credit" : "wallet-debit"
                    }
                  >
                    {item.amount > 0 ? "+" : "−"}
                    {money(Math.abs(item.amount))}
                  </td>
                  <td>{money(Number(item.balance_after))}</td>
                  <td className="wallet-reason">{item.reason}</td>
                  <td>{item.actor_email}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {history.length === 0 && (
          <Empty
            message="Chưa có điều chỉnh thủ công."
            hint="Tiền nạp qua QR và tiền gửi xe được giữ trong lịch sử giao dịch riêng."
          />
        )}
      </Panel>
      {editor && (
        <Dialog
          title={
            editor.direction > 0 ? "Cộng tiền vào số dư" : "Trừ tiền từ số dư"
          }
          onClose={() => {
            if (!locked) {
              setEditor(null);
              setError("");
            }
          }}
          footer={
            <div className="dialog-action-row">
              <Button
                secondary
                disabled={locked}
                onClick={() => setEditor(null)}
              >
                Hủy
              </Button>
              <Button
                form="wallet-adjustment"
                disabled={
                  busy ||
                  storageError ||
                  !validAmount ||
                  editor.reason.trim().length < 3
                }
              >
                {busy
                  ? "Đang xác nhận…"
                  : pending
                    ? "Thử lại cùng giao dịch"
                    : editor.direction > 0
                      ? "Xác nhận cộng tiền"
                      : "Xác nhận trừ tiền"}
              </Button>
            </div>
          }
        >
          <form
            id="wallet-adjustment"
            className="wallet-form"
            onSubmit={(event) => {
              event.preventDefault();
              void submit();
            }}
          >
            <p>
              <strong>{editor.account.name}</strong>
              <br />
              {editor.account.email}
            </p>
            <p>
              Số dư đang hiển thị:{" "}
              <strong>{money(Number(editor.account.balance))}</strong>
            </p>
            <label>
              Số tiền (đ)
              <input
                type="number"
                inputMode="numeric"
                min={1}
                max={5000000}
                step={1}
                required
                value={editor.amount}
                disabled={locked}
                onChange={(event) =>
                  setEditor({ ...editor, amount: event.target.value })
                }
              />
            </label>
            <label>
              Lý do điều chỉnh
              <textarea
                required
                minLength={3}
                maxLength={500}
                value={editor.reason}
                disabled={locked}
                onChange={(event) =>
                  setEditor({ ...editor, reason: event.target.value })
                }
              />
            </label>
            {validAmount && (
              <p className="wallet-preview">
                {delta > 0 ? "Cộng" : "Trừ"}{" "}
                <strong>{money(Math.abs(delta))}</strong> · Số dư dự kiến:{" "}
                <strong>{money(Number(editor.account.balance) + delta)}</strong>
              </p>
            )}
            <p className="form-hint">
              Máy chủ kiểm tra số dư mới nhất và không cho phép số dư âm. Tối đa
              5.000.000đ mỗi lần.
            </p>
            {pending && (
              <p>
                Mã giao dịch:{" "}
                <code className="wallet-operation">{pending.id}</code>
              </p>
            )}
            {error && (
              <p role="alert" className="wallet-error">
                {error}
              </p>
            )}
          </form>
        </Dialog>
      )}
    </>
  );
}
