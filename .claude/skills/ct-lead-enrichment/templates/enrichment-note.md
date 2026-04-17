# Enrichment Note Template

## Note Title Format
```
AI Lead Enrichment — {Full_Name}
```

If the company name is known and verified:
```
AI Lead Enrichment — {Full_Name} — {Company}
```

---

## Note Content Structure

The note is plain text (no markdown rendering in Zoho CRM). Use CAPS for section headers, dashes for visual separation, and plain line breaks for structure.

---

### Template:

```
LEAD SNAPSHOT
{Full_Name} | {City}, {State} | {Email} | {Phone}
Source: {Lead_Source} — {FB_Campaign or Campaign or Lead_Received_Method}
Landed on: {First_Visited_URL — simplified to readable form} — {Days_Visited} visit(s), avg {Average_Time_Spent_Minutes} min, visitor score {Visitor_Score}
Message: "{Message field — quoted verbatim, truncated if very long}"
AI Message Score: {AI_Message_Score}

---

DUE DILIGENCE
{Business validation paragraph. What was found about the business — type, location, description, review presence, anything notable. Keep it factual and concise. 2-5 sentences.}

{Weave visit behavior into the narrative where it adds context — don't list it separately. Examples:
- "Visited the bars landing page three times over five days before filling out the form — not a casual clicker."
- "Spent 4.2 minutes reading the page, which is well above average for these leads."
- "Single visit, under a minute on the page — impulse form fill. Set expectations accordingly."
- "Came in through the Google Ad, not Facebook — was actively searching for commercial AV."
Only mention visit behavior when it changes the read on the lead. A single 2-minute visit with nothing notable doesn't need a sentence.}

Google: {rating} / {review count} reviews
Website: {URL if found, or "None found"}
Owner: {Confirmed as owner/operator if verified, or "Not confirmed" if unknown}
Size estimate: {Small (under 1,000 sqft / under 5 employees) | Mid (1,000-3,000 sqft / 10-20 employees) | Large (3,000+ sqft / 20+ employees) | Unknown} — {basis for estimate, e.g., "BBB lists 5-9 employees, reviews say 'small pub'" or "multiple zones mentioned, seats 200+ per event page"}

{If address correction needed:}
⚠️ ADDRESS CORRECTION: {Company} is at {correct address}, not {CRM address}. The CRM city/state should be updated.

{If growth/timing signals found:}
Signals: {Describe — renovation, new location, relaunch, new build, etc.}

{If no business found:}
⚠️ No verifiable business found. The Company field contains "{Company field value}" which does not appear to be an operating business. Manual verification recommended before outreach.

---

PRIOR CRM HISTORY
{One of the following:}

None — clean across Leads, Contacts, and Accounts.

OR

⚠️ EXISTING CONTACT FOUND
{Full_Name} exists as a Contact ({contact_email}) under Account: {Account_Name} (ID: {account_id})
Deal history: {Deal_Name} — {Stage} — ${Amount} — Close date: {Closing_Date}
{If Closed Lost: "This is a RETURNING LOST DEAL. The rep should reference the prior conversation."}

OR

Duplicate lead detected — same email exists on Lead ID {other_lead_id} created {date}. May need to be merged.

---

ICP FIT
ICP Fit: {Strong / Moderate / Weak / Unknown}
ICP Score: {X}/100
Rationale: {One sentence explaining why. E.g., "Owner of established sports bar with strong reviews, expanding to second location, active inquiry."}

Product Line: {AV / Padzilla / Unreal Bowling}

---

HOOKS FOR THE CALL
1. {First hook — the most important thing the rep should know or reference on the call. Specific to what enrichment found.}
2. {Second hook — another angle or talking point. Based on visit behavior, business details, or timing signals. If the lead visited multiple times or spent significant time on the page, tell the rep: "She spent 4 minutes on the page and came back twice — she's done her homework. Skip the intro pitch." If they came through a specific campaign or landing page, note it: "He came in through the sports bar ad, not the general site — he's already thinking about screens and sound."}
3. {Third hook if warranted — or a "don't" / what to avoid assuming.}

---

DISCOVERY QUESTIONS (for the call)
{3-5 questions tailored to this specific lead based on enrichment findings. These are NOT generic discovery questions. They are informed by what we already know — so the rep skips "tell me about your venue" and jumps to smart questions that demonstrate expertise.}

Question generation rules:
- Never ask something the enrichment already answered (don't ask "what type of venue is this" if we already know)
- Start with what we know and go deeper ("You just finished a renovation — where did AV land in that process?")
- Include one question about their current setup ("What are you running for screens/sound right now?")
- Include one question that gets to timeline/budget without asking "what's your budget?" ("Is this something you're looking to do this quarter or more of a planning conversation?")
- Include one question specific to their situation from enrichment (multi-location, renovation, relaunch, returning buyer, etc.)
- If returning lost deal: lead with "What's changed since we last talked?" — it's the most natural opener
- Keep questions conversational, not interrogative — these are talking points, not a survey
- If the lead came through a specific landing page (e.g., lp.crunchytech.com/bars/), the rep can reference it naturally: "You came in through our sports bar page — is that the main concept?" This shows the rep did homework and steers the conversation.

Example for Warren Ackley (3-zone venue, just renovated):
1. "You just wrapped a big renovation — did AV get included in that or was it pushed to phase 2?"
2. "With the Sports Zone, the restaurant, and The Club, are you thinking about upgrading all three or starting with one?"
3. "What are you running for control right now — remotes per room, or do you have something centralized?"
4. "Is this something you want to move on soon or more of a 'let's figure out what it looks like' conversation?"

Example for Sean Kobos (2 locations, expanding):
1. "What are you running at the Conway location right now — consumer TVs or commercial?"
2. "For location #2, are you building out from scratch or is there existing AV in the space?"
3. "When you're running game day across 20 taps and a full house, what's the biggest pain point with the current setup?"
4. "Are you looking to get both locations on the same system or handle them separately?"

Example for Kevin Havens (returning lost deal, new-build):
1. "What's changed since last year — did construction hit a milestone or did the budget open up?"
2. "Last time we talked about 8 lanes for self-install. Is that still the thinking or has the scope shifted with the full 60K sqft plan?"
3. "Are you working with a GC on the buildout? Helps us know who to coordinate AV rough-in with."

Example for Serafin Miranda (restaurant relaunch, not sports bar):
1. "What's driving the relaunch — new ownership, new concept, or a refresh of the existing space?"
2. "When your guests are at the bar vs. the dining room, how different do you want those two experiences to feel?"
3. "Are you mostly thinking about sound, or are you also looking at adding screens or digital elements?"
4. "Is there a target date for the relaunch you're working toward?"

---

{FOR AV LEADS ONLY — include this section:}

DRAFTED FOLLOW-UP EMAIL
Subject: {subject line}

{Email body — 3 sentences, under 50 words. See email-guidelines.md for tone rules.}

{Rep First Name}
Crunchy Tech
(407) 545-1788

[Rep: review, personalize if needed, send from CRM]

---

{FOR NON-AV LEADS — include this instead:}

NOTE: Draft email not included for {Padzilla / Unreal Bowling} leads. Use the hooks above for manual outreach.

---

RECOMMENDED ACTION
{One of: Call / Email (draft above) / Nurture / Disqualify / Manual Research Needed}
{One sentence of reasoning. E.g., "Strong ICP fit with active timing signal — call this week." or "No business exists — nurture drip only." or "Enrichment partial — needs manual research on venue type before outreach."}

---

Enrichment Status: {Complete / Partial / Failed}
{If Partial: "Gaps: {list what couldn't be found — e.g., no Google listing, website under construction, ownership unconfirmed}"}
Enriched: {current date/time}
```

---

## Formatting Notes

- Keep the entire note under 1000 words. Reps won't read a novel.
- The DUE DILIGENCE section is the meatiest — 2-5 sentences of actual research findings.
- HOOKS should be 1-2 sentences each, max 3 hooks.
- DISCOVERY QUESTIONS should be 3-5 questions, each one sentence. These must be specific to what enrichment found — if the questions could apply to any lead, they're too generic. Rewrite them.
- The DRAFTED EMAIL section is literally the email — ready to copy-paste. Not a description of what the email should say.
- Use ⚠️ emoji sparingly but it's effective for flagging corrections and critical findings (prior deals, address errors).
- Plain text only. No markdown bold/italic — it won't render in Zoho CRM notes.
