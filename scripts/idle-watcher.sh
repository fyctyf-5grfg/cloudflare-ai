#!/usr/bin/env bash
# Self-stop watcher: exits the runtime job when no chat activity for 15 min.
# Activity signal = latest commit on the runtime repo (every chat message
# commits session state via the worker; skill saves also count). The runner's
# own start time is the baseline, so a fresh boot never self-stops instantly.
set -u
REPO="${GITHUB_REPO:?GH_PAT and GITHUB_REPO env required}"
PAT="${GH_PAT:-}"
IDLE_LIMIT=900

date +%s > /tmp/runner-start

while true; do
  last_ep=0
  if [ -n "$PAT" ]; then
    last=$(curl -s -m 15 "https://api.github.com/repos/$REPO/commits?per_page=1" \
      -H "Authorization: Bearer $PAT" -H "User-Agent: idle-watcher" 2>/dev/null |
      jq -r ".[0].commit.committer.date // empty" 2>/dev/null || true)
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
