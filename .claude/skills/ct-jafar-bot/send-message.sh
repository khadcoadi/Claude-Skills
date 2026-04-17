#!/bin/bash
# ============================================
# Jafar Bot — Send Teams DM
# Usage:
#   bash send-message.sh "Recipient Name" "Your message here"
#   bash send-message.sh "Recipient Name" --card /path/to/card.json --summary "Notification text"
# ============================================

# --- CREDENTIALS ---
TENANT_ID="609b5b72-9a87-4376-825b-20726d50a60b"
APP_ID="f3e98254-9f0e-4dfa-88b5-7d83f88c535f"
CLIENT_SECRET="ygX8Q~chzir5_T8i9i3U0tTdJiTrPEnke5uh4bCx"

# --- CONSTANTS ---
SERVICE_URL="https://smba.trafficmanager.net/teams"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROSTER_FILE="${SCRIPT_DIR}/team-roster.json"
TOKEN_CACHE="/tmp/jafar-token-cache.json"
CONV_CACHE="/tmp/jafar-conversations.json"

# --- INPUT VALIDATION ---
if [ -z "$1" ]; then
  echo "ERROR: No recipient specified."
  echo "Usage: bash send-message.sh \"Recipient Name\" \"Message text\""
  exit 1
fi

RECIPIENT_NAME="$1"
shift

CARD_FILE=""
CARD_SUMMARY=""
MESSAGE_TEXT=""
MESSAGE_MODE="text"

while [ $# -gt 0 ]; do
  case "$1" in
    --card)
      CARD_FILE="$2"
      MESSAGE_MODE="card"
      shift 2
      ;;
    --summary)
      CARD_SUMMARY="$2"
      shift 2
      ;;
    *)
      MESSAGE_TEXT="${MESSAGE_TEXT:+$MESSAGE_TEXT }$1"
      shift
      ;;
  esac
done

if [ "$MESSAGE_MODE" = "card" ]; then
  if [ ! -f "$CARD_FILE" ]; then
    echo "ERROR: Card file not found: $CARD_FILE"
    exit 1
  fi
elif [ -z "$MESSAGE_TEXT" ]; then
  echo "ERROR: No message specified."
  echo "Usage: bash send-message.sh \"Recipient Name\" \"Message text\""
  echo "       bash send-message.sh \"Recipient Name\" --card /path/to/card.json --summary \"Notification text\""
  exit 1
fi

# --- LOOK UP RECIPIENT ---
AZURE_ID=$(python3 -c "
import json, sys
with open('${ROSTER_FILE}') as f:
    roster = json.load(f)
name = '${RECIPIENT_NAME}'
# Case-insensitive exact match
for key, val in roster.items():
    if key.lower() == name.lower():
        print(val['azure_id'])
        sys.exit(0)
# Partial match
for key, val in roster.items():
    if name.lower() in key.lower():
        print(val['azure_id'])
        sys.exit(0)
print('')
" 2>/dev/null)

if [ -z "$AZURE_ID" ]; then
  echo "ERROR: Recipient '${RECIPIENT_NAME}' not found in roster."
  echo "Available team members:"
  python3 -c "
import json
with open('${ROSTER_FILE}') as f:
    roster = json.load(f)
for name in sorted(roster.keys()):
    print(f'  - {name}')
" 2>/dev/null
  exit 1
fi

echo "🧞 Jafar Bot"
echo "Recipient: ${RECIPIENT_NAME} (${AZURE_ID})"

# --- GET OR CACHE TOKEN ---
get_token() {
  # Check cache
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

  # Fetch new token
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

  # Cache with 50-min expiry (token lasts 60 min)
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

  # Check cache
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

  # Create new conversation
  echo "Creating conversation..."
  CONV_RESPONSE=$(curl -s -X POST \
    "${SERVICE_URL}/v3/conversations" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"bot\": {\"id\": \"28:${APP_ID}\", \"name\": \"Jafar\"},
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

  # Cache it
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

# --- SEND MESSAGE ---
send_message() {
  if [ "$MESSAGE_MODE" = "card" ]; then
    BODY=$(python3 -c "
import json, sys
with open('${CARD_FILE}') as f:
    card = json.load(f)
summary = '''${CARD_SUMMARY}'''
if not summary:
    for item in card.get('body', []):
        if item.get('type') == 'Container':
            for sub in item.get('items', []):
                t = sub.get('text', '')
                if t and '\${' not in t:
                    summary = t
                    break
        if summary:
            break
if not summary:
    summary = 'New notification from Jafar'
payload = {
    'type': 'message',
    'summary': summary,
    'attachments': [{
        'contentType': 'application/vnd.microsoft.card.adaptive',
        'content': card
    }]
}
print(json.dumps(payload))
" 2>/dev/null)

    if [ -z "$BODY" ]; then
      echo "ERROR: Failed to parse card JSON."
      exit 1
    fi
  else
    BODY=$(python3 -c "
import json
msg = '''${MESSAGE_TEXT}'''
payload = {'type': 'message', 'text': msg}
print(json.dumps(payload))
" 2>/dev/null)
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

  echo "🧞 Message sent. Activity ID: ${MSG_ID}"
  return 0
}

# --- MAIN ---
echo "=== 🧞 Jafar Messenger ==="
echo ""

get_token || exit 1
echo ""

get_conversation "$AZURE_ID" || exit 1
echo ""

echo "Sending message..."
send_message || exit 1

echo ""
echo "=== Done ==="
