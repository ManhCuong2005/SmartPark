import { createClient } from "@supabase/supabase-js";
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL ??
    "https://odpxmbkzdqutxitsdfaw.supabase.co",
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ??
    "sb_publishable_FW7A4HEtGwng-PPHQVZzsg_6WQx6Zd0",
);
