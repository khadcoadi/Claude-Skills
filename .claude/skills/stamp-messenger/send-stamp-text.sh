#!/bin/bash
# ============================================
# Stamp Messenger — Send plain-text DM
#
# Use for error notifications, system alerts, or anywhere a
# simple text message is better than an approval card.
#
# Usage:
#   bash send-stamp-text.sh --recipient "Adi Khanna" \
#     --message "⚠️ CRM push failed for FA850126Q0016 — Replace Bowling Alley Sound System. Manual attention needed."
# ============================================

TENANT_ID="609b5b72-9a87-4376-825b-20726d50a60b"
APP_ID="71916c47-9267-4742-9068-17022cc8bb68"
CLIENT_SECRET="g4D8Q~UFYfFP3Jmd_76VXKWLWjY6ANO8ixIkVb17"

SERVICE_URL="https://smba.trafficmanager.net/teams"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="${SCRIPT_DIR}/references/team-roster.json"
TOKEN_CACHE="/tmp/stamp-token-cache.json"
CONV_CACHE="/tmp/stamp-conversations.json"

RECIPIENT_NAME=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recipient) RECIPIENT_NAME="$2"; shift 2 ;;
    --message)   MESSAGE="$2";        shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$RECIPIENT_NAME" ] || [ -z "$MESSAGE" ]; then
  echo "ERROR: --recipient and --message are required."
  exit 1
fi

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

echo "🛡️ Stamp Text"
echo "Recipient: ${RECIPIENT_NAME} (${AZURE_ID})"

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
      return 0
    fi
  fi

  TOKEN_RESPONSE=$(curl -s -X POST \
    "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${APP_ID}&client_secret=${CLIENT_SECRET}&scope=https://api.botframework.com/.default")

  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: Failed to get token."
    return 1
  fi

  python3 -c "
import json, time
cache = {'access_token': '${ACCESS_TOKEN}', 'expires_at': int(time.time()) + 3000}
with open('${TOKEN_CACHE}', 'w') as f:
    json.dump(cache, f)
"
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
      return 0
    fi
  fi

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
  return 0
}

send_text() {
  BODY=$(python3 -c "
import json, sys
msg = sys.argv[1]
print(json.dumps({'type': 'message', 'text': msg}))
" "$MESSAGE")

  MSG_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SERVICE_URL}/v3/conversations/${CONV_ID}/activities" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY")

  HTTP_CODE=$(echo "$MSG_RESPONSE" | tail -1)
  BODY_RESP=$(echo "$MSG_RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    echo "🛡️ Text sent. HTTP ${HTTP_CODE}."
    return 0
  fi

  echo "ERROR: Send failed with HTTP ${HTTP_CODE}"
  echo "$BODY_RESP"
  return 1
}

get_token || exit 1
get_conversation "$AZURE_ID" || exit 1
send_text || exit 1
