type Env = Record<string, string | undefined>;
type Transport = typeof fetch;
type Job = {
  id: string;
  lease_id: string;
  notification_id: string;
  user_id: string;
  title: string;
  body: string;
  token: string;
  category: string | null;
  booking_id: string | null;
  ends_at: string | null;
};
type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};
const encoder = new TextEncoder();
const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
const encoded = (value: unknown) =>
  base64url(encoder.encode(JSON.stringify(value)));

async function secretMatches(input: string, expected: string) {
  const [a, b] = await Promise.all(
    [input, expected].map(
      async (value) =>
        new Uint8Array(
          await crypto.subtle.digest("SHA-256", encoder.encode(value)),
        ),
    ),
  );
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

/** Dependency-injected HTTP worker: tested against local failure simulations.
 * Device tokens, service-account credentials and service-role keys never leave
 * the worker in logs or responses. Delivery is at least once; FCM's stable tag
 * collapses a retry when the send succeeded but the database ACK was lost.
 */
export function createPushHandler(
  env: Env,
  transport: Transport = fetch,
  now = Date.now,
) {
  let access: { token: string; expires: number } | undefined;
  const request = (url: string, init: RequestInit) =>
    transport(url, {
      ...init,
      signal: AbortSignal.timeout(12000),
    });
  async function googleToken(account: ServiceAccount) {
    if (access && access.expires > now() + 60000) return access.token;
    const time = Math.floor(now() / 1000);
    const unsigned = `${encoded({ alg: "RS256", typ: "JWT" })}.${encoded({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: time,
      exp: time + 3600,
    })}`;
    const pem = account.private_key
      .replace(/-----[^-]+-----/g, "")
      .replace(/\s/g, "");
    const key = await crypto.subtle.importKey(
      "pkcs8",
      Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const signature = new Uint8Array(
      await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        encoder.encode(unsigned),
      ),
    );
    const response = await request("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${unsigned}.${base64url(signature)}`,
      }),
    });
    if (!response.ok) throw new Error("FCM_AUTH_UNAVAILABLE");
    const result = await response.json();
    if (typeof result.access_token !== "string")
      throw new Error("FCM_AUTH_UNAVAILABLE");
    access = {
      token: result.access_token,
      expires: now() + Math.min(Number(result.expires_in) || 3600, 3600) * 1000,
    };
    return access.token;
  }
  async function rpc(name: string, body: unknown) {
    const response = await request(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.SUPABASE_SERVICE_ROLE_KEY!,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify(body),
    });
    if (!response.ok) throw new Error("DATABASE_UNAVAILABLE");
    const content = await response.text();
    return content ? JSON.parse(content) : null;
  }
  return async (incoming: Request): Promise<Response> => {
    if (incoming.method !== "POST")
      return new Response("Method not allowed", { status: 405 });
    const secret = env.PUSH_DISPATCH_SECRET;
    if (
      !secret ||
      secret.length < 32 ||
      !(await secretMatches(
        incoming.headers.get("x-smartpark-dispatch-secret") ?? "",
        secret,
      ))
    ) {
      return new Response("Unauthorized", { status: 401 });
    }
    try {
      if (
        !env.SUPABASE_URL ||
        !env.SUPABASE_SERVICE_ROLE_KEY ||
        !env.FCM_SERVICE_ACCOUNT_JSON
      ) {
        return new Response("Push configuration incomplete", { status: 503 });
      }
      const account = JSON.parse(
        env.FCM_SERVICE_ACCOUNT_JSON,
      ) as ServiceAccount;
      if (
        typeof account.project_id !== "string" ||
        !/^[a-z][a-z0-9-]+$/.test(account.project_id) ||
        typeof account.client_email !== "string" ||
        !account.client_email ||
        typeof account.private_key !== "string" ||
        !account.private_key
      ) {
        return new Response("Push configuration incomplete", { status: 503 });
      }
        if (env.FCM_PROJECT_ID && account.project_id !== env.FCM_PROJECT_ID) {
          return new Response("Firebase project mismatch", { status: 503 });
        }
      const bearer = await googleToken(account);
      const jobs: Job[] = await rpc("claim_push_jobs", { p_limit: 20 });
      const totals = { sent: 0, retry: 0, failed: 0, ackPending: 0 };
      async function send(job: Job) {
        let result = "retry",
          error: string | null = null;
        try {
          const seconds =
            job.category === "pickup_soon" && job.ends_at
              ? Math.max(
                  1,
                  Math.min(
                    3600,
                    Math.floor((Date.parse(job.ends_at) - now()) / 1000),
                  ),
                )
              : 3600;
          const response = await request(
            `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${bearer}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                message: {
                  token: job.token,
                  notification: { title: job.title, body: job.body },
                  data: {
                    notification_id: job.notification_id,
                    user_id: job.user_id,
                    booking_id: job.booking_id ?? "",
                    category: job.category ?? "",
                  },
                  android: {
                    priority: "high",
                    ttl: `${seconds}s`,
                    notification: {
                      channel_id: "smartpark_parking",
                      icon: "ic_notification",
                      tag: job.notification_id,
                    },
                  },
                },
              }),
            },
          );
          if (response.ok) result = "sent";
          else {
            const details = await response.json().catch(() => ({}));
            const unregistered = details.error?.details?.some(
              (d: { errorCode?: string }) => d.errorCode === "UNREGISTERED",
            );
            result = unregistered
              ? "invalid_token"
              : [400, 404].includes(response.status)
                ? "permanent"
                : "retry";
            error = unregistered
              ? "UNREGISTERED"
              : `FCM_HTTP_${response.status}`;
            if (response.status === 401) access = undefined;
          }
        } catch (_) {
          error = "FCM_NETWORK_UNAVAILABLE";
        }
        try {
          await rpc("finish_push_job", {
            p_id: job.id,
            p_lease_id: job.lease_id,
            p_result: result,
            p_error: error,
          });
          if (result === "sent") totals.sent++;
          else if (result === "retry") totals.retry++;
          else totals.failed++;
        } catch (_) {
          totals.ackPending++;
        } // Lease expiry safely recovers it.
      }
      for (let i = 0; i < jobs.length; i += 5)
        await Promise.all(jobs.slice(i, i + 5).map(send));
      return Response.json(totals);
    } catch (_) {
      return new Response("Push worker temporarily unavailable", {
        status: 503,
      });
    }
  };
}
