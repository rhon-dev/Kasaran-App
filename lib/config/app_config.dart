// lib/config/app_config.dart
//
// Build-time environment configuration.
//
// Values are injected via --dart-define at build/run time. The defaults here
// are the local Supabase CLI values so `flutter run` works against
// `supabase start` without extra flags.
//
// deployment-plan §2.5 — SEC-26:
//   SUPABASE_SERVICE_ROLE_KEY is intentionally absent from this file.
//   It belongs only in CI secrets and backend jobs, never in a client build.
//   Any search of the compiled .aab or .ipa for "service_role" must return
//   zero matches (verified by the build-android CI step).
//
// Usage:
//   flutter run  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
//                --dart-define=SUPABASE_ANON_KEY=<key>           \
//                --dart-define=ENV=local
//
//   flutter build appbundle \
//                --dart-define=SUPABASE_URL=https://kasaran-staging.supabase.co \
//                --dart-define=SUPABASE_ANON_KEY=<staging-key>   \
//                --dart-define=ENV=staging

// ignore_for_file: do_not_use_environment
// Rationale: String.fromEnvironment is the only supported mechanism for
// --dart-define injection. This file is the single authorised location for
// environment reads in the client codebase.

/// Supabase project URL for the current build environment.
/// Defaults to the local Supabase CLI dev server.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);

/// Supabase anon (public) key. Safe to embed in a client build — has no
/// privileges beyond what RLS and Auth policies allow.
///
/// The default is the deterministic local CLI anon key (public, safe to commit).
/// Never use this default for staging or production.
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
      '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

/// Current environment name: 'local', 'staging', or 'production'.
/// Defaults to 'local' so debug builds never accidentally tag themselves
/// as staging or production in Sentry.
const String appEnvironment = String.fromEnvironment(
  'ENV',
  defaultValue: 'local',
);

/// True when this build targets the local Supabase CLI instance.
bool get isLocalEnv => appEnvironment == 'local';

/// True when this build targets the staging project.
bool get isStagingEnv => appEnvironment == 'staging';

/// True when this build targets production.
bool get isProductionEnv => appEnvironment == 'production';
