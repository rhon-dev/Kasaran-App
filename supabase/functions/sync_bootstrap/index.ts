// No third-party dependency: never parse/re-encode financial request/response JSON.
const headers = { 'Content-Type': 'application/json' };
const error = (status: number, code: string) =>
  new Response(JSON.stringify({ error: code }), { status, headers });

Deno.serve(async (request: Request): Promise<Response> => {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return error(401, 'authentication_required');
    if (request.method !== 'POST') return error(405, 'method_not_allowed');
    // Bound bytes while streaming, not after an unbounded allocation.
    const reader = request.body?.getReader();
    if (!reader) return error(400, 'invalid_json');
    let size = 0;
    const chunks: Uint8Array[] = [];
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 1048576) { await reader.cancel(); return error(413, 'payload_too_large'); }
        chunks.push(value);
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      const payloadText = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
      const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/sync_bootstrap_v1`, {
        method: 'POST',
        headers: {
          Authorization: authorization,
          apikey: Deno.env.get('SUPABASE_ANON_KEY') ?? '',
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        // Only encode the text wrapper. Numeric JSON tokens remain untouched inside.
        body: JSON.stringify({ payload_text: payloadText }),
        signal: AbortSignal.timeout(15000),
      });
      if (response.ok) {
        // PostgREST wraps a returns-text scalar in a JSON string. Decode only
        // that outer string; the financial JSON inside is NEVER parsed.
        const wrapped = await response.text();
        if (!wrapped.trimStart().startsWith('"')) return error(503, 'service_unavailable');
        const serialized: unknown = JSON.parse(wrapped);
        if (typeof serialized !== 'string') return error(503, 'service_unavailable');
        return new Response(serialized, { status: 200, headers });
      }
      if (response.status === 426) return new Response(
        '{"error":"unsupported_protocol","min_supported_build":1}', { status: 426, headers });
      // Do not disclose Postgres detail, original events, IDs or internal diagnostics.
      const status = [400, 401, 403, 409].includes(response.status) ? response.status : 503;
      const code = status === 403 ? 'plan_unavailable' : status === 401 ? 'authentication_required'
        : status === 409 ? 'event_conflict' : status === 400 ? 'invalid_request' : 'service_unavailable';
      return error(status, code);
    } catch {
      return error(503, 'service_unavailable');
    }
});
