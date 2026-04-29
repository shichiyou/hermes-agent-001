---
name: hermes-gateway-ops
version: 1.0.0
author: Hermes Agent
description: Operating and debugging the Hermes Agent gateway — safe restarts, Discord channel mention issues, and log diagnostics.
---

# Hermes Gateway Operations

## Safe Gateway Restart

### CRITICAL: Never use `&` for background launch in terminal tool

**Do NOT** run `hermes gateway run --replace &` via the terminal tool.
This will hijack the shell session, causing ALL subsequent terminal commands
to return exit code 130 (SIGINT). The session becomes unusable.

**Correct approach** — use the terminal tool's `background=true` feature:

```python
from hermes_tools import terminal
terminal("hermes gateway run --replace", background=True, notify_on_complete=True)
```

Or start gateway from a separate process/session that won't interfere.

If the session is already broken (all commands returning 130):
1. Open a new terminal in VS Code (Ctrl+Shift+`  or the "+" button)
2. Kill stuck processes: `pkill -f "hermes gateway"`
3. Restart gateway properly

### Standard restart sequence

```bash
# 1. Stop existing gateway
pkill -f "hermes gateway"

# 2. Wait briefly
sleep 3

# 3. Start fresh (use background=true or nohup, NOT bare &)
nohup hermes gateway run --replace > ~/hermes-gw.log 2>&1 &

# 4. Verify it started
sleep 5
ps aux | grep "hermes gateway" | grep -v grep
```

## Discord Channel Mention Not Responding

### Symptom
- DMs work fine (bot responds normally)
- Channel mentions (`@botname`) produce no response
- No inbound message entry in agent.log for channel messages

### Root Cause Analysis (in order of likelihood)

#### 1. `message.mentions` filter (most common)
**File**: `gateway/platforms/discord.py` line ~808
```python
if self._client.user not in message.mentions: return
```
Discord.py may not populate `message.mentions` correctly for:
- Silent mentions (`@silent`)
- Mentions in edited messages
- Gateway reconnect scenarios where member cache is stale

**Verification**: Enable DEBUG logging and check if `message.mentions` contains the bot user.

#### 2. `DISCORD_IGNORE_NO_MENTION` (default: true)
**File**: `gateway/platforms/discord.py` lines 696-700
```python
if _ignore_no_mention and not _self_mentioned and not _other_bots_mentioned:
    # silently drops message
```
If `_self_mentioned` is False despite the bot being @mentioned, the message is dropped.

**Quick test**: Set `DISCORD_IGNORE_NO_MENTION` to `false` in the hermes environment configuration, then also set `DISCORD_ALLOWED_CHANNELS` to restrict which channels the bot responds in.

#### 3. `auto_thread` creation failure
**File**: `gateway/platforms/discord.py` lines 2820-2832
When `auto_thread` is enabled and the bot cannot create threads (permissions), the message may be silently dropped.

**Verification**: Disable `auto_thread` in the hermes discord configuration and retry.

### Debugging Steps

1. **Enable DEBUG logging** in hermes environment config:
   Add `DISCORD_LOG_LEVEL=DEBUG`

2. **Restart gateway** (properly — see Safe Gateway Restart above)

3. **Send a channel mention** from Discord, then check logs:
   ```bash
   grep -i "mention\|inbound\|on_message\|_self_mentioned" ~/.hermes/logs/agent.log | tail -30
   ```

4. **Look for**:
   - `inbound message: platform=discord` entries for channel messages
   - `message.mentions` debug output
   - Any ERROR/WARNING entries

5. **Turn off DEBUG** after diagnosing (it's very noisy)

### Important Config Values

| Variable | Default | Effect |
|----------|---------|--------|
| `DISCORD_IGNORE_NO_MENTION` | true | Drop messages that don't mention the bot |
| `DISCORD_ALLOWED_USERS` | (none = all) | Restrict to specific user IDs |
| `DISCORD_HOME_CHANNEL` | (none) | Default channel for broadcast messages |
| `DISCORD_ALLOWED_CHANNELS` | (none = all) | Restrict bot to specific channels |
| `discord.require_mention` | true | Require @mention to respond |
| `discord.auto_thread` | true | Auto-create threads for responses |

### Verifying Gateway and Dashboard status

Always verify with HTTP health checks, not just process existence:

```bash
# Gateway — check process AND agent.log for "Gateway running"
ps aux | grep "hermes gateway" | grep -v grep
grep "Gateway running" ~/.hermes/logs/agent.log | tail -3

# Dashboard — process exists ≠ HTTP ready
# Dashboard takes ~35 minutes to initialize from container start
ps aux | grep "hermes dashboard" | grep -v grep   # shows process immediately
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9119/  # actual readiness
ss -tlnp | grep 9119                                # port listening check
```

**Critical**: `pgrep -f "hermes dashboard"` succeeds as soon as the Python process spawns, but the web server won't respond for many minutes. Always use `curl` or `ss` to confirm actual readiness.

Dashboard logs appear in `~/.hermes/logs/agent.log` (look for `hermes_cli.web_server: Mounted plugin API routes`), NOT in `dashboard.log` which stays empty (0 bytes).

## Pitfalls

- **Gateway restart may fix mention issues**: Discord.py's WebSocket connection can degrade, causing guild message events to stop being delivered. A simple restart often resolves this.
- **Environment variable changes require gateway restart** to take effect.
- **`DISCORD_IGNORE_NO_MENTION=true`** is the default and means the bot silently ignores any channel message where it doesn't detect itself in `message.mentions`. This is the #1 suspect for "works in DM but not in channel".
- **Log verbosity**: `DISCORD_LOG_LEVEL=DEBUG` produces massive output. Always turn off after diagnosing.