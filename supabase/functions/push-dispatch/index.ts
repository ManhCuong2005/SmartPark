import { createPushHandler } from "./core.ts";

// Automatic Supabase server environment + two user-configured secrets.
// No service-role credential is included in Flutter, Vite or repository files.
Deno.serve(
  createPushHandler({
    SUPABASE_URL: Deno.env.get("SUPABASE_URL"),
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    FCM_SERVICE_ACCOUNT_JSON: Deno.env.get("FCM_SERVICE_ACCOUNT_JSON"),
    FCM_PROJECT_ID: Deno.env.get("FCM_PROJECT_ID") ?? "smartpark-606ea",
    PUSH_DISPATCH_SECRET: Deno.env.get("PUSH_DISPATCH_SECRET"),
  }),
);
