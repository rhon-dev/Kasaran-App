import { rawSyncHandler } from '../_shared/raw_sync.ts';
Deno.serve(rawSyncHandler('pull'));
