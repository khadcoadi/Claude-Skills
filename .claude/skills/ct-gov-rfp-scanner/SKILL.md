---
name: ct-gov-rfp-scanner
description: >
  Searches SAM.gov for government AV/conferencing/display RFPs and produces
  full opportunity briefs with scope, programming/control analysis, Q&A
  summary, red flags, and downloadable solicitation documents. Use whenever
  someone says "scan SAM.gov", "find government AV bids", "run the RFP
  scanner", "check for government opportunities", or asks about federal AV
  solicitations. Also triggers on a schedule when no user prompt is present.
  Always run this skill — do not attempt a SAM.gov search without it.
---

# ct-gov-rfp-scanner

Searches SAM.gov for government AV/conferencing/display solicitations,
scans for disqualifiers, scores against CT's
profile, and produces a full brief per qualifying opportunity including
scope narrative, programming/control analysis, Q&A digest, red flags,
and all documents available for download.

---

## Execution Discipline (scheduled/unattended runs)

This skill runs on a schedule with no human watching. A turn that emits
only narration or a question will silently end the run mid-flight, because
there is nobody to reply. Follow these rules:

- **Every assistant turn must contain at least one tool call** until you
  emit the final one-line completion log (either the "No new gov AV opps"
  line or the stamp-messenger send). No exceptions.
- **Do not narrate intent.** Do not write "Now I'll...", "Next, I'll...",
  "Building payloads...", or any other transition sentence as a standalone
  message. Execute directly.
- **Do not ask clarifying questions.** If information is missing or
  ambiguous, pick the most defensible default based on the skill's rules
  and continue. Log the assumption in the final summary if it's material.
- **Never end a turn with a question.** A question with no tool call is a
  dead stop in unattended mode.
- **Brief updates are fine**, but only when attached to a tool call in the
  same turn (e.g., one sentence of context + the next Bash/Edit/Skill
  call). Standalone text = silent failure.
- **No corpus echo.** Do not `print()`, `cat`, `head`, or `tail` the
  contents of `corpus`, notice descriptions, or extracted PDF/DOCX/XLSX
  text to the terminal. After `scored.json` exists, the only remaining
  work on document contents happens *inside* a Python builder script
  that reads `scored.json`, extracts fields with regex, and writes
  payload JSON to disk. Echoing raw SOW text to stdout pulls it into
  context, and a handful of 5–15K char dumps will exhaust the per-response
  token budget before Step 10 runs.

If you catch yourself about to output narration-only text, replace it with
the next concrete tool call instead.

---

## Known SAM.gov API Quirks

**Critical:** The v2 endpoint silently ignores `naicsCode`,
`classificationCode`, and `keyword` params. Only `title`, `ptype`,
`postedFrom`, `postedTo`, and `limit` filter server-side.

**Description endpoint is separate:** The notice description (where
mandatory site visit language often lives) is NOT in the search result.
Always fetch it:
```
GET https://api.sam.gov/prod/opportunities/v1/noticedesc?noticeid={noticeId}&api_key={KEY}
```
Strip HTML tags from the response before scanning.

**Attachment download:** Fresh API calls return pre-signed S3 URLs
(`iae-fbo-attachments.s3.amazonaws.com`) with ~9-second expiry. Fetch
and write the file in a single request with no delay. Use `verify=False`
on the requests call to bypass the intermediate SSL redirect. The CDN
path (`sam.gov/api/prod/opps/v3/...`) resolves to the same S3 endpoint.

**PDF extraction:** Use `pdftotext -layout` as primary extractor.
Fall back to `pdfplumber` if pdftotext returns < 100 chars. Floor plans
and drawing PDFs will return blank — flag as `[Scanned drawing]` and
skip rather than wasting time on OCR. DOCX files use `python-docx`.

---

## Step 1 — Search

**API key:** `SAM-fc5c7c25-a32d-4827-aa57-481c78ad37bf`
**Endpoint:** `https://api.sam.gov/opportunities/v2/search`

Run a separate search for each term below with `ptype=o,p,k`,
`postedFrom=01/01/{current_year}`, `postedTo={today}`, `limit=25`.
Deduplicate results by `solicitationNumber` (fall back to `noticeId`).

**Search terms:**
- AV-specific: `audio visual`, `audiovisual`, `audio video`, `Audio/Visual`, `AV system`, `AV integration`, `AV equipment`
- Conferencing: `conference room`, `video conferencing`, `video teleconference`, `SVTC`, `unified communications`
- Display/signage: `video wall`, `digital signage`, `display system`, `video display`
- Audio: `sound system`, `audio system`, `public address`

---

## Step 2 — Deadline Filter

Drop any opportunity where `responseDeadLine` is **strictly less than
TODAY + 3 days**. Keep opportunities with no deadline listed
(presolicitations, sources sought). Label dropped items `EXPIRED_OR_SOON`
— do not scan their documents.

Use `datetime.strptime` for date parsing. The boundary is `< cutoff`,
not `<=` — an opportunity due exactly 3 days out passes the filter.

---

## Step 3 — Title False-Positive Filter

Before fetching any documents, drop results whose title matches:

```
\b(UAV|ultrasound|ophthalm|furniture|\btable\b|lodging|hotel|
spare parts|sole source|radiology|flight simulator|runway)\b
```

Label these `DISQUALIFIED` with reason `Title false positive`.

---

## Step 4 — Fetch Description + Documents

For each opportunity that passed Steps 2–3:

1. **Fetch the notice description** (see quirk above). Scan this FIRST
   before downloading any attachments — mandatory site visit language
   almost always lives here, not in PDFs.

2. **Download attachments** — up to 5 per opportunity. Skip JPEGs and
   image-only files for text scanning (keep them for user download).
   Fetch + write atomically with no delay between request and file write.

3. **Extract text** using `pdftotext -layout` → `pdfplumber` fallback
   → flag as unreadable. Combine description + doc text into a single
   scan corpus (description first, max 20,000 chars total).

---

## Step 5 — Disqualification Check

Run the combined text corpus through all checks below. A single hit
on any disqualifier = `DISQUALIFIED`.

### Hard Disqualifiers
| Label | Pattern to match |
|---|---|
| Mandatory site visit | `mandatory site visit`, `mandatory pre-bid`, `mandatory walkthrough`, `attendance is mandatory`, `only offerors who attend` |
| On-site response SLA | `on-site within N hour`, `N-hour on-site`, `4-hour response` |
| Security clearance required | `security clearance required`, `must hold/possess Secret`, `TS/SCI`, `SCIF construction` |
| Geographic restriction | `must be located within`, `local contractor only`, `within N miles of` |
| Overseas installation | `incirlik`, `OCONUS`, `outside the continental US` |
| Restricted set-aside | ISBEE, 8(a), HUBZone, SDVOSB / Service-Disabled Veteran, WOSB / Women-Owned, Native American / Tribally-owned |
| Under $15K | `estimated cost/value of $N` where N < 15,000 |
| Non-AV scope | Medical imaging, broadcast studio, residential |
| Sole source | `intent to sole source`, `notice of intent` with no competitive language |

**Allowed set-asides (do not disqualify):** Unrestricted / full & open,
Total Small Business (FAR 19.5), no set-aside listed.

### Warnings (flag but do not disqualify)
- Davis-Bacon / Prevailing Wage
- GSA Schedule / Federal Supply Schedule required
- Past performance evaluation criteria
- STIG / DISA / SIPR / AFNET / DoD network integration
- Insurance minimums above $2M
- TAA compliance required
- 30-day or shorter delivery ARO

---

## Step 6 — CT Match Score (1–10)

Only scored if not disqualified. Baseline = 5.

**Add points:**
- +1 video wall / display wall scope
- +1 named platform in scope: Crestron, QSC/Q-SYS, Biamp, Extron, Shure
- +1 hospitality / entertainment / sports bar / recreation venue
- +1 multi-location or multi-site rollout
- +1 turnkey / design-build language

**Subtract points:**
- −1 maintenance-only or service contract
- −1 conference room only (no video wall or display wall)
- −2 SVTC / SIPR / STIG / AFNET scope
- −0.5 per warning flag

Clamp result to 1–10.

---

## Step 7 — Build Opportunity Briefs

For each `QUALIFIED` or `WARNING` opportunity, produce a full brief
with all sections below. This is the primary deliverable.

**Implementation shape — one builder, one Bash run.** Write a single
Python builder script (`build_briefs.py`) that reads `scored.json`,
iterates qualifying opps, extracts every field in 7a–7g via regex
over the already-loaded `corpus`, and writes one
`/tmp/stamp-payload-{sol_num}.json` per opp in a single execution.
Do not open the corpus interactively between `scored.json` and the
builder run — no `python3 -c "print(o['corpus'])"`, no `head`, no
`cat`. If the builder misses a field for a specific opp, edit the
builder and re-run it; do not hand-compose a brief around the gap.
Start from `templates/build_briefs.py` in this skill's directory —
adjust extractors if a solicitation has an unusual field shape, but
do not rebuild the scaffold from scratch.

### 7a. Header block
- Full title and solicitation number
- Agency, office, location (city/state/installation)
- Posted date, response deadline with days remaining
- NAICS code, set-aside type
- CT Match Score / 10
- SAM.gov URL: `https://sam.gov/opp/{noticeId}/view`

### 7b. Scope narrative
Write a detailed paragraph (or several) covering the full scope. Cover:
- What facility / room type / installation
- What the contractor is replacing or building new
- Primary system categories involved (display, audio, control, networking)
- Deliverable format (turnkey, equipment-only, design-build, maintenance)

**CLIN-level equipment breakdown (required when applicable):** If the
solicitation has multiple CLINs with distinct bills of materials, list
each CLIN inline in the scope paragraph with its specific equipment.
Example: `CLIN 0001 — Classrooms 120, 113, 124: 10× 98" 4K UHD LED
displays, 2× 86" interactive touchscreens, 2× 10.1" touch panels...`
Do not collapse CLINs into a single generic summary when each CLIN has
distinct equipment — the reviewer needs to see what's actually being
asked for at the line-item level.

**Warranty subsection (required):** State duration, whether extended
support is required or optional, remote diagnostics, and whether labor
is included. Note if no warranty term is specified (defaults to
manufacturer only, no labor).

**Training / Docs subsection (required):** On-site training days
required, whether ongoing technical support is mandated, manuals and
documentation deliverables (as-built drawings, signal flow diagrams,
quick-start guides, maintenance guidelines).

### 7c. Programming and control system analysis *(required)*
Explicitly call out what programming and functional configuration is
required. This section should answer: does this job require a
programmer, or is it configure-and-done?

Extract and include:
- Named control platforms (Crestron, QSC, Extron, AMX, etc.) and
  specific models if listed (e.g., CP4, TS-1070)
- DSP platform and programming scope (Biamp Tesira, QSC Q-SYS, etc.)
- Matrix switcher and routing logic (number of sources, number of zones,
  independent vs. mirrored operation)
- Touch panel / control interface requirements
- Any classification-level switching, KVM integration, or secure
  enclave requirements
- Training and documentation deliverables
- If no control platform is named, note whether scope implies a
  programmer is needed (multi-zone independent switching = yes;
  simple mirror = no)

### 7d. Q&A digest
If a Q&A document was downloaded and parsed, summarize the 6–10
most operationally relevant exchanges as question → answer pairs.
Focus on: room dimensions, existing equipment to reuse, structural
unknowns, shipping/access constraints, network integration, and
any clarifications that affect pricing.

If no Q&A document is present, note that no Q&A was posted.

### 7e. Red flags
List each flag as a short bolded label + 1–2 sentence explanation of
the practical impact on CT. Distinguish:
- 🔴 Hard risk (affects ability to bid or perform)
- 🟡 Pricing risk (adds cost or uncertainty)
- 🔵 Admin overhead (adds deliverables or compliance burden)

Always check for and call out:
- Delivery timeline vs. equipment lead times
- No as-built drawings / blind pricing exposure
- Base/installation access requirements
- TAA compliance burden
- Structural unknowns (wall backing, ceiling load)
- Any discrepancies between documents (e.g., conflicting building numbers)
- Davis-Bacon wage determination requirements
- **SAPF/SCIF-compliant audio equipment** — if `SAPF` or `SCIF` appears near microphone, audio, speaker, or camera language, note that contractor-furnished AV equipment must meet classified facility security standards; flag for CT to verify sourcing before bidding
- **Tight post-start install window** — if scope requires completion `within N calendar days of project start` or `within N days of notice to proceed`, call this out explicitly; it is separate from and shorter than the overall period of performance and directly affects how CT must stage equipment and staff the job
- **Pre-work base training required** — if the contract requires contractor personnel to complete on-base training (Energy Management System/EnMS, Environmental Management System/EMS, safety orientation) before beginning work, flag it; failure to document completion can block project start or trigger contract termination
- **Design approval required before installation** — if the SOO/SOW requires the installation design plan to be approved by a facility management office or government representative before work begins, note the unknown delay this introduces between award and installation start
- **Warranty and support requirements** — if warranty duration, extended support, or remote diagnostics are required, confirm they are priced into the proposal; if no warranty term is stated, flag it (manufacturer-only default means no labor coverage on punch list or callback work); if ongoing technical support is listed as an essential characteristic rather than optional, note it as a scope commitment

### 7f. Bid submission requirements *(required)*
Extract and list everything a vendor must include in or do to submit a
compliant bid. Cover all of the following if present:

**Submission mechanics**
- Where to submit (email address(es), portal, or physical)
- File formats accepted (PDF, Word, Excel — note if other formats are
  explicitly rejected)
- What to put in the subject line
- Whether the vendor must confirm receipt before the deadline
- Whether amendments must be acknowledged in the submission

**Required content in the bid package**
- Product specifications and proposed brand/model information
- CAGE code and SAM Unique Entity ID
- Payment and discount terms
- Proposed delivery schedule
- Safety and Health Plan (if required as a pre-award submission)
- Warranty terms (note if required in proposal vs. post-award)
- Training plan or training days (note if priced as a line item vs. included)
- Any other named documents or forms the solicitation requires with the offer

**Evaluation basis**
- How the award will be made: LPTA (lowest price, technically acceptable),
  best value trade-off, or price-only
- If best value: which non-price factors are weighted (warranty, delivery
  schedule, past performance, etc.)
- All-or-none requirement if present

**Post-award deliverables** (not in the bid but worth knowing)
- COTS manuals — format and due date
- As-built drawings or system documentation
- Training — who attends, how many days, when
- Design approval before installation begins
- Required compliance documentation (EMS/EnMS training records, etc.)

### 7g. Push payload

The scanner does NOT download documents. Document downloading and
attachment to CRM is handled by the ct-gov-potential-push skill at
push time, using the notice ID to re-fetch fresh files from SAM.gov.

For each QUALIFIED or WARNING opportunity (except Presolicitations —
see Step 10), build a structured push payload that feeds both the
Stamp approval card (what Adi sees at review time) and the push
routine (what fires into CRM on approval).

**Required fields — synthesized per-opportunity from the actual
document corpus. Do not use generic templates or placeholders.** The
scope_summary, programming_scope, detailed_flags, and description
fields must reflect real findings from that specific solicitation's
SOW/amendment/Q&A text — include brand names, part numbers, CLINs,
delivery terms, and base-specific requirements where present.

```json
{
  "sol_num": "FA857126Q0048",
  "notice_id": "b1f9d43b2c2c4a2fa1b77c4c8c943b12",
  "title": "Commander's Conference Room Upgrade",
  "account_name": "Department of the Air Force",
  "deadline": "2026-03-23",
  "bid_due_date": "Mar 23, 2026 4:30 PM EDT",
  "location": "Robins AFB, GA",
  "sam_url": "https://sam.gov/opp/{notice_id}/view",
  "amount": null,
  "set_aside": "Total Small Business",
  "type_of_system": ["Meeting Space"],
  "mandatory_site_visit": "No",
  "bid_submission_style": "Email",
  "contact_name": "Patrick Madan",
  "contact_email": "patrick.madan.2@us.af.mil",
  "contact_phone": "478-222-4098",
  "questions_due_date": "Mar 13, 2026 4:30 PM EDT",
  "response_date": "Mar 23, 2026 4:30 PM EDT",
  "scope_summary": "[3–5 sentence scope narrative with specifics: part numbers, quantities, delivery terms, warranty, occupancy impact. This is what appears on the card's SCOPE section — must stand on its own.]",
  "programming_scope": "[Assessment of whether the job needs a control programmer, a DSP programmer, an install tech, or just supply. Name platforms if called out (Crestron, QSC, Biamp, Extron, Shure). If no platform is named, state that explicitly and note what skill level is needed based on scope. Covers the card's PROGRAMMING & CUSTOM WORK section.]",
  "detailed_flags": "[Multi-line string, one flag per line, each prefixed with an emoji: 🔴 hard risk, 🟡 pricing risk, 🔵 admin overhead, 🟢 helpful info. Each flag has a short bold label and a 1-sentence impact statement. Include ALL material flags from the corpus — CDRLs, base access, safety plans, continued occupancy, warranty, Davis-Bacon, TAA, WAWF/PIEE, etc. This is what appears on the card's FLAGS section.]",
  "description": "[Full 7-section brief text — markdown formatted. Flows into the CRM Deal Description on approval. Must match the depth of the template in Step 7a–7f.]",
  "ct_score": 5,
  "status": "QUALIFIED",
  "warnings": ["short label 1", "short label 2"]
}
```

The `warnings` array remains as short labels (used for scoring and
summary table). The `detailed_flags` string is the human-facing
formatted version on the card.

This payload is serialized as JSON and passed as the `text` field
when the push routine's `/fire` endpoint is called.

Write each payload to a temp file:
```python
import json
payload_path = f'/tmp/stamp-payload-{sol_num}.json'
with open(payload_path, 'w') as f:
    json.dump(payload, f)
```

After all briefs are built, call the `stamp-messenger` skill to send
stacked approval cards to Adi — see Step 10.

---

## Step 8 — Summary Table

Before the detail cards, show a summary table of ALL results from the
search (not just active ones) with columns:

| Title | Sol # | Agency | Deadline | Set-aside | Status | Reason |

- `QUALIFIED` — passed all filters, no warnings
- `WARNING` — passed filters but has warning flags
- `DISQUALIFIED` — failed a hard disqualifier (include reason)
- `EXPIRED_OR_SOON` — dropped by deadline filter (dim/gray)

Show expired rows at reduced opacity. Include the disqualification
reason for every DQ'd row so the user can see the scanner's logic.

---

## Step 9 — Output Format

Render using `visualize:show_widget` with:
1. Stats row: searches run / unique opps / passed filter / qualified / warning
2. Summary table (all results)
3. One detail card per QUALIFIED or WARNING opportunity with all
   sections from Step 7 (7a through 7g)

No file downloads or `present_files` calls — document handling is
fully delegated to ct-gov-potential-push at approval time.

If zero qualified opportunities, say so clearly and list notable
expired opportunities worth watching for re-solicitation.

---

## Step 10 — CRM dedup check + Send Stamp approval cards

Before sending any Stamp cards:

1. **Exclude Presolicitations from the Stamp batch.** Presolicitations
   (SAM.gov notice type `Presolicitation`) are advance notice only —
   no bid can be submitted yet. Keep them in the Step 8 summary table
   so they're visible, but do NOT send Stamp approval cards for them
   and do NOT write payload files for them. When the follow-on actual
   solicitation is posted (type `Solicitation` or `Combined Synopsis/
   Solicitation`), a future scan will pick it up and send the card.

2. Check Zoho CRM to see if a Deal already exists for each of the
   remaining qualifying opportunities. Only send cards for opps that
   are not yet in CRM.

### 10a — Dedup check

For each payload file written in Step 7g, query Zoho using the
SAM.gov URL as the unique key:

```python
# For each qualifying opp
query = f"SELECT id, Deal_Name, Stage FROM Deals WHERE Bid_Link = '{sam_url}' LIMIT 1"
```

Using `ZohoCRM_executeCOQLQuery` with the above query.

- If a Deal is found → log `Already in CRM: [Deal_Name] ([Stage]) — skipping` and exclude from Stamp batch
- If no Deal found → include in Stamp batch

### 10b — Send Stamp cards

After filtering, assess the batch:

- **Batch is empty** — all qualifying opps already have Deals in CRM.
  Skip Stamp entirely. Log: `All qualifying opportunities already in CRM — no Stamp card sent.`

- **Batch has opps** — send a single stacked Teams message to Adi
  containing one card per new opp:

```bash
bash /path/to/stamp-messenger/send-stamp.sh \
  --recipient "Adi Khanna" \
  --subject "Gov Bid Scanner — ${N} opportunit$([ $N -eq 1 ] && echo 'y' || echo 'ies') need approval" \
  --card /path/to/stamp-messenger/templates/gov-bid-approval-card.json \
  --payload /tmp/stamp-payload-${sol_num}.json \
  --stacked
```

No environment variables required — credentials are hardcoded in send-stamp.sh.

If running in a session without access to the stamp-messenger skill (e.g.
interactive chat review only), note the payload files written to `/tmp/`
and inform the user they can be pushed manually.

---

## CT Company Profile (for scoring and analysis)

- **Company:** Crunchy Tech — national commercial AV integration, Orlando FL
- **Brands:** Crunchy Tech, Padzilla (interactive displays), Unreal Bowling
- **Sweet spot:** $50K–$500K turnkey AV integration projects
- **Platforms:** SAVI, Crestron, QSC (Q-SYS), Biamp, Extron, QoraLux lighting
- **Strengths:** Hospitality/entertainment venues, sports bars, restaurants,
  recreation centers, multi-location rollouts, video walls, digital signage,
  background music/audio, control systems
- **Can do, not ideal:** Pure conference room upgrades (lower margin),
  maintenance-only contracts, design-only engagements
- **Avoid:** Pure IT/networking, residential, broadcast, medical imaging,
  military SCIF, projects under $15K, SVTC/SIPR/AFNET work

---

## Environment Notes

- SAM.gov API key: `SAM-fc5c7c25-a32d-4827-aa57-481c78ad37bf`
- Domain `api.sam.gov` is on the network allowlist
- Domain `iae-fbo-attachments.s3.amazonaws.com` is on the allowlist
- Use `pip install pdfplumber python-docx --break-system-packages` if
  libraries are not installed
- `pdftotext` is available via system path
- Do not download solicitation documents — document fetching is handled
  by ct-gov-potential-push at approval time using the notice_id
- Do not push anything to Zoho CRM unless the user explicitly requests it
