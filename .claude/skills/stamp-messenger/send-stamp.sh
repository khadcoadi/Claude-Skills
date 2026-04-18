#!/bin/bash
# ============================================
# Stamp Messenger — Send Teams DM Approval Card(s)
#
# Usage (single card):
#   bash send-stamp.sh --recipient "Adi Khanna" \
#     --subject "Subject line" --card /path/card-template.json \
#     --payload /tmp/payload.json
#
# Usage (stacked — all cards in one message):
#   bash send-stamp.sh --recipient "Adi Khanna" \
#     --subject "Subject line" --card /path/card-template.json \
#     --payload /tmp/payload1.json --payload /tmp/payload2.json \
#     --stacked
#
# Card populate logic lives in populate-card.py so we avoid bash
# heredoc escape hell. Send logic mirrors ct-pixel-bot/send-message.sh.
# ============================================

TENANT_ID="609b5b72-9a87-4376-825b-20726d50a60b"
APP_ID="71916c47-9267-4742-9068-17022cc8bb68"
CLIENT_SECRET="g4D8Q~UFYfFP3Jmd_76VXKWLWjY6ANO8ixIkVb17"

SERVICE_URL="https://smba.trafficmanager.net/teams"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="${SCRIPT_DIR}/references/team-roster.json"
POPULATE_SCRIPT="${SCRIPT_DIR}/populate-card.py"
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
  echo "ERROR: Recipient '${RECIPIENT_NAME}' not found in roster."
  exit 1
fi

echo "🛡️ Stamp Bot"
echo "Recipient: ${RECIPIENT_NAME} (${AZURE_ID})"
echo "Payloads: ${#PAYLOAD_FILES[@]} | Stacked: ${STACKED}"

# --- GET OR CACHE TOKEN ---
get_token() {
  if [ -f "$TOKEN_CACHE" ]; then
    CACHED_EXPIRY=$(python3 -c "
import json
with open('${TOKEN_CACHE}') as f:
    print(json.load(f).get('expires_at', 0))
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

  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: Failed to get token."
    echo "$TOKEN_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$TOKEN_RESPONSE"
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

  CONV_ID=$(echo "$CONV_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  if [ -z "$CONV_ID" ]; then
    echo "ERROR: Failed to create conversation."
    echo "$CONV_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CONV_RESPONSE"
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

# --- BUILD + SEND MESSAGE ---
send_message() {
  local summary="${SUBJECT_LINE:-Stamp approval required}"
  local cards_dir
  cards_dir=$(mktemp -d)

  # Populate each payload into a card JSON file via Python helper
  local idx=0
  for pf in "${PAYLOAD_FILES[@]}"; do
    local out="${cards_dir}/card-${idx}.json"
    if ! python3 "${POPULATE_SCRIPT}" "${CARD_FILE}" "${pf}" > "${out}"; then
      echo "ERROR: Failed to populate card for ${pf}"
      rm -rf "${cards_dir}"
      return 1
    fi
    idx=$((idx + 1))
  done

  # Build message body (like pixel's: card(s) wrapped in attachments)
  BODY=$(python3 - "$cards_dir" "$summary" <<'PYEOF'
import json, os, sys, glob
cards_dir, summary = sys.argv[1], sys.argv[2]
cards = []
for p in sorted(glob.glob(os.path.join(cards_dir, "card-*.json"))):
    with open(p) as f:
        cards.append(json.load(f))
payload = {
    "type": "message",
    "summary": summary,
    "attachments": [
        {"contentType": "application/vnd.microsoft.card.adaptive", "content": c}
        for c in cards
    ],
}
print(json.dumps(payload))
PYEOF
)

  rm -rf "${cards_dir}"

  if [ -z "$BODY" ]; then
    echo "ERROR: Failed to build message body."
    return 1
  fi

  MSG_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SERVICE_URL}/v3/conversations/${CONV_ID}/activities" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY")

  HTTP_CODE=$(echo "$MSG_RESPONSE" | tail -1)
  BODY_RESP=$(echo "$MSG_RESPONSE" | sed '$d')

  # Teams Bot Framework returns 200/201/202 on success
  if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    MSG_ID=$(echo "$BODY_RESP" | python3 -c "import sys,json; d=sys.stdin.read().strip(); print(json.loads(d).get('id','(accepted, no id)') if d else '(accepted, no body)')" 2>/dev/null)
    echo "🛡️ Sent ${#PAYLOAD_FILES[@]} card(s) in one message. HTTP ${HTTP_CODE}. Activity: ${MSG_ID}"
    return 0
  fi

  echo "ERROR: Send failed with HTTP ${HTTP_CODE}"
  echo "$BODY_RESP" | python3 -m json.tool 2>/dev/null || echo "$BODY_RESP"
  return 1
}

# --- MAIN ---
echo "=== 🛡️ Stamp Messenger ==="
echo ""

get_token || exit 1
echo ""

get_conversation "$AZURE_ID" || exit 1
echo ""

echo "Populating and sending card(s)..."
send_message || exit 1

echo ""
echo "=== Done ==="
