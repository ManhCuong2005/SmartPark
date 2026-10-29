abstract final class SupabaseConfig {
  // Both values are public client configuration, never privileged credentials.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://odpxmbkzdqutxitsdfaw.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_FW7A4HEtGwng-PPHQVZzsg_6WQx6Zd0',
  );
}
