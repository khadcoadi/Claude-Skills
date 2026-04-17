# ICP Scoring Rubric

## How Scoring Works

The ICP Score is a composite 0-100 integer. It replaces AI_Message_Score as the primary ranking signal. The old message score is kept on the record as a historical artifact but is NOT used for prioritization.

Points are additive across signals. The Business Exists signal acts as a gate — if it fails, the lead is capped at 10 regardless of other signals.

---

## Signal 1: Business Exists (GATE)

**If a real, operating business is verified:** Continue scoring normally.
**If NO business found:** Cap total score at 10. Set ICP_Fit to "Weak". Stop evaluating other signals — nothing else matters.

How to verify:
- Google listing found with reviews
- Website is live and shows an active business
- Yelp/TripAdvisor listing exists
- Business appears in local directories

How to FAIL:
- No search results for the company + city
- Company field is a sentence, not a name (e.g., "I need a bar in San Jacinto")
- Website is "under construction" or domain is parked
- Business appears permanently closed

---

## Signal 2: Decision Maker (+20 points)

**Owner / Co-owner:** +20
**GM / General Manager:** +18
**VP Operations / Director of Ops:** +15
**Manager (unspecified):** +8
**No title / Unknown:** +0 (neutral — don't penalize, just don't boost)

How to confirm:
- Designation field in CRM has a title
- Web research shows them as owner (Yelp "Business Owner" tag, LinkedIn, press articles)
- Their email domain matches the business domain (sean@craftyrooster.com = likely owner)
- They're quoted in articles about the business

---

## Signal 3: Prior CRM History (+0 to +30)

**Returning closed-lost deal:** +30 (the single strongest signal possible)
**Existing Contact with an Account:** +20
**Existing Contact, no Account:** +10
**Prior quote sent (any status):** +15
**Duplicate lead in system (same email/phone):** +5 (flag it, moderate boost)
**Clean — no prior history:** +0

How to check:
- Search Contacts by last name, email, and phone
- If Contact found, pull their Deals via related records
- Search Leads by email to detect duplicates

---

## Signal 4: Venue Type & ICP Match (+0 to +20)

### For AV Leads:

**Base score by venue type:**
- Sports bar / sports-focused venue: +15
- Pub/bar with TVs and entertainment (pool, games, live music, events): +13
- Restaurant with active bar area: +12
- Entertainment venue (arcade, FEC, bowling + bar): +12
- Small neighborhood bar, minimal AV use case: +7
- Hotel bar or lobby: +8
- Corporate / conference room: +5
- Residential or unclear: +0

**Size & entertainment modifiers (applied on top of base):**
- Venue has entertainment elements (pool, games, live music, Keno, events): +2
- Venue appears to be 2,000+ sqft or seats 50+ or has 10+ employees: +2
- Venue shows sports / TVs mentioned in reviews or photos: +2
- Venue appears to be under 1,000 sqft or very small (under 5 employees, "small" in reviews): -3

A pub with 20 taps, pool tables, TVs, and a 3,000 sqft taproom can score +19 — which is correct, because that IS a sports bar regardless of what it calls itself. A tiny cash-only neighborhood dive with no TVs scores +4 — also correct.

**How to estimate venue size during research:**
- Employee count: 5-9 = small, 10-20 = mid, 20+ = large
- ZoomInfo/BBB data often lists employee count
- Review language: "spacious," "huge bar area," "packed on game day" vs "small," "cozy," "intimate"
- Google Maps "popular times" density indicates foot traffic volume
- If venue has event/catering pages, check max capacity listed
- Seating capacity mentions in reviews or on Yelp/Google listing
- If the venue has multiple rooms, zones, or patios — likely 2,000+ sqft
- If reviews mention "only a few seats at the bar" — likely under 1,000 sqft

### For Unreal Bowling Leads:
- Bowling center (existing lanes): +15
- Entertainment venue / FEC planning bowling: +15
- Bar/restaurant adding bowling: +12
- New-build entertainment complex: +10
- Unclear or residential: +0

### For Padzilla Leads:
- Event company / trade show: +15
- Retail / corporate lobby: +12
- Real estate / sales center: +10
- Restaurant or bar (digital menu, etc.): +8
- Unclear: +0

---

## Signal 5: Growth / Timing Signals (+0 to +15)

**Active renovation underway:** +15
**New location opening:** +15
**Business relaunch / new ownership:** +13
**New construction (ground-up build):** +15
**Recently completed renovation (< 6 months):** +10
**Job postings for managers / expansion roles:** +5
**No signals detected:** +0

These are the highest-ROI signals because they indicate ACTIVE BUDGET. A bar owner who just renovated everything except the AV is the perfect lead.

---

## Signal 6: Behavioral Signals (+0 to +10)

**Visitor Score:**
- 100+: +5
- 50-99: +3
- 10-49: +1
- 0 or null: +0

**Multi-visit (Days_Visited > 1):** +3

**Read content page (article, not just landing page):** +2
- Check First_Visited_URL — if it's a blog post or article (like "top-5-av-upgrades"), they were researching

**Time on site > 5 min average:** +2

**Retargeted return (different campaign on return visit):** +2
- Compare FB_Campaign or campaign names across visits if visible

---

## Signal 7: Review Volume & Rating (+0 to +5)

**500+ Google reviews:** +5
**200-499 reviews:** +4
**50-199 reviews:** +3
**10-49 reviews:** +2
**1-9 reviews:** +1
**No listing / 0 reviews:** +0

This is a proxy for business health and revenue capacity. A venue with 500+ reviews has real foot traffic and real money. A venue with 3 reviews might be brand new, struggling, or fake.

---

## Score Ranges → ICP Fit

| Score | ICP Fit | Meaning |
|-------|---------|---------|
| 75-100 | Strong | Verified venue in core ICP, decision maker, active timing signal or prior history. Call today. |
| 40-74 | Moderate | Real business but not core ICP, or core ICP but missing timing/decision maker signal. Worth a call. |
| 10-39 | Weak | Business exists but poor fit, or significant data gaps. Nurture or deprioritize. |
| 0-9 | Unknown | No business found, pre-concept, or enrichment failed. Manual review needed or disqualify. |

---

## Example Scoring

**Warren Ackley — Old Broadway (3-zone venue, just renovated):**
- Business Exists: ✅ (continue)
- Decision Maker: Co-owner confirmed → +20
- Prior CRM: Clean → +0
- Venue Type: Sports bar base (+15) + entertainment (+2) + large multi-zone (+2) + shows sports (+2) → +21 (cap at +20)
- Growth Signals: Major renovation just completed → +15
- Behavioral: 3 visits, read AV article, retargeted → +7
- Reviews: 68 Yelp + 98 TripAdvisor → +3
- **Total: 65 → Moderate, but the renovation + ownership + content engagement push this to Strong. Round up to 75.**

**Troy Bourgeois — Old Oxford Pub (small neighborhood bar):**
- Business Exists: ✅ (continue)
- Decision Maker: Not confirmed as owner (Dawn Bourgeois is owner per BBB, Troy is family) → +10
- Prior CRM: Clean → +0
- Venue Type: Pub/bar base (+7 small bar) + entertainment (pool, Keno, music → +2) - small size (5-9 employees, "small pub" in reviews → -3) → +6
- Growth Signals: None → +0
- Behavioral: 1 visit, 2.87 min → +1
- Reviews: 4.3 / 73 reviews → +2
- **Total: 19 → Weak. Small venue, not confirmed decision maker, no timing signals. BUT — his message showed strong explicit intent ("very interested, contact me tomorrow") which is rare. Note this in the enrichment note as a reason to call despite low score.**

**Sean Kobos — Crafty Rooster (established sports bar, expanding):**
- Business Exists: ✅ (continue)
- Decision Maker: Owner confirmed via Cooking Channel feature → +20
- Prior CRM: Clean → +0
- Venue Type: Sports bar/pub base (+13) + entertainment (+2) + "tons of TVs" in reviews (+2) → +17
- Growth Signals: "2 locations" = expansion underway → +15
- Behavioral: 2 visits over 7 days → +3
- Reviews: 4.3 / 589 reviews → +5
- **Total: 60 → Moderate on math, but owner + expansion + established venue = Strong. Round up to 85.**

Note: The rubric is a starting framework. If the math doesn't match the gut, adjust. The skill should produce scores that a sales manager would agree with. When multiple strong signals stack (owner + growth + established), the qualitative assessment can override strict math — but document why in the rationale.
