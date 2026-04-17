# ICP Criteria by Product Line

## How to Identify the Product Line

Check in this order:

1. `Interested_Products` field:
   - Contains "AV" → AV lead
   - Contains "Padzilla" → Padzilla lead
   - Contains "Unreal Bowling" → Unreal Bowling lead

2. If `Interested_Products` is empty or ambiguous, check `Form_URL` and `First_Visited_URL`:
   - URL contains `lp.crunchytech.com/bars` → AV
   - URL contains `bowling` or `unrealbowl` → Unreal Bowling
   - URL contains `padzilla` or `touchscreen` → Padzilla

3. If still unclear, check `Campaign` and `FB_Campaign` fields for keywords.

4. If no signal at all, default to AV (highest volume).

---

## AV Leads — Ideal Customer Profile

### Core ICP (Strong fit):
- Sports bars, brew pubs, craft beer bars with TVs
- Restaurants with a dedicated bar area that shows games
- Entertainment venues (arcades, FECs, bowling alleys with bar areas)
- Multi-location restaurant/bar groups
- Venues undergoing renovation or new construction

### Moderate fit:
- Upscale restaurants with bar (ambiance AV, not sports)
- Hotels with bar/lobby areas
- Corporate event spaces
- Nightclubs (audio-heavy, less video)

### Weak fit:
- Fine dining with no bar
- Fast casual / counter service
- Food trucks
- Residential
- Someone who wants to "open a business someday" (no existing venue)

### Red flags that indicate Weak/Unknown:
- Company field is a sentence, not a business name
- Message says "I want to start a business" or "help me open"
- No verifiable business found in web search
- AI_Message_Score is 0 AND no visit history AND no business found

### What makes an AV lead "Strong":
At least 3 of these:
- Real business verified with reviews
- Owner or decision maker
- Sports bar or entertainment venue
- Active renovation, new location, or relaunch
- Multi-visit or content engagement

---

## Unreal Bowling Leads — Ideal Customer Profile

### Core ICP (Strong fit):
- Existing bowling centers looking to upgrade/activate lanes
- Entertainment venues / FECs adding bowling
- New-build entertainment complexes with bowling in the plan
- Bowling center owners expanding to additional locations

### Moderate fit:
- Bars or restaurants considering adding mini-bowling
- Event venues exploring bowling as an attraction
- Franchise groups evaluating bowling concepts

### Weak fit:
- Residential inquiries
- Someone who wants to "open a bowling alley someday"
- No existing business or venue
- Inquiries about equipment only (pins, balls) not full systems

### What makes a UB lead "Strong":
- They own or operate a bowling center or entertainment venue
- They specifically mentioned "activated lanes" or "interactive bowling"
- They have prior deal history with Unreal Bowling
- Active construction or expansion underway

---

## Padzilla Leads — Ideal Customer Profile

### Core ICP (Strong fit):
- Event companies / trade show exhibitors
- Real estate developers / sales centers
- Retail flagship stores
- Corporate experience centers
- Museums / visitor centers

### Moderate fit:
- Restaurants wanting digital menu boards
- Hotels wanting lobby displays
- Conference / meeting facilities
- Sports teams / venues wanting interactive fan experiences

### Weak fit:
- Personal / home use
- Small businesses wanting a basic digital sign
- No clear use case described

### What makes a Padzilla lead "Strong":
- Clear commercial use case
- Budget signals or corporate buyer
- Event or trade show timeline mentioned
- Multi-unit inquiry

---

## Cross-Product Signals

Some leads may be interested in multiple products. For example, an entertainment venue might want Unreal Bowling + AV for the bar area. In these cases:

- Score against the PRIMARY product interest (the one in `Interested_Products`)
- Note the cross-sell opportunity in the enrichment note hooks
- Tag the lead for both teams if applicable
