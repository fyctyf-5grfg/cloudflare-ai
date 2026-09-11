# cloudflare-ai runtime

GitHub Actions runtime powering the [cloudflare-ai](https://cloudflare-ai.kahibexi.workers.dev/) chat worker.

- `scripts/cf-proxy.py` — local Cloudflare AI proxy rotating 300 accounts on 429 (:8788)
- `scripts/run-mcp` — MCP server (files/execute/web/skills tools, :8000)
- `scripts/kv` — cloudflared tunnel supervisor publishing URLs to the container-target KV namespace
- `.github/workflows/hermes-runtime.yml` — the runtime session (dispatch-only, 1 h cap)

The worker dispatches `hermes-runtime.yml` here when it detects the runtime
is down; a 10-min cron in the worker cancels it after 30 min idle.
