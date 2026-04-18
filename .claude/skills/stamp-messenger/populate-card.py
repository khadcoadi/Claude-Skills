#!/usr/bin/env python3
"""Populate a Stamp card template from a payload JSON.

Usage:
    populate-card.py <template.json> <payload.json>

Writes the populated card JSON to stdout. This keeps the card-build
logic in Python (not bash heredoc) so JSON escaping is correct.
"""
import json
import os
import sys
from datetime import datetime


ROUTINE_FIRE_URL = os.environ.get(
    "STAMP_ROUTINE_FIRE_URL",
    "https://api.anthropic.com/v1/claude_code/routines/trig_01PFRCg73uCRpzGkG9wn2J2G/fire",
)
ROUTINE_BEARER_TOKEN = os.environ.get(
    "STAMP_ROUTINE_BEARER_TOKEN",
    "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",
)

RAW_KEYS = {"${push_payload_json}", "${routine_fire_url}", "${routine_bearer_token}"}


def days_remaining(deadline_str):
    try:
        dl = datetime.strptime(deadline_str, "%Y-%m-%d")
        diff = (dl - datetime.today()).days
        return f"{diff} day{'s' if diff != 1 else ''}"
    except Exception:
        return "check SAM.gov"


def score_color(score):
    if score >= 7:
        return "good"
    if score >= 4:
        return "warning"
    return "attention"


def red_flags_text(warnings):
    lines = []
    for w in warnings[:3]:
        lw = w.lower()
        is_red = any(k in lw for k in ["mandatory", "clearance", "scif", "overseas", "sla", "install window", "training"])
        lines.append(("Red: " if is_red else "Yellow: ") + w)
    return "\n".join(lines) if lines else "No flags"


def populate(template_path, payload):
    with open(template_path) as f:
        card_str = f.read()

    score = payload.get("ct_score", 5)
    tos = payload.get("type_of_system", [])
    type_of_system = ", ".join(tos) if isinstance(tos, list) else str(tos)

    push_payload_json = json.dumps(json.dumps(payload))[1:-1]

    detailed_flags = payload.get("detailed_flags") or red_flags_text(payload.get("warnings", []))
    programming_scope = payload.get("programming_scope") or "Not specified — review scope before assigning resource."

    replacements = {
        "${title}": payload.get("title", ""),
        "${sol_number}": payload.get("sol_num", ""),
        "${agency}": payload.get("account_name", ""),
        "${location}": payload.get("location", ""),
        "${deadline}": payload.get("bid_due_date", ""),
        "${days_remaining}": days_remaining(payload.get("deadline", "")),
        "${set_aside}": payload.get("set_aside", "") or "Unrestricted",
        "${type_of_system}": type_of_system,
        "${bid_submission_style}": payload.get("bid_submission_style", ""),
        "${mandatory_site_visit}": payload.get("mandatory_site_visit", ""),
        "${match_score}": str(score),
        "${score_color}": score_color(score),
        "${status_badge}": payload.get("status", "QUALIFIED"),
        "${scope_summary}": (payload.get("scope_summary") or payload.get("description") or "")[:1200],
        "${programming_scope}": programming_scope,
        "${detailed_flags}": detailed_flags,
        "${red_flags}": detailed_flags,
        "${poc_name}": payload.get("contact_name", "") or "—",
        "${poc_email}": payload.get("contact_email", ""),
        "${notice_id}": payload.get("notice_id", ""),
        "${routine_fire_url}": ROUTINE_FIRE_URL,
        "${routine_bearer_token}": ROUTINE_BEARER_TOKEN,
        "${push_payload_json}": push_payload_json,
    }

    for k, v in replacements.items():
        sv = str(v)
        if k not in RAW_KEYS:
            sv = json.dumps(sv)[1:-1]
        card_str = card_str.replace(k, sv)

    return json.loads(card_str)


def main():
    if len(sys.argv) != 3:
        print("Usage: populate-card.py <template.json> <payload.json>", file=sys.stderr)
        sys.exit(2)

    template_path, payload_path = sys.argv[1], sys.argv[2]
    with open(payload_path) as f:
        payload = json.load(f)

    card = populate(template_path, payload)
    json.dump(card, sys.stdout)


if __name__ == "__main__":
    main()
