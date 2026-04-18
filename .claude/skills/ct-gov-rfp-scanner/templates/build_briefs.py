#!/usr/bin/env python3
"""
build_briefs.py — Step 7 scaffold for ct-gov-rfp-scanner.

Input:  /tmp/gov-rfp-scan/scored.json  (written by Step 5-6)
Output: /tmp/stamp-payload-{sol_num}.json  (one per QUALIFIED/WARNING opp,
         excluding Presolicitations per Step 10 rule)

Do NOT print corpus text to stdout. All field extraction happens here —
this script is the single Bash call that reads the corpus after scoring.
If an extractor misses a field for a specific opp, edit the extractor
and re-run this script. Do not hand-compose a brief around the gap.
"""
import json
import os
import re
from datetime import datetime

SCORED = "/tmp/gov-rfp-scan/scored.json"
OUT_DIR = "/tmp"


# ---------- Field extractors (regex-over-corpus) ----------

def extract_clins(corpus):
    """Return list of 'CLIN NNNN — description' strings found in corpus."""
    pat = re.compile(
        r"\bCLIN\s*(\d{3,4})\s*[—–\-:]\s*([^\n]{10,200})", re.IGNORECASE
    )
    seen = set()
    out = []
    for m in pat.finditer(corpus):
        key = m.group(1)
        if key in seen:
            continue
        seen.add(key)
        out.append(f"CLIN {m.group(1)} — {m.group(2).strip()}")
    return out


def extract_warranty(corpus):
    """Return a short warranty summary string or '' if nothing explicit."""
    m = re.search(
        r"(minimum\s+)?(\d+)\s*[\-\(]*year[s\)]*\s+warranty",
        corpus, re.IGNORECASE,
    )
    if m:
        return f"{m.group(2)}-year warranty on equipment, materials, workmanship."
    if re.search(r"commercial\s+warranty\s+applies", corpus, re.IGNORECASE):
        return "Commercial (manufacturer) warranty only — no labor coverage specified."
    return "No warranty term specified — defaults to manufacturer-only, no labor."


def extract_support_term(corpus):
    m = re.search(
        r"(\d+)\s*\(?\s*(\d+)?\s*\)?\s*year[s]?\s+(?:of\s+)?(?:system\s+)?support",
        corpus, re.IGNORECASE,
    )
    if m:
        return f"{m.group(1)}-year system support required."
    return ""


def extract_site_visit(corpus):
    """Return ('mandatory'|'optional'|'none', raw_snippet|'')."""
    if re.search(
        r"\b(mandatory site visit|mandatory pre-?bid|mandatory walk-?through|"
        r"attendance is mandatory|only offerors who attend)\b",
        corpus, re.IGNORECASE,
    ):
        return "mandatory", "Site visit is MANDATORY."
    m = re.search(
        r"site visit[^\n]{0,500}(is not required|not mandatory|highly encouraged|optional)",
        corpus, re.IGNORECASE | re.DOTALL,
    )
    if m:
        return "optional", "Site visit scheduled but not required."
    if re.search(r"\bsite visit\b", corpus, re.IGNORECASE):
        return "optional", "Site visit mentioned (check solicitation for whether required)."
    return "none", ""


def extract_submission_email(corpus, fallback=""):
    m = re.search(
        r"submit[^\n]{0,80}(?:to|:)\s*([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})",
        corpus, re.IGNORECASE,
    )
    return m.group(1) if m else fallback


def extract_questions_due(corpus):
    m = re.search(
        r"question[s]?[^\n]{0,200}?(due|deadline)[^\n]{0,200}?"
        r"([A-Z][a-z]+\s+\d{1,2},?\s+\d{4}[^\n]{0,40}|"
        r"\d{1,2}\s+[A-Z][a-z]+\s+\d{4}[^\n]{0,40})",
        corpus, re.IGNORECASE,
    )
    return m.group(2).strip() if m else ""


def extract_programming_platforms(corpus):
    platforms = []
    for name, pat in [
        ("Crestron", r"\bCrestron\b"),
        ("QSC/Q-SYS", r"\b(QSC|Q-?SYS)\b"),
        ("Biamp", r"\bBiamp\b"),
        ("Extron", r"\bExtron\b"),
        ("Shure", r"\bShure\b"),
        ("AMX", r"\bAMX\b"),
        ("SAVI", r"\bSAVI\b"),
    ]:
        if re.search(pat, corpus, re.IGNORECASE):
            platforms.append(name)
    return platforms


def detect_flags(corpus):
    """Return list of (emoji, label, impact) for the FLAGS section."""
    flags = []
    checks = [
        ("🟡", "TAA compliance required",
         r"\b(TAA compliant|Trade Agreements Act)\b",
         "Equipment sourcing restricted to TAA-designated countries — verify each line item."),
        ("🟡", "Davis-Bacon / Prevailing Wage",
         r"\b(Davis-?Bacon|prevailing wage|wage determination)\b",
         "Installation labor must be paid per DOL wage determination — affects labor pricing."),
        ("🔵", "WAWF / PIEE invoicing",
         r"\b(WAWF|PIEE|Wide Area WorkFlow)\b",
         "Invoicing through government electronic portal — setup overhead."),
        ("🔵", "CDRLs / Data deliverables",
         r"\bCDRL\b|\bA00[1-9]\b|data item description",
         "Contract data requirements list — adds documentation obligations beyond hardware."),
        ("🔵", "Safety & Health Plan required",
         r"\b(Safety (and|&) Health Plan|Contractor Safety Plan)\b",
         "Pre-award safety plan submission required — drafts add lead time."),
        ("🔴", "OPSEC / installation access",
         r"\b(OPSEC|CAC|Real[- ]?ID|installation access|base access|background check)\b",
         "Contractor personnel require base access vetting — plan for delays before mobilization."),
        ("🟡", "SAPF / SCIF-compliant audio",
         r"\b(SAPF|SCIF)\b.{0,200}\b(microphone|audio|speaker|camera)\b",
         "Contractor-furnished AV gear must meet classified-facility security specs — verify sourcing."),
        ("🔵", "Past performance evaluation",
         r"past performance.{0,80}(evaluation|factor|criteria)",
         "Non-price factor — prepare relevant past-performance references."),
        ("🟡", "Short delivery window",
         r"\bwithin (10|14|15|20|21|25|30) (calendar )?days\b.{0,60}\b(ARO|notice to proceed|NTP|award)\b",
         "Tight post-award install window — equipment lead times may conflict."),
    ]
    for emoji, label, pat, impact in checks:
        if re.search(pat, corpus, re.IGNORECASE | re.DOTALL):
            flags.append((emoji, label, impact))
    return flags


def format_flags(flags):
    if not flags:
        return "No material red flags detected in corpus."
    return "\n".join(f"{e} **{label}** — {impact}" for e, label, impact in flags)


# ---------- Main ----------

def build_payload(o):
    raw = o["raw"]
    corpus = o.get("corpus", "")
    sol = o["sol"]
    notice_id = o["notice_id"]

    # Header-block fields
    title = o["title"]
    pop = raw.get("placeOfPerformance") or {}
    city = (pop.get("city") or {}).get("name", "")
    state = (pop.get("state") or {}).get("code") or (pop.get("state") or {}).get("name", "")
    location = f"{city}, {state}".strip(", ")

    poc_list = raw.get("pointOfContact") or []
    poc = poc_list[0] if poc_list else {}
    contact_name = poc.get("fullName", "")
    contact_email = poc.get("email", "")
    contact_phone = poc.get("phone", "")

    deadline_raw = raw.get("responseDeadLine") or ""
    deadline_date = deadline_raw[:10] if deadline_raw else ""
    try:
        dl_dt = datetime.strptime(deadline_date, "%Y-%m-%d")
        bid_due_date = dl_dt.strftime("%b %d, %Y") + (
            f" {deadline_raw[11:16]}" if len(deadline_raw) >= 16 else ""
        )
    except Exception:
        bid_due_date = deadline_raw

    # Field extractors
    clins = extract_clins(corpus)
    warranty = extract_warranty(corpus)
    support = extract_support_term(corpus)
    sv_state, sv_note = extract_site_visit(corpus)
    sub_email = extract_submission_email(corpus, contact_email)
    q_due = extract_questions_due(corpus)
    platforms = extract_programming_platforms(corpus)
    flags = detect_flags(corpus)

    # 7b scope narrative
    scope_lines = [
        f"{title} at {location or 'see solicitation'}.",
    ]
    if clins:
        scope_lines.append("Line-item breakdown: " + " | ".join(clins[:6]) + ".")
    scope_lines.append(f"Warranty: {warranty}")
    if support:
        scope_lines.append(support)
    scope_summary = " ".join(scope_lines)

    # 7c programming analysis
    if platforms:
        prog_scope = (
            f"Named platforms in scope: {', '.join(platforms)}. "
            "Job requires a qualified AV install tech with DSP/control "
            "configuration experience on the named platforms."
        )
    else:
        prog_scope = (
            "No named control/DSP platform in the corpus. Scope implies "
            "equipment supply + install; configure-and-done likely "
            "sufficient — verify via the SOW before pricing a programmer."
        )

    detailed_flags = format_flags(flags)

    # 7e/7f full-brief markdown
    description = (
        f"# {title}\n\n"
        f"**Sol #:** {sol}  |  **Agency:** {raw.get('fullParentPathName','')}  "
        f"|  **Location:** {location}\n"
        f"**Deadline:** {bid_due_date}  |  **Set-aside:** "
        f"{raw.get('typeOfSetAsideDescription') or 'Unrestricted'}\n"
        f"**CT Score:** {o.get('score')}/10  |  **Status:** {o.get('final_status')}\n\n"
        f"## Scope\n{scope_summary}\n\n"
        f"## Programming & Control\n{prog_scope}\n\n"
        f"## Site Visit\n{sv_note or 'No site visit mentioned.'}\n\n"
        f"## Flags\n{detailed_flags}\n\n"
        f"## Submission\nSubmit to: {sub_email or contact_email}. "
        f"Questions due: {q_due or 'see solicitation'}.\n"
    )

    payload = {
        "sol_num": sol,
        "notice_id": notice_id,
        "title": title,
        "account_name": raw.get("fullParentPathName", "").split(".")[0] or "Federal Agency",
        "deadline": deadline_date,
        "bid_due_date": bid_due_date,
        "location": location,
        "sam_url": f"https://sam.gov/opp/{notice_id}/view",
        "amount": None,
        "set_aside": raw.get("typeOfSetAsideDescription") or "Unrestricted",
        "type_of_system": ["Meeting Space"],
        "mandatory_site_visit": "Yes" if sv_state == "mandatory" else "No",
        "bid_submission_style": "Email" if sub_email else "See solicitation",
        "contact_name": contact_name,
        "contact_email": contact_email,
        "contact_phone": contact_phone,
        "questions_due_date": q_due,
        "response_date": bid_due_date,
        "scope_summary": scope_summary,
        "programming_scope": prog_scope,
        "detailed_flags": detailed_flags,
        "description": description,
        "ct_score": o.get("score"),
        "status": o.get("final_status"),
        "warnings": [w["label"] for w in o.get("warnings", [])],
    }
    return payload


def main():
    with open(SCORED) as f:
        opps = json.load(f)

    written = []
    skipped_presol = []
    for o in opps:
        if o.get("final_status") not in ("QUALIFIED", "WARNING"):
            continue
        if (o.get("type") or "").lower() == "presolicitation":
            skipped_presol.append(o["sol"])
            continue
        payload = build_payload(o)
        path = os.path.join(OUT_DIR, f"stamp-payload-{o['sol'].replace('/', '_')}.json")
        with open(path, "w") as f:
            json.dump(payload, f, indent=2)
        written.append((o["sol"], path))

    print(f"Wrote {len(written)} payload file(s):")
    for sol, path in written:
        print(f"  {sol} -> {path}")
    if skipped_presol:
        print(f"Skipped {len(skipped_presol)} presolicitation(s) (Step 10 rule): "
              f"{', '.join(skipped_presol)}")


if __name__ == "__main__":
    main()
