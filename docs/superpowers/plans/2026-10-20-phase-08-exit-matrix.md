# Phase 08 completion acceptance matrix

Authority: `docs/development-phases.md` Phase 08 exit criteria and `docs/design.md` §§2/4. The owner requested completing the phase, not redefining its exit as ledger-only transport/convergence. This matrix records required engine assertions separately from later feature UI and cross-platform release reruns. Read-only source audit: scratch report `kasaran-phase08-exit-map.md` dated 2026-10-20.

## Engine acceptance

| Requirement | Current status | Required evidence |
|---|---|---|
| TC-API-01…04,06…08 | Transport/auth/order baseline passes; server payload validation remains structural ledger/schema1 | Semantic full-create/group/field validation, derived-field refusal and full supported entity acceptance |
| TC-SE-43, TC-OF-23, TC-API-02/06 | Server ordering and explicit encrypted inbox pass scoped review/live evidence; full-entity matrix remains open | Atomic entire raw page + per-device cursor, rollback/reopen/unknown rows, bounded limit-one no-skip proof |
| TC-OF-12/15/18, TC-API-03 | Reviewed explicit push/worker core and live initial bootstrap-ledger convergence pass; automatic production wiring missing | Automatic durable two-device push/pull, restart/retry/no duplicate monetary sums |
| TC-SE-20/21/24/25/27/28/29/33/38/39 | Ledger reducer and encrypted atomic rebuild reviewed; child/entity expansion missing | Authoritative key sort, provisional overlays, stale conflicts, create/child gates, tombstone suppression/Restore and attribution |
| TC-SE-30/34/35/36/37 | Pure financial engine/fixtures reviewed; fee-component group and persisted entity integration missing | Both full groups, invariant-safe dependent totals, no repair writes, no persisted computed totals |
| TC-SE-44, TC-OF-24/25, TC-MIG-04/05 | Encrypted v2-to-v3 inbox upgrade and ledger rebuild reviewed; complete entity/native upgrade matrix remains open | Old unknown events + queued writes retained, transactional upgrade/rebuild/swap and separately injected rollback |
| TC-SEC-01/02/04/05, TC-PL-47/48/49 | Ledger/log/session isolation passes; pair unsupported/refused | All-entity RLS, local/server indivisible sponsor payment+receipt, pair-safe queue bounds and pull staging at limit1 |
| Runtime triggers / supporting TC-OF-14 | Scheduling core reviewed; installed production lifecycle/connectivity/writer wiring missing | Foreground/reconnect/local-write debounce, serialized bounded worker, stale-account stop and safe status |

## Missing data prerequisites included in completion work

Existing schema contains plan/access facts, ledger, log, sync state and outbox only. Implement these required source-data foundations rather than claiming unsupported financial pairs converge:

- [ ] Plan financial settings writer/replay.
- [x] Authorized explicit initial metadata bootstrap into a fresh second encrypted device; reviewed client/backend and actual Edge-ledger convergence.
- [ ] `guests`, `crew_headcount`, `hidden_fee_prompts`, `plan_allocations`, `checklist_items`.
- [ ] `fee_components`, `payment_schedule_items` with same-plan parent constraints and tombstone/Restore gates.
- [ ] `pledges`, `payments`, `pledge_receipts` together with unique reciprocal sponsor-direct pair integrity.
- [ ] `gifts_received` and correction/tombstone semantics.
- [ ] Matching local/server numbered migrations, forced RLS, repositories/writers/codecs, semantic validation and expanded tenant tests.
- [x] Pure input-only financial calculations and independent documented FIX-A…E oracles; persisted adapters and all-entity convergence remain separate.
- [ ] Pair-aware acceptance, outbound batching and inbound staging before either half contributes to projections/totals.

No new benchmark prices, verified legal/church fees or offsets may be invented. Missing pinned assets/unknown dependencies must produce unavailable/needs-attention, not zero totals.

## Decisions and evidence boundaries

No unresolved product choice blocks local synthetic LWW, groups, tombstones or pair semantics: existing ADRs decide those. Concrete implementation contracts must still be reviewed. OQ-07 blocks hosted/real-user processing, not these local tests. OQ-01/03 block legal erasure/force-wipe claims, not sync.

Phase 07 native source/publication protections remain enforced. Signed iOS protection/sidecars, canonical native paths, crash-durable publication and any actual required migration/device evidence cannot be inferred from Android compilation. Later phase16/17 UI assertions and phase19 complete cross-platform reruns remain explicitly deferred by the canonical phase index; they are not marked passed. Full Phase 08 engine completion requires the applicable engine rows above to execute, not merely broader prose or generic in-memory tests.
