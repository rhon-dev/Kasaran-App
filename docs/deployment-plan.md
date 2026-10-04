# Kasaran — Deployment Plan

*Inputs: [design.md](./design.md), [security-plan.md](./security-plan.md), [testing-plan.md](./testing-plan.md), [decision-log.md](./decision-log.md).*

---

## 0. Precondition check

| Precondition | Status | Source |
|---|---|---|
| Backend / data-store ADR is DECIDED | ✅ **DECIDED** — Supabase (Postgres + Auth + RLS) | ADR-16, 2026-09-13 |
| App name ADR is DECIDED | ✅ **DECIDED** — "Kasaran" | ADR-27, 2026-09-14 (OQ-06 closed) |

Both preconditions are met, so this is a single-option plan for Supabase and the store metadata uses the real name. **No `NAME PENDING` marker is needed.**

### 0.1 Constraints that affect this document

Neither triggers the stop condition, but both change what this plan can promise.

**(a) Technical data region is chosen; legal approval is not.** ADR-72 selects Supabase production `ap-southeast-1` (Singapore). This fixes the infrastructure planning assumption, not the cross-border legal basis, processor review or privacy notice. OQ-07 remains open until DPO/counsel review; SEC-29/30 and the real-data beta gate still block collection. Staging remains synthetic-only.

**(b) Flutter store-release constraint.** ADR-12 selects Flutter for iOS and Android. The first-party Flutter release pipeline does not provide code OTA; Dart release builds are AOT-compiled. **Client code fixes require a store release.** §3.5 describes the available backend and configuration levers, and §8 uses store-review latency rather than promising an instant client hotfix.

**Compounding this:** ADR-15 bundles the allocation ruleset as a **JSON asset inside the app binary**. Combined with no OTA, a wrong baseline percentage or a bad regional modifier cannot be corrected without a full store release on both platforms. Given the reference-cost values are still unpopulated (OQ-04), that is a live operational risk. Mitigation options are in §3.6; changing it requires amending ADR-15, which I am not doing unilaterally.

---

## 1. Environments

| | **Local dev** | **Staging** | **Production** |
|---|---|---|---|
| Backend URL | `http://localhost:54321` (Supabase CLI) | `https://kasaran-staging.supabase.co` *(project ref TBD — created in phase 04)* | **DEFERRED — OQ-07 OPEN** |
| API path | `/v1/sync/*` | `/v1/sync/*` | `/v1/sync/*` |
| Database instance | Local Postgres in Docker, ephemeral | Dedicated Supabase project `ap-southeast-1`, separate from prod | **DEFERRED — OQ-07 OPEN.** Production region = residency decision, irreversible post-creation. |
| Auth tenant | Local Supabase Auth, throwaway users | Staging Auth project — **separate user pool**, no prod identities | **DEFERRED** |
| Seeded data policy | Synthetic inputs for FIX-A…E (testing-plan §3), once implemented as version-controlled test data, loaded on `db reset` | **Synthetic only** — generated from the same five specified fixtures plus a generator for volume | **None.** Real user data only |
| Migrations applied | Automatically on reset | Automatically on merge to `main` | Manually gated (§2.3) |
| Who can access | The maintainer, locally only | Maintainer + any future collaborator; credentials in CI secrets | **Maintainer only.** MFA required (SEC-27) |
| Client build pointed at it | Debug build, `--dart-define=ENV=local` | Internal TestFlight / Play internal track | App Store / Play production |
| Crash reporting | Disabled | Sentry EU organization, `environment=staging`, synthetic-only payloads | Sentry **EU (Frankfurt event storage)** organization, `environment=production`, scrubbed diagnostics; US metadata caveat (§7.2) |

> **Phase 04 descope note (ADR-72/OQ-07):** Staging project creation in `ap-southeast-1` was authorised as a staging-only descope, but its project reference is not yet recorded; authorization does not prove creation. ADR-72 selects Singapore as the intended production region, **not** legal or real-data approval. Production provisioning for real beta remains deferred until OQ-07's DPO/counsel processor, transfer and notice review and the other pre-beta gates pass. See §2.2 and `decision-log.md`.

### 1.1 Production data is never copied to staging

**Stated explicitly and treated as a hard rule.** No production database dump, PITR restore, table export, or single-row copy is ever loaded into staging or a local machine. Production holds names, wedding dates, sponsor identities, guest lists, and financial detail; copying it into a lower environment multiplies the number of places a breach can originate and defeats SEC-22's tenant isolation model, since staging has looser access.

**What staging uses instead:**

1. **The five specified fixtures** (FIX-A NCR, FIX-B Boracay, FIX-C Iloilo, FIX-D money flows and FIX-E civil micro-wedding), once implemented as version-controlled inputs, as the canonical synthetic plans. Their expected values are hand-computed in testing-plan §3; staging must assert against that spec, not generated output. Explicitly applied FIX-C rebalance and FIX-A affordable-guest cases are additional expected results; baseline FIX-A/B/C fixture values do not change (ADR-53/54).
2. **A synthetic volume generator** for load-shaped data: N plans × M ledger entries × K change-log rows, with names drawn from a fixed fake-name list, amounts from plausible ranges, and Ninong/Ninang roles distributed realistically. Deterministic from a seed so bugs reproduce.
3. **Synthetic pairing sets** — pre-paired two-account plans for testing shared editing and removal, including the demo pair used for store review (§5.4).

If a production bug cannot be reproduced from synthetic data, the fix is to **extend the generator**, not to copy production. A production-only bug is investigated via logs (which carry UUIDs only, never content — SEC-28) and by asking the affected user directly.

**Real-data beta (ADR-63):** invited couples use the separately controlled **production** Supabase project and production app configuration, not staging, scratch or local. Create/enable this only after ADR-72's chosen Singapore location receives OQ-07 DPO/counsel processor, transfer and notice approval and SEC-29/30/31/35 are demonstrated PASS, including an approved pre-signup privacy notice, lawful-basis review, 18+ declaration, versioned acknowledgement and incident runbook. SEC-27/28 and the production PITR/off-provider backup are also PASS before accepting real records. If any approval is missing, test only with synthetic accounts and do not invite real couples. A scratch restore of real data is production-equivalent restricted recovery infrastructure, not staging; delete it promptly after the validated drill.

---

## 2. Backend deployment

### 2.1 Hosting

Per **ADR-16/64**: Supabase managed Postgres, with Supabase Auth and Row-Level Security. Three isolated paid Pro projects — `kasaran-staging`, `kasaran-prod`, and a restricted scratch restore project (created as needed) — never share an Auth pool or service-role key. The scratch project's existence and billable duration must be checked at each monthly review; its access and cleanup are part of the drill, not a license to move real data to staging.

The backend surface is deliberately thin (design.md §2.4): two idempotent endpoints over one append-only table, plus auth. Deployable units:

| Unit | What it is | How it deploys |
|---|---|---|
| Schema + RLS policies | SQL migrations in `supabase/migrations/` | `supabase db push`, gated (§2.3) |
| Sync endpoints | Postgres RPC functions (`sync_push`, `sync_pull`) | Same migration pipeline |
| Auth config | Providers, token TTL (SEC-03), email templates | Declarative config in `supabase/config.toml`, reviewed in PR |
| Feature flags / min-client | A small `app_config` table (§3.6, §4.4) | Data change, no deploy |

### 2.2 Region — technical choice and outstanding residency review

**Chosen technical region: `ap-southeast-1` (Singapore) for Supabase (ADR-72).** OQ-07 remains open for DPO/counsel approval of cross-border processing and processor disclosures. This choice does not create a production project or permit real-data beta. Local-first sync reduces latency sensitivity; no unverified round-trip estimate is promised.

**There is no Supabase region in the Philippines in the current provider region list.** Philippine personal data would therefore be stored outside the country under the chosen architecture; ADR-72 is an infrastructure choice, not a legal conclusion:

- Cross-border processing, processor terms and controller safeguards require documented DPO/counsel review. Neither region selection nor a signup checkbox establishes a lawful basis.
- **SEC-30 requires the privacy notice to state recipients and locations.** Draft it for Supabase Singapore and Sentry's selected EU organization: diagnostic events at rest in **Frankfurt, Germany**, while Sentry says some account/project/usage/integration metadata may be stored in the **US** regardless of region and shared support material is stored there. DPO/counsel must approve the recipient, transfer, retention and notice language before publication. Use a region-specific endpoint and verify settings before sending any real event. Sources: https://supabase.com/docs/guides/platform/regions ; https://docs.sentry.io/organization/data-storage-location/ .

**OQ-07 remains open for legal and notice review, not region selection.** Until those reviews and SEC-29–31/35 pass, do not provision a real-data beta or invite real couples. An in-country alternative would require a separately designed and reviewed infrastructure change; do not claim it is available in this setup.

### 2.3 CI/CD stages, in order, with gates

```
① PR opened
   ├─ dart analyze + money-path lint          gate: zero violations (TC-GEN-01)
   ├─ domain unit tests incl. FIX-A…E plus explicit rebalance/guest previews
   ├─ widget tests + golden verify            gate: no unreviewed golden diff
   ├─ integration_test (Android emulator)     gate: green
   ├─ TENANT ISOLATION SUITE                  gate: TC-SEC-01 green — BLOCKING
   ├─ migration forward/backward              gate: TC-MIG-01..03 green
   └─ secret scan                             gate: clean (SEC-26)
        ↓ all green + human review
② Merge to main
   ├─ migrations applied to STAGING automatically
   ├─ staging smoke: sync push/pull round-trip
   └─ nightly: iOS integration_test only (no nightly Maestro; ADR-68)
        ↓
③ Release candidate cut (tag vX.Y.Z)
   ├─ Maestro E2E on iOS and Android (TC-E2E-01; RC-only, ADR-68)
   ├─ PRODUCTION READINESS GATE (§7)          gate: every row PASS
   └─ manual approval by rollback owner (§7.1)
        ↓
④ Production backend deploy
   ├─ migration applied manually, backup taken immediately before
   └─ post-deploy verification: old-client compatibility probe (§2.4)
        ↓
⑤ Mobile build + store submission (§4)
```

Nothing auto-deploys to production. For a solo maintainer the risk is not slow releases, it is an unattended 3 a.m. migration.

### 2.4 Migration strategy — the backward-compatibility constraint

**The constraint, spelled out:** mobile clients update on their own schedule. Some users will not update for months; some never will. Therefore **the backend at version N must correctly serve clients at version N−1**, and a client built against schema N−1 will keep calling the new backend indefinitely. A migration that breaks an old client breaks a user who did nothing wrong and cannot be reached without a store release (§0.1b — there is no OTA to push them past it).

**Rule: every migration must be backward compatible for at least one full release cycle.** Implemented as expand → migrate → contract (parallel change):

| Phase | Action | Client compatibility |
|---|---|---|
| **Expand** (release N) | Add the new column/table as nullable or with a default. Backend writes both old and new shapes. Nothing is removed. | N−1 clients ignore the new column and keep working. N clients use it. |
| **Migrate** (release N) | Backfill existing rows. Reads prefer new, fall back to old. | Both work. |
| **Contract** (release N+2, earliest) | Remove the old column, only after telemetry shows N−1 client usage has fallen below the deprecation threshold (§4.4). | Old clients already forced to update. |

**Forbidden in a single release** — each of these breaks an old client immediately:

- Dropping or renaming a column an old client reads or writes.
- Adding `NOT NULL` without a default to a table clients insert into.
- Narrowing a type (`bigint` → `int`), or tightening a `CHECK` to reject a value old clients still send.
- Removing a value from an enum-like `CHECK` constraint (e.g. deleting a pledge status).
- Any **breaking** change to `change_log`'s shape. Additive, versioned nullable fields (`change_group_id`, `schema_version` in ADR-44/49) follow expand/migrate/contract and require an N−1 compatibility probe; changing an existing field so an older client cannot write or retain an unknown field stops sync entirely. An older client must preserve additive unknown events in its log even when it cannot project them.

**Sync-specific hazard.** `server_ts` is assigned server-side (ADR-21/D1) and is the ordering authority. A migration that rewrites, re-bases, or re-assigns `server_ts` on existing rows **silently changes past conflict outcomes** — a field that resolved to partner A's value could flip to B's. Treat `server_ts` as immutable once assigned. If a migration must touch it, that is a data-integrity change requiring its own review and a documented recomputation of affected projections.

**Old-client compatibility probe.** After every production migration, CI replays a recorded N−1 client request set (captured push/pull payloads from the previous release's integration tests) against production and asserts identical acceptance behaviour. A failure here is a rollback trigger.

### 2.5 Secrets management per environment

| Secret | Local | Staging | Production |
|---|---|---|---|
| Supabase anon/public key | `.env.local`, gitignored | CI secret → build-time `--dart-define` | CI secret → build-time `--dart-define` |
| Supabase **service-role key** | Not present | CI secret, backend jobs only | CI secret, backend jobs only. **Never in a client build** (SEC-26) |
| DB connection string | Local, no secret | CI secret | CI secret |
| iOS signing (see §3.4) | Local keychain | Fastlane Match repo + passphrase in CI | Same |
| Android upload keystore | Local file, gitignored | Base64 in CI secret | Base64 in CI secret |
| Sentry DSN | Not used | CI secret | CI secret |

Rules: no secret in the repo, ever (enforced by the CI secret scan, SEC-26). The client bundle contains **only** the anon key — verified by inspecting the built artifact. Rotation: on any suspected exposure, and on collaborator offboarding. Service-role key rotation is a production change and follows §2.3 gating.

### 2.6 Rollback plan — code and migrations are different problems

These are separated because conflating them is how a bad deploy becomes data loss.

#### Roll back code

Fast and safe. Revert the commit, redeploy the RPC functions from the previous tag. Because the endpoints are thin and stateless, this is a minutes-scale operation with no data implication. **Always the first move.**

#### Roll back a migration

Depends entirely on what the migration did.

| Migration type | Reversible? | Action |
|---|---|---|
| Additive (new nullable column, new table, new index) | **Yes** | Down-migration drops the addition. Safe if no client depends on it yet — which the expand/contract order guarantees. |
| Backfill (writes values into an existing column) | **Partially** | Reversible only if the pre-existing values were preserved. If the backfill overwrote, it is not reversible from the schema alone. |
| Destructive (drop column, drop table, transform-in-place, tighten constraint) | **No** | **Cannot be rolled back.** The data is gone. Must be **forward-fixed**: write a new migration that restores a working shape, and recover lost values from the most recent backup if they are needed. |

**The honest note, stated plainly:** a down-migration is not a general safety net. Additive migrations reverse cleanly; destructive ones do not, and pretending otherwise is how teams discover mid-incident that "rollback" was never available. The real protections are (1) keeping migrations additive by policy, per §2.4, (2) taking a backup immediately before every production migration, and (3) the readiness-gate requirement that rollback has actually been rehearsed in staging at least once (§7, row 10) rather than assumed to work.

#### Point-in-time recovery — last resort, with a specific side effect

Supabase PITR can restore production to a prior timestamp. Two consequences to understand before using it:

1. **Writes after the restore point are lost server-side.** Clients still holding them in their local queues will re-push on next sync, so much of the data returns — that is a genuine benefit of the local-first design (GIV-03).
2. **But re-pushed rows receive *new* `server_ts` values.** Since `server_ts` is the LWW ordering authority (ADR-21), re-pushing can **change conflict outcomes** relative to the original history: a field that had resolved to A's value may resolve to B's. Restoring is therefore not a perfectly transparent rewind. If PITR is used, the incident record must note that conflict resolution may have shifted, and the change log will show the new ordering.

#### Recovery targets and independent copy (ADR-65/67)

**Production target:** RPO **≤1 hour** while PITR is healthy and its latest recovery point has been checked; RTO **≤24 hours** from incident declaration to validated service. These are operational targets, **not Supabase SLAs**. A complete provider outage or unusable PITR may fall back to the daily off-provider copy (up to **24 hours** of server-side data at risk); declare target breach rather than quietly relabel the RPO. Local unsynced writes and re-push behavior are not guaranteed recovery and require reconciliation (§2.6). Track recovery-point lag and actual drill elapsed time; escalate if the one-hour window cannot be selected or a restore exceeds 24 hours.

Run a **daily encrypted, authenticated off-provider logical export** of production Postgres including application schemas, `auth.users` and the needed Auth schema/identity dependencies, schema migrations, roles/grants **without copying operational credentials**, plus a versioned inventory of Auth settings and required project configuration. Use a dedicated least-privilege backup principal as feasible, encrypt before transfer with an independently held key, store in a separately administered destination with MFA and restricted restore access, retain **30 days**, and verify upload, integrity/hash and decryptability. Supabase's downloadable backup behavior and PITR do not themselves establish an independent copy; database backup excludes Storage object bytes (v1.1 needs a separate object-backup design). Provider documents: https://supabase.com/docs/guides/platform/backups . Do not place live dumps in repo, CI artifacts, staging or developer laptops. The scratch restore project is isolated production-grade infrastructure with access logging, no email delivery to real users, and prompt secure disposal after a drill; never send actual restored data to staging.

**Drill cadence:** monthly, **and before every release** (ADR-67). Restore the off-provider copy to the restricted scratch project, check decrypt/hash, row counts and `change_log` checksum, Auth user count and synthetic test account's auth/authorization path, and record restore point, missing fields, elapsed wall-clock time and deletion evidence. Also separately rehearse PITR at a safe point where provider tooling allows; never trigger a destructive production restore just to demonstrate readiness. Keep the drill record access-controlled, with no user content in it. Failure blocks release, initiates remediation and a fresh drill.

**Break glass:** escrow recovery instructions, Supabase organization recovery/admin access, MFA recovery material, independent backup decryption key, CI ownership, Apple signing/App Store Connect access, Android upload key/Play access, Fastlane Match repo/passphrase, domain and support-mail recovery in two independently controlled secure vaults (primary maintainer plus an authorized trusted alternate). Do not put any actual secrets in this document. Assign and test the alternate's *independent* access in a tabletop and after credential rotation; require an incident record and revocation/audit after use. If no authorized alternate or working escrow exists, mark ADR-65 recovery gate NOT MET, not “covered by the solo maintainer.”

---

## 3. Mobile build tooling

### 3.1 Flutter project and native dependencies

**ADR-12 locks Flutter.** The iOS and Android platform projects build native SQLCipher-backed SQLite dependencies (SEC-12, via `drift` and `sqlcipher_flutter_libs`). Build and signing jobs must compile and link those native libraries on their respective platform toolchains.

### 3.2 Build tooling decision: **Fastlane** (+ GitHub Actions)

Fastlane is the chosen Flutter iOS and Android release orchestrator, with GitHub Actions for CI. The criteria are:

| Criterion | Assessment |
|---|---|
| **Native SQLite encryption module** | Fastlane runs the real `flutter build ipa` / `appbundle` on a real toolchain, so SQLCipher's native compilation and linking work normally. Any hosted service that abstracts the native build would be a liability here. |
| **Solo maintainer** | Fastlane's value is exactly the tedium a solo maintainer cannot afford: `match` for certificate/profile sync, `pilot` for TestFlight upload, `supply` for Play publishing. One `fastlane release` replaces a dozen manual portal steps that are easy to get wrong at 1 a.m. Cost: a Ruby dependency and occasional Xcode-upgrade breakage. |
| **CI cost** | GitHub Actions: Android builds on Linux runners (cheap, generous free minutes). iOS builds require macOS runners at roughly 10× the minute multiplier — so iOS builds run **only on tagged release candidates and nightly**, never per PR. This is the single biggest CI cost lever. |

**Alternative if macOS minutes become the binding constraint:** Codemagic, which is Flutter-specialised and has a free tier sized for a solo project. Not chosen now because Fastlane keeps the pipeline portable and avoids a second CI vendor.

### 3.3 Build numbering

| Field | Scheme | Rule |
|---|---|---|
| Version name (both platforms) | Semver from `pubspec.yaml`, e.g. `1.2.0` | §6.1 |
| iOS `CFBundleVersion` | Monotonic integer = CI run number | Must strictly increase within a version name; never reused |
| Android `versionCode` | **Same** monotonic integer as iOS build | Keeping them identical makes a bug report's build number unambiguous across platforms |

Build numbers come from CI, never from a developer's machine — a local build cannot accidentally consume a number the store has seen.

### 3.4 Signing and credential storage

**iOS.** Distribution certificate + provisioning profiles managed by **Fastlane Match**, stored encrypted in a private git repo; the Match passphrase and an **App Store Connect API key** (JSON) live in CI secrets. API key rather than an Apple ID password, so no 2FA prompt blocks CI. Never in the app repo.

**Android.** **Play App Signing enabled** — Google holds the app signing key, the maintainer holds only the upload key. This is deliberate: for a solo maintainer, a lost upload key is recoverable through Google, whereas a lost app signing key without Play App Signing would permanently orphan the listing. Upload keystore stored base64-encoded in a CI secret with its password as a separate secret.

Both: credentials are rotated on suspected exposure, and their storage locations are recorded in §2.5.

### 3.5 OTA update policy — there is no code OTA

**Policy: no over-the-air client code updates in v1. Every client code change ships through the stores.**

This follows from Flutter (§0.1b), not from choice. Consequences and the levers that remain:

| What can change without a store release | Mechanism | Notes |
|---|---|---|
| RLS policies, DB schema, RPC behaviour | Backend deploy (§2.3) | Subject to the backward-compatibility rule (§2.4) |
| Feature flags / kill switches | `app_config` table read at launch (§3.6) | The only fast client-behaviour lever |
| Minimum supported client version | `app_config` value (§4.4) | Forces an update; does not deliver one |
| Store listing text and screenshots | Store console | No binary change |
| **Nothing in Dart code** | — | Requires a store release |

**What may never ship OTA even if a mechanism were added later.** Recorded now as policy so a future Shorebird-style patcher cannot quietly widen its blast radius:

1. Anything touching the **sync protocol** — payload shape, ordering, cursor semantics.
2. Anything touching the **local schema** or migrations.
3. Anything touching **auth** — token handling, session logic, key storage.
4. Anything touching **money arithmetic** or the allocation engine.

Rationale: each of these can put a client into a state where it corrupts or loses data that the server cannot repair, and OTA patches skip store review — so they also skip the only external check.

**Avoiding client/backend desync.** The relevant risk is **old client vs new backend**, addressed by the one-release backward-compatibility rule (§2.4), the old-client compatibility probe after each production migration (§2.4), and the forced-update floor (§4.4). If a third-party Flutter code-push tool is ever adopted, the four prohibitions above become the hard boundary, and patched builds must still pass the tenant-isolation suite (TC-SEC-01) before release.

### 3.6 Kill switch and the bundled-ruleset problem

Because a code fix takes days (§8.3), the app reads an `app_config` row at launch exposing:

- `min_supported_build` — forced-update floor (§4.4)
- feature kill switches, e.g. `sync_enabled`, `whatif_enabled`
- `notice` — an optional message the app displays

**Critical constraint: flags must fail *open*.** If `app_config` cannot be fetched (the normal state for an offline user, REQ-OF-1), the app uses its last-known values, and absent those, its compiled defaults. A flag system that fails closed would break offline-first the first time the network hiccuped.

**The bundled-ruleset risk (§0.1b).** ADR-15 ships the allocation ruleset as a bundled JSON asset, so a wrong baseline or regional modifier needs a store release on both platforms — days, per §8.3 — and the reference-cost values are still unpopulated (OQ-04). Options, none of which I am adopting unilaterally since it means amending ADR-15:

1. **Keep bundled** (status quo). Simplest, fully offline, but wrong numbers are stuck for days.
2. **Remote ruleset with bundled fallback.** Fetch the ruleset into the local DB when online, fall back to the bundled asset; plans keep pinning a ruleset version (REQ-AE-3), so existing plans do not shift underneath users. Fixes a bad ruleset in minutes and is how the reference costs would land without a release.
3. **Bundled, but versioned + validated at load** (already required by REQ-AE-1 cl. 4). Catches an invalid ruleset; does not fix one.

**Recommendation: option 2**, precisely because it converts a class of days-long incidents into minutes-long ones on a platform with no code OTA. Needs an ADR amendment. Logged as **OQ-08**.

---

## 4. Mobile release pipeline

### 4.1 iOS

```
Build (CI, tagged RC) → TestFlight INTERNAL (maintainer + up to 100 internal)
                         no Beta App Review, minutes to available
        ↓ readiness gate §7 PASS
                      → TestFlight EXTERNAL (invited PH testers)
                         requires Beta App Review, ~1 day typical
        ↓ soak ≥ 5 days, zero S1/S2
                      → App Store submission (full review, 1–3 days typical)
        ↓ approved
                      → v1 **initial release is not eligible for phased update**; release manually after approval. For later version updates, choose Apple's built-in 7-day phased release for automatic updates (ADR-69), monitor and pause as needed; no custom percentage schedule. Source: https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/
```

### 4.2 Android

```
Build (CI, tagged RC) → INTERNAL TESTING (maintainer, immediate)
        ↓ readiness gate §7 PASS
                      → CLOSED TESTING (invited PH testers)
        ↓ soak ≥ 5 days, zero S1/S2
                      → PRODUCTION, STAGED ROLLOUT: 5% → 10% → 20% → 50% → 100%
                         advance one step per 24 h, only if crash-free ≥ 99% and no S1/S2
```

### 4.3 Rollback reality per platform — what is actually possible

**Neither platform can un-install an update from users who already have it.** This is the fact that makes staged rollout the primary safety mechanism rather than rollback.

| | **Android** | **iOS** |
|---|---|---|
| Stop further distribution | **Halt rollout** — takes effect quickly, stops new users receiving the build | **Pause phased release** — stops progression; can be held up to 30 days |
| Users already updated | Keep the bad build. No downgrade mechanism exists | Keep the bad build. No downgrade mechanism exists |
| Serve previous code again | Re-publish previous source as a **new build with a higher `versionCode`** (codes cannot decrease) | Re-submit previous source as a **new build**, requiring review |
| Fastest path to a fix | New build + review (often hours to ~1 day) + staged rollout | New build + review (1–3 days); **expedited review** may cut this to under a day but is discretionary and not guaranteed |
| Practical implication | Halt fast, then ship forward | Pause fast, then ship forward; request expedited review only for genuine S1 |

**Therefore:** the real controls are (1) advance staged rollout slowly and watch the §7 alerts, (2) use the §3.6 server-side kill switch to disable a broken feature without a release, and (3) fix forward. "We'll roll back" is not an available plan on mobile.

### 4.4 Minimum OS versions and client deprecation

| | Minimum supported | Rationale |
|---|---|---|
| iOS | **15.0** | Keychain protection classes and crypto APIs relied on by SEC-13/SEC-14; keeps the tested surface honest (testing-plan §1.3 tests latest−1) |
| Android | **API 24 (7.0)** | SQLCipher and modern Keystore behaviour required by SEC-12/SEC-13; below this, at-rest guarantees weaken |

**Client-version deprecation and forced update.** The backend serves `min_supported_build` in `app_config`. On launch and on sync attempt the client compares its build number:

| Client state | Behaviour |
|---|---|
| ≥ `min_supported_build` | Normal operation |
| < `min_supported_build` | **Blocking update-required screen.** Sync is disabled. **Local data remains readable** — the app does not hold a user's own budget hostage; it degrades to read-only rather than dark. Copy follows ux-spec §7.3 rules: never implies data loss |
| Cannot reach `app_config` (offline) | Uses last-known value; if never fetched, treats itself as supported. Fails open (§3.6) |

**Versioned sync envelopes (ADR-49).** Push/pull include `protocol_version`; each immutable log row carries `schema_version`. The server rejects an unsupported major version before accepting a batch, with a structured incompatible-protocol response that contains `min_supported_build`. The client retains every queued write, displays the existing update-required/read-only state (without implying loss), and retries only after an update. A supported older minor client persists unknown additive events unchanged and omits them only from projections; after updating, a transactional drift migration rebuilds those projections from the retained log. Raising `min_supported_build` does not rewrite `server_ts` or bypass the two-minor-release/90-day deprecation policy below. Test the N−1 request set for both read and write, unknown-event preservation, and incompatible-major refusal before contracting a protocol shape.

**When the floor is raised:** only when an old client would be *unsafe to sync* — it writes a `change_log` shape the backend no longer accepts, mishandles `server_ts` ordering, or misses a security fix. Not for feature parity. Raising the floor is a production change requiring §2.3 gating, and the deprecation window is **two minor releases or 90 days, whichever is longer**. Coarse first-party client-version events are opt-in under REQ-MT-1/ADR-62; they cannot prove absence of unconsenting old clients. Before any contract migration, use a documented compatibility test and safe server-side version negotiation; extend the window if evidence is insufficient (§2.4).

---

## 5. Store submission checklist

### 5.1 Metadata

| Field | Value / rule |
|---|---|
| App name | **Kasaran** (ADR-27 — decided). Subject to clearance, §5.6 |
| Subtitle / short description | "Wedding budget planning for Filipino couples" |
| Category | **Lifestyle** — deliberately not Finance (§5.3) |
| Age rating | 4+ (iOS) / Everyone (Android). §5.2 |
| Support URL | Required. Must be live before submission |
| Privacy policy URL | Required. **Blocked on OQ-07 DPO/counsel transfer and notice review** — ADR-72 selected Singapore, but the live notice must accurately disclose approved recipients/locations (§2.2, SEC-30) |
| Account deletion URL | Required by both stores (SEC-40) |
| Languages | English (ux-spec §8.4) |
| Devices | iPhone only in v1; iPad not declared. No device-location permission requested (SEC-41) |

### 5.2 Screenshots and age rating

**Screenshots** — must show real, populated data (the FIX-A plan), never empty states (§5.5):

| Platform | Required set |
|---|---|
| iOS | 6.7" (1290×2796) and 6.5" (1242×2688) — 3–5 each: dashboard bento, ledger with hidden fees, pledges showing net vs expected, guest what-if, change log |
| Android | Phone screenshots ×4–8 (min 1080px), plus 1024×500 feature graphic and 512×512 icon |

**Age rating is distinct from eligibility.** Complete the actual Apple/Play content questionnaires truthfully (the preliminary content assessment is 4+ / Everyone, subject to store determination). Set **Google Play target audience to 18+**, and require the **18+ self-declaration at signup** (ADR-63, SEC-31); do not claim age verification. Counsel must review the declaration's lawful basis and privacy notice. The listing's content rating does not imply minors are allowed to sign up.

### 5.3 Privacy labels — pulled from security-plan §6

Transcribed from security-plan.md §6.2 and §6.3; must match the §6.1 data inventory exactly (SEC-39).

**Apple App Privacy:** Contact Info, Financial Info, User Content and Identifiers — linked, not advertising tracking; **Diagnostics** (Sentry crash/other diagnostic data and any actual performance data) collected when enabled. **Usage Data / Product Interaction** for optional opt-in measurement, including net-view and client-version events, if shipped; mark its actual analytics purpose, linked status and optional collection accurately. Survey answer category is subject to a payload/category audit. Self-selected region is User Content, not GPS Location (SEC-41). No third-party analytics SDK in v1. Apple's definitions explicitly require declaration even when collection is solely for app functionality: https://developer.apple.com/app-store/app-privacy-details/ .

**Google Play Data Safety:** disclose Personal, Financial, other user content, Sentry crash logs/diagnostics and identifiers actually transmitted, and any optional first-party product interaction/survey collection. Indicate purposes and optionality as implemented. DPO checks Supabase/Sentry processor and user-directed share-sheet handling under Play's definitions; do **not** assert blanket “no sharing” before review. Encryption and deletion claims require their actual SEC-17/12/34 pass evidence, not planned checkmarks. No advertising tracking. Official guidance: https://support.google.com/googleplay/android-developer/answer/10787469 .

**Account deletion path:** SCR-18 account settings offers an in-app deletion request and confirmation (SEC-34), plus a publicly reachable deletion-instructions URL is planned (SEC-40). The alias-based log attribution can render “Former member” without mutating history (ADR-51), but this does **not** decide how a shared plan or historical personal content is erased. The shared-record completion outcome remains counsel-gated on OQ-01/SEC-33/38; no production deletion-flow pass may be claimed before a reviewed, working path exists. This is a release blocker, not a resolved store-submission item.

### 5.4 Review risk: reviewers cannot pair two accounts — pre-paired demo required

**This is the highest-probability rejection cause in the whole submission.** Shared editing (REQ-SE-1) needs two accounts on one plan. A reviewer given one fresh account sees a single-user app, cannot exercise the headline feature, and can reasonably reject as incomplete or non-functional.

**Supply both credential sets in App Store Connect review notes and the Play console:**

| | Account 1 | Account 2 |
|---|---|---|
| Role | Plan creator ("Partner A") | Joined partner ("Partner B") |
| Email | `review-a@kasaran.app` | `review-b@kasaran.app` |
| Password | Supplied in review notes | Supplied in review notes |
| State | **Already paired to the same plan** — no invite step needed | Same plan, already accepted |

**The demo plan is FIX-A** (testing-plan §3.1), because its numbers are already hand-verified and realistic:

- Wedding date ~8 months out, so the countdown shows a sensible figure.
- Budget ₱800,000; 150 guests; NCR; church + hotel.
- **13 ledger entries** across all six categories, mixing per-head and flat-rate, with some `actual` set and some estimate-only so the variance UI is populated.
- **All six hidden fees resolved:** crew meals filled (18 crew × ₱350), church aircon ₱8,000, corkage ₱5,500, OOT dismissed, overtime dismissed, venue power dismissed — so no blocking setup gate greets the reviewer.
- **Three pledges spanning all states:** Ninong Ramon ₱50,000 **received**, Ninang Cora ₱30,000 confirmed, Tita Mila ₱20,000 tentative — so the D2 net-vs-expected distinction is visible on screen (net ₱636,800 vs gross ₱686,800 vs expected ₱50,000).
- **Guests with both axes** populated: Tier 1 and Tier 2, across confirmed/invited/tentative.
- **Change-log history containing entries attributed to BOTH partners**, so a reviewer signing in as either account immediately sees shared editing working rather than an empty activity feed.
- Reset nightly by a scheduled job so a reviewer's edits do not degrade the demo for the next reviewer.

**Review note text:** "This app is designed for two people sharing one wedding budget. Two pre-paired accounts are provided. Sign in as either to see the shared plan; edits made on one account appear attributed to that partner in the Activity view."

### 5.5 Review risk: offline-first apps look broken on first launch

**The risk:** offline-first apps are commonly rejected for showing empty states, spinners, or errors on a reviewer's first launch. Two specific traps here.

**Trap 1 — the reviewer signs in and sees nothing.** Mitigated: the demo accounts are pre-populated (§5.4), so first launch after sign-in lands on a fully populated dashboard — every bento tile shows a real value, not a zero state (ux-spec §4.4).

**Trap 2 — the reviewer tests airplane mode first and cannot sign in.** This is real and worth stating plainly: per ux-spec's state matrix, **sign-in requires network** (it is the one genuinely online-only action), even though everything after it works offline. A reviewer who opens the app in airplane mode before ever signing in will see a blocked sign-in and may read the app as broken.

Mitigations: (a) the SCR-01 offline copy states explicitly that a connection is needed **for first sign-in only** and that all planning works offline afterwards; (b) the review notes say the same in one sentence; (c) the App Store description leads with "works offline" so the behaviour is framed as intended rather than discovered as a fault.

### 5.6 Review risk: finance-adjacent, and name clearance

**Finance-adjacent but processes no payments.** Stated plainly in review notes to preempt financial-services scrutiny:

> "Kasaran is a budgeting and planning tool. It does **not** process, transmit, or store payments, and contains no payment integration, in-app purchase, or financial account linking. Recording that a supplier deposit was paid is a manual bookkeeping entry only (REQ-LG-4). There is no money movement of any kind in this version."

Supporting choices: category **Lifestyle**, not Finance. No payment SDK in the dependency list — auditable. No IAP, so Guideline 3.1.1 does not apply. This matters because a Finance categorisation can pull in additional verification requirements the app cannot satisfy and does not need.

**PH cultural terms in the listing.** The listing uses **Ninong**, **Ninang**, **OOT**, and **corkage**. In-app these are never glossed (ux-spec §8.4) — but the **store listing is a different audience**, potentially including a reviewer unfamiliar with Filipino wedding practice. Mitigation: the description glosses each term once in a natural sentence ("principal sponsors — Ninong and Ninang — who traditionally pledge support"), which aids both reviewers and PH users searching those exact words. The in-app no-gloss rule is unchanged.

**Name clearance — a step, not an assumption.** ADR-27 decided the name; **decided is not cleared.** Before submission:

| # | Clearance step | Blocks submission? |
|---|---|---|
| 1 | App Store name availability — is "Kasaran" reserved or taken? | **Yes** |
| 2 | Google Play title collision / confusing-similarity check | **Yes** |
| 3 | IPOPHIL trademark search (Philippine Intellectual Property Office), classes covering software/apps | No, but a conflict found later is expensive |
| 4 | Domain and social handle availability (`kasaran.app` used above for demo emails — must actually be owned) | **Yes** — the support, privacy, and deletion URLs depend on owning a domain |
| 5 | Confirm no existing PH wedding-services brand uses the name | No, advisory |

Logged as **OQ-09**. Steps 1, 2, and 4 are hard submission blockers; the decided name does not survive contact with a collision.

---

## 6. Versioning and release notes

### 6.1 App semver

`MAJOR.MINOR.PATCH`:

- **MAJOR** — the client requires a backend API major version the previous client did not, or the local schema changes in a way that is not backward compatible. Expected to be rare; every MAJOR implies a forced-update campaign (§4.4).
- **MINOR** — new user-visible capability, backward compatible with the current backend.
- **PATCH** — fixes and copy changes only, no schema or protocol change.

v1 ships as **1.0.0**.

### 6.2 Backend API versioning and its relation to the app

- Sync endpoints are path-versioned: `/v1/sync/push`, `/v1/sync/pull`.
- **Within `/v1`, only backward-compatible changes are permitted** (§2.4). Additive fields, new optional parameters, looser validation.
- A breaking protocol change means **`/v2`**, published alongside `/v1`. `/v1` is maintained for the full deprecation window (two minor releases or 90 days, §4.4) before removal.
- Relationship: an app MAJOR bump is required when the client moves to a new API major. The backend must serve **both** majors during the window — this is what allows a user on an old build to keep planning while they get around to updating.

### 6.3 Changelog source and user-facing tone

**Source of truth:** conventional-commit messages on `main` generate `CHANGELOG.md` per tag. That file is the engineering record — complete, technical, includes internal changes.

**Store release notes are hand-written from it**, not generated. Tone rules, consistent with ux-spec §7.3:

- Plain and specific. "Crew meals no longer change when you adjust your guest count" beats "bug fixes and improvements."
- Name the thing the user noticed. If a total was wrong, say a total was wrong.
- **Never imply data loss where none occurred** — the prohibition on *lost*, *deleted*, *failed to save* applies to release notes as much as to in-app copy.
- No marketing superlatives. No exclamation points.
- If a release forces an update, say why in one sentence.

Example: *"Fixed: the buffer total could show as under-spent when one category was over budget. Your figures are recalculated automatically when you open the app — nothing needs re-entering."*

---

## 7. Production readiness gate

**Pass/fail only. No row may be "in progress" — an unverifiable row is FAIL** (consistent with security-plan §7 and testing-plan §10).

**Current status: the app is not built. Every row below is therefore NOT MET.** This table is the definition of ready, not a report of readiness.

| # | Requirement | Source | Pass condition | Status |
|---|---|---|---|---|
| 1 | Tenant isolation suite green in CI | TC-SEC-01, SEC-24 | Cross-tenant read/write/delete and forged-`plan_id` pull all denied; suite blocks the pipeline | NOT MET |
| 2 | All fixture calculations exact | testing-plan §3, §4 (FIX-A…E; TC-PL-19, TC-AE-05 and new rebalance/guest cases) | All specified assertions green; pre-action FIX-C net remains ₱335,750.00; only explicit Apply changes allocations, not net or the pinned baseline | NOT MET |
| 3 | Full MVP E2E on both platforms | TC-E2E-01 | 20/20 steps + offline gate, iOS and Android | NOT MET |
| 4 | Sync conflict matrix green both platforms | testing-plan §5 (10 rows) | 10/10, incl. clock-skew TC-SE-20 and the LWW/removal asymmetry | NOT MET |
| 5 | Offline matrix green | TC-OF-01…17 | 8 entity rows + 9 durability rows; TC-OF-10 string scan finds zero prohibited words | NOT MET |
| 6 | Device at-rest security on real hardware | TC-SEC-03, TC-SEC-07…10, SEC-12/13/14/16/28 | Simulator results do not count | NOT MET |
| 7 | Migrations forward/backward + old-client probe | TC-MIG-01…03, §2.4 | Green, and the N−1 replay set passes against production schema | NOT MET |
| 8 | **Backup verified by an actual restore drill with recorded duration** | TC-BAK-02, SEC-27, ADR-67 | Last monthly drill plus **one before each release**, restoring the encrypted off-provider backup (including Auth users) to restricted scratch; row counts, Auth test login and `change_log` checksum verified; elapsed time ≤24 h recorded. A missed drill or unrecorded duration is FAIL | NOT MET |
| 9 | Zero open S1/S2 defects | testing-plan §9 | Count = 0 | NOT MET |
| 10 | **Rollback rehearsed once in staging** | §2.6 | A code rollback **and** an additive-migration rollback both performed in staging, with the outcome and duration written up. Not a thought experiment | NOT MET |
| 11 | Monitoring and alerting live | §7.1 | All named alerts firing correctly, verified by deliberately tripping at least one | NOT MET |
| 12 | Error tracking with release tagging | §7.2, ADR-61 | Sentry EU project verified receiving scrubbed events tagged with version + build + git SHA; US metadata caveat disclosed and **PII scrubbing verified** (SEC-28) | NOT MET |
| 13 | Support intake channel live | §7.3 | Address reachable, in-app link works, response-time expectation published | NOT MET |
| 14 | Rollback decision owner named | §7.4 | A named person, reachable, with documented authority | NOT MET |
| 15 | Secrets audit | SEC-26 | CI secret scan clean; built artifact contains no service-role key | NOT MET |
| 16 | Store privacy labels match inventory | SEC-39, §5.3 | Submitted labels diffed against security-plan §6.1; zero mismatch | NOT MET |
| 17 | Account deletion path live | SEC-34, SEC-40 | In-app deletion works end-to-end; public URL live | NOT MET |
| 18 | Privacy notice published | SEC-30, ADR-72/OQ-07 | Live URL naming the chosen Singapore/Sentry locations and DPO/counsel-approved recipients and transfers; technical region choice alone is insufficient | NOT MET |
| 19 | Name clearance | §5.6, OQ-09 | Store name availability confirmed on both platforms; domain owned | NOT MET |
| 20 | Verified checklist preset content | OQ-11, ADR-56, REQ-CK-1 | Before publishing any v1 legal/church applicability or date-offset preset, verify each item with the relevant authority and record its source; otherwise show only user-managed NEEDS VERIFICATION prompts without a claimed preset date. **OQ-11 remains open; preset release is blocked.** | NOT MET |
| 21 | Private offline export/share | ADR-57/60, SEC-32/42, REQ-EX-2, testing-plan export cases | Project-owner design scope approved under ADR-60, but PDF/CSV and the separate full local-data copy must work offline; privacy preview, single-sponsor scoping and spreadsheet-formula neutralization must pass on both platforms; authenticated server-only retrieval and DPO review of subject/shared-plan access remain required before SEC-32 passes | NOT MET |
| 22 | Real-data beta privacy and residency | ADR-61..63/72, SEC-29/30/31/35, OQ-07 | Before any real-couple account: Singapore technical choice documented, cross-border processor/transfer and notice approved by DPO/counsel, lawful bases and 18+ flow signed off, consent/withdrawal tested, breach tabletop run; staging synthetic-only | NOT MET |
| 23 | Recovery independence and budget | ADR-64..67, §8.4 | Pro+PITR active on production with latest recovery point monitored; daily encrypted off-provider backup including Auth users verified; break-glass escrow and monthly/pre-release drill tested; billing alarms active | NOT MET |

**v1.1 is not part of this v1 gate.** A later attachment release separately requires SEC-43/44 Storage RLS, size/MIME, encrypted offline staging and Photos-label PASS before store submission; localization needs ARB fallback and pseudo-localization tile-overflow tests (ADR-58/59). A backlog stub is not a green release gate.

### 7.1 Named alerts and thresholds

| Alert | Threshold | Severity | Route |
|---|---|---|---|
| Sync push error rate | > 2% of requests over 15 min | P1 | Push notification + email |
| Sync pull error rate | > 2% over 15 min | P1 | Same |
| Sync p95 latency | > 3 s over 15 min | P2 | Email |
| Auth failure rate | > 10% over 10 min | P1 | Push + email |
| RLS denial spike | > 5× the 7-day baseline over 10 min | P1 | Push + email — possible attack **or** a policy bug |
| DB connection saturation | > 80% of pool for 5 min | P2 | Email |
| DB disk usage | > 80% of quota | P2 | Email |
| Crash-free session rate | < 99.0% over 1 h on a staged rollout | P1 | Push — halts rollout advance (§4.2) |
| Backup job failure | Any failure | P1 | Push + email |
| Migration applied to production | Any occurrence | Info | Audit log |

### 7.2 Error tracking

Sentry **EU organization** (`de.sentry.io` region endpoint), `environment` set per §1, **releases tagged `kasaran@<semver>+<build>` with the git SHA** so a crash maps to an exact artifact. EU organization selection is irreversible; EU event data at rest is Frankfurt, but some organization/project/usage metadata can reside in the US and user-shared support material is stored in the US. Verify the location in organization settings and approve OQ-07 notice before real beta. Source: https://docs.sentry.io/organization/data-storage-location/ .

**Non-negotiable configuration constraint:** Sentry's default breadcrumbs and context can capture exactly what SEC-28 forbids — peso amounts tied to a user, sponsor and guest names, emails, tokens. A `beforeSend` scrubber must strip these, and **that scrubbing is itself verified** by TC-SEC-10 extended to crash payloads. Shipping Sentry unscrubbed would turn the error tracker into the largest PII leak in the system.

Set `sendDefaultPii=false`; disable request-body capture, session replay, profiling and automatic performance/analytics features unless separately audited and declared. Scrub at capture **before upload**, including stack breadcrumbs, URLs, tags and exception messages; run canary payloads containing known synthetic names, amounts, email and token strings and inspect the received event in Sentry. Disable diagnostics collection if scrub evidence fails. Sentry diagnostics does not grant consent to first-party measurement (ADR-62, security-plan §6.1.1).

### 7.3 Support intake

Single channel: `support@kasaran.app`, linked from an in-app "Get help" item and [support FAQ](./support-faq.md) (ADR-66). Published expectation: initial response within 2 business days, **not** a guarantee that a rights request is completed in two days. Auto-reply confirms receipt, points to privacy/deletion instructions, and says not to email passwords, tokens, IDs, guest lists, screenshots or financial details. Verify requester identity via an authenticated in-app workflow or a fresh, expiring, single-use account-bound verification link; never disclose a plan or even confirm another person's membership solely from an email address. Log request ID, category, receipt time, verifier, lawful deadline, escalation and outcome in restricted records; DPO reviews SEC-32 server-only/third-party scope and counsel-gated shared-record erasure (OQ-01). Ex-partner disputes: give neutral safety instructions for either partner's own access/revocation path (SEC-07), do not mediate ownership or share the other party's records; escalate threats, coercion or exposure to the privacy/security incident path without alerting the alleged aggressor by default. Publish the FAQ only after legal review of rights copy.

### 7.4 Rollback decision owner

**The solo maintainer** holds the decision, with pre-authorisation to act without consultation: halt an Android rollout, pause an iOS phased release, flip a kill switch, or roll back backend code. Pre-authorising these removes hesitation during an incident. **Destructive actions — PITR restore, forward-fix migration on production — require writing the decision down first** (a one-paragraph incident note), because §2.6 shows those are the irreversible ones.

---

## 8. Day-2 operations

### 8.1 On-call reality for a solo maintainer

No pretence of 24/7. Stated honestly so the published expectations match what can be delivered:

- **Coverage:** best-effort, waking hours, Philippine time. No paging rota, no secondary.
- **P1 alerts** go to phone push and are expected to be seen within a few hours while awake, next morning if overnight.
- **P2 and below** are reviewed once daily.
- **Published support expectation is 2 business days** (§7.3) — deliberately more conservative than the internal target, so the public promise is one that can be kept.
- **Compensating controls, because the human is single-threaded:** staged rollouts advanced slowly (§4.2), kill switches that need no release (§3.6), backend deploys gated manually (§2.3), and alert thresholds tuned to avoid fatigue — a maintainer who ignores alerts is worse than no alerts.

### 8.2 What a P1 looks like

A P1 maps to an **S1** in testing-plan §9 — data loss, corruption, cross-tenant exposure, or money computed wrong — plus total outage:

| P1 | Immediate action |
|---|---|
| Cross-tenant data exposure | Disable the affected endpoint via kill switch; assess scope from logs; **72-hour NPC breach clock starts** (SEC-35) |
| Sync down (push or pull failing broadly) | Roll back backend code first (§2.6); clients keep working offline, which buys real time |
| Data loss — writes accepted then vanishing | Stop further writes via kill switch before investigating; do not use PITR until scope is known (§2.6) |
| Money computed wrong (wrong net, buffer drift) | Kill-switch the affected surface; determine whether stored data is wrong or only the display; a display bug is far cheaper than a corrupted total |
| Auth down | No new sign-ins; existing sessions and offline use continue. Roll back auth config |

**The local-first design is the biggest operational asset here.** A backend outage does not stop users planning — they keep working offline and sync later (GIV-03, REQ-OF-1). That converts many would-be P1s into P2s and is worth stating, because it is the reason a solo maintainer can run this service at all.

### 8.3 Incident → fix → release latency

Honest numbers, and the reason §3.5 matters:

| Fix location | Time to users | Notes |
|---|---|---|
| Backend code / RLS / RPC | **Minutes to 1 hour** | Deploy and done. Always check first whether a fix can live here |
| Backend data (kill switch, `min_supported_build`, config) | **Minutes** | No deploy at all — the fastest lever available |
| Bundled ruleset value | **Days** (a full store release on both platforms) | The problem OQ-08 proposes to fix |
| Android client code | **~1–2 days** | Build + review (often hours) + staged rollout, which should not be rushed |
| **iOS client code** | **~1–5 days** | Build + review typically 1–3 days; expedited review may cut it but is discretionary. Then phased release |
| Dart code via OTA | **Not available** | Flutter has no supported code push (§0.1b, §3.5) |

**The operational conclusion:** because a client fix can take up to five days and there is no OTA escape hatch, the architecture must be able to mitigate client bugs from the server. That is why §3.6's kill switches exist, why §4.4's forced-update floor exists, and why OQ-08 (remote ruleset) is worth resolving before launch rather than after the first bad number ships.

### 8.4 Cost monitoring

**Budget policy (ADR-64):** monthly ceiling **USD 200** for Supabase service spending, not a provider-enforced hard cap or an all-in business budget. As of 2026-10-03, official list pricing: Pro organization **$25/month** with **$10/month compute credits**; PITR requires at least Small compute, so the production **Small $15/month** plus synthetic staging/scratch **two Micro $10/month each** gives **$50/month net plan+compute** ($25 + $15 + $10 + $10 − $10). Seven-day production PITR adds **about $100/month**, making a **$150/month** fixed baseline before variable usage. A scratch project created only during drills may have lower prorated compute, but do not budget assuming that. PITR may replace daily backups; off-provider backup has separate destination/egress costs. Verify actual invoices, active projects, taxes and usage before approving real beta. Source: https://supabase.com/pricing ; PITR minimum and backup behavior: https://supabase.com/docs/guides/platform/backups .

At **$150 projected month-to-date spend**, warn the maintainer and inspect usage/PITR/project inventory; at **$180**, freeze nonessential load and project creation (never turn off backups/security or discard user data); at **$200**, stop new onboarding and escalate to the owner to approve a funded overage or a safe capacity plan. Protect existing users, exports and recovery; do not disable production mid-session or claim these actions prevent provider charges. Supabase's Pro spend cap applies only to supported usage categories and is **not** this USD 200 policy; monitor billing dashboard and invoice, configure available provider alerts, and reassess forecasts at least weekly during beta. This is a decision threshold, **not a contractual hard cap**.

| Cost | What to watch | Alarm |
|---|---|---|
| Supabase | Billed project count, production Small compute, PITR, DB size, egress, monthly active users and backup destination | USD 150/180/200 actions above; project/usage alerts; inspect actual bill. Free tier does not meet the three-project/PITR plan. |
| CI | GitHub Actions minutes, macOS consumption | Alarm at 70% of monthly allowance; Maestro runs on RC only (ADR-68), not nightly; iOS integration test remains nightly unless separately changed |
| Sentry | Event quota | Alarm at 70%; a crash loop can exhaust a month's quota in hours, so a spike is itself a P1 signal |
| Apple / Google | Apple Developer USD 99/yr; Google Play USD 25 one-off | Calendar reminder 30 days before Apple renewal — **an expired membership removes the app from sale** |
| Domain | `kasaran.app` renewal | Auto-renew on; the support, privacy, and deletion URLs all depend on it (§5.6 step 4) |

Review actual bill monthly against the USD 200 Supabase policy and monitor projected spend weekly. CI, Sentry, backup destination, domains and store fees are **outside** that ceiling; a future all-in budget needs separate approval. The cost model is an estimate, not a claim that invoices cannot exceed it.

---

## 9. Open questions raised by this plan

| # | Question | Blocks | Recommendation |
|---|---|---|---|
| **OQ-07** | **Transfer/notice approval remains open.** ADR-72 selects Supabase `ap-southeast-1` (Singapore) as the technical production region; this does not approve cross-border basis or create a project. Sentry EU/possible US metadata remains a separate processor disclosure. | DPO/counsel-approved privacy notice (SEC-29/30), real-data beta, then store submission (§7 row 18) | Review processor agreements, recipients, transfer safeguards, retention and accurate notice; keep the real-data gate closed until signed off |
| **OQ-08** | **Bundled vs remote ruleset.** ADR-15 bundles the allocation ruleset in the binary; with no code OTA, a wrong baseline is stuck for days. | Nothing yet, but it caps incident response (§8.3) | Move to remote-with-bundled-fallback, keeping per-plan ruleset pinning (REQ-AE-3). Requires amending ADR-15 |
| **OQ-09** | **Name clearance.** ADR-27 decided "Kasaran"; clearance is a separate step — store availability, Play collision, IPOPHIL trademark, domain ownership. | Store submission (§7 row 19) | Run steps 1, 2, and 4 of §5.6 before any other submission work; they are cheap and can invalidate the name |
| **OQ-12** | **Business model, undecided.** Options: free (no IAP, sustainable cost unfunded); one-time supporter purchase (store IAP review/payment disclosure, preserve core access and no pressure); premium exports/templates (store IAP review, privacy/access inequity and “no upsell” vision tension); planner tier later (new B2B permissions, processor/privacy contracts and payment review). | Monetization, store metadata and privacy review for any paid feature; **not** a license to add v1 upsell | Evaluate sustainability, store rules and “no upsell” vision with owner; do not introduce payment or analytics SDK from this table. |

**Carried forward, unchanged and still counsel-gated:**

- **OQ-01 / SEC-33, SEC-38** — shared-record DPA erasure. Still open, and it now has a deployment consequence: the store-required account-deletion path (§5.3, SEC-34) cannot be finalised until the erasure model for a two-partner plan is settled. Both stores test that path.
- **OQ-02 / SEC-37** — NPC registration and DPO designation.
- **OQ-04** — reference cost values, still unpopulated; budget adequacy cannot ship verified (TC-AE-07 asserts nothing).
