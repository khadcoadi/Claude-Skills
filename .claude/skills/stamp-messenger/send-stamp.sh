#!/bin/bash
# ============================================
# Stamp Messenger — Send Teams DM Approval Card(s)
# Usage (single):
#   bash send-stamp.sh --recipient "Adi Khanna" \
#     --subject "Subject line" --card /path/card.json \
#     --payload /tmp/payload.json
#
# Usage (stacked — all cards in one message):
#   bash send-stamp.sh --recipient "Adi Khanna" \
#     --subject "Subject line" --card /path/card.json \
#     --payload /tmp/payload1.json --payload /tmp/payload2.json \
#     --stacked
# ============================================

TENANT_ID="609b5b72-9a87-4376-825b-20726d50a60b"
APP_ID="71916c47-9267-4742-9068-17022cc8bb68"
CLIENT_SECRET="g4D8Q~UFYfFP3Jmd_76VXKWLWjY6ANO8ixIkVb17"

SERVICE_URL="https://smba.trafficmanager.net/teams"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="${SCRIPT_DIR}/../references/team-roster.json"
TOKEN_CACHE="/tmp/stamp-token-cache.json"
CONV_CACHE="/tmp/stamp-conversations.json"

# --- PARSE ARGS ---
RECIPIENT_NAME=""
SUBJECT_LINE=""
CARD_FILE=""
PAYLOAD_FILES=()
STACKED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recipient) RECIPIENT_NAME="$2"; shift 2 ;;
    --subject)   SUBJECT_LINE="$2";   shift 2 ;;
    --card)      CARD_FILE="$2";      shift 2 ;;
    --payload)   PAYLOAD_FILES+=("$2"); shift 2 ;;
    --stacked)   STACKED=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$RECIPIENT_NAME" ] || [ -z "$CARD_FILE" ] || [ ${#PAYLOAD_FILES[@]} -eq 0 ]; then
  echo "ERROR: --recipient, --card, and at least one --payload are required."
  exit 1
fi

if [ -z "$CLIENT_SECRET" ]; then
  echo "ERROR: STAMP_CLIENT_SECRET environment variable not set."; exit 1
fi

# --- LOOK UP RECIPIENT ---
AZURE_ID=$(python3 -c "
import json, sys
with open('${ROSTER_FILE}') as f:
    roster = json.load(f)
name = '${RECIPIENT_NAME}'
for key, val in roster.items():
    if key.lower() == name.lower():
        print(val['azure_id']); sys.exit(0)
for key, val in roster.items():
    if name.lower() in key.lower():
        print(val['azure_id']); sys.exit(0)
print('')
" 2>/dev/null)

if [ -z "$AZURE_ID" ]; then
  echo "ERROR: Recipient '${RECIPIENT_NAME}' not found in roster."; exit 1
fi

echo "Recipient: ${RECIPIENT_NAME} (${AZURE_ID})"
echo "Payloads: ${#PAYLOAD_FILES[@]} | Stacked: ${STACKED}"

# --- POPULATE CARD FROM PAYLOAD ---
populate_card() {
  local payload_file="$1"
  python3 << PYEOF
import json, os
from datetime import datetime

with open('${payload_file}') as f:
    payload = json.load(f)

with open('${CARD_FILE}') as f:
    card_str = f.read()

try:
    deadline_dt = datetime.strptime(payload.get('deadline', ''), '%Y-%m-%d')
    days_rem = (deadline_dt - datetime.today()).days
    days_remaining = f"{days_rem} day{'s' if days_rem != 1 else ''}"
except:
    days_remaining = 'check SAM.gov'

score = payload.get('ct_score', 5)
score_color = 'good' if score >= 7 else ('warning' if score >= 4 else 'attention')

tos = payload.get('type_of_system', [])
type_of_system = ', '.join(tos) if isinstance(tos, list) else str(tos)

warnings = payload.get('warnings', [])
red_flags_lines = []
for w in warnings[:3]:
    prefix = 'Red: ' if any(k in w.lower() for k in ['mandatory', 'clearance', 'scif', 'overseas', 'sla', 'install window', 'training']) else 'Yellow: '
    red_flags_lines.append(prefix + w)
red_flags = '\n'.join(red_flags_lines) if red_flags_lines else 'No flags'

push_payload_json = json.dumps(payload).replace('"', '\\"')

routine_fire_url = 'https://api.anthropic.com/v1/claude_code/routines/trig_01PFRCg73uCRpzGkG9wn2J2G/fire'
routine_bearer_token = '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'

replacements = {
    '\${title}':                payload.get('title', ''),
    '\${sol_number}':           payload.get('sol_num', ''),
    '\${agency}':               payload.get('account_name', ''),
    '\${location}':             payload.get('location', ''),
    '\${deadline}':             payload.get('bid_due_date', ''),
    '\${days_remaining}':       days_remaining,
    '\${set_aside}':            payload.get('set_aside', ''),
    '\${type_of_system}':       type_of_system,
    '\${bid_submission_style}': payload.get('bid_submission_style', ''),
    '\${mandatory_site_visit}': payload.get('mandatory_site_visit', ''),
    '\${match_score}':          str(score),
    '\${score_color}':          score_color,
    '\${status_badge}':         payload.get('status', 'QUALIFIED'),
    '\${scope_summary}':        payload.get('scope_summary', ''),
    '\${red_flags}':            red_flags,
    '\${poc_name}':             payload.get('contact_name', ''),
    '\${poc_email}':            payload.get('contact_email', ''),
    '\${notice_id}':            payload.get('notice_id', ''),
    '\${routine_fire_url}':     routine_fire_url,
    '\${routine_bearer_token}': routine_bearer_token,
    '\${push_payload_json}':    push_payload_json,
}

for k, v in replacements.items():
    card_str = card_str.replace(k, str(v))

parsed = json.loads(card_str)
print(json.dumps(parsed))
PYEOF
}

# --- GET OR CACHE TOKEN ---
get_token() {
  if [ -f "$TOKEN_CACHE" ]; then
    CACHED_EXPIRY=$(python3 -c "
import json, time
with open('${TOKEN_CACHE}') as f:
    cache = json.load(f)
print(cache.get('expires_at', 0))
" 2>/dev/null)
    NOW=$(python3 -c "import time; print(int(time.time()))")
    if [ "$CACHED_EXPIRY" -gt "$NOW" ] 2>/dev/null; then
      ACCESS_TOKEN=$(python3 -c "
import json
with open('${TOKEN_CACHE}') as f:
    print(json.load(f)['access_token'])
" 2>/dev/null)
      echo "Using cached token."
      return 0
    fi
  fi

  echo "Fetching new token..."
  TOKEN_RESPONSE=$(curl -s -X POST \
    "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${APP_ID}&client_secret=${CLIENT_SECRET}&scope=https://api.botframework.com/.default")

  ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: Failed to get token."
    echo $TOKEN_RESPONSE | python3 -m json.tool 2>/dev/null || echo $TOKEN_RESPONSE
    return 1
  fi

  python3 -c "
import json, time
cache = {'access_token': '${ACCESS_TOKEN}', 'expires_at': int(time.time()) + 3000}
with open('${TOKEN_CACHE}', 'w') as f:
    json.dump(cache, f)
"
  echo "Token acquired and cached."
  return 0
}

# --- GET OR CACHE CONVERSATION ---
get_conversation() {
  local user_id="$1"
  if [ -f "$CONV_CACHE" ]; then
    CONV_ID=$(python3 -c "
import json
with open('${CONV_CACHE}') as f:
    cache = json.load(f)
print(cache.get('${user_id}', ''))
" 2>/dev/null)
    if [ -n "$CONV_ID" ]; then
      echo "Using cached conversation."
      return 0
    fi
  fi

  echo "Creating conversation..."
  CONV_RESPONSE=$(curl -s -X POST \
    "${SERVICE_URL}/v3/conversations" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"bot\": {\"id\": \"28:${APP_ID}\", \"name\": \"Stamp\"},
      \"members\": [{\"id\": \"${user_id}\", \"name\": \"${RECIPIENT_NAME}\"}],
      \"channelData\": {\"tenant\": {\"id\": \"${TENANT_ID}\"}},
      \"isGroup\": false,
      \"tenantId\": \"${TENANT_ID}\"
    }")

  CONV_ID=$(echo $CONV_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -z "$CONV_ID" ]; then
    echo "ERROR: Failed to create conversation."
    echo $CONV_RESPONSE | python3 -m json.tool 2>/dev/null || echo $CONV_RESPONSE
    return 1
  fi

  python3 -c "
import json, os
cache = {}
if os.path.exists('${CONV_CACHE}'):
    with open('${CONV_CACHE}') as f:
        cache = json.load(f)
cache['${user_id}'] = '${CONV_ID}'
with open('${CONV_CACHE}', 'w') as f:
    json.dump(cache, f, indent=2)
"
  echo "Conversation created and cached."
  return 0
}

# --- SEND ---
send_message() {
  local summary="${SUBJECT_LINE:-Stamp approval required}"

  if [ "$STACKED" = true ] && [ ${#PAYLOAD_FILES[@]} -gt 1 ]; then
    # Build one message with multiple attachments stacked
    ATTACHMENTS_JSON=$(python3 << PYEOF
import json, subprocess, sys

payload_files = [$(printf '"%s",' "${PAYLOAD_FILES[@]}" | sed 's/,$//')]
attachments = []

for pf in payload_files:
    result = subprocess.run(
        ['bash', '${SCRIPT_DIR}/send-stamp.sh'],
        capture_output=False
    )

# Actually populate each card inline
cards = []
for pf in payload_files:
    import os
    from datetime import datetime

    with open(pf) as f:
        payload = json.load(f)
    with open('${CARD_FILE}') as f:
        card_str = f.read()

    try:
        deadline_dt = datetime.strptime(payload.get('deadline',''), '%Y-%m-%d')
        days_rem = (deadline_dt - datetime.today()).days
        days_remaining = f"{days_rem} day{'s' if days_rem != 1 else ''}"
    except:
        days_remaining = 'check SAM.gov'

    score = payload.get('ct_score', 5)
    score_color = 'good' if score >= 7 else ('warning' if score >= 4 else 'attention')
    tos = payload.get('type_of_system', [])
    type_of_system = ', '.join(tos) if isinstance(tos, list) else str(tos)
    warnings = payload.get('warnings', [])
    red_flags_lines = []
    for w in warnings[:3]:
        prefix = 'Red: ' if any(k in w.lower() for k in ['mandatory','clearance','scif','overseas','sla','install window','training']) else 'Yellow: '
        red_flags_lines.append(prefix + w)
    red_flags = '\n'.join(red_flags_lines) if red_flags_lines else 'No flags'
    push_payload_json = json.dumps(payload).replace('"', '\\"')
    routine_fire_url = 'https://api.anthropic.com/v1/claude_code/routines/trig_01PFRCg73uCRpzGkG9wn2J2G/fire'
    routine_bearer_token = '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'

    replacements = {
        '\${title}': payload.get('title',''),
        '\${sol_number}': payload.get('sol_num',''),
        '\${agency}': payload.get('account_name',''),
        '\${location}': payload.get('location',''),
        '\${deadline}': payload.get('bid_due_date',''),
        '\${days_remaining}': days_remaining,
        '\${set_aside}': payload.get('set_aside',''),
        '\${type_of_system}': type_of_system,
        '\${bid_submission_style}': payload.get('bid_submission_style',''),
        '\${mandatory_site_visit}': payload.get('mandatory_site_visit',''),
        '\${match_score}': str(score),
        '\${score_color}': score_color,
        '\${status_badge}': payload.get('status','QUALIFIED'),
        '\${scope_summary}': payload.get('scope_summary',''),
        '\${red_flags}': red_flags,
        '\${poc_name}': payload.get('contact_name',''),
        '\${poc_email}': payload.get('contact_email',''),
        '\${notice_id}': payload.get('notice_id',''),
        '\${routine_fire_url}': routine_fire_url,
        '\${routine_bearer_token}': routine_bearer_token,
        '\${push_payload_json}': push_payload_json,
    }
    for k, v in replacements.items():
        card_str = card_str.replace(k, str(v))

    cards.append(json.loads(card_str))

attachments = [{'contentType': 'application/vnd.microsoft.card.adaptive', 'content': c} for c in cards]
print(json.dumps(attachments))
PYEOF
)

    BODY=$(python3 -c "
import json, sys
attachments = json.loads('''${ATTACHMENTS_JSON}''')
payload = {
    'type': 'message',
    'summary': $(python3 -c "import json; print(json.dumps('${summary}'))"),
    'attachments': attachments
}
print(json.dumps(payload))
" 2>/dev/null)

  else
    # Single card
    POPULATED=$(populate_card "${PAYLOAD_FILES[0]}")
    if [ -z "$POPULATED" ]; then
      echo "ERROR: Failed to populate card."; exit 1
    fi

    BODY=$(python3 -c "
import json
card = json.loads('''${POPULATED}''')
payload = {
    'type': 'message',
    'summary': $(python3 -c "import json; print(json.dumps('${summary}'))"),
    'attachments': [{'contentType': 'application/vnd.microsoft.card.adaptive', 'content': card}]
}
print(json.dumps(payload))
" 2>/dev/null)
  fi

  if [ -z "$BODY" ]; then
    echo "ERROR: Failed to build message body."; exit 1
  fi

  MSG_RESPONSE=$(curl -s -X POST \
    "${SERVICE_URL}/v3/conversations/${CONV_ID}/activities" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY")

  MSG_ID=$(echo $MSG_RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -z "$MSG_ID" ]; then
    echo "ERROR: Failed to send message."
    echo $MSG_RESPONSE | python3 -m json.tool 2>/dev/null || echo $MSG_RESPONSE
    return 1
  fi

  echo "Sent ${#PAYLOAD_FILES[@]} card(s) in one message. Activity ID: ${MSG_ID}"
  return 0
}

# --- MAIN ---
echo "=== Stamp Messenger ==="
echo ""

get_token || exit 1
echo ""
get_conversation "$AZURE_ID" || exit 1
echo ""
echo "Sending card(s)..."
send_message || exit 1
echo ""
echo "=== Done ==="
