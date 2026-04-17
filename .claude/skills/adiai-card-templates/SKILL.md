---
name: adiai-card-templates
description: >
  Adaptive card templates for Crunchy Tech automation notifications sent through
  the Adiai Teams bot. Contains ready-to-populate JSON templates for lead
  enrichment, government RFP scanner, and venue prospector cards. Use this skill
  whenever an automation finishes producing results and needs to notify a team
  member with a rich Teams card — after lead enrichment completes, after an RFP
  scan finds qualified opportunities, after a venue prospector run surfaces new
  prospects, or any time you need to build an adaptive card for the Adiai
  messenger. Always read this skill before constructing any adaptive card JSON.
  Do not build adaptive cards from scratch without consulting these templates.
---

# Adiai Card Templates

Adaptive card JSON templates for Crunchy Tech automations. Each template is a
ready-to-populate JSON file with `${placeholder}` variables. The automation
fills in the placeholders from its output data, writes the card JSON to a temp
file, then hands it to the `adiai-messenger` skill for delivery.

---

## How It Works

1. The automation (lead enrichment, RFP scanner, venue prospector) finishes its
   work and has structured output data.
2. This skill provides the card template. Read the appropriate JSON file from
   `templates/`.
3. Replace every `${placeholder}` with actual values from the automation output.
4. Write the populated JSON to a temp file (e.g., `/tmp/card-{lead_id}.json`).
5. Call the `adiai-messenger` skill to send the card:
   ```bash
   bash /path/to/adiai-messenger/send-message.sh "Recipient Name" --card /tmp/card-{id}.json
   ```

The templates are designed to stay under Teams' ~28KB card payload limit. They
show only the data the recipient needs to act immediately — the full details
live in the CRM note, the chat brief, or the CSV.

---

## Available Templates

| Template | File | Recipient | Purpose |
|----------|------|-----------|---------|
| Lead Enrichment | `templates/lead-enrichment-card.json` | Assigned rep (Kevin, Leo, TJ) | "Should I call this person, and what do I say?" |
| Gov RFP Scanner | `templates/gov-rfp-scanner-card.json` | Adi Khanna | "Is this bid worth reading the full brief?" |
| Venue Prospector | `templates/venue-prospector-card.json` | Assigned rep or Adi | "Should I reach out to this pre-construction prospect?" |

---

## Template 1: Lead Enrichment Card

**File:** `templates/lead-enrichment-card.json`

**When to use:** After the `ct-lead-enrichment` skill completes enrichment on a
lead and writes the note to CRM. Send one card per enriched lead to the lead's
assigned rep.

**Who receives it:** The rep who owns the lead in Zoho CRM. Map the Owner field
to the team roster name:

| CRM Owner ID | Rep Name |
|---|---|
| 1351252000153431001 | Kevin Lacayo |
| 1351252000000162033 | Leonardo Moretti |
| 1351252000001578206 | TJ Paone |

**Placeholders to fill:**

| Placeholder | Source | Example |
|---|---|---|
| `${full_name}` | Lead Full_Name | Sean Kobos |
| `${company}` | Lead Company field | Crafty Rooster |
| `${icp_fit}` | Enrichment output | Strong |
| `${icp_score}` | Enrichment output | 85 |
| `${fit_color}` | Derived from ICP_Fit (see color map below) | good |
| `${city}` | Lead City | Conway |
| `${state}` | Lead State | AR |
| `${lead_source}` | Lead Lead_Source | Facebook Ad |
| `${campaign}` | Lead FB_Campaign or Campaign | Sports Bar Retarget Q1 |
| `${venue_type}` | Enrichment output | Sports Bar |
| `${google_rating}` | Enrichment output | 4.3 / 589 reviews |
| `${visits_summary}` | Built from visit fields | 3 visits over 5 days, 4.2 min avg, sports bar ad |
| `${lead_message}` | Lead Message field, truncated to ~120 chars | I need AV for 2 locations, very interested |
| `${hooks_formatted}` | Enrichment hooks, newline-separated | 1. He owns 2 locations...\n2. Expansion underway... |
| `${recommended_action}` | Enrichment output | Call this week — owner of established sports bar, expanding to second location |
| `${action_color}` | Derived from action type (see color map) | good |
| `${lead_id}` | Lead record ID from CRM | 1351252000012345678 |
| `${org_id}` | Zoho CRM org ID | (your org ID) |
| `${phone}` | Lead Phone field | 5015551234 |
| `${enrichment_timestamp}` | Current date/time | 2026-03-22 08:15 ET |
| `${venue_url}` | Website URL, or Facebook page URL if no website | https://www.facebook.com/p/Bienville-Bar-And-Grill-61587470363335/ |
| `${article_url}` | Press article URL from enrichment | https://www.al.com/life/2026/02/alabama-beach-town... |
| `${article_title}` | Short article headline for button label | AL.com: New restaurant coming |
| `${location_count}` | Number of locations from enrichment | 3 locations |
| `${action_style}` | Card container style from action type (see style map) | good |

**ICP Fit color map** (these are Adaptive Card color keywords, not hex):

| ICP Fit | `${fit_color}` |
|---|---|
| Strong | good |
| Moderate | warning |
| Weak | attention |
| Unknown | default |

**Recommended action color map:**

| Action | `${action_color}` |
|---|---|
| Call | good |
| Email | accent |
| Nurture | warning |
| Disqualify | attention |
| Manual Research Needed | default |

**Action style map** (for the recommended action container):

| Action | `${action_style}` |
|---|---|
| Call | good |
| Email | accent |
| Nurture | warning |
| Disqualify | attention |
| Manual Research Needed | default |

**Conditional buttons — View Venue and Article:**

The card template includes four action buttons: Open in CRM, Call, View Venue, and Article. The last two are conditional:

- **View Venue:** If a website URL was found, use it. If no website but a Facebook page was found, use the Facebook URL. If neither was found, REMOVE the entire View Venue action from the actions array before sending.
- **Article:** If a press article was found, use the article URL and set the button title to a short version of the headline (e.g., "📰 AL.com: New restaurant coming"). If no article was found, REMOVE the entire article action from the actions array before sending.

When building the card in code, filter out any action where the URL placeholder is empty or "None found":

```python
# After populating the card JSON
card['actions'] = [a for a in card['actions'] if '${' not in a.get('url', '') and a.get('url', '')]
```

**Building the visits_summary string:**

Combine these CRM fields into one plain-language line:
- `Days_Visited` → "{N} visit(s)"
- `Average_Time_Spent_Minutes` → "{N} min avg"
- `FB_Campaign` or `Lead_Source` → source context

Examples:
- "3 visits over 5 days, 4.2 min avg, sports bar ad"
- "1 visit, under a minute"
- "2 visits, 6.1 min avg, Google search"

If Days_Visited is null or 0, use "No visit data".

---

## Template 2: Gov RFP Scanner Card

**File:** `templates/gov-rfp-scanner-card.json`

**When to use:** After the `ct-gov-rfp-scanner` skill finds QUALIFIED or
WARNING opportunities. Send one card per qualifying opportunity.

**Who receives it:** Adi Khanna (always — gov bids are reviewed centrally).

**Placeholders to fill:**

| Placeholder | Source | Example |
|---|---|---|
| `${status_badge}` | Scanner status | QUALIFIED |
| `${status_emoji}` | Derived from status | (checkmark for qualified, warning for warning) |
| `${match_score}` | CT Match Score from scanner | 8 |
| `${score_color}` | Derived: 7+ = good, 4-6 = warning, 1-3 = attention | good |
| `${title}` | Opportunity title from SAM.gov | Audio Visual Integration - Fort Bragg MWR |
| `${sol_number}` | Solicitation number | W9124D-26-R-0042 |
| `${agency}` | Contracting agency | US Army Corps of Engineers |
| `${location}` | Installation/facility location | Fort Bragg, NC |
| `${deadline}` | Response deadline formatted | April 15, 2026 |
| `${days_remaining}` | Calculated days until deadline | 24 days |
| `${set_aside}` | Set-aside type | Total Small Business |
| `${naics}` | NAICS code | 238210 |
| `${scope_summary}` | 2-3 sentence scope from brief | Turnkey AV integration for 4 conference rooms. Crestron control, QSC audio, 2x video walls. Design-build. |
| `${red_flags}` | Compact flag list from brief | Red: Tight 60-day completion. Yellow: No as-builts, blind pricing. |
| `${platforms}` | Named platforms from scope | Crestron, QSC Q-SYS, Biamp — 3 zones, touch panel |
| `${notice_id}` | SAM.gov notice ID for URL | abc123def456 |
| `${poc_name}` | Point of contact name | Jane Smith |
| `${poc_email}` | POC email | jane.smith@army.mil |

**Score color map:**

| CT Match Score | `${score_color}` |
|---|---|
| 7-10 | good |
| 4-6 | warning |
| 1-3 | attention |

---

## Template 3: Venue Prospector Card

**File:** `templates/venue-prospector-card.json`

**When to use:** After the `ct-venue-prospector` skill identifies new prospects
during a city scan. The scheduled task prompt decides how many cards to send and
for which prospects — this template just defines the card structure for one
prospect.

**Who receives it:** Determined by the scheduled task prompt. Could be a rep, or
Adi for review before assignment.

**Placeholders to fill:**

| Placeholder | Source | Example |
|---|---|---|
| `${urgency_emoji}` | From prospector urgency matrix | (green circle) |
| `${urgency_label}` | Text label for urgency | OPTIMAL WINDOW |
| `${urgency_color}` | Derived from emoji (see map) | good |
| `${venue_name}` | Prospect venue name | Bath & Racquet House |
| `${city_suburb}` | City or suburb name | St. Petersburg, FL |
| `${est_size}` | Estimated square footage | 18,000+ sq ft |
| `${opening_timeline}` | When the venue opens | 2027 |
| `${pipeline_stage}` | Current construction stage | Broke ground Q1 2026 |
| `${concept}` | 1-line concept description | Upscale racquet club with full bar, event space, and live entertainment |
| `${why_ct}` | Specific AV scope opportunity | Multi-zone audio, display network, event PA, outdoor sound, centralized control |
| `${hook}` | Cold call opening line | "You broke ground on the racquet club — has your GC locked conduit for AV yet?" |
| `${contact_name}` | Primary contact (owner/operator) | Jason Kuhn |
| `${contact_title}` | Their role | Co-Owner |
| `${linkedin_url}` | Confirmed LinkedIn profile URL | https://linkedin.com/in/jason-kuhn-12345 |
| `${source_info}` | Where the prospect was found | Business Debut, March 2026 — Pass 2 |

**Urgency color map:**

| Emoji | Meaning | `${urgency_color}` |
|---|---|---|
| Green circle | Optimal window — permit/design phase | good |
| Yellow circle | Still viable — 3-6 months out | warning |
| Orange circle | Relationship play — pitch the next buildout | accent |
| White square | Monitor — too early or uncertain | default |
| Warning sign | Risk flag — financial/legal issues | attention |

---

## Populating a Template — Step by Step

Here is the exact process for building a card from a template. This example
uses lead enrichment but the pattern is the same for all three.

```python
import json

# 1. Read the template
with open('templates/lead-enrichment-card.json') as f:
    template = f.read()

# 2. Replace placeholders
card_json = template
card_json = card_json.replace('${full_name}', lead['Full_Name'])
card_json = card_json.replace('${company}', lead['Company'] or 'Unknown')
card_json = card_json.replace('${icp_fit}', enrichment['icp_fit'])
card_json = card_json.replace('${icp_score}', str(enrichment['icp_score']))
# ... replace all remaining placeholders ...

# 3. Validate it's valid JSON
parsed = json.loads(card_json)

# 4. Write to temp file
card_path = f'/tmp/card-{lead_id}.json'
with open(card_path, 'w') as f:
    json.dump(parsed, f)

# 5. Send via adiai-messenger
# bash send-message.sh "Kevin Lacayo" --card /tmp/card-{lead_id}.json
```

When replacing placeholders, always escape special characters that could break
JSON — especially double quotes in the lead message or scope summary fields.
The safest approach is to do the replacements on a Python dict (not raw string)
and then json.dumps() the result. But string replacement works fine if you
sanitize the values first.

---

## What Goes on the Card vs. What Stays in CRM/Brief

The card is a notification — it tells the recipient "act on this now" with just
enough data to know what to do. Everything else lives in the CRM note or the
chat brief.

**Lead Enrichment:**
- ON the card: name, company, ICP badge, score, location, source, venue type, Google rating, visit behavior, location count, lead message, hooks, recommended action, venue website/Facebook link (button), press article link (button)
- OFF the card: full enrichment note, discovery questions, drafted email, CRM history detail, venue size estimate, full article text, address corrections

**Gov RFP Scanner:**
- ON the card: status badge, match score, title, sol #, agency, location, deadline, set-aside, scope summary, red flags, platforms, SAM.gov link
- OFF the card: full Q&A digest, bid submission details, document package, full scope narrative

**Venue Prospector:**
- ON the card: urgency badge, venue name, location, size, timeline, stage, concept, why CT, hook, primary contact + LinkedIn
- OFF the card: secondary/tertiary contacts, design firm info, full pitch positioning, source attribution detail
