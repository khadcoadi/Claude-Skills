---
name: ct-gov-potential-push
description: >
  Creates Zoho CRM Deals (Potentials) from government AV bid opportunities
  found by the ct-gov-rfp-scanner. Handles account lookup and creation,
  maps all scanner fields to the correct CRM fields, and confirms before
  writing. Use when someone says "push to CRM", "add to Zoho", "create the
  potential", "log this bid", or "push these opps". Always run this skill
  when pushing government bids into Zoho — do not attempt to create Deals
  manually without it.
---

# ct-gov-potential-push

Takes qualifying opportunity data from the ct-gov-rfp-scanner output and
creates a properly structured Deal in Zoho CRM. Checks for an existing
account first, creates one if needed following CT's account naming rules,
then creates the Deal with all available fields populated.

Always show a confirmation summary and get explicit approval before
creating anything in CRM.

---

## Step 1 — Resolve the Account

Before creating any Deal, find the correct account to attach it to.

### Account lookup
Search for the account by exact name:
```
SELECT Account_Name, id FROM Accounts WHERE Account_Name = '[name]' LIMIT 5
```

If an exact match is found, use that account ID. If multiple results
return (duplicates that haven't been merged yet), flag this to the user
and use the one with the most existing Deals.

### Account naming rules

**Military branches — use the Department name:**
| Branch | Correct account name |
|---|---|
| Air Force | `Department of the Air Force` |
| Army | `Department of the Army` |
| Navy | `United States Navy` |
| Marine Corps | `US Marine Corps` |
| Space Force | `United States Space Force` |
| Coast Guard | `United States Coast Guard` |

**National Guard — state-level accounts:**
Format: `[State] [Army/Air] National Guard`
Examples: `Washington Army National Guard`, `Texas Air National Guard`,
`Indiana National Guard`
Search for the state-specific account before creating. If it doesn't
exist, create it.

**Federal civilian agencies:**
Use `Department of [Name]` format.
Examples: `Department of Veteran Affairs`, `Department of the Interior`,
`Department of Agriculture`, `Defense Health Agency`

**Never use:**
- `Department of Defense` as a catch-all — always use the correct branch
- Installation-level accounts for new bids (Robins AFB, Nellis AFB, etc.)
  unless that base already has an established account with existing deals

### Creating a new account
If no matching account exists, create it before creating the Deal:
```json
{
  "Account_Name": "[correct name per rules above]",
  "Industry": "Government",
  "Description": "Government entity — auto-created by ct-gov-potential-push"
}
```
Confirm account creation with the user before proceeding.

---

## Step 2 — Resolve Owner (round robin)

Before mapping fields, determine who owns this Deal.

### Query last government bid owner
```sql
SELECT Owner, Deal_Name, Created_Time 
FROM Deals 
WHERE Is_this_a_Government_or_Partner_Bid = 'Yes' 
ORDER BY Created_Time DESC 
LIMIT 1
```

### Round robin logic
| Last owner | Assign to |
|---|---|
| Kevin Lacayo | Leonardo Moretti |
| Leonardo Moretti | Kevin Lacayo |
| No result found | Kevin Lacayo (default) |
| Anyone else | Kevin Lacayo (default) |

**Known owner IDs:**
- Kevin Lacayo: `1351252000153431001`
- Leonardo Moretti: `1351252000000162033`

### Intra-session tracking
If pushing multiple opportunities in the same session, do not re-query
CRM for each one — track the last assignment locally and alternate each
time. Example: CRM last owner was Leo → first push goes to Kevin → second
push goes to Leo → third push goes to Kevin, and so on.

Include the assigned owner in the Step 4 confirmation card so it's
visible before confirming the push.

---

## Step 3 — Map Fields

Map scanner output to CRM fields using the table below. Only populate
fields where data is available — leave others blank rather than guessing.

### Deal Name format
`AV - [Account Name] - [Brief Installation/Project Description]`

Examples from existing entries:
- `AV - Department of the Air Force - AFIT Building 643 Room 206 Audio Visual Upgrade`
- `AV - Department of the Army - Conference Room Refresh Camp Keyes`
- `AV - Department of the Air Force - Commander's Conference Room Upgrade Robins AFB`

Keep the description portion concise — installation name + project type.
Do not include the solicitation number in the Deal Name.

This naming convention is fixed and must be followed for every government bid entry — no variations (not 'AVV -', not 'DOD -', always 'AV - [Account] - [Description]').

### Field mapping

| CRM Field | API Name | Source | Notes |
|---|---|---|---|
| Potential Name | `Deal_Name` | Scanner title + account | Format per naming convention above |
| Account Name | `Account_Name` | Resolved in Step 1 | Lookup ID |
| Stage | `Stage` | Always `Qualification` | Fixed value for new bids |
| Closing Date | `Closing_Date` | Response deadline | Date format YYYY-MM-DD |
| Amount | `Amount` | Estimated value | Numeric only; leave blank if not stated |
| Lead Source | `Lead_Source` | Always `AI` | Fixed value — scanner found it |
| Is Gov/Partner Bid | `Is_this_a_Government_or_Partner_Bid` | Always `Yes` | Fixed value |
| US/International | `US_International` | Always `US` | Fixed unless overseas (which should be DQ'd) |
| Sale Type | `Sale_Type` | Always `External` | Fixed value for government bids |
| Bid Link | `Bid_Link` | SAM.gov URL from scanner | Full URL |
| Bid Due Date | `Bid_Due_Date` | Response deadline | Text — use human-readable format e.g. "Apr 10, 2026 12:00 PM EST" |
| Location | `Location` | Installation name + state | e.g. "Robins AFB, GA" |
| Description | `Description` | Full opportunity brief | Paste full scanner brief including all 7 sections. Scope field is intentionally left blank — Description is the only narrative field used. |
| Type of System | `Type_of_System` | Inferred from scope | Multi-select: see mapping below |
| Mandatory Site Visit | `Mandatory_Site_Visit` | Scanner DQ check result | "Yes", "No", or leave blank if unknown |
| Bid Submission Style | `Bid_Submission_Style_electronic_or_mail` | From 7f submission mechanics | "Email", "Portal", "Mail" |
| Contact Email | `Contact_Email` | CO/CS email from documents | As found in solicitation |
| Contact Phone | `Contact_Phone` | CO/CS phone from documents | As found in solicitation |
| Questions Due Date | `Questions_Due_Date` | From 7f or Q&A docs | Text, as stated in solicitation |
| Date of Site Visit | `Date_of_Site_Visit` | From docs if applicable | Text, as stated |
| Owner | `Owner` | Resolved in Step 2 | Kevin or Leo per round robin — lookup ID |
| Pre Sale Designer | `Pre_Sale_Designer` | Leave blank | Assigned by design team post-entry |
| Response Date | `Response_Date` | Response deadline | Same as Bid Due Date, text format |

### Type of System mapping
Infer from scope — select all that apply:
- `Distributed System` — background audio, distributed video, multi-room
- `Meeting Space` — conference room, huddle room, boardroom, VTC, SVTC
- `Video Walls` — video wall, display wall, multi-panel display
- `Other` — anything that doesn't fit above categories

---

## Step 4 — Confirmation Display

Before creating anything, show the user a clean summary card with every
field that will be written. Format it clearly so they can spot errors.

Include:
- Deal name
- Account (and whether it's existing or being created new)
- All populated fields with their values
- Any fields being left blank and why

Ask: **"Ready to push this to Zoho? Confirm to create."**

Wait for explicit yes before proceeding.

---

## Step 5 — Create the Deal

Use `ZohoCRM_createRecords` on the `Deals` module with the mapped payload.

```json
{
  "data": [{
    "Deal_Name": "AV - Department of the Air Force - ...",
    "Account_Name": {"id": "1351252000172670341"},
    "Stage": "Qualification",
    "Closing_Date": "2026-03-23",
    "Amount": 0,
    "Lead_Source": "AI",
    "Is_this_a_Government_or_Partner_Bid": "Yes",
    "US_International": "US",
    "Sale_Type": "External",
    "Bid_Link": "https://sam.gov/opp/.../view",
    "Bid_Due_Date": "Mar 23, 2026 4:30 PM EDT",
    "Location": "Robins AFB, GA",
    "Description": "...",  // Scope field intentionally left blank
    "Type_of_System": ["Meeting Space"],
    "Mandatory_Site_Visit": "No",
    "Bid_Submission_Style_electronic_or_mail": "Email",
    "Contact_Email": "...",
    "Contact_Phone": "...",
    "Questions_Due_Date": "...",
    "Response_Date": "Mar 23, 2026 4:30 PM EDT"
  }]
}
```

After creation, confirm success and return the Zoho CRM record URL:
`https://crm.zoho.com/crm/org45247585/tab/Potentials/{record_id}`

---

## Step 6 — Download and attach solicitation documents

After successful Deal creation, fetch all solicitation documents fresh
from SAM.gov using the `notice_id` from the push payload, then attach
each file individually to the Deal.

### 6a — Get fresh resource links

Call the SAM.gov search API to retrieve current attachment URLs:

```python
import requests

API_KEY = 'SAM-fc5c7c25-a32d-4827-aa57-481c78ad37bf'
r = requests.get(
    'https://api.sam.gov/opportunities/v2/search',
    params={'api_key': API_KEY, 'solnum': sol_num, 'limit': 1},
    timeout=20
)
links = r.json().get('opportunitiesData', [{}])[0].get('resourceLinks', [])
```

**Critical:** These are pre-signed S3 URLs with a ~9-second expiry.
Fetch and write each file to disk immediately — no delay between the
GET and the file write. Use `verify=False` on all requests to bypass
the S3 SSL redirect.

### 6b — Download each file

```python
import os, subprocess
import warnings; warnings.filterwarnings('ignore')

os.makedirs(f'/home/claude/docs_push/{sol_num}/', exist_ok=True)

downloaded = []
for i, link in enumerate(links):
    file_id = link.split('/files/')[-1].split('/')[0][:16]
    fpath = f'/home/claude/docs_push/{sol_num}/{sol_num}_{i}_{file_id}'
    try:
        resp = requests.get(link, timeout=20, verify=False)
        if resp.status_code == 200 and len(resp.content) > 500:
            with open(fpath, 'wb') as f:
                f.write(resp.content)
            downloaded.append(fpath)
    except Exception as e:
        print(f'Download failed: {link[:60]} — {e}')
```

**File type detection:** Use `subprocess.run(['file', fpath])` to detect
type. Skip JPEG/image-only files — attach text documents only
(PDF, DOCX, XLSX). Flag scanned drawing PDFs as unreadable but still
attach them so the full solicitation package is in the record.

**Naming convention:** Rename files with clean names before attaching:
`{SOL_SHORT}_{DocType}.{ext}`
Examples: `FA857_QandA.pdf`, `FA857_PurchaseDescription.pdf`

Use `pdftotext -layout` to peek at the first page of each PDF to
identify the document type for naming (Q&A, SOW, Purchase Description,
Amendment, Safety Requirements, etc.).

### 6c — Attach each file to the Deal

Upload each downloaded file individually using `ZohoCRM_uploadAttachment`:
- `moduleApiName`: `Deals`
- `recordId`: record ID returned from Step 5
- `file`: binary content of the file

```python
for fpath in downloaded:
    with open(fpath, 'rb') as f:
        file_content = f.read()
    # Call ZohoCRM_uploadAttachment with binary file content
```

If a single upload fails, log the filename and continue — do not stop
the batch.

After all uploads complete, report total files attached and list each
filename.

---

## Step 7 — Multi-opportunity handling

If the scanner produced multiple qualifying opportunities, process them
one at a time. After confirming and pushing the first, ask:
"Push the next one ([deal name])?"

Do not batch-create without individual confirmation on each.

---

## Account creation rules (reference)

These rules govern all government account creation in Zoho CRM:

1. **Use the branch, not the unit.** Account = military department or
   federal agency at top level. The installation or squadron lives in
   the Deal Name and Location field, not as a separate account.

2. **National Guard exception.** State Guard units get state-level
   accounts: `[State] [Army/Air] National Guard`. Search for the
   state-specific account before creating.

3. **Base-level account exception.** Only use an installation-level
   account if CT has an ongoing relationship and the base already has
   an established account with multiple deals. For a first-time SAM.gov
   bid at a new base, use the branch account.

4. **Never use `Department of Defense` as the account.** Each deal must
   be under the correct branch.

5. **Federal civilian agencies** use `Department of [Name]` format.

6. **Duplicate account check.** Before creating, always search. If a
   name-match exists that isn't in the canonical list above, flag it to
   the user rather than creating a second entry.

---

## Known canonical account IDs

| Account | ID |
|---|---|
| Department of the Air Force | `1351252000172670341` |
| Department of the Army | `1351252000021117133` |
| United States Navy | `1351252000036395051` |
| US Marine Corps | `1351252000022815107` |
| Department of Veteran Affairs | `1351252000204508065` |
| Department of Defense | `1351252000186118067` *(do not use for new bids)* |
| Department of the Interior | `1351252000204499674` |
| Indiana National Guard | `1351252000179468059` |
