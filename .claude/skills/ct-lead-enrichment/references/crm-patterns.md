# Zoho CRM MCP Patterns

## Key IDs
- Zoho CRM Org ID: 45247585 (base URL: https://crm.zoho.com/crm/org45247585/)
- Zoho Desk Org: 45524447
- Zoho Projects Portal: 45517604
- Leads Module ID: 1351252000000002175

## Tool Name Reference (actual MCP tool names)

Use these exact tool names — the skill was originally written with generic names that don't match the live connector:

| Intent | Actual Tool Name |
|--------|-----------------|
| Query leads / contacts with filters | `ZohoCRM_executeCOQLQuery` |
| Get a single lead record | `ZohoCRM_executeCOQLQuery` (WHERE id = '...') |
| Search contacts by name / email / phone | `ZohoCRM_executeCOQLQuery` |
| Get related records (e.g. Deals on a Contact) | `ZohoCRM_getRelatedRecords` |
| Create a note on a record | `ZohoCRM_createNotes` |
| Update a lead record | `ZohoCRM_updateLeadsRecord` |

---

## Pulling Lead Data

All lead data pulls use ZohoCRM_executeCOQLQuery. Stay under the 50-field SELECT limit per query.

**Batch 1 — Core fields:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, First_Name, Last_Name, Email, Phone, Mobile, Company, Designation, Lead_Status, Lead_Source, Message, Business_Type, Interested_Products, Interested_Services, Sale_Type, Website, City, State, Zip_Code, Country, AI_Message_Score, Attempts, Created_Time, Owner FROM Leads WHERE id = '{lead_id}'"
}
```

**Batch 2 — Visit & campaign fields:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, Visitor_Score, First_Visited_URL, Referrer, Average_Time_Spent_Minutes, Days_Visited, First_Visited_Time, Last_Visited_Time, FB_Campaign, FB_Ad_Name, Form_URL, Lead_Received_Method, Campaign FROM Leads WHERE id = '{lead_id}'"
}
```

**Finding unenriched AV leads (by date):**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, First_Name, Last_Name, Email, Phone, Company, Lead_Source, Interested_Products, CT_Enrichment_Status, Lead_Status, Created_Time FROM Leads WHERE Created_Time >= '{YYYY-MM-DD}T00:00:00-05:00' AND Interested_Products like '%AV%' LIMIT 10"
}
```
Then filter manually in conversation: skip any where CT_Enrichment_Status = "Complete".

**COQL limitations to know:**
- Does not support IS NULL or OR in WHERE clauses reliably — pull all and filter manually
- Field names are case-sensitive and must match the CRM API names exactly
- LIMIT max is 200; default is 10

---

## CRM Duplicate Check

All duplicate checks use ZohoCRM_executeCOQLQuery.

**Search Contacts by last name:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, Email, Account_Name FROM Contacts WHERE Last_Name = '{Last_Name}' LIMIT 5"
}
```

**Search Contacts by email:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, Email, Account_Name FROM Contacts WHERE Email = '{email}' LIMIT 5"
}
```

**Search Contacts by phone:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, Email, Account_Name FROM Contacts WHERE Phone = '{phone}' LIMIT 5"
}
```

**Search for duplicate Leads by email:**
```
ZohoCRM_executeCOQLQuery
body: {
  "select_query": "SELECT id, Full_Name, Created_Time, Lead_Status FROM Leads WHERE Email = '{email}' LIMIT 5"
}
```
If count > 1, it is a duplicate.

**If Contact found — get their Deals:**
```
ZohoCRM_getRelatedRecords
(parentRecordModule: Contacts, parentRecord: {contact_id}, relatedList: Deals)
```

---

## Writing the Enrichment Note

Use ZohoCRM_createNotes. Both path_variables AND Parent_Id inside the body are required. The tool will fail with "Mandatory path variable parentRecordId is not present" if path_variables is omitted.

```
ZohoCRM_createNotes
path_variables: {
  "parentRecordModule": "Leads",
  "parentRecordId": "{lead_id}"
}
body: {
  "data": [{
    "Note_Title": "AI Lead Enrichment — {Full_Name} — {Company}",
    "Note_Content": "{full enrichment note — plain text, no markdown}",
    "Parent_Id": {
      "id": "{lead_id}",
      "module": {
        "api_name": "Leads",
        "id": "1351252000000002175"
      }
    }
  }]
}
```

Note_Content accepts plain text only. Do not use markdown — it will not render in Zoho CRM notes.

---

## Updating Lead Custom Fields

Use ZohoCRM_updateLeadsRecord. Both path_variables.recordID and Last_Name in the body are required — omitting either causes the call to fail.

```
ZohoCRM_updateLeadsRecord
path_variables: {
  "recordID": "{lead_id}"
}
body: {
  "data": [{
    "id": "{lead_id}",
    "Last_Name": "{Last_Name}",
    "CT_Enrichment_Status": "Complete",
    "ICP_Fit": "Moderate",
    "ICP_Score": 55,
    "Venue_Type": "Sports Bar",
    "Location_Count": 1,
    "Google_Rating": "4.3 / 212 reviews"
  }]
}
```

### Custom Field API Names (must match exactly)
- CT_Enrichment_Status — Picklist: Complete, Partial, Failed, Pending
- ICP_Fit — Picklist: Strong, Moderate, Weak, Unknown
- ICP_Score — Integer (0-100)
- Venue_Type — Picklist: Sports Bar, Restaurant, Entertainment, Hotel, Bowling, Other
- Location_Count — Integer
- Google_Rating — Text (format: "X.X / NNN reviews")

NOTE: If custom fields have not been created yet in Zoho admin, the update call will silently ignore those fields but still return SUCCESS for standard fields. Always write the Note first — it is the most valuable output.

---

## Rep Mapping (Owner ID to First Name for email signatures)

| Owner ID | First Name | Email | Brand |
|----------|------------|-------|-------|
| 1351252000153431001 | Kevin | klacayo@crunchytech.com | Crunchy Tech |
| 1351252000000162033 | Leonardo | lmoretti@crunchytech.com | Crunchy Tech |
| 1351252000001578206 | TJ | tj@unrealbowl.com | Unreal Bowling |
| 1351252000000075001 | Adi | akhanna@crunchytech.com | Crunchy Tech |

Use the Owner.id from the lead record to look up the rep. Sign emails with first name only.

For Unreal Bowling leads owned by TJ, sign as "TJ / Unreal Bowling".
For AV leads, sign as "{First Name} / Crunchy Tech".

If Owner ID is not in this table, use the Owner.name from the record and "Crunchy Tech" as the brand.
