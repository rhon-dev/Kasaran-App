# Kasaran — Deployment Plan

*Inputs: [design.md](./design.md), [security-plan.md](./security-plan.md), [testing-plan.md](./testing-plan.md), [decision-log.md](./decision-log.md).*

---

## 0. Precondition check

| Precondition | Status | Source |
|---|---|---|
| Backend / data-store ADR is DECIDED | ✅ **DECIDED** — Supabase (Postgres + Auth + RLS) | ADR-16, 2026-09-13 |
| App name ADR is DECIDED | ✅ **DECIDED** — "Kasaran" | ADR-27, 2026-09-14 (OQ-06 closed) |

Both preconditions are met, so this is a single-option plan for Supabase and the store metadata uses the real name. **No `NAME PENDING` marker is needed.**

### 0.1 Two gaps that affect this document

Neither triggers the stop condition, but both change what this plan can promise.

**(a) There is no data residency ADR.** §2 was requested "including region and its relation to the data residency ADR." I searched the doc set: no residency decision exists. I have not invented one. §2.2 states what this plan *assumes*, why it matters legally, and logs it as **OQ-07** for you to decide. It is not a blocker for staging, but it must be settled before the privacy notice is published, because SEC-30 requires disclosing data recipients and locations.

**(b) Platform conflict — with a material consequence this time.** §3 asks for "Expo EAS Build or Fastlane" and "Expo-managed or bare RN." Those are React Native concepts. **ADR-12 locks the platform as Flutter**, and GIV-02 records React Native as SUPERSEDED.

This is not a naming quibble. It removes a capability your §8 reasoning depends on:

> **Flutter has no supported over-the-air code push.** Dart is AOT-compiled for release builds; there is no Flutter equivalent of EAS Update or CodePush in the first-party toolchain. Under React Native, a JS-only hotfix can reach users in minutes. Under Flutter, **every code fix requires a store release.**

Your §8 says "a native iOS fix can take days, which is why the OTA policy in section 3 matters." Under Flutter that mitigation largely does not exist, so §3.5 replaces the OTA policy with the levers that *do* exist, and §8 is written against the honest worst case rather than assuming a hotfix channel.

**Compounding this:** ADR-15 bundles the allocation ruleset as a **JSON asset inside the app binary**. Combined with no OTA, a wrong baseline percentage or a bad regional modifier cannot be corrected without a full store release on both platforms. Given the reference-cost values are still unpopulated (OQ-04), that is a live operational risk. Mitigation options are in §3.6; changing it requires amending ADR-15, which I am not doing unilaterally.

---

## 1. Environments

| | **Local dev** | **Staging** | **Production** |
|---|---|---|---|
| Backend URL | `http://localhost:54321` (Supabase CLI) | `https://kasaran-staging.supabase.co` | `https://kasaran-prod.supabase.co` |
| API path | `/v1/sync/*` | `/v1/sync/*` | `/v1/sync/*` |
| Database instance | Local Postgres in Docker, ephemeral | Dedicated Supabase project, separate from prod | Dedicated Supabase project, PITR enabled |
| Auth tenant | Local Supabase Auth, throwaway users | Staging Auth project — **separate user pool**, no prod identities | Production Auth project |
| Seeded data policy | Fixtures FIX-A / FIX-B / FIX-C (testing-plan §3) loaded on `db reset` | **Synthetic only** — generated from the same three fixtures plus a generator for volume | **None.** Real user data only |
| Migrations applied | Automatically on reset | Automatically on merge to `main` | Manually gated (§2.3) |
| Who can access | The maintainer, locally only | Maintainer + any future collaborator; credentials in CI secrets | **Maintainer only.** MFA required (SEC-27) |
| Client build pointed at it | Debug build, `--dart-define=ENV=local` | Internal TestFlight / Play internal track | App Store / Play production |
| Crash reporting | Disabled | Sentry, `environment=staging` | Sentry, `environment=production` |

### 1.1 Production data is never copied to staging

**Stated explicitly and treated as a hard rule.** No production database dump, PITR restore, table export, or single-row copy is ever loaded into staging or a local machine. Production holds names, wedding dates, sponsor identities, guest lists, and financial detail; copying it into a lower environment multiplies the number of places a breach can originate and defeats SEC-22's tenant isolation model, since staging has looser access.

**What staging uses instead:**

1. **The three committed fixtures** (FIX-A NCR, FIX-B Boracay, FIX-C Iloilo) as the canonical realistic plans. They already have hand-verified expected values, so staging doubles as a place to confirm the numbers match production behaviour.
2. **A synthetic volume generator** for load-shaped data: N plans × M ledger entries × K change-log rows, with names drawn from a fixed fake-name list, amounts from plausible ranges, and Ninong/Ninang roles distributed realistically. Deterministic from a seed so bugs reproduce.
3. **Synthetic pairing sets** — pre-paired two-account plans for testing shared editing and removal, including the demo pair used for store review (§5.4).

If a production bug cannot be reproduced from synthetic data, the fix is to **extend the generator**, not to copy production. A production-only bug is investigated via logs (which carry UUIDs only, never content — SEC-28) and by asking the affected user directly.

---

## 2. Backend deployment

### 2.1 Hosting

Per **ADR-16**: Supabase managed Postgres, with Supabase Auth and Row-Level Security. Two projects — `kasaran-staging` and `kasaran-prod` — never sharing a database, an Auth pool, or a service-role key.

The backend surface is deliberately thin (design.md §2.4): two idempotent endpoints over one append-only table, plus auth. Deployable units:

| Unit | What it is | How it deploys |
|---|---|---|
| Schema + RLS policies | SQL migrations in `supabase/migrations/` | `supabase db push`, gated (§2.3) |
| Sync endpoints | Postgres RPC functions (`sync_push`, `sync_pull`) | Same migration pipeline |
| Auth config | Providers, token TTL (SEC-03), email templates | Declarative config in `supabase/config.toml`, reviewed in PR |
| Feature flags / min-client | A small `app_config` table (§3.6, §4.4) | Data change, no deploy |

### 2.2 Region — and the residency gap

**Chosen region: `ap-southeast-1` (Singapore).** It is Supabase's closest region to the Philippines; expected round-trip from Metro Manila is roughly 30–60 ms, which matters little for a local-first app that syncs in the background but does matter for sign-in and first-device replay (design.md §2.5).

**There is no Supabase region in the Philippines.** So Philippine personal data will be stored outside the country. This is a decision with legal weight and **no ADR currently covers it** (see §0.1a):

- The Data Privacy Act of 2012 does **not** mandate local storage. Cross-border transfer is permitted.
- But the personal information controller remains **accountable** for data transferred abroad, and must ensure comparable protection.
- **SEC-30 already requires the privacy notice to state recipients and locations.** That notice cannot be finalised until this is decided, because it must name Singapore.

**Logged as OQ-07 — data residency.** Options: accept Singapore and disclose it (recommended, and what this plan assumes); or require in-country storage, which would mean leaving Supabase and rebuilding auth. Do not let this drift — it gates the privacy notice, which gates store submission (SEC-30, §5.1).

### 2.3 CI/CD stages, in order, with gates

```
① PR opened
   ├─ dart analyze + money-path lint          gate: zero violations (TC-GEN-01)
   ├─ domain unit tests incl. all 3 fixtures  gate: 8/8 fixture TCs green
   ├─ widget tests + golden verify            gate: no unreviewed golden diff
   ├─ integration_test (Android emulator)     gate: green
   ├─ TENANT ISOLATION SUITE                  gate: TC-SEC-01 green — BLOCKING
   ├─ migration forward/backward              gate: TC-MIG-01..03 green
   └─ secret scan                             gate: clean (SEC-26)
        ↓ all green + human review
② Merge to main
   ├─ migrations applied to STAGING automatically
   ├─ staging smoke: sync push/pull round-trip
   └─ nightly: iOS integration_test + Maestro E2E both platforms (TC-E2E-01)
        ↓
③ Release candidate cut (tag vX.Y.Z)
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
- Any change to `change_log`'s shape. This one is the most dangerous in the whole schema: it is the sync unit (design.md §2.1), so a client that cannot write a valid `change_log` row cannot sync **at all** — it does not degrade, it stops.

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

---

## 3. Mobile build tooling

### 3.1 Project type — the question does not apply as asked

The request asks whether the app is **Expo-managed or bare React Native**. Neither: **ADR-12 locks Flutter.** For completeness, the RN counterfactual is worth one line because it points the same way: this app needs **SQLCipher-backed SQLite** (SEC-12, via `drift` + `sqlcipher_flutter_libs`), which requires native linking. Under React Native that would have forced a **bare** project, ruling out Expo-managed anyway. The native-crypto requirement drives the answer on either platform.

### 3.2 Build tooling decision: **Fastlane** (+ GitHub Actions)

**Expo EAS Build is not an option** — EAS builds React Native / Expo projects; it does not build Flutter apps. So the stated choice is resolved by the platform, not by preference. Justified against the three criteria anyway:

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

**Policy: no over-the-air code updates in v1. Every code change ships through the stores.**

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

**Avoiding OTA/backend desync.** With no code OTA, the classic desync (patched JS bundle expecting a backend that has not shipped) cannot occur. The remaining desync is **old client vs new backend**, addressed by three layers already specified: the one-release backward-compatibility rule (§2.4), the old-client compatibility probe run after every production migration (§2.4), and the forced-update floor (§4.4). If a third-party Flutter code-push tool is ever adopted, the four prohibitions above become the hard boundary, and patched builds must still pass the tenant-isolation suite (TC-SEC-01) before release.

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
                      → PHASED RELEASE over 7 days: 1% → 2% → 5% → 10% → 20% → 50% → 100%
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

**When the floor is raised:** only when an old client would be *unsafe to sync* — it writes a `change_log` shape the backend no longer accepts, mishandles `server_ts` ordering, or misses a security fix. Not for feature parity. Raising the floor is a production change requiring §2.3 gating, and the deprecation window is **two minor releases or 90 days, whichever is longer**, tracked by client-version telemetry before any contract-phase migration (§2.4).

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
| Privacy policy URL | Required. **Blocked on OQ-07** — must name the data location (§2.2, SEC-30) |
| Account deletion URL | Required by both stores (SEC-40) |
| Languages | English (ux-spec §8.4) |
| Devices | iPhone only in v1; iPad not declared. No device-location permission requested (SEC-41) |

### 5.2 Screenshots and age rating

**Screenshots** — must show real, populated data (the FIX-A plan), never empty states (§5.5):

| Platform | Required set |
|---|---|
| iOS | 6.7" (1290×2796) and 6.5" (1242×2688) — 3–5 each: dashboard bento, ledger with hidden fees, pledges showing net vs expected, guest what-if, change log |
| Android | Phone screenshots ×4–8 (min 1080px), plus 1024×500 feature graphic and 512×512 icon |

**Age rating answers:** no violence, no sexual content, no profanity, no gambling or simulated gambling, no drug references, no unrestricted web access, no user-generated content shared publicly. Result: **4+ / Everyone**.

### 5.3 Privacy labels — pulled from security-plan §6

Transcribed from security-plan.md §6.2 and §6.3; must match the §6.1 data inventory exactly (SEC-39).

**Apple App Privacy:** Contact Info (email, name) — linked, not tracking. Financial Info (budget, pledges, amounts) — linked, not tracking. User Content (supplier/sponsor/guest names, notes) — linked, not tracking. Identifiers (account id) — linked, not tracking. **Usage Data: not collected in v1. Location: not collected** — the self-selected region is declared as User Content, not Location (SEC-41).

**Google Play Data Safety:** collects Personal (name, email), Financial, and other user content. **No third-party sharing** in the Play sense (Supabase is a processor). Encrypted in transit (SEC-17) ✅. Encrypted at rest on device (SEC-12) ✅. Users can request deletion in-app (SEC-34) ✅. Not used for tracking ✅.

**Account deletion path (both stores require it):** in-app deletion under Shared Access / account settings (SEC-34), plus a publicly reachable deletion-instructions URL for Apple (SEC-40). Deletion behaviour follows SEC-33 — **and note the open dependency:** the shared-record erasure model is still counsel-gated (OQ-01), so the deletion flow's exact behaviour on a two-partner plan is not finalised. This is a genuine submission risk, not a formality: both stores check that the deletion path works.

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
| 2 | All fixture calculations exact | TC-FIX-A1/A2/B1/B2/C1/C2, TC-PL-19, TC-AE-05 | 8/8 green; FIX-C net = ₱335,750.00 | NOT MET |
| 3 | Full MVP E2E on both platforms | TC-E2E-01 | 20/20 steps + offline gate, iOS and Android | NOT MET |
| 4 | Sync conflict matrix green both platforms | testing-plan §5 (10 rows) | 10/10, incl. clock-skew TC-SE-20 and the LWW/removal asymmetry | NOT MET |
| 5 | Offline matrix green | TC-OF-01…17 | 8 entity rows + 9 durability rows; TC-OF-10 string scan finds zero prohibited words | NOT MET |
| 6 | Device at-rest security on real hardware | TC-SEC-03, TC-SEC-07…10, SEC-12/13/14/16/28 | Simulator results do not count | NOT MET |
| 7 | Migrations forward/backward + old-client probe | TC-MIG-01…03, §2.4 | Green, and the N−1 replay set passes against production schema | NOT MET |
| 8 | **Backup verified by an actual restore drill with recorded duration** | TC-BAK-02, SEC-27 | Restore to a scratch project completed within the last 7 days; row counts and `change_log` checksum verified; **wall-clock duration recorded in the drill log**. A drill without a recorded duration is FAIL | NOT MET |
| 9 | Zero open S1/S2 defects | testing-plan §9 | Count = 0 | NOT MET |
| 10 | **Rollback rehearsed once in staging** | §2.6 | A code rollback **and** an additive-migration rollback both performed in staging, with the outcome and duration written up. Not a thought experiment | NOT MET |
| 11 | Monitoring and alerting live | §7.1 | All named alerts firing correctly, verified by deliberately tripping at least one | NOT MET |
| 12 | Error tracking with release tagging | §7.2 | Sentry receiving events tagged with version + build + git SHA, **and PII scrubbing verified** (SEC-28) | NOT MET |
| 13 | Support intake channel live | §7.3 | Address reachable, in-app link works, response-time expectation published | NOT MET |
| 14 | Rollback decision owner named | §7.4 | A named person, reachable, with documented authority | NOT MET |
| 15 | Secrets audit | SEC-26 | CI secret scan clean; built artifact contains no service-role key | NOT MET |
| 16 | Store privacy labels match inventory | SEC-39, §5.3 | Submitted labels diffed against security-plan §6.1; zero mismatch | NOT MET |
| 17 | Account deletion path live | SEC-34, SEC-40 | In-app deletion works end-to-end; public URL live | NOT MET |
| 18 | Privacy notice published | SEC-30 | Live URL naming data location — **blocked on OQ-07** | NOT MET |
| 19 | Name clearance | §5.6, OQ-09 | Store name availability confirmed on both platforms; domain owned | NOT MET |

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

Sentry, `environment` set per §1, **releases tagged `kasaran@<semver>+<build>` with the git SHA** so a crash maps to an exact artifact.

**Non-negotiable configuration constraint:** Sentry's default breadcrumbs and context can capture exactly what SEC-28 forbids — peso amounts tied to a user, sponsor and guest names, emails, tokens. A `beforeSend` scrubber must strip these, and **that scrubbing is itself verified** by TC-SEC-10 extended to crash payloads. Shipping Sentry unscrubbed would turn the error tracker into the largest PII leak in the system.

### 7.3 Support intake

Single channel: `support@kasaran.app`, linked from an in-app "Get help" item. Published expectation: response within 2 business days (honest for a solo maintainer — see §8.1). Auto-reply confirms receipt and links the privacy and deletion pages.

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

| Cost | What to watch | Alarm |
|---|---|---|
| Supabase | DB size, egress, monthly active users, PITR retention | Email at 70% of any plan quota; the free tier's idle-project pause is a demo hazard (security-plan §3) |
| CI | GitHub Actions minutes, **macOS multiplier ≈ 10×** | Alarm at 70% of the monthly allowance; iOS builds are the dominant cost and are already restricted to RC + nightly (§3.2) |
| Sentry | Event quota | Alarm at 70%; a crash loop can exhaust a month's quota in hours, so a spike is itself a P1 signal |
| Apple / Google | Apple Developer USD 99/yr; Google Play USD 25 one-off | Calendar reminder 30 days before Apple renewal — **an expired membership removes the app from sale** |
| Domain | `kasaran.app` renewal | Auto-renew on; the support, privacy, and deletion URLs all depend on it (§5.6 step 4) |

Reviewed monthly against a stated budget ceiling. For a student-scale project the binding constraints will be macOS CI minutes and Supabase egress, in that order.

---

## 9. Open questions raised by this plan

| # | Question | Blocks | Recommendation |
|---|---|---|---|
| **OQ-07** | **Data residency.** No ADR covers where PH personal data is stored. This plan assumes Supabase `ap-southeast-1` (Singapore); there is no PH region. | Privacy notice (SEC-30) → store submission (§7 row 18) | Accept Singapore and disclose it explicitly in the privacy notice. The alternative — in-country storage — means leaving Supabase and rebuilding auth |
| **OQ-08** | **Bundled vs remote ruleset.** ADR-15 bundles the allocation ruleset in the binary; with no code OTA, a wrong baseline is stuck for days. | Nothing yet, but it caps incident response (§8.3) | Move to remote-with-bundled-fallback, keeping per-plan ruleset pinning (REQ-AE-3). Requires amending ADR-15 |
| **OQ-09** | **Name clearance.** ADR-27 decided "Kasaran"; clearance is a separate step — store availability, Play collision, IPOPHIL trademark, domain ownership. | Store submission (§7 row 19) | Run steps 1, 2, and 4 of §5.6 before any other submission work; they are cheap and can invalidate the name |

**Carried forward, unchanged and still counsel-gated:**

- **OQ-01 / SEC-33, SEC-38** — shared-record DPA erasure. Still open, and it now has a deployment consequence: the store-required account-deletion path (§5.3, SEC-34) cannot be finalised until the erasure model for a two-partner plan is settled. Both stores test that path.
- **OQ-02 / SEC-37** — NPC registration and DPO designation.
- **OQ-04** — reference cost values, still unpopulated; budget adequacy cannot ship verified (TC-AE-07 asserts nothing).
