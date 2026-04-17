---
name: ct-lead-enrichment
description: Researches and enriches Crunchy Tech AV leads with business validation, ICP scoring, call hooks, discovery questions, and drafted emails. Use when the scheduled task check found unenriched AV leads, or when someone says "enrich leads", "run enrichment", or asks to research a specific lead. Runs a three-stage pipeline (research, validate, push) with QC before anything touches CRM. Only drafts emails for AV leads.
---

# CT Lead Enrichment Engine

## YOU ARE HERE BECAUSE LEADS WERE FOUND

The scheduled task already confirmed unenriched AV leads exist. Do not re-check. Proceed directly to processing.

If you were triggered manually for a specific lead, pull that lead's data and proceed.

---

## THREE-STAGE PIPELINE

### ========================================
### STAGE 1: RESEARCH & COMPILE
### ========================================

For each lead, execute these steps in order:

**1A — Pull Lead Data**

Two COQL queries using ZohoCRM_executeCOQLQuery (see crm-patterns.md for exact syntax):

Query 1 — Core fields:
SELECT id, Full_Name, First_Name, Last_Name, Email, Phone, Mobile, Company, Designation, Lead_Status, Lead_Source, Message, Business_Type, Interested_Products, Interested_Services, Sale_Type, Website, City, State, Zip_Code, Country, AI_Message_Score, Attempts, Created_Time, Owner FROM Leads WHERE id = '{lead_id}'

Query 2 — Visit & campaign fields:
SELECT id, Full_Name, Visitor_Score, First_Visited_URL, Referrer, Average_Time_Spent_Minutes, Days_Visited, First_Visited_Time, Last_Visited_Time, FB_Campaign, FB_Ad_Name, Form_URL, Lead_Received_Method, Campaign FROM Leads WHERE id = '{lead_id}'

**1B — Analyze Visit Behavior**

From the data above, note:
- What page they landed on (lp.crunchytech.com/bars/ = AV interest)
- Multi-visit (Days_Visited > 1) = warmer
- Time on site > 5 min = engaged
- Visitor_Score: higher = more engagement
- Did they read a content page (article URL, not just landing page)?
- Were they retargeted (different campaign on return)?

**1C — Web Research (1-5 searches per lead)**

Search 1: `{Company} {City} {State}` — business validation, Google rating, Yelp, website
Search 2 (if business found): `{Company} owner` OR `{Company} renovation` — ownership, growth signals
Search 3 (if website found): WebFetch on the business website. **If NO website found:** search `{Company} {City} facebook` — grab the Facebook business page URL. Many small bars and restaurants have no website but have an active Facebook page with photos, hours, menus, and event posts. That Facebook page becomes the web presence for enrichment purposes — check it for TV photos, event posts, renovation announcements, and ownership info.
Search 4: `{Company} {City} {State} {Lead Full_Name}` — press and article search. Look for local news coverage: openings, renovations, features, profiles, reviews by journalists. These are high-value hooks — the rep can reference them on the call ("Saw the piece in AL.com about the Gulf Shores opening"). If an article is found, fetch it to extract details that inform hooks and discovery questions.
Search 5 (if article found): WebFetch on the article URL to pull details for hooks.

If Company field is garbage (a sentence, not a name): search by lead name + city, or parse Message field. If nothing found, note "No verifiable business found."

**During web research, also estimate venue size.** This affects ICP scoring. Look for:
- Employee count from ZoomInfo, BBB, or LinkedIn (5-9 = small, 10-20 = mid, 20+ = large)
- Seating capacity or sqft mentioned in reviews, website, or Google listing
- Review language clues: "spacious," "huge bar area," "packed on game day" = larger. "Small," "cozy," "intimate" = smaller.
- Multiple rooms, zones, or patios mentioned = likely 2,000+ sqft
- Event/catering pages listing max capacity
- Entertainment elements: pool tables, games, multiple TVs, live music stage, outdoor areas = larger footprint
- "Only a few seats at the bar" = likely under 1,000 sqft

**A pub or bar with decent square footage and entertainment is NOT a weak lead.** A 2,500 sqft pub with pool, TVs, and 20 taps is functionally a sports bar for AV purposes. Score it accordingly. Size and entertainment signals matter more than what the venue calls itself.

**1D — CRM Duplicate Check**

Run ALL of these using ZohoCRM_executeCOQLQuery (see crm-patterns.md for exact COQL syntax):
- Search Contacts by last name: WHERE Last_Name = '{Last_Name}'
- Search Contacts by email: WHERE Email = '{Email}'
- Search Contacts by phone: WHERE Phone = '{Phone}'
- If Contact found: pull Deals via ZohoCRM_getRelatedRecords (Contacts → Deals)
- Search Leads by email for duplicates: WHERE Email = '{Email}' — if count > 1, it's a duplicate

**1E — Score the Lead**

Read `references/scoring-rubric.md` and apply the 7-signal composite:

1. Business Exists — GATE (no business = cap at 10)
2. Decision Maker — +20 if owner/GM confirmed
3. Prior CRM History — +30 for returning lost deal, +20 existing contact w/ account, +15 prior quote
4. Venue Type & ICP Match — base +7 to +15 by type, PLUS size/entertainment modifiers up to +6 (see scoring-rubric.md for details). A large pub with TVs, games, and 20 taps can outscore a generic sports bar.
5. Growth/Timing Signals — +15 for renovation, new location, relaunch
6. Behavioral Signals — +10 max from visits, content reads, retarget
7. Review Volume & Rating — +5 max

Map to ICP_Fit: 75-100=Strong, 40-74=Moderate, 10-39=Weak, 0-9=Unknown

**1F — Draft Enrichment Content**

**IMPORTANT: Visit and ad data from Step 1B gets woven INTO the existing sections — it does NOT get its own section.** Specifically:
- LEAD SNAPSHOT: Source line includes campaign name and landing page. Visit stats on the next line.
- DUE DILIGENCE: Mention visit behavior in the narrative when it changes the read on the lead (multi-visit = warmer, long time on page = engaged, impulse click = set expectations). Don't mention it if it's unremarkable.
- HOOKS: If visit data gives the rep ammo ("she came back 3 times"), put it in a hook. If a press article was found, reference it as a hook — "Mention the AL.com article about the Gulf Shores opening. Shows you did homework." Press references are high-value hooks because they make the rep sound informed and give a natural conversation opener.
- DISCOVERY QUESTIONS: If the landing page tells you what they were looking at, reference it in a question. If a press article revealed details (new concept, opening timeline, ownership change), build a question around it.
- ICP SCORING: Signal 6 uses the actual numbers from Days_Visited, Average_Time_Spent_Minutes, and Visitor_Score.

For ALL leads:
- Hooks: 2-3 specific talking points from research (not generic)
- Discovery Questions: 3-5 questions specific to THIS lead (read `templates/enrichment-note.md` for rules and examples)
- Recommended Action: Call / Email / Nurture / Disqualify

For AV leads ONLY:
- Drafted Email: read `references/email-guidelines.md`
- 3 sentences, under 50 words body
- Sentence 1: Mirror their words
- Sentence 2: Revenue/guest experience framing
- Sentence 3: "When works for a call?"
- Sign with rep's first name from Owner field (see crm-patterns.md for rep mapping)

For non-AV leads: note "Draft email not included for [product] leads"

---

### ========================================
### STAGE 2: VALIDATE & QC
### ========================================

Before writing ANYTHING to CRM, check each lead against these 12 points. Auto-fix minor issues. Exclude leads with major issues.

1. **Business match** — Did research find the RIGHT business? City matches CRM? If not, flag ⚠️ correction.
2. **Score math** — Do breakdown points sum to stated ICP_Score?
3. **Fit label** — Does label match score range? (75-100=Strong, 40-74=Moderate, 10-39=Weak, 0-9=Unknown)
4. **Discovery questions specific** — Could these apply to any lead? If yes, rewrite with enrichment context.
5. **Email tone** (AV only) — No "solutions", "specialize", "thanks for reaching out" opener. Under 50 words. Mirrors lead's words.
6. **No email on non-AV** — If not AV product line, remove any drafted email.
7. **Duplicate check ran** — If skipped, EXCLUDE the lead. Cannot auto-fix.
8. **Prior history flagged** — If prior deal exists, must be hook #1 with ⚠️.
9. **Google rating format** — Must be "X.X / NNN reviews" not just a number.
10. **Action aligns with fit** — Strong ≠ Nurture. Weak ≠ "Call today."
11. **Rep name correct** — Matches Owner field (see `references/crm-patterns.md` for mapping).
12. **Note under 1000 words** — Trim if over.

After validation, proceed only with APPROVED leads. Log excluded leads with reasons.

---

### ========================================
### STAGE 3: PUSH TO CRM
### ========================================

**BEFORE WRITING: Re-read these files to carry full context:**
- `templates/enrichment-note.md` — note structure and discovery question rules
- `references/crm-patterns.md` — CRM write patterns, correct tool names, field API names, rep mapping
- `references/email-guidelines.md` — final email compliance check

**3A — Construct the Note (plain text, no markdown)**

Build per `templates/enrichment-note.md`. Required sections in order:

```
LEAD SNAPSHOT
{contact info, source, landing page, visit data, form message, AI message score}

---

DUE DILIGENCE
{business validation, Google rating, website or Facebook page, owner confirmation, size estimate}
{Press: article reference if found}
{⚠️ ADDRESS CORRECTION if applicable}
{Growth signals if found}
{⚠️ No business found if applicable}

---

PRIOR CRM HISTORY
{None OR ⚠️ EXISTING CONTACT FOUND with deal details}

---

ICP FIT
{Fit label, Score /100, Rationale, Product Line}

---

HOOKS FOR THE CALL
{2-3 specific hooks}

---

DISCOVERY QUESTIONS (for the call)
{3-5 lead-specific questions}

---

DRAFTED FOLLOW-UP EMAIL (AV only)
{Subject + body + signature}
[Rep: review, personalize if needed, send from CRM]

OR: NOTE: Draft email not included for {product} leads.

---

RECOMMENDED ACTION
{Action — reasoning}

---

Enrichment Status: {Complete / Partial}
Enriched: {timestamp}
```

**3B — Pre-Write Verification**

Before each CRM write, verify:
- All required sections present
- Discovery questions reference specific enrichment findings
- Email (if present) passes tone rules
- Score matches fit label
- Prior deal flagged with ⚠️ if exists
- Under 1000 words

If anything fails → fix it, don't write broken data.

**3C — Write Note to CRM**

Use ZohoCRM_createNotes. BOTH path_variables AND Parent_Id in the body are required — omitting either will cause the call to fail.

```
ZohoCRM_createNotes
path_variables: {
  parentRecordModule: "Leads",
  parentRecordId: "{lead_id}"
}
body: {
  data: [{
    Note_Title: "AI Lead Enrichment — {Full_Name} — {Company}",
    Note_Content: "{constructed note — plain text only, no markdown}",
    Parent_Id: {
      id: "{lead_id}",
      module: { api_name: "Leads", id: "1351252000000002175" }
    }
  }]
}
```

**3D — Update Custom Fields**

Use ZohoCRM_updateLeadsRecord. Both path_variables.recordID and Last_Name in the body are required.

```
ZohoCRM_updateLeadsRecord
path_variables: {
  recordID: "{lead_id}"
}
body: {
  data: [{
    id: "{lead_id}",
    Last_Name: "{Last_Name}",
    CT_Enrichment_Status: "Complete",
    ICP_Fit: "{Strong/Moderate/Weak/Unknown}",
    ICP_Score: {0-100},
    Venue_Type: "{Sports Bar/Restaurant/Entertainment/Hotel/Bowling/Other}",
    Location_Count: {integer},
    Google_Rating: "{X.X / NNN reviews}"
  }]
}
```

If field updates fail (fields not created yet), the Note is still valid. Log the error but don't mark as Failed.

---

### ========================================
### STAGE 4: PIXEL NOTIFICATION
### ========================================

After CRM writes complete, send a Pixel bot card to the assigned rep only.

**4A — Determine recipient**

Map the lead's Owner ID to the rep name:
- 1351252000153431001 = Kevin Lacayo
- 1351252000000162033 = Leonardo Moretti
- 1351252000001578206 = TJ Paone

Send to the assigned rep only. Do NOT send copies to Adi Khanna or any other team member.

**4B — Build and send the card**

1. Read `ct-pixel-bot/templates/lead-enrichment-card.json`
2. Replace all ${placeholder} values (see ct-pixel-bot/SKILL.md for the full placeholder list)
3. Sanitize values: escape double quotes, replace newlines with \n
4. Write populated card to `/tmp/pixel-card-{lead_id}.json`
5. Send:
```
bash ct-pixel-bot/send-message.sh "{Rep Name}" --card /tmp/pixel-card-{lead_id}.json
```

**4C — Error handling**

If Pixel delivery fails, log the error and continue. The CRM note is the primary deliverable — a Pixel failure does not fail the enrichment.

---

## SUMMARY REPORT

After all leads processed:
```
ENRICHMENT COMPLETE — {timestamp}
Leads enriched: X
- Strong: X (names)
- Moderate: X (names)
- Weak: X (names)
Excluded by validation: X (names + reasons)
Top priority: {Name} — {why}
```

---

## REFERENCE FILES

Read these as needed during execution:
- `references/scoring-rubric.md` — point weights for each scoring signal
- `references/icp-criteria.md` — ICP fit definitions per product line
- `references/crm-patterns.md` — all Zoho CRM MCP call patterns, correct tool names, and rep mapping
- `references/email-guidelines.md` — AV email tone rules, banned phrases, examples
- `templates/enrichment-note.md` — note template with discovery question rules and examples

---

## RULES

1. Never assume the lead's pain. Keep hooks and emails introductory.
2. Mirror their words. "2 locations" stays "2 locations."
3. Correct CRM data when wrong. Flag with ⚠️.
4. Prior CRM history is the highest-value finding. Always flag prominently.
5. When in doubt, mark Partial. Better incomplete than skipped.
6. Cap at 10 leads per batch.
7. AV emails only. No drafts for Padzilla or Unreal Bowling.
8. The Note is the product. Fields are for filtering. Make the Note scannable, specific, honest.
9. Discovery questions must be specific to what enrichment found. Generic = rewrite.
10. Stage 2 is mandatory. Never skip validation.
