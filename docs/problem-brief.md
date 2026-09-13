# Kasaran — Problem Brief

*Filipino wedding budget planning app. One-page brief for alignment before design.*

## Business story: how Filipino couples budget weddings today

Most couples planning a 2026 Philippine wedding without a full-service planner cobble together three inadequate tools:

- **Spreadsheets (Google Sheets / Excel).** The default. Flexible but manual: no supplier templates, no reminders, and every couple rebuilds the same categories from scratch. Formulas break, versions drift between partners, and there's no structure for the line items that actually blow up Filipino wedding budgets.
- **Generic Western wedding apps (The Knot, Zola, WeddingWire).** Built around USD budgets, US vendor marketplaces, and Western wedding structure (rehearsal dinner, open bar, tipping norms). They don't model peso pricing realities, local supplier categories, or Filipino traditions like the sponsor system. Vendor marketplaces are US-only, so the discovery value is dead weight here.
- **Local competitors — Nuptl and Vowly.** Closer to the market, but they operate primarily as vendor directories and inspiration portals rather than active financial calculators or ledger systems. They surface *who* to hire and *what's trending*, not *what it truly costs you out of pocket* once hidden fees and sponsor pledges are accounted for. That leaves the budgeting-first lane open.

**Where they all fail for 2026 PH:** none of them model the two things that decide whether a Filipino couple goes over budget — the hidden fees layered onto local suppliers, and the sponsorship pledges that change the couple's real out-of-pocket number.

## The "hidden fee" problem

Filipino wedding costs are rarely a single sticker price. Generic tools capture the headline (photographer ₱X, catering ₱Y) and miss the surcharges that stack on top:

- **Crew meals.** Every supplier feeds their team on the day. With 15–20 suppliers (photo/video, HMUA, coordination, band, lights & sound, etc.), crew meals become a real per-head line item that couples forget until the caterer's final count.
- **OOT (out-of-town) fees.** Suppliers charge travel, lodging, and per-diem when the venue is outside their base city. Invisible in generic budgets, material for destination or province weddings.
- **Church aircon premiums.** Air-conditioned ceremonies commonly carry a ₱5,000–₱15,000 add-on that no Western app has a field for.
- **Corkage fees.** Venues and caterers charge corkage on outside food, cake, drinks, or lechon — often a surprise line.
- **Overtime charges.** Receptions run long. Venues, caterers, coordinators, and bands bill by the hour past the contracted end time — one of the biggest single-day overruns.
- **Venue power fees.** Generator use, power surcharges, and electrical/genset requirements for garden and outdoor venues that don't have sufficient supply on site.

**What it costs couples:** these are individually small but collectively add up to a meaningful share of the budget. Because they surface late (final billing, week-of), they arrive exactly when there's no room left to absorb them — forcing panic cuts or borrowing. Kasaran's opportunity is to make these first-class, expected line items instead of end-of-planning surprises.

## The sponsorship problem

Filipino weddings are partly funded by others, and no tool tracks it:

- **Ninong/Ninang (principal sponsors)** and **family members** pledge cash or cover specific items (the gown, the venue, the mobile bar).
- These pledges live in group chats, verbal promises, and memory — not in the budget.
- As a result, couples can't distinguish **gross event budget** (what the wedding costs) from **true out-of-pocket** (what the couple personally pays after pledges). They over- or under-estimate their own exposure and can't plan cash flow.

Kasaran's opportunity: track pledges (who, what, how much, confirmed vs. tentative) and show two clear numbers — event gross vs. couple net.

## Target user

A couple planning their own wedding in the Philippines:

- **Budget:** ₱30K–₱500K sweet spot — the majority of standard local hotel and garden weddings. Civil or micro-weddings under ₱30K are supported simply by omitting line items.
- **No full-service planner** (maybe an on-the-day coordinator at most), so they carry the budgeting themselves. Full-service coordinators / on-the-day managers are a possible secondary portal or collaboration tier in a future release, not launch.
- Comfortable with phones and spreadsheets, but not with the hidden-fee and sponsorship math that trips them up.
- Both partners want a shared, single source of truth.

## Naming note (decided)

**Name: Kasaran (final).** Confirmed by the decision-maker (decision-log ADR-27, GIV-07 resolved, OQ-06 closed). For the record, "kasaran" reads closer to "roughness/coarseness" in Filipino while "kasalan" means wedding — this was raised, acknowledged, and set aside. The decision is to proceed with **Kasaran** as the brand, treating it as a distinct, ownable mark rather than a literal Tagalog word. Cleared for logo/domain.

## Confirmed decisions (locked for Prompt 2)

1. **Competitor positioning:** Confirmed — Nuptl and Vowly are directory/inspiration-first, not financial calculators or ledgers. Budgeting-first is our differentiated lane.
2. **Currency & market scope:** Confirmed — v1 is Philippines-only, PHP-only. No multi-currency, no international weddings.
3. **Budget band:** Confirmed — target ₱30K–₱500K (standard hotel/garden weddings). Sub-₱30K civil/micro-weddings supported by omitting line items. No premium (>₱500K) focus for v1.
4. **Personas:** Confirmed — self-planning couple is the sole primary persona at launch. Coordinators/on-the-day managers = future secondary portal/collaboration tier.
5. **Hidden-fee launch set:** Confirmed and expanded — crew meals, OOT fees, church aircon premiums, corkage, **plus overtime charges and venue power fees.**
6. **Sponsorship model:** Confirmed — show gross event total and net couple out-of-pocket, with pledge status (confirmed vs. tentative).

7. **Name:** **Kasaran** — final (decision-log ADR-27). The "roughness" vs. "kasalan/wedding" nuance was acknowledged and set aside; adopted as a distinct brand mark. Cleared for logo/domain.

*All scoping decisions locked, including the product name (Kasaran, decision-log ADR-27). No open naming item.*
