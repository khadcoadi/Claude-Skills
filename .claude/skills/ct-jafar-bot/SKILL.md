---
name: ct-jafar-bot
description: >
  Send notifications via the Jafar Teams bot to Crunchy Tech team members.
  Jafar is the project/issue bot — it delivers Zoho Projects bug and issue
  notifications, and will handle other project-related alerts (tasks,
  milestones, comments) as they are added. Use this skill whenever a Zoho
  Projects webhook fires, or any time someone says "send via Jafar", "Jafar
  notify", "send a Jafar card", "DM through Jafar", or when another skill or
  automation needs to push a project notification. Always use this skill for
  Jafar bot messaging — do not call the Bot Framework API without it. Do NOT
  use this skill for other bots (Pixel, Alfred, Stamp) — each bot has its
  own skill.
---

# Jafar Bot — Teams Projects Messenger

## Identity

Jafar is Crunchy Tech's project/issue bot. Amber/gold theme, 🧞 icon. It delivers:
- Zoho Projects bug notifications (new bugs, status changes)
- (Future) Task assignments and updates
- (Future) Milestone alerts
- (Future) Comment mentions
- (Future) Any Projects-related notification that needs a Teams DM

Jafar does NOT handle: lead/intel notifications (Pixel), morning briefings
(Alfred), or approval flows (Stamp).

---

## How to Send a Message

### Step 1: Identify the recipient

Look up the recipient in `team-roster.json`. Match by name (case-insensitive).

For Zoho Projects bugs, map the Assignee (or Reporter as fallback) name to
the roster. If neither matches, surface the raw name in the error so the
roster can be updated.

### Step 2: Build the message

**For plain text:**
```bash
bash ct-jafar-bot/send-message.sh "Recipient Name" "Your message here"
```

**For adaptive cards (Zoho Projects issue, etc.):**
1. Read the appropriate template from `templates/`
2. Replace all `${placeholder}` values with actual data
3. Validate the JSON
4. Write to a temp file
5. Send with a `--summary` so the Teams notification shows context instead of "Sent a card":
```bash
bash ct-jafar-bot/send-message.sh "Recipient Name" --card /tmp/card-file.json --summary "🧞 New Bug: ${title} (${project})"
```

The `--summary` text appears in the Teams notification toast and chat preview. Keep it under ~100 chars. For Zoho issue cards, use: `🧞 New Bug: {title} ({project})`

If `--summary` is omitted, the script auto-extracts text from the card body (the title line), but explicit is better.

### Step 3: Confirm delivery

The script outputs success/failure. On success you'll see an Activity ID.

---

## Card Templates

### Zoho Projects Issue Card

**File:** `templates/zoho-issue-card.json`

**When:** Zoho Projects webhook fires for a new/updated bug.

**Recipient:** The Assignee on the bug (fallback: Reporter).

**Placeholders:**

| Placeholder | Source | Example |
|---|---|---|
| `${issue_id}` | Webhook ID | 763637000022707118 |
| `${title}` | Webhook Title | AV feed dropping in Conference Room 3 |
| `${project}` | Webhook Project | Unreal Bowl AV Refresh |
| `${reporter}` | Webhook Reporter | Kevin Lacayo |
| `${assignee}` | Webhook Assignee | TJ Paone |
| `${due_date}` | Webhook Due | 2026-04-25 |
| `${description}` | Webhook Description, truncated ~500 chars | HDMI input 2 drops signal every ~15 min... |

If any field is empty, substitute a reasonable default (`Unassigned`,
`No due date`, `No description provided`) rather than leaving `${...}` in
the rendered card.

**Open in Zoho Projects URL:**

```
https://projects.zoho.com/portal/crunchy#zp/issues/custom-view/763637000016633093/list/issue-detail/${issue_id}?group_by=none
```

The `763637000016633093` segment is the default "All Issues" custom-view ID
for the crunchy portal. Only `${issue_id}` changes per bug.

---

## Populating a Card

```python
import json

# 1. Read template
with open('ct-jafar-bot/templates/zoho-issue-card.json') as f:
    template = f.read()

# 2. Replace placeholders — sanitize values to avoid breaking JSON
replacements = {
    '${issue_id}':    webhook['id'],
    '${title}':       webhook.get('title') or 'Untitled bug',
    '${project}':     webhook.get('project') or 'Unknown project',
    '${reporter}':    webhook.get('reporter') or 'Unknown',
    '${assignee}':    webhook.get('assignee') or 'Unassigned',
    '${due_date}':    webhook.get('due') or 'No due date',
    '${description}': (webhook.get('description') or 'No description provided')[:500],
}
card_json = template
for key, val in replacements.items():
    safe_val = str(val).replace('"', '\\"').replace('\n', '\\n')
    card_json = card_json.replace(key, safe_val)

# 3. Validate
parsed = json.loads(card_json)

# 4. Write temp file
card_path = f'/tmp/jafar-card-{webhook["id"]}.json'
with open(card_path, 'w') as f:
    json.dump(parsed, f)

# 5. Send
# bash ct-jafar-bot/send-message.sh "TJ Paone" --card /tmp/jafar-card-{id}.json --summary "🧞 New Bug: ..."
```

---

## Error Handling

| Error | Cause | Fix |
|---|---|---|
| "Recipient not found" | Name doesn't match roster | Check spelling / add to roster |
| "Token failed" | Client secret expired | Create new secret in Azure portal |
| "Conversation failed" | Bot not installed for user | User adds Jafar in Teams → Apps |
| "Message failed" | Transient | Retry once |

---

## Important Notes

- Jafar can only DM users who have the Jafar app installed in Teams
- Conversation IDs are cached in `/tmp/jafar-conversations.json`
- Token is cached for 50 minutes in `/tmp/jafar-token-cache.json`
- The card template stays under Teams' ~28KB payload limit
- Card is for quick action — full issue detail lives in Zoho Projects
