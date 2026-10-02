# Kasaran — Project Brief

*Scope contract for v1. Derived from [problem-brief.md](./problem-brief.md). The v1/AI-phase line in this document is binding — anything below the line does not enter v1 without an explicit written decision to move it.*

## 1. Vision statement

Kasaran is the budgeting ledger Filipino couples actually need: a shared, offline-capable app where a couple planning a ₱30K–₱500K Philippine wedding sets a realistic budget, gets it allocated across local supplier categories by a transparent rule-based engine, and tracks every peso in a running expense ledger. Unlike vendor directories and Western wedding apps, Kasaran treats the costs that actually cause overruns as first-class citizens — crew meals for 15–20 suppliers, out-of-town fees, church aircon premiums, corkage, overtime, and venue power fees are prompted line items, not week-of surprises. It also models how Filipino weddings are really financed: Ninong/Ninang and family pledges have tentative, confirmed, and received states; only received pledges reduce net out-of-pocket, while promised support is shown separately (ADR-22). Both partners edit the same plan from their own phones, on or offline, and it stays consistent. No AI, no marketplace, no upsell — just arithmetic the couple can trust and audit.

## 2. Objectives

The app must:

1. **Get a couple from zero to a credible allocated budget in under 10 minutes**, using the required total budget, wedding date, guest cap, and region inputs (REQ-BS-1). The guest cap is a warning ceiling, not the driving guest count (REQ-BS-5).
2. **Make all six hidden-fee categories unavoidable by design** — crew meals, OOT fees, church aircon, corkage, overtime, and venue power — by prompting for each during setup rather than waiting for the couple to discover them.
3. **Compute gross event total and net couple out-of-pocket as two distinct, always-visible figures**: net is gross minus **received pledges only**. Tentative and confirmed pledges remain expected support and do not reduce net (ADR-22, REQ-PL-2).
4. **Propagate changes to the driving guest count through guest per-head costs automatically** — catering, invitations, favors, seating — so changing 150 guests to 180 updates those items without manual recalculation. Crew meals depend on supplier crew headcount separately and never propagate with guest count (REQ-GM-4).
5. **Keep a complete, auditable expense ledger** where every entry has a date, category, supplier, amount, and payment state, and where planned-vs-actual variance is visible per category and in total.
6. **Let both partners edit concurrently from separate devices, including fully offline**, and converge to a consistent, non-lossy state when connectivity returns.
7. **Produce deterministic, explainable numbers.** Every figure the engine outputs must be traceable to a rule and its inputs. No black-box suggestions, no unexplained recommendations.
8. **Replace the spreadsheet outright** — become the couple's single source of truth for wedding money, with nothing forcing them back to Sheets.

## 3. In scope for v1

Backend + frontend, **rule-based engine only. Explicitly NO AI features of any kind.**

| Area | What v1 includes |
|---|---|
| **Budget setup** | Guided intake: required total budget, wedding date, guest cap (a ceiling), and region (REQ-BS-1). Region taxonomy and destination flag drive regional expectations and OOT prompting (REQ-BS-4); the driving guest count is separate from the cap (REQ-BS-5). Produces an initial category-level allocation. |
| **Rule-based allocation engine** | Deterministic allocation of the total across local supplier categories using a versioned, bundled JSON ruleset and fixed baseline shares (ADR-10/15). The regional index affects expected cost, not allocation shares (ADR-11). Every output is traceable to a rule. Couples can override allocations manually; overrides are preserved and never silently recomputed away. |
| **Expense ledger** | Full CRUD on line items: category, supplier name, estimated amount, actual amount, deposit paid, due date, notes; `paid`/`pending`/`overdue` status is derived, not directly edited (REQ-LG-1/4/5). Planned-vs-actual variance per category and overall. Manual entry only. |
| **Hidden-fee line items** | All six as first-class, prompted item types with their own input shapes — crew meals (per-supplier headcount × per-meal rate), OOT fees (travel / lodging / per-diem per supplier), church aircon premium, corkage (per item type), overtime (hourly rate × projected hours, per supplier), venue power/genset fees. Each defaults to prompted-but-unfilled, so skipping is a visible choice rather than an oversight. |
| **Pledges module** | Record pledges from Ninong/Ninang and family: pledger name, role, pledge type (cash amount or specific item/category), value, status (tentative / confirmed / received). Feeds the gross-vs-net calculation. Shows unfulfilled pledge exposure. |
| **Guest math** | Guest RSVP and priority tiers; the selected driving guest count propagates into guest per-head costs, not flat-rate entries or crew meals. Crew headcount is separate from guest headcount (REQ-GM-4). |
| **Shared editing with offline sync** | Two-partner shared plan. Full offline read and write. Deterministic, rule-based conflict resolution on reconnect (no AI merge, no silent data loss). Change history sufficient to see who changed what. |
| **Platform basics** | PHP-only currency formatting, Philippines-only assumptions, account/auth, plan invite for the second partner. |

## 4. Explicitly out of scope for v1

**None of the following ship in v1.** AI capabilities are deferred to the post-launch AI phases; payment integration has a separate post-launch payments phase (ADR-28). Marketplace remains excluded entirely.

- **OCR contract parsing** — no scanning supplier contracts or receipts to extract line items. v1 entry is manual, by hand.
- **On-device AI categorization** — no local model auto-assigning categories, suppliers, or fee types to entries. Categorization in v1 is user-selected from a fixed taxonomy.
- **Cloud AI reasoning** — no LLM-generated budget advice, negotiation tips, risk warnings, forecasting, or natural-language summaries. The allocation engine is lookup tables and arithmetic, nothing learned or generative.
- **InstaPay / QR Ph payment integration** — no in-app payments, transfers, or bank/e-wallet connections in v1. This is a separate post-launch payments phase, not an AI feature (ADR-28, development-phases phase 25); v1 records payment state but never moves money.
- **Supplier marketplace** — no vendor directory, listings, reviews, ratings, quotes, lead-gen, or booking. That is deliberately the competitors' lane (Nuptl, Vowly), not ours.
- **Chat assistant** — no conversational interface, no chatbot, no natural-language input to any part of the app.

### The v1/AI-phase line — how to test a new idea

Before adding anything to v1, it must pass all four:

1. **Deterministic?** Same inputs always produce the same output. If it involves inference, prediction, or generation, it is AI phase.
2. **Explainable to the couple?** They can see which rule produced the number and why. If the answer is "the model decided," it is AI phase.
3. **Does it move money or touch a payment rail?** If yes, it belongs to the separate post-launch payments phase (ADR-28), not v1 or the AI phases; v1 has no financial-rail compliance scope.
4. **Does it recommend a supplier or broker a relationship?** If yes, it is out of scope entirely, not just deferred — marketplace is not our product.

Anything failing a test goes to the appropriate post-launch backlog or remains excluded entirely, not into v1.

## 5. Success metrics

Measured post-launch against a first cohort. Targets are directional and need calibration against real baseline data (see open items).

1. **Budget accuracy at wedding day.** Share of couples whose final actual gross total lands within **10%** of the budget they set at the end of setup. This is the core proof — it means hidden fees stopped ambushing them. *Target: 60%+.*
2. **Hidden-fee capture rate.** Share of active plans with at least **4 of 6** hidden-fee categories either filled in or explicitly dismissed **more than 60 days before** the wedding date. Measures whether we surface these early rather than late. *Target: 70%+.*
3. **Pledge module adoption and net-view usage.** Share of couples who record at least one pledge **and** view the gross-vs-net comparison more than once. Confirms the sponsorship problem is real and our framing lands. *Target: 50%+.*
4. **Spreadsheet displacement.** Share of couples self-reporting (single in-app survey) that Kasaran is their **only** wedding budget tool, with no parallel spreadsheet. *Target: 50%+.*
5. **Two-partner active use through wedding day.** Share of plans where **both** partners made a ledger edit within the final 30 days before the wedding. Proves the shared-editing and offline work is genuinely used, not just shipped. *Target: 40%+.*

## Assumptions and open items to confirm

1. **OPEN — metric baselines and benchmark data (OQ-04).** The five success targets need real cohort baselines; regional reference-cost benchmarks for budget adequacy still need evidence. Do not invent data to fill this gap. Allocation shares have a decided baseline (ADR-10), separate from missing reference costs.
2. **RESOLVED — offline conflict policy.** Field-level LWW plus immutable change history is ADR-08; the server-assigned ordering timestamp is ADR-21 (REQ-SE-2, REQ-SE-4).
3. **RESOLVED — platform.** Flutter for iOS and Android; web excluded from v1 (ADR-12).
4. **RESOLVED — payment states.** Deposits and balance are explicit (REQ-LG-4); paid/pending/overdue are derived, not manually set (ADR-07, REQ-LG-5).
5. **RESOLVED — active-plan limit.** Exactly one active plan per account (REQ-PLT-3).
