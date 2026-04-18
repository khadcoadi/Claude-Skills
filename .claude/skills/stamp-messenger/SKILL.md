---
name: stamp-messenger
description: >
  Sends Stamp bot approval cards to Crunchy Tech team members via Teams DM.
  Stamp is the approval bot — gold/shield identity. Use whenever an automation
  needs a human to approve an action before it executes. Handles all approval
  types: government bids, contract approvals, vendor approvals, or any future
  approval flow. Always use this skill for Stamp messaging — do not call the
  Bot Framework API directly. Each approval type has its own template and
  configuration in the registry below.
---

# Stamp Messenger — Teams Approval Card Skill

Sends Stamp bot DM approval cards to any CT team member. The approver
receives a rich adaptive card with an Approve button that fires an action
directly (webhook, API endpoint, etc.) and a Skip button to dismiss.

One message per approval batch. Multiple opportunities/items stack as
multiple cards in a single message via `--stacked`.

**Two send modes:**
- **Card mode (`send-stamp.sh`)** — adaptive approval cards with Approve/Skip buttons. Used for approval flows.
- **Text mode (`send-stamp-text.sh`)** — plain-text DM. Used for error notifications, alerts, or simple status updates where no button is needed.

---

## Usage

```bash
bash send-stamp.sh \
  --recipient "Adi Khanna" \
  --subject "Subject line — controls Teams preview" \
  --card templates/{template-name}.json \
  --payload /tmp/payload1.json \
  [--payload /tmp/payload2.json ...] \
  [--stacked]
```

`--stacked` sends all cards in one message. Omit for a single card.

---

## Approval Type Registry

Each approval type defines: who receives it, subject line format,
which template to use, and what payload fields are required.

---

### 1. Government Bid Approval

**Trigger:** ct-gov-rfp-scanner finds QUALIFIED or WARNING opportunities
**Recipient:** Adi Khanna (always — gov bids reviewed centrally)
**Template:** `templates/gov-bid-approval-card.json`
**Delivery:** Stacked — all qualifying opps from one scan run in one message
**Subject format:** `Gov Bid Scanner — {N} opportunit{y/ies} need approval`

**Subject examples:**
- `Gov Bid Scanner — 1 opportunity needs approval`
- `Gov Bid Scanner — 3 opportunities need approval`

**Approve action:** `Action.Http` POST to push routine's `/fire` endpoint
**Skip action:** `Action.Submit` — dismisses, no CRM push

**Required payload fields:**
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
  "set_aside": "Small Business",
  "type_of_system": ["Meeting Space"],
  "mandatory_site_visit": "No",
  "bid_submission_style": "Email",
  "contact_name": "Patrick Madan",
  "contact_email": "patrick.madan.2@us.af.mil",
  "contact_phone": "478-222-4098",
  "questions_due_date": "Mar 13, 2026 4:30 PM EDT",
  "response_date": "Mar 23, 2026 4:30 PM EDT",
  "scope_summary": "2-3 sentence scope summary",
  "description": "[full 7-section brief text]",
  "ct_score": 5,
  "status": "QUALIFIED",
  "warnings": ["No ship-ahead, 2-day install window", "NIPR network integration required"]
}
```

**Credentials:** Hardcoded in `send-stamp.sh` — no env vars required.

**Called by:** ct-gov-rfp-scanner Step 10

---

*(Future approval types go here — add template + registry entry)*

---

## Card Template Placeholders

### gov-bid-approval-card.json

| Placeholder | Source | Example |
|---|---|---|
| `${title}` | payload.title | Commander's Conference Room Upgrade |
| `${sol_number}` | payload.sol_num | FA857126Q0048 |
| `${agency}` | payload.account_name | Department of the Air Force |
| `${location}` | payload.location | Robins AFB, GA |
| `${deadline}` | payload.bid_due_date | Mar 23, 2026 4:30 PM EDT |
| `${days_remaining}` | Calculated from payload.deadline | 4 days |
| `${set_aside}` | payload.set_aside | Small Business |
| `${type_of_system}` | payload.type_of_system (join list) | Meeting Space |
| `${bid_submission_style}` | payload.bid_submission_style | Email |
| `${mandatory_site_visit}` | payload.mandatory_site_visit | No |
| `${match_score}` | payload.ct_score | 5 |
| `${score_color}` | Derived: 7+= good, 4-6= warning, 1-3= attention | warning |
| `${status_badge}` | payload.status | QUALIFIED |
| `${scope_summary}` | payload.scope_summary | Full AV upgrade of... |
| `${red_flags}` | payload.warnings — top 3, Red:/Yellow: prefix | Red: No ship-ahead... |
| `${poc_name}` | payload.contact_name | Patrick Madan |
| `${poc_email}` | payload.contact_email | patrick.madan.2@us.af.mil |
| `${notice_id}` | payload.notice_id | b1f9d43b... |
| `${routine_fire_url}` | env STAMP_ROUTINE_FIRE_URL | https://api.anthropic.com/... |
| `${routine_bearer_token}` | env STAMP_ROUTINE_BEARER_TOKEN | sk-ant-oat01-... |
| `${push_payload_json}` | Serialized + escaped payload JSON | {\"sol_num\":\"FA857...\"} |

---

## Stamp Bot Credentials

| Key | Value |
|---|---|
| App ID | `71916c47-9267-4742-9068-17022cc8bb68` |
| Tenant ID | `609b5b72-9a87-4376-825b-20726d50a60b` |
| Client Secret | Hardcoded in send-stamp.sh |
| Bot display name | `Stamp` |

---

## Subject Line / Preview

The `--subject` flag sets the `summary` field on the Teams message
attachment. This is what appears in the Teams activity feed and push
notification before the recipient opens the message. Always fill it —
an empty subject means the notification preview is blank.

---

## Token and Conversation Caching

Tokens cached 50 min at `/tmp/stamp-token-cache.json`.
Conversations cached at `/tmp/stamp-conversations.json`.
Both keyed separately from adiai-messenger.

---

## Plain-text notifications (text mode)

For non-approval notifications — error alerts, "manual attention needed"
pings, simple status updates — use the text variant:

```bash
bash send-stamp-text.sh \
  --recipient "Adi Khanna" \
  --message "⚠️ CRM push failed for FA850126Q0016 — Replace Bowling Alley Sound System. Manual attention needed."
```

Same credentials, same token/conversation caches. No card template,
no payload, no buttons — just a text DM. Keep messages short (one
line subject + one line detail is ideal).

**When to use text mode vs card mode:**
- **Text mode** — error alerts, system failures, status FYIs. No user
  action needed, just a heads-up.
- **Card mode** — approval flows where the user clicks Approve/Skip
  to trigger downstream action.

---

## Adding a New Approval Type

1. Create a new card template in `templates/{type}-card.json` with
   `${placeholder}` variables for all dynamic fields
2. Add a new registry entry to this SKILL.md following the same format
   as the gov bid entry above — define recipient, subject format,
   template name, payload schema, approve action, and which skill calls it
3. Update `send-stamp.sh` populate_card() if the new template needs
   custom derived fields (e.g. calculated values, color maps) beyond
   the standard string replacements
