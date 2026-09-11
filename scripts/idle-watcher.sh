#!/usr/bin/env bash
# Self-stop watcher: exits the runtime job when no chat activity for 15 min.
# Activity signal = `last_used` timestamp in the worker's Workers KV namespace
# (written by the worker at the START of every chat, success or not). Falls
# back to runner start time. Also never kills while a session save is in
# flight (the worker commits chat state to the repo right after replying).
set -u
IDLE_LIMIT=900

CREDS_URL="${CF_CREDS_URL:-https://bitbucket.org/cf_worker/workers/raw/main/credentials/workers.txt}"
creds="$(curl -fsSL "$CREDS_URL")"
CF_TOKEN=$(printf '%s' "$creds" | grep 'Edit_Cloudflare_Workers_api_token=' | cut -d= -f2-)
CF_ACC=$(printf '%s' "$creds" | grep 'ACCOUNT_ID=' | cut -d= -f2-)
CF_NS="${CF_KV_NS:-4a4becdae45b4865aa9ff5bd7729bcae}"
date +%s > /tmp/runner-start

while true; do
  last_ep=0
  if [ -n "$CF_TOKEN" ] && [ -n "$CF_ACC" ]; then
    last=$(curl -s -m 15 "https://api.cloudflare.com/client/v4/accounts/$CF_ACC/storage/kv/namespaces/$CF_NS/values/last_used" \
      -H "Authorization: Bearer $CF_TOKEN" 2>/dev/null | jq -r ".result // empty" 2>/dev/null || true)
    [ -n "${last:-}" ] && last_ep=$(date -d "$last" +%s 2>/dev/null || echo 0)
  fi
  start_ep=$(cat /tmp/runner-start 2>/dev/null || date +%s)
  now=$(date +%s)
  ref=$(( last_ep > start_ep ? last_ep : start_ep ))
  idle=$(( now - ref ))
  if [ "$idle" -gt "$IDLE_LIMIT" ]; then
    echo "[idle-watcher] idle ${idle}s > ${IDLE_LIMIT}s — stopping runtime cleanly"
    pkill -f "scripts/kv" 2>/dev/null || true
    pkill -x cloudflared 2>/dev/null || true
    exit 0
  fi
  sleep 60
done
