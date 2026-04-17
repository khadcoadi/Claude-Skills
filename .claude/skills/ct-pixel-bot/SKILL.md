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
5. Send:
```bash
bash ct-pixel-bot/send-message.sh "Recipient Name" --card /tmp/card-file.json
```

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
| `${fit_color}` | Derived from ICP_Fit | good |
| `${city}` | Lead City | Conway |
| `${state}` | Lead State | AR |
| `${lead_source}` | Lead Lead_Source | Facebook Ad |
| `${campaign}` | Lead FB_Campaign or Campaign | Sports Bar Retarget Q1 |
| `${venue_type}` | Enrichment output | Sports Bar |
| `${google_rating}` | Enrichment output | 4.3 / 589 reviews |
| `${visits_summary}` | Built from visit fields | 3 visits over 5 days, 4.2 min avg |
| `${lead_message}` | Lead Message, truncated ~120 chars | I need AV for 2 locations |
| `${hooks_formatted}` | Enrichment hooks, newline-separated | 1. He owns 2 locations... |
| `${recommended_action}` | Enrichment output | Call this week |
| `${action_color}` | Derived from action type | good |
| `${lead_id}` | Lead record ID | 1351252000012345678 |
| `${org_id}` | Zoho CRM org ID | (your org ID) |
| `${phone}` | Lead Phone | 5015551234 |
| `${enrichment_timestamp}` | Current date/time | 2026-03-22 08:15 ET |

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

**Building visits_summary:**

Combine: `Days_Visited` → "{N} visit(s)", `Average_Time_Spent_Minutes` → "{N} min avg", source context from `FB_Campaign` or `Lead_Source`. If Days_Visited is null/0, use "No visit data".

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
