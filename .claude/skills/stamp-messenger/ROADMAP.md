# Stamp Messenger — Roadmap

Future enhancements. Not scheduled — prioritize as needs arise.

## Card feedback after Approve / Skip

**Current:** clicking Approve silently fires the routine webhook via the
Azure Function handler. The card stays on screen with no visual
acknowledgement. User has no confirmation the push happened.

**Proposed:** after the handler fires the routine successfully, post a
reply activity to the same Teams conversation:

```
✅ Approved — pushing {title} to CRM
```

Skip action would post a similar dismissal note. Requires:

- Bot token (reuse existing client credentials flow)
- POST to `{serviceUrl}/v3/conversations/{conversation.id}/activities`
  with a plain text activity
- Pull `serviceUrl`, `conversation.id`, and original card title from
  the incoming Action.Submit payload

Adds ~30 lines to `azure/function_app.py` in the handler.

## Update original card to "Approved" state

**Next level:** replace the Approve/Skip buttons with a disabled
"✅ Approved by {user} at {time}" banner so the card itself reflects
its resolved state. Prevents double-submission and gives a persistent
audit trail inside Teams.

Requires switching the Approve button from `Action.Submit` to
`Action.Execute` (invoke activity) and returning a new adaptive card
in the invoke response (`adaptiveCard/action` invoke response type).

More complex than simple feedback — involves:

- Changing the card action type
- Handler returns a new `AdaptiveCard` JSON in the invoke response
- Need to preserve original card body fields when rebuilding

## Azure Function — bot identity hardening

**Current:** the `/api/messages` endpoint is unauthenticated. Anyone
with the URL can POST a fake Activity.Submit and fire the routine.

**Proposed:** validate the JWT on the `Authorization: Bearer` header
using Microsoft's Bot Framework public keys (JWKS). Confirms the
caller is Teams on behalf of our bot.

Requires `PyJWT` + `cryptography` in `requirements.txt` and fetching
the OpenID config from
`https://login.botframework.com/v1/.well-known/openidconfiguration`.

## Retry + dead-letter on routine fire failure

**Current:** if the routine webhook returns non-2xx, the handler
returns 500. Teams may retry, but there's no durable queue.

**Proposed:** on failure, write the payload to an Azure Storage queue
or table so it can be retried later (manual or via a timer-triggered
function). Alert the sender in Teams that the push failed.

## Multi-approver routing

**Current:** every gov bid card goes to Adi. If Adi is out, nothing
gets approved.

**Proposed:** add a fallback list per approval type in the skill
registry. If primary approver doesn't respond within N hours, send
a copy to the fallback.

Requires a timer-triggered function checking pending approvals and a
lightweight state store (Table Storage).

## Skip action — confirm dismissal

**Current:** Skip fires an Action.Submit that goes nowhere (the
messaging endpoint handler only handles `action == "approve"`).

**Proposed:** handle `action == "skip"` in the handler — log the
dismissal to Application Insights with the sol_num and user, then
(optionally) update the card to show "⚪ Skipped by {user}".

Useful for audit: we want to know which opps Adi reviewed and
rejected, not just the approved ones.
