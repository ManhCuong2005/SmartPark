import { PayOS } from "npm:@payos/node@2";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Cache-Control": "no-store",
};

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: cors });
}

type Topup = {
  order_code: number;
  customer_id: string;
  amount: number;
  expires_at: string;
  payment_link_id: string | null;
  checkout_url: string | null;
  paid_at: string | null;
  booking_kind: string | null;
  booking_payload: Record<string, unknown> | null;
  booking_operation_id: string | null;
  booking_result: Record<string, unknown> | null;
  booking_error: string | null;
};

Deno.serve(async (request) => {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method === "GET") {
    return new Response(
      "Quay lại SmartPark và chọn Kiểm tra giao dịch để xem kết quả nạp tiền.",
      { headers: { ...cors, "Content-Type": "text/plain; charset=utf-8" } },
    );
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const clientId = Deno.env.get("PAYOS_CLIENT_ID");
  const apiKey = Deno.env.get("PAYOS_API_KEY");
  const checksumKey = Deno.env.get("PAYOS_CHECKSUM_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!clientId || !apiKey || !checksumKey || !supabaseUrl || !serviceRole) {
    return json({ error: "payments_not_configured" }, 503);
  }

  const payos = new PayOS({ clientId, apiKey, checksumKey });
  const db = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Verify the current provider state before crediting. This also handles a
  // late/missed webhook when the customer checks the order from the app.
  async function reconcile(order: Topup) {
    if (order.paid_at) return "PAID";
    if (!order.payment_link_id) return "PENDING";
    const link = await payos.paymentRequests.get(order.payment_link_id);
    if (link.id !== order.payment_link_id || link.orderCode !== order.order_code ||
        link.amount !== order.amount) throw new Error("Payment link mismatch");
    if (link.status !== "PAID") return link.status;
    if (link.amountPaid !== order.amount || link.amountRemaining !== 0) {
      throw new Error("Payment amount needs review");
    }
    const { error } = await db.rpc("settle_payos_topup", {
      p_order_code: order.order_code,
      p_payment_link_id: order.payment_link_id,
      p_amount: order.amount,
    });
    if (error) throw error;
    return "PAID";
  }

  let body;
  try {
    body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return json({ error: "invalid_request" }, 400);
    }
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  try {
    if (url.searchParams.get("webhook") === "1") {
      let event;
      try {
        event = await payos.webhooks.verify(body);
      } catch {
        return json({ error: "invalid_signature" }, 401);
      }
      if (!Number.isSafeInteger(event.orderCode) || typeof event.paymentLinkId !== "string") {
        return json({ error: "invalid_event" }, 400);
      }
      const { data, error } = await db.from("wallet_topups").select("*")
        .eq("order_code", event.orderCode).maybeSingle<Topup>();
      if (error) throw error;
      // payOS sends a signed sample when registering the webhook.
      if (!data || data.payment_link_id !== event.paymentLinkId ||
          event.currency !== "VND" || event.code !== "00") return json({ received: true });
      await reconcile(data);
      return json({ received: true });
    }

    const token = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)?.[1];
    if (!token) return json({ error: "sign_in_required" }, 401);
    const { data: { user }, error: authError } = await db.auth.getUser(token);
    if (authError || !user) return json({ error: "sign_in_required" }, 401);

    if (body.action === "check") {
      if (!Number.isSafeInteger(body.orderCode)) return json({ error: "invalid_order" }, 400);
      const { data, error } = await db.from("wallet_topups").select("*")
        .eq("order_code", body.orderCode).eq("customer_id", user.id).maybeSingle<Topup>();
      if (error) throw error;
      if (!data) return json({ error: "not_found" }, 404);
      const status = await reconcile(data);
      const { data: settled, error: readError } = await db.from("wallet_topups")
        .select("booking_result,booking_error").eq("order_code", data.order_code).single();
      if (readError) throw readError;
      return json({ status, booking: settled.booking_result, bookingError: settled.booking_error });
    }

    let amount = body.amount;
    let bookingFields: Record<string, unknown> = {};
    let existing: Topup | null = null;
    if (body.action === "create_booking") {
      if (typeof body.operationId !== "string" ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.operationId) ||
          !["booking.pay", "booking.extend.pay"].includes(body.kind) ||
          !body.payload || typeof body.payload !== "object" || Array.isArray(body.payload)) {
        return json({ error: "invalid_request" }, 400);
      }
      const { data, error } = await db.from("wallet_topups").select("*")
        .eq("customer_id", user.id).eq("booking_operation_id", body.operationId).maybeSingle<Topup>();
      if (error) throw error;
      existing = data;
      if (existing) {
        const saved = existing.booking_payload ?? {};
        if (existing.booking_kind !== body.kind || Object.keys(saved).length !== Object.keys(body.payload).length ||
            !Object.entries(saved).every(([key, value]) => body.payload[key] === value)) {
          return json({ error: "OPERATION_ID_REUSED" }, 409);
        }
        if (existing.checkout_url) return json({ checkoutUrl: existing.checkout_url, orderCode: existing.order_code });
        amount = existing.amount;
      } else {
        // Quote under the customer's JWT; amounts and ownership stay server-side.
        const scoped = createClient(supabaseUrl, serviceRole, {
          global: { headers: { Authorization: `Bearer ${token}` } },
          auth: { persistSession: false, autoRefreshToken: false },
        });
        const { data: quote, error: quoteError } = await scoped.rpc("booking_payment_quote", {
          p_kind: body.kind, p_payload: body.payload,
        });
        if (quoteError) return json({ error: quoteError.code === "PGRST202"
          ? "BOOKING_PAYMENT_SCHEMA_REQUIRED"
          : quoteError.code === "P0001" ? quoteError.message : quoteError.code }, 409);
        amount = quote.amount;
        if (amount !== body.payload.expected_amount) return json({ error: "PRICE_CHANGED" }, 409);
      }
      bookingFields = {
        booking_kind: body.kind, booking_payload: body.payload, booking_operation_id: body.operationId,
      };
    } else if (body.action !== "create") {
      return json({ error: "invalid_request" }, 400);
    }
    if (!Number.isSafeInteger(amount) || amount < 2000 || amount > 5000000) {
      if (body.action === "create_booking") return json({ error: "QR_AMOUNT_UNSUPPORTED" }, 400);
      return json({ error: "invalid_amount" }, 400);
    }
    const returnUrl = Deno.env.get("PAYOS_RETURN_URL") ??
      `${supabaseUrl}/functions/v1/payos-topup`;
    let order = existing;
    if (!order) {
      const { data, error } = await db.from("wallet_topups")
        .insert({ customer_id: user.id, amount, ...bookingFields }).select().single<Topup>();
      if (error || !data) throw error ?? new Error("Missing order");
      order = data;
    }

    const link = await payos.paymentRequests.create({
      orderCode: order.order_code,
      amount: order.amount,
      description: body.action === "create_booking" ? "THANH TOAN VE" : "NAP TIEN",
      returnUrl,
      cancelUrl: returnUrl,
      expiredAt: Math.floor(Date.parse(order.expires_at) / 1000),
    });
    if (link.orderCode !== order.order_code || link.amount !== order.amount ||
        link.currency !== "VND" || !link.paymentLinkId ||
        new URL(link.checkoutUrl).origin !== "https://pay.payos.vn") {
      throw new Error("Invalid checkout link");
    }
    const { error: saveError } = await db.from("wallet_topups").update({
      payment_link_id: link.paymentLinkId,
      checkout_url: link.checkoutUrl,
    }).eq("order_code", order.order_code);
    if (saveError) throw saveError;
    return json({ checkoutUrl: link.checkoutUrl, orderCode: order.order_code }, 201);
  } catch (error) {
    // Provider error bodies can contain payment details. Log only a class name.
    console.error("payos-topup failed", error instanceof Error ? error.name : "database_error");
    return json({ error: "payment_service_error" }, 502);
  }
});
