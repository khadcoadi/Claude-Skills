---
name: ct-pixel-bot
description: >
  Send notifications via the Pixel Teams bot to Crunchy Tech team members.
  Pixel is the intel bot — it delivers lead enrichment results, new opportunity
  alerts, and other intelligence drops to the right person's Teams DM. Use this
  skill whenever a lead enrichment completes and needs to notify the assigned rep,
  or any time someone says "send via Pixel", "Pixel notify", "send a Pixel card",
  "DM through Pixel", or when another skill or automation needs to push an intel
  notification. Always use this skill for Pixel bot messaging — do not call the
  Bot Framework API without it. Do NOT use this skill for other bots (Alfred,
  Jafar, Stamp) — each bot has its own skill.
---

# Pixel Bot — Teams Intel Messenger

## Identity

Pixel is Crunchy Tech's intel bot. Green theme, ⚡ icon. It delivers:
- Lead enrichment results to the assigned sales rep
- (Future) Venue prospector alerts
- (Future) RFP scanner notifications
- (Future) Any intelligence drop that needs immediate attention

Pixel does NOT handle: morning briefings (Alfred), urgent escalations (Jafar),
or approval flows (Stamp).

---

## How to Send a Message

### Step 1: Identify the recipient

Look up the recipient in `team-roster.json`. Match by name (case-insensitive).

For lead enrichment, map the CRM Owner ID to the rep name:

| CRM Owner ID | Rep Name |
|---|---|
| 1351252000153431001 | Kevin Lacayo |
| 1351252000000162033 | Leonardo Moretti |
| 1351252000001578206 | TJ Paone |

### Step 2: Build the message

**For plain text:**
```bash
bash ct-pixel-bot/send-message.sh "Recipient Name" "Your message here"
```

**For adaptive cards (lead enrichment, etc.):**
1. Read the appropriate template from `templates/`
2. Replace all `${placeholder}` values with actual data
3. Validate the JSON
4. Write to a temp file
5. Send with a `--summary` so the Teams notification shows context instead of "Sent a card":
```bash
bash ct-pixel-bot/send-message.sh "Recipient Name" --card /tmp/card-file.json --summary "⚡ New Lead: Sean Kobos — Crafty Rooster (Strong 85/100)"
```

The `--summary` text appears in the Teams notification toast and chat preview. Keep it under ~100 chars. For lead enrichment cards, use: `⚡ New Lead: {Full_Name} — {Company} ({ICP_Fit} {ICP_Score}/100)`

If `--summary` is omitted, the script auto-extracts text from the card body (the name/company line), but explicit is better.

### Step 3: Confirm delivery

The script outputs success/failure. On success you'll see an Activity ID.

---

## Card Templates

### Lead Enrichment Card

**File:** `templates/lead-enrichment-card.json`

**When:** After ct-lead-enrichment completes and writes the CRM note.

**Recipient:** The rep who owns the lead (see Owner ID mapping above).

**Placeholders:**

| Placeholder | Source | Example |
|---|---|---|
| `${full_name}` | Lead Full_Name | Sean Kobos |
| `${company}` | Lead Company | Crafty Rooster |
| `${icp_fit}` | Enrichment output | Strong |
| `${icp_score}` | Enrichment output | 85 |
| `${fit_color}` | Derived from ICP_Fit (see color map) | good |
| `${city}` | Lead City | Conway |
| `${state}` | Lead State | AR |
| `${lead_source}` | Lead Lead_Source | Facebook Ad |
| `${campaign}` | Lead FB_Campaign or Campaign | Sports Bar Retarget Q1 |
| `${venue_type}` | Enrichment output | Sports Bar |
| `${google_rating}` | Enrichment output | 4.3 / 589 reviews |
| `${visits_summary}` | Built from visit fields | 3 visits over 5 days, 4.2 min avg, sports bar ad |
| `${location_count}` | Number of locations from enrichment | 3 locations |
| `${lead_message}` | Lead Message, truncated ~120 chars | I need AV for 2 locations |
| `${hooks_formatted}` | Enrichment hooks, newline-separated | 1. He owns 2 locations... |
| `${recommended_action}` | Enrichment output | Call this week — owner of established sports bar, expanding to second location |
| `${action_color}` | Derived from action type (see color map) | good |
| `${action_style}` | Card container style from action type (see style map) | good |
| `${lead_id}` | Lead record ID | 1351252000012345678 |
| `${org_id}` | Zoho CRM org ID | (your org ID) |
| `${phone}` | Lead Phone | 5015551234 |
| `${enrichment_timestamp}` | Current date/time | 2026-03-22 08:15 ET |
| `${venue_url}` | Website URL, or Facebook page URL if no website | https://www.facebook.com/p/SomeVenue |
| `${article_url}` | Press article URL from enrichment | https://www.al.com/life/2026/02/... |
| `${article_title}` | Short article headline for button label | AL.com: New restaurant coming |

**ICP Fit color map:**

| ICP Fit | `${fit_color}` |
|---|---|
| Strong | good |
| Moderate | warning |
| Weak | attention |
| Unknown | default |

**Action color map:**

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

When building the card, filter out any action where the URL placeholder is empty or wasn't replaced.

**Building visits_summary:**

Combine: `Days_Visited` → "{N} visit(s)", `Average_Time_Spent_Minutes` → "{N} min avg", source context from `FB_Campaign` or `Lead_Source`. Examples: "3 visits over 5 days, 4.2 min avg, sports bar ad" or "1 visit, under a minute". If Days_Visited is null/0, use "No visit data".

---

### Gov Bid Notification Card

**File:** `templates/pixel-gov-bid-notification-card.json`

**Type name:** `gov-bid-notification`

**When:** After ct-gov-potential-push creates a Deal in Zoho CRM for a qualifying government AV opportunity. Sent to the assigned sales rep (Kevin or Leo).

**Recipient:** The rep assigned to the opportunity (Kevin Lacayo or Leonardo Moretti).

**Summary line:**
```
⚡ New Gov Bid: {title} — {days_remaining} to bid
```

**Placeholders:**

| Placeholder | Source | Example |
|---|---|---|
| `${title}` | Deal name / opportunity title | Commander's Conference Room Upgrade |
| `${sol_number}` | SAM.gov solicitation number | FA857126Q0048 |
| `${agency}` | Contracting agency | Department of the Air Force |
| `${location}` | Installation and state | Robins AFB, GA |
| `${deadline}` | Bid due date formatted | Mar 23, 2026 4:30 PM EDT |
| `${days_remaining}` | Calculated days until deadline | 4 days |
| `${set_aside}` | Set-aside type | Small Business |
| `${type_of_system}` | AV system type | Meeting Space |
| `${bid_submission_style}` | How to submit | Email |
| `${poc_name}` | Contracting officer name | Patrick Madan |
| `${poc_email}` | Contracting officer email | patrick.madan.2@us.af.mil |
| `${match_score}` | CT match score 1–10 | 7 |
| `${score_color}` | Adaptive Card color keyword | good |
| `${scope_summary}` | 2–3 sentence scope description | Replace existing AV in... |
| `${red_flags}` | Top 3 flags, newline-separated with Red:/Yellow: prefix | Red: Tight 30-day install window\nYellow: Davis-Bacon applies |
| `${notice_id}` | SAM.gov notice ID | b1f9d43b2c2c4a2fa1b77c4c8c943b12 |
| `${zoho_deal_url}` | Full Zoho CRM Deal URL | https://crm.zoho.com/crm/org45247585/tab/Potentials/1351252000012345678 |
| `${deal_created_at}` | Timestamp when Deal was created | 2026-03-22 09:41 ET |

**Score color map:**

| CT Score | `${score_color}` |
|---|---|
| 7–10 | good |
| 4–6 | warning |
| 1–3 | attention |

**Calling this card from ct-gov-potential-push:**
```bash
bash ct-pixel-bot/send-message.sh "Kevin Lacayo" \
  --card /tmp/pixel-gov-bid-card-${sol_num}.json \
  --summary "⚡ New Gov Bid: ${title} — ${days_remaining} to bid"
```

---

## Populating a Card

```python
import json

# 1. Read template
with open('ct-pixel-bot/templates/lead-enrichment-card.json') as f:
    template = f.read()

# 2. Replace placeholders — sanitize values to avoid breaking JSON
replacements = {
    '${full_name}': lead['Full_Name'],
    '${company}': lead.get('Company') or 'Unknown',
    # ... all placeholders
}
card_json = template
for key, val in replacements.items():
    safe_val = str(val).replace('"', '\\"').replace('\n', '\\n')
    card_json = card_json.replace(key, safe_val)

# 3. Validate
parsed = json.loads(card_json)

# 4. Write temp file
card_path = f'/tmp/pixel-card-{lead_id}.json'
with open(card_path, 'w') as f:
    json.dump(parsed, f)

# 5. Send
# bash ct-pixel-bot/send-message.sh "Kevin Lacayo" --card /tmp/pixel-card-{lead_id}.json
```

---

## Error Handling

| Error | Cause | Fix |
|---|---|---|
| "Recipient not found" | Name doesn't match roster | Check spelling |
| "Token failed" | Client secret expired | Create new secret in Azure portal |
| "Conversation failed" | Bot not installed for user | User adds Pixel in Teams → Apps |
| "Message failed" | Transient | Retry once |

---

## Important Notes

- Pixel can only DM users who have the Pixel app installed in Teams
- Conversation IDs are cached in `/tmp/pixel-conversations.json`
- Token is cached for 50 minutes in `/tmp/pixel-token-cache.json`
- The card template stays under Teams' ~28KB payload limit
- Card is for quick action — full enrichment detail lives in the CRM note
