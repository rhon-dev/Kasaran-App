// supabase/functions/_shared/validation.ts
//
// Request-body validators for sync endpoints.
// Phase 08 extends these with full ChangeLogRow validation once the schema
// exists; for now they enforce the structural envelope defined in design.md §2.4.

export interface SyncPushBody {
  plan_id: string;
  rows: ChangeLogRow[];
}

export interface SyncPullQuery {
  plan_id: string;
  since_server_ts: string; // numeric string — bigint-safe over JSON
  limit?: string;
}

/**
 * A single change-log row as sent by the client in a push request.
 * Only the structural shape is validated here; field-level semantic validation
 * is added in phase 08 alongside the real change_log table.
 *
 * design.md §2.4 / §4.6
 */
export interface ChangeLogRow {
  id: string;            // UUIDv7 — client-generated idempotency key
  plan_id: string;       // Must match the envelope plan_id
  entity_type: string;
  entity_id: string;
  field_name: string;
  old_value: unknown;    // JSON — nullable
  new_value: unknown;    // JSON — nullable
  device_monotonic: number;
  device_id: string;
  actor_user_id: string;
  created_at: string;    // ISO 8601
  // server_ts intentionally absent from client push — assigned by server (D1)
}

/** Returns true when [s] looks like a UUID (any version). */
function isUuid(s: unknown): s is string {
  if (typeof s !== 'string') return false;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    .test(s);
}

/** Returns true when [s] is a non-empty string. */
function isNonEmptyString(s: unknown): s is string {
  return typeof s === 'string' && s.trim().length > 0;
}

/** Returns true when [n] is a safe non-negative integer. */
function isSafeNonNegativeInt(n: unknown): n is number {
  return typeof n === 'number' && Number.isSafeInteger(n) && n >= 0;
}

/**
 * Validates a sync_push request body.
 * Returns an error message string or null when valid.
 */
export function validatePushBody(body: unknown): string | null {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return 'Request body must be a JSON object';
  }

  const b = body as Record<string, unknown>;

  if (!isUuid(b.plan_id)) {
    return 'plan_id must be a valid UUID';
  }

  if (!Array.isArray(b.rows)) {
    return 'rows must be an array';
  }

  for (let i = 0; i < (b.rows as unknown[]).length; i++) {
    const row = (b.rows as unknown[])[i];
    const rowErr = validateRow(row, b.plan_id as string, i);
    if (rowErr) return rowErr;
  }

  return null;
}

function validateRow(row: unknown, envelopePlanId: string, idx: number): string | null {
  if (typeof row !== 'object' || row === null) {
    return `rows[${idx}] must be an object`;
  }
  const r = row as Record<string, unknown>;

  if (!isUuid(r.id)) return `rows[${idx}].id must be a valid UUID`;
  if (!isUuid(r.plan_id)) return `rows[${idx}].plan_id must be a valid UUID`;
  if (r.plan_id !== envelopePlanId) {
    return `rows[${idx}].plan_id must match envelope plan_id`;
  }
  if (!isNonEmptyString(r.entity_type)) {
    return `rows[${idx}].entity_type must be a non-empty string`;
  }
  if (!isUuid(r.entity_id)) return `rows[${idx}].entity_id must be a valid UUID`;
  if (!isNonEmptyString(r.field_name)) {
    return `rows[${idx}].field_name must be a non-empty string`;
  }
  if (!isSafeNonNegativeInt(r.device_monotonic)) {
    return `rows[${idx}].device_monotonic must be a non-negative safe integer`;
  }
  if (!isUuid(r.device_id)) return `rows[${idx}].device_id must be a valid UUID`;
  if (!isUuid(r.actor_user_id)) {
    return `rows[${idx}].actor_user_id must be a valid UUID`;
  }
  if (!isNonEmptyString(r.created_at)) {
    return `rows[${idx}].created_at must be a non-empty ISO 8601 string`;
  }
  // server_ts must NOT be present in client push — clients never assign ordering.
  if ('server_ts' in r) {
    return `rows[${idx}].server_ts must not be set by the client (D1)`;
  }

  return null;
}
