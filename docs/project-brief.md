# Kasaran — Project Brief

*Scope contract for v1. Derived from [problem-brief.md](./problem-brief.md). The v1/AI-phase line in this document is binding — anything below the line does not enter v1 without an explicit written decision to move it.*

## 1. Vision statement

Kasaran is the budgeting ledger Filipino couples actually need: a shared, offline-capable app where a couple planning a ₱30K–₱500K Philippine wedding sets a realistic budget, gets it allocated across local supplier categories by a transparent rule-based engine, and tracks every peso in a running expense ledger. Unlike vendor directories and Western wedding apps, Kasaran treats the costs that actually cause overruns as first-class citizens — crew meals for 15–20 suppliers, out-of-town fees, church aircon premiums, corkage, overtime, and venue power fees are prompted line items, not week-of surprises. It also models how Filipino weddings are really financed: Ninong/Ninang and family pledges are tracked with confirmed/tentative status, so the couple always sees two honest numbers side by side — the gross event total and their true net out-of-pocket. Both partners edit the same plan from their own phones, on or offline, and it stays consistent. No AI, no marketplace, no upsell — just arithmetic the couple can trust and audit.

## 2. Objectives

The app must:

1. **Get a couple from zero to a credible allocated budget in under 10 minutes**, using only a total budget figure, guest count, venue type, and ceremony type as inputs.
2. **Make all six hidden-fee categories unavoidable by design** — crew meals, OOT fees, church aircon, corkage, overtime, and venue power — by prompting for each during setup rather than waiting for the couple to discover them.
3. **Compute gross event total and net couple out-of-pocket as two distinct, always-visible figures**, with pledge status (confirmed vs. tentative) affecting the net calculation in a way the couple can trace.
4. **Propagate guest count changes through every per-head cost automatically** — catering, crew meals, invitations, favors, seating — so changing 150 guests to 180 updates the whole budget without manual recalculation.
5. **Keep a complete, auditable expense ledger** where every entry has a date, category, supplier, amount, and payment state, and where planned-vs-actual variance is visible per category and in total.
6. **Let both partners edit concurrently from separate devices, including fully offline**, and converge to a consistent, non-lossy state when connectivity returns.
7. **Produce deterministic, explainable numbers.** Every figure the engine outputs must be traceable to a rule and its inputs. No black-box suggestions, no unexplained recommendations.
8. **Replace the spreadsheet outright** — become the couple's single source of truth for wedding money, with nothing forcing them back to Sheets.

## 3. In scope for v1

Backend + frontend, **rule-based engine only. Explicitly NO AI features of any kind.**

| Area | What v1 includes |
|---|---|
| **Budget setup** | Guided intake: total budget, wedding date, guest count, venue type (hotel / garden / other), ceremony type (church / civil / other), OOT flag. Produces an initial category-level budget. |
| **Rule-based allocation engine** | Deterministic allocation of the total across local supplier categories using versioned lookup tables and heuristics keyed to budget band, guest count, and venue/ceremony type. Every output traceable to a rule. Rules are data, editable without a code change. Couple can override any allocation manually; overrides are preserved and never silently recomputed away. |
| **Expense ledger** | Full CRUD on line items: category, supplier name, quoted amount, actual amount, payment state, due date, notes. Planned-vs-actual variance per category and overall. Manual entry only. |
| **Hidden-fee line items** | All six as first-class, prompted item types with their own input shapes — crew meals (per-supplier headcount × per-meal rate), OOT fees (travel / lodging / per-diem per supplier), church aircon premium, corkage (per item type), overtime (hourly rate × projected hours, per supplier), venue power/genset fees. Each defaults to prompted-but-unfilled, so skipping is a visible choice rather than an oversight. |
| **Pledges module** | Record pledges from Ninong/Ninang and family: pledger name, role, pledge type (cash amount or specific item/category), value, status (tentative / confirmed / received). Feeds the gross-vs-net calculation. Shows unfulfilled pledge exposure. |
| **Guest math** | Guest list count with tiers (confirmed / invited / tentative), and propagation of headcount into every per-head cost in the ledger and allocation. Crew headcount tracked separately from guest headcount. |
| **Shared editing with offline sync** | Two-partner shared plan. Full offline read and write. Deterministic, rule-based conflict resolution on reconnect (no AI merge, no silent data loss). Change history sufficient to see who changed what. |
| **Platform basics** | PHP-only currency formatting, Philippines-only assumptions, account/auth, plan invite for the second partner. |

## 4. Explicitly out of scope for v1 — deferred to the AI phase

**None of the following ship in v1.** They are the AI phase, and they stay there.

- **OCR contract parsing** — no scanning supplier contracts or receipts to extract line items. v1 entry is manual, by hand.
- **On-device AI categorization** — no local model auto-assigning categories, suppliers, or fee types to entries. Categorization in v1 is user-selected from a fixed taxonomy.
- **Cloud AI reasoning** — no LLM-generated budget advice, negotiation tips, risk warnings, forecasting, or natural-language summaries. The allocation engine is lookup tables and arithmetic, nothing learned or generative.
- **InstaPay / QR Ph payment integration** — no in-app payments, transfers, or bank/e-wallet connections. v1 records that a payment happened; it never moves money.
- **Supplier marketplace** — no vendor directory, listings, reviews, ratings, quotes, lead-gen, or booking. That is deliberately the competitors' lane (Nuptl, Vowly), not ours.
- **Chat assistant** — no conversational interface, no chatbot, no natural-language input to any part of the app.

### The v1/AI-phase line — how to test a new idea

Before adding anything to v1, it must pass all four:

1. **Deterministic?** Same inputs always produce the same output. If it involves inference, prediction, or generation, it is AI phase.
2. **Explainable to the couple?** They can see which rule produced the number and why. If the answer is "the model decided," it is AI phase.
3. **Does it move money or touch a payment rail?** If yes, it is AI phase — payments are bundled there deliberately, to keep v1 free of financial-rail compliance scope.
4. **Does it recommend a supplier or broker a relationship?** If yes, it is out of scope entirely, not just deferred — marketplace is not our product.

Anything failing a test goes to a backlog document, not into v1.

## 5. Success metrics

Measured post-launch against a first cohort. Targets are directional and need calibration against real baseline data (see open items).

1. **Budget accuracy at wedding day.** Share of couples whose final actual gross total lands within **10%** of the budget they set at the end of setup. This is the core proof — it means hidden fees stopped ambushing them. *Target: 60%+.*
2. **Hidden-fee capture rate.** Share of active plans with at least **4 of 6** hidden-fee categories either filled in or explicitly dismissed **more than 60 days before** the wedding date. Measures whether we surface these early rather than late. *Target: 70%+.*
3. **Pledge module adoption and net-view usage.** Share of couples who record at least one pledge **and** view the gross-vs-net comparison more than once. Confirms the sponsorship problem is real and our framing lands. *Target: 50%+.*
4. **Spreadsheet displacement.** Share of couples self-reporting (single in-app survey) that Kasaran is their **only** wedding budget tool, with no parallel spreadsheet. *Target: 50%+.*
5. **Two-partner active use through wedding day.** Share of plans where **both** partners made a ledger edit within the final 30 days before the wedding. Proves the shared-editing and offline work is genuinely used, not just shipped. *Target: 40%+.*

## Assumptions and open items to confirm

1. **Metric targets are guesses.** The five percentages above are placeholders. We have no baseline for typical PH wedding budget overrun, so metric 1 in particular needs a real reference point before we commit to 10% / 60%.
2. **Allocation rule source data.** The engine needs actual PH category benchmarks (what share of a ₱300K wedding typically goes to catering, venue, photo/video, etc.) for the ₱30K–₱500K band. Where do we source these — your own research, supplier quotes, published data? This is the engine's substance and I don't want to invent the numbers.
3. **Offline conflict-resolution policy.** "Deterministic, non-lossy" needs a concrete rule (field-level last-write-wins, per-entry ownership, or explicit conflict surfacing for the couple to resolve). Materially affects data model and sync complexity.
4. **Platform.** Not decided yet. Mobile-first implies native or cross-platform mobile, but offline-first plus shared editing needs a call on iOS / Android / web, and whether web is in v1 at all.
5. **Payment states.** I proposed quoted / committed / partially paid / settled. Confirm this matches how couples actually think about supplier payment stages — reservation fee → downpayment → balance is common locally and may need explicit modeling.
6. **Single wedding per account?** Assuming one active plan per couple for v1. Confirm.
