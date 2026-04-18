# ct-gov-potential-push — Roadmap

Future enhancements. Not scheduled — prioritize as needs arise.

## Proactive "Key questions worth submitting" on the Potential

**Current:** if no Q&A has been posted for a solicitation, neither the
scanner nor the push skill generates suggested pre-bid questions for
the reviewer to submit before the Q&A deadline. The Deal's Description
just notes "no Q&A posted."

**Proposed:** at push time (Step 5 or Step 6), generate a short list of
proactive pre-bid questions based on the opportunity payload, and
attach them to the Potential either:

- Appended to the Deal `Description` field under a `### Pre-bid
  questions to submit` section, **or**
- Created as a separate CRM Note on the Deal titled
  `Pre-bid questions — submit before {questions_due_date}`

Questions should be tailored to the opportunity type — for AV installs:
- Existing network infrastructure (dedicated AV VLAN, PoE capacity)
- Existing endpoints to integrate (Polycom/Teams Rooms/Zoom Rooms model)
- Room dimensions and ceiling height (affects mic/speaker placement)
- Electrical availability at rack location (20A circuits, UPS)
- Whether listed equipment is dealer-supplied or client-preferred
- Warranty / support term expectations (remote-only vs on-site SLA)

**Why not in the scanner:** the scanner's role is to find and classify
opportunities, not to draft bid team worksheets. Adding this at push
time keeps the analysis closer to when it's actionable (the Deal is
now owned by Kevin or Leo and they can work the question list
directly against the Q&A deadline).

**Trigger logic:** only generate proactive questions when
`questions_due_date` is present in the payload AND it's >= today. If
the Q&A deadline has already passed, skip this step.
