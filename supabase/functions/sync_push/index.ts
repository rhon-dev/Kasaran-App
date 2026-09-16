// supabase/functions/sync_push/index.ts
//
// POST /v1/sync/push
//
// Phase 04 stub — authenticates the caller, validates the request envelope,
// and returns an empty accepted list. No rows are written to the database yet
// (change_log table does not exist until phase 07/08). server_ts assignment
// and idempotency (TC-API-03) are implemented in phase 08.
//
// Request  (design.md §2.4):
//   POST /sync/push
//   Authorization: Bearer <jwt>
//   Content-Type: application/json
//   { "plan_id": "<uuid>", "rows": [ChangeLogRow, ...] }
//
// Response (phase 04 stub):
//   200 OK  { "accepted": [], "server_ts_high": null }
//
// Error responses:
//   401 — missing/invalid token
//   400 — malformed body (invalid JSON, missing fields, wrong types)
//   405 — non-POST method

import { requireAuth } from '../_shared/auth.ts';
import { validatePushBody } from '../_shared/validation.ts';

Deno.serve(async (req: Request) => {
  // Only POST is accepted.
  if (req.method !== 'POST') {
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

  // Parse and validate the request body.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Request body must be valid JSON' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const validationError = validatePushBody(body);
  if (validationError) {
    return new Response(
      JSON.stringify({ error: validationError }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // Phase 04 stub: no rows written, empty accepted list, no server_ts yet.
  // Phase 08 implements: insert-ignore on change_log, assign server_ts,
  // return accepted with server_ts per row (TC-API-03).
  return new Response(
    JSON.stringify({
      accepted: [],
      server_ts_high: null,
      // Stub marker — removed when phase 08 implements real behaviour.
      _stub: 'phase-04: no rows written; server_ts assignment in phase-08',
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
