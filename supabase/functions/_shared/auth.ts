// supabase/functions/_shared/auth.ts
//
// Shared auth helper for sync Edge Functions.
// Extracts and verifies the caller's JWT from the Authorization header.
// Returns the authenticated user record or throws a 401 response.

import { createClient } from 'jsr:@supabase/supabase-js@2';

export interface AuthedUser {
  id: string;
  email: string | undefined;
}

/**
 * Extracts the bearer token from the request, verifies it against Supabase
 * Auth, and returns the authenticated user.
 *
 * Throws a Response with HTTP 401 if:
 *   - No Authorization header is present.
 *   - The token is malformed or expired.
 *   - Supabase Auth cannot verify the token.
 */
export async function requireAuth(req: Request): Promise<AuthedUser> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Response(
      JSON.stringify({ error: 'Missing or invalid Authorization header' }),
      {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  const token = authHeader.slice('Bearer '.length);

  // Use the anon client with the caller's token so RLS applies at the DB level.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: `Bearer ${token}` } } },
  );

  const { data: { user }, error } = await supabase.auth.getUser();

  if (error || !user) {
    throw new Response(
      JSON.stringify({ error: 'Invalid or expired token' }),
      {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  return { id: user.id, email: user.email };
}
