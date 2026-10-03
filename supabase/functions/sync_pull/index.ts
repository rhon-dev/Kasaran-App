// supabase/functions/sync_pull/index.ts
//
// GET /v1/sync/pull?plan_id=<uuid>&since_server_ts=<bigint>&limit=<n>
//
// Phase 04 stub — authenticates the caller, validates query parameters,
// and returns an empty row set. No rows exist yet (change_log table and
// RLS policies are implemented in phases 07/08).
//
// Phase-04-only legacy GET envelope (not design.md §2.4's future
// versioned POST /sync/pull cursor contract):
//   GET /sync/pull?plan_id=<uuid>&since_server_ts=<int>&limit=<n>
//   Authorization: Bearer <jwt>
//
// Response (phase 04 stub):
//   200 OK  { "rows": [], "next_cursor": null, "has_more": false }
//   limit defaults to 100; explicit values must be integers in [1, 1000].
//
// Error responses:
//   401 — missing/invalid token
//   400 — missing/invalid query parameters
//   405 — non-GET method

import { requireAuth } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  // Only GET is accepted.
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: `Method ${req.method} not allowed` }),
      { status: 405, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // Auth gate — throws a 401 Response on failure.
  try {
    await requireAuth(req);
  } catch (e) {
    if (e instanceof Response) return e;
    throw e;
  }

  // Validate query parameters.
  const url = new URL(req.url);
  const planId = url.searchParams.get('plan_id');
  const sinceServerTs = url.searchParams.get('since_server_ts');
  const limits = url.searchParams.getAll('limit');

  if (!planId) {
    return new Response(
      JSON.stringify({ error: 'Missing required query parameter: plan_id' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // plan_id must be a UUID.
  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(planId)) {
    return new Response(
      JSON.stringify({ error: 'plan_id must be a valid UUID' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  if (sinceServerTs === null) {
    return new Response(
      JSON.stringify({
        error: 'Missing required query parameter: since_server_ts',
      }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // since_server_ts must be a non-negative integer string.
  if (!/^\d+$/.test(sinceServerTs)) {
    return new Response(
      JSON.stringify({
        error: 'since_server_ts must be a non-negative integer',
      }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // Keep the phase-04 endpoint's paging contract bounded even before rows exist.
  const limitText = limits[0];
  const limit = limitText === undefined ? 100 : Number(limitText);
  if (limits.length > 1 || (limitText !== undefined && !/^\d+$/.test(limitText)) ||
    !Number.isSafeInteger(limit) || limit < 1 || limit > 1000) {
    return new Response(
      JSON.stringify({ error: 'limit must be an integer between 1 and 1000' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // Phase 04 stub: no rows returned, cursor null, has_more false.
  // Phase 08 implements: query change_log WHERE server_ts > since_server_ts
  // ORDER BY server_ts, paged by limit, returning rows with server_ts values.
  return new Response(
    JSON.stringify({
      rows: [],
      next_cursor: null,
      has_more: false,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
