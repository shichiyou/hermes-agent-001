---
name: discord-secure-setup
description: Secure Discord bot setup for Hermes Agent — security-first configuration with Private Bot, hardening steps, and known vulnerability mitigations.
version: 1.2
---

# Discord Secure Setup for Hermes Agent

Security-hardened setup guide based on code audit of Hermes Agent Discord adapter (discord.py 3486 lines, run.py 10288 lines). The official docs (`website/docs/user-guide/messaging/discord.md`) recommend Public Bot ON for convenience but lack security considerations entirely.

## Critical Decision: Public Bot vs Private Bot

**ALWAYS use Private Bot (Public Bot = OFF) unless there is a specific reason to be public.**

| | Public Bot (ON) | Private Bot (OFF) |
|---|---|---|
| Invite method | Discord Installation tab auto-generates URL | Manual URL required (one extra step) |
| Security | **Anyone can add bot to any server** | **Only those with the URL can add** |
| Attack surface | Unlimited — any Discord user | Limited to URL holders |
| Official docs position | "recommended" (convenience only) | "Alternative" |

### Manual Invite URL (Private Bot compatible)

```
https://discord.com/oauth2/authorize?client_id=YOUR_APP_ID&scope=bot+applications.commands&permissions=274878286912
```

Replace `YOUR_APP_ID` with the Application ID from the Developer Portal.

## Mandatory Configuration

### 1. Set DISCORD_ALLOWED_USERS (REQUIRED)

If not set, the adapter-level check `_is_allowed_user()` (discord.py:1396-1397) returns True for ALL users when both allowlists are empty. The gateway provides a partial backstop but defense-in-depth is broken.

Add user IDs (comma-separated) to the Hermes environment config.

### 2. Set DISCORD_HOME_CHANNEL (for cron delivery)

Add the channel ID and display name to the Hermes environment config.

### 3. Privileged Gateway Intents (REQUIRED in Developer Portal)

- **Message Content Intent** = ON (bot cannot read messages without it)
- **Server Members Intent** = ON (cannot resolve usernames/roles without it)
- Presence Intent = Optional

## Known Vulnerabilities and Mitigations

### HIGH: Prompt Injection via display_name/topic/guild name

**Code**: discord.py:2884, session.py:258

External text (user display names, channel topics, guild names) flows unsanitized into the system prompt. No length limit, no sanitization, no XML tag isolation.

**Mitigation**:
- Limit who can interact via DISCORD_ALLOWED_USERS
- Use Private Bot to limit which servers the bot joins
- Be aware that any allowed user's display name is an injection vector

### HIGH: Full CLI toolset exposed to Discord users

**Code**: toolsets.py:305-309 — `hermes-discord` = `_HERMES_CORE_TOOLS`

Discord users get: terminal, read_file, write_file, execute_code, cronjob, send_message, delegate_task

**ExecApprovalView._check_auth() vulnerability** (discord.py:3118-3119):
When the allowed user set is empty, `return True` allows anyone to approve dangerous commands.

**Mitigation**:
- Always set DISCORD_ALLOWED_USERS (fills the user set, restricting approval)
- The read_file tool bypasses the approval gate entirely — any allowed user can read any file the agent can access
- Consider creating a restricted `hermes-discord-safe` toolset excluding read_file, cronjob, delegate_task, send_message

### MEDIUM-HIGH: Credential self-read vector

The agent's file reading capability can access its own credential store without approval. A Discord user could ask the agent to show config and retrieve all API keys.

**Mitigation**:
- Enforce restrictive file permissions on the credential store (owner-read-only)
- Restrict toolset as above
- Never put sensitive credentials in agent-accessible config if the bot serves untrusted users

### MEDIUM: DISCORD_ALLOWED_ROLES gateway bypass

**Code**: run.py:2736-2740 — if DISCORD_ALLOWED_ROLES has any value, gateway auto-authorizes ALL Discord users without re-verifying role membership.

**Mitigation**: Don't rely solely on role-based auth. Always pair with DISCORD_ALLOWED_USERS.

### MEDIUM: Bot chain reaction with DISCORD_ALLOW_BOTS=all

**Code**: discord.py:652-668 — "all" mode enables unbounded bot-to-bot loops with no rate limiting or cycle detection.

**Mitigation**: Keep DISCORD_ALLOW_BOTS at default "none". If "mentions" mode is needed, be aware webhook echoes can trigger the bot.

### MEDIUM: DISCORD_IGNORE_NO_MENTION naming is inverted

`true` = require mention (SAFE default), `false` = respond to everything (DANGEROUS)

The variable name confuses operators. Default is "true" (safe), but document this for team members.

### LOW-MEDIUM: Thread sessions shared across users by default

**Code**: session.py:490-491 — `thread_sessions_per_user: bool = False`

All participants in a Discord thread share one session. Context from one user is visible to others.

**Mitigation**: Set `thread_sessions_per_user: true` in config.yaml if needed.

## 100-Server Verification Threshold

Discord requires verification for bots in 100+ servers to use Privileged Intents. For private single-server use, this is irrelevant. For Public Bots that might grow, plan for this or stay under the limit.

## Developer Portal UI Pitfalls

### "Save Changes" fails when setting Public Bot = OFF

**Root cause (most common)**: The Installation tab has Install Link set to "Discord Provided Link", which requires Public Bot = ON. You cannot save Private Bot while this link exists.

**Fix — do this BEFORE touching the Bot page**:
1. Go to **Installation** tab in the left sidebar
2. Set **Install Link** → **None**
3. Remove any **Installation Contexts** (Guild Install toggle → OFF if present)
4. **Save Changes** on the Installation page
5. Now go to **Bot** page and set Public Bot = OFF → Save will succeed

**Secondary cause**: Require OAuth2 Code Grant is ON. Both toggles must be OFF:
| Setting | Value |
|---------|-------|
| Public Bot | **OFF** |
| Require OAuth2 Code Grant | **OFF** |

**If both fixes fail** (generic error like "Something went wrong"):
```bash
curl -X PATCH \
  "https://discord.com/api/v10/applications/YOUR_APP_ID" \
  -H "Authorization: Bot YOUR_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"flags": 0}'
```
`flags: 0` = Public Bot OFF + Require OAuth2 Code Grant OFF.

### Bot Permissions are NOT on the Bot page

The Bot page has no permission settings. Bot Permissions are configured in **OAuth2 → URL Generator** when creating the invite URL. Many users mistakenly look for permissions on the Bot page.

### OAuth2 URL Generator has an Integration Type selector

At the top of the URL Generator, you'll see a choice between:
- **ギルドのインストール (Guild Install)** → select this (server-level bot)
- **ユーザーのインストール (User Install)** → do NOT select this (user-level app)

Hermes Agent needs Guild Install. The URL Generator has no Save button — it generates the URL live, just copy it.

### Hermes gateway code does NOT depend on Public Bot

Verified in code: `hermes_cli/gateway.py` line 1816-1827 uses OAuth2 URL Generator method, which works for both Public and Private bots. The `tree.sync()` slash command registration (discord.py:794) also works for Private bots. There is zero code dependency on Public Bot = ON.

The official website docs (`discord.md`) recommend Public Bot ON solely for the convenience of the Installation tab auto-generating an invite URL. This is a documentation choice, not a technical requirement.

## Step-by-Step Setup (Private Bot)

⚠️ **Step order matters**: Installation settings (Step 2) MUST be changed BEFORE setting Public Bot = OFF (Step 3), otherwise the Bot page will refuse to save.

### Step 1: Create Application
1. https://discord.com/developers/applications → **New Application** → name → **Create**
2. Note the **Application ID** (needed for invite URL in Step 5)

### Step 2: Configure Installation (prerequisite for Step 3)
1. Left sidebar → **Installation**
2. Set **Install Link** → **None** (Private Bot cannot use Discord-provided link)
3. Remove any **Installation Contexts** if present (Guild Install toggle → OFF)
4. **Save Changes**

> ⚠️ Without this step, saving Public Bot = OFF on the Bot page will fail with "Private applications cannot have a default authorization link".

### Step 3: Create and Configure Bot
1. Left sidebar → **Bot**
2. **Authorization Flow** — both must be OFF:
   - **Public Bot** → **OFF**
   - **Require OAuth2 Code Grant** → **OFF** (⚠️ leaving this ON causes save errors)
3. **Save Changes** (should succeed now that Step 2 is done)
4. **Privileged Gateway Intents** (scroll down):
   - **Server Members Intent** → ON (required for username/role resolution)
   - **Message Content Intent** → ON (required — without it, bot cannot read messages)
5. **Save Changes**

### Step 4: Get Bot Token
1. Bot page → **Token** → **Reset Token**
2. Copy token immediately (shown only once)

### Step 5: Generate Invite URL (works for Private Bot)
1. Left sidebar → **OAuth2** → **URL Generator** tab
2. **連携タイプ (Integration Type)**: select **ギルドのインストール** (Guild Install / server install)
   - ❌ Do NOT select ユーザーのインストール (User Install)
3. **Scopes**: check `bot` + `applications.commands`
4. **Bot Permissions**: check View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Add Reactions
5. Copy generated URL → open in browser → select server → Authorize

> The URL Generator does not have a Save button — it generates the URL live. Just copy and use it.

### Step 6: Get Your User ID
1. Discord Settings → Advanced → **Developer Mode** ON
2. Right-click your username → **Copy User ID**

### Step 7: Configure Hermes
Add to the Hermes environment config file (replace with actual values):
- DISCORD_BOT_TOKEN (from Step 4)
- DISCORD_ALLOWED_USERS (numeric user ID from Step 6, comma-separated for multiple)
- DISCORD_HOME_CHANNEL (optional, channel ID for cron/notification delivery)

### Step 8: Verify config.yaml
Defaults are fine for initial setup:
```yaml
discord:
  require_mention: true
  auto_thread: true
  reactions: true
  free_response_channels: ''
  channel_prompts: {}
```

### Step 9: Start Gateway
```bash
hermes gateway
```
Bot appears online in Discord within seconds. Test via DM or @mention in a channel.

### Step 10: Persist as Service (optional)
```bash
hermes gateway install    # register as systemd service
hermes gateway start      # run in background
hermes gateway status     # check status
```

## Setup Checklist

- [ ] Step 2: Installation page → Install Link set to **None** (must do BEFORE Step 3)
- [ ] Step 3: Private Bot (Public Bot = OFF) + Require OAuth2 Code Grant = OFF in Developer Portal
- [ ] Step 3: Privileged Intents: Message Content + Server Members = ON
- [ ] Step 4: Bot token copied and stored securely
- [ ] Step 5: Invite URL generated with **Guild Install** integration type selected
- [ ] Step 5: Scopes: bot + applications.commands checked
- [ ] Step 5: Bot Permissions: View Channels, Send Messages, Send Messages in Threads, Embed Links, Attach Files, Read Message History, Add Reactions checked
- [ ] Bot token set in Hermes environment config
- [ ] DISCORD_ALLOWED_USERS set (comma-separated user IDs)
- [ ] Credential store file permissions set to owner-read-only
- [ ] Manual invite URL used to add bot to server
- [ ] Test DM and @mention in server channel
- [ ] Verify unauthorized users are rejected

## Diagnosing Channel Mention Not Responding (DM works, channel mention doesn't)

### Symptom
Bot responds to DMs but ignores @mentions in server channels. No error in logs — messages simply never reach `inbound message`.

### Diagnostic Procedure

1. **Check agent.log for inbound messages around the timestamp:**
   ```bash
   grep -E "inbound message|response ready|Flushing|Sending response" ~/.hermes/logs/agent.log | tail -30
   ```
   DM entries appear as `discord:dm:ID`. Channel/thread entries appear as `discord:thread:ID:ID` or `discord:channel:ID`. If only DM entries show, the channel message is being filtered upstream.

2. **Check the triple-gate filter chain** (all must pass for a channel message to reach `_handle_message`):

   **Gate 1: User allowlist** (discord.py:670)
   - `_is_allowed_user()` — if DISCORD_ALLOWED_USERS is set and the sender is not in it, silently dropped.

   **Gate 2: Multi-agent mention filter** (discord.py:682-700)
   - If `message.mentions` is non-empty (i.e., ANY mention is present, including the bot):
     - `_self_mentioned` = bot in `message.mentions`
     - `_other_bots_mentioned` = any other bot in `message.mentions`
     - If other bots mentioned but NOT self → dropped
     - If `DISCORD_IGNORE_NO_MENTION=true` (default!) and NOT self-mentioned and NOT other-bots-mentioned → dropped
   - **KEY**: If message.mentions is EMPTY (no @mention at all), this gate is skipped entirely

   **Gate 3: require_mention in _handle_message** (discord.py:2807-2809)
   - `require_mention=true` (config.yaml default) + not free_channel + not in_bot_thread → must have bot in `message.mentions`
   - **Common failure**: Discord sometimes doesn't populate `message.mentions` correctly (e.g., @silent mentions, certain mobile clients, or if Message Content Intent is OFF)

3. **Verify Privileged Intents in Developer Portal:**
   - Message Content Intent = ON is **required** for `message.mentions` to be populated
   - Without it, `message.content` and `message.mentions` may be empty → all 3 gates fail silently

4. **Check DISCORD_ALLOWED_CHANNELS** (discord.py:2777-2782):
   - If set, only listed channel IDs are responded to. Empty = all channels allowed.

5. **Check DISCORD_IGNORED_CHANNELS** (discord.py:2785-2789):
   - If the channel ID is listed, bot NEVER responds, even when @mentioned.

6. **Enable debug logging to see where messages are dropped:**
   ```bash
   DISCORD_LOG_LEVEL=DEBUG hermes gateway run --replace
   ```
   Then send a test @mention and watch for "Ignoring message" or "non-allowed channel" log lines.

### Common Root Causes

| Cause | Check | Fix |
|-------|-------|-----|
| Message Content Intent OFF | Developer Portal → Bot → Privileged Gateway Intents | Enable Message Content Intent |
| `message.mentions` empty | Debug log or add temporary logger | Usually Intent issue, sometimes client bug |
| Channel in DISCORD_IGNORED_CHANNELS | Check `.env` | Remove channel ID |
| Channel not in DISCORD_ALLOWED_CHANNELS | Check `.env` | Add channel ID or leave empty |
| Auto-thread creation failure | Check gateway.log for thread errors | Check bot has "Manage Threads" permission |
| `DISCORD_IGNORE_NO_MENTION=true` + message has human mentions but not bot | Debug `message.mentions` content | Ensure @bot is explicitly mentioned |

### Quick Workaround

To make the bot respond to ALL messages in specific channels (no @mention required):
1. Add channel IDs to `discord.free_response_channels` in config.yaml
2. Or set `DISCORD_IGNORE_NO_MENTION=false` in `.env` (WARNING: responds to everything, use with `DISCORD_ALLOWED_CHANNELS`)

## Key File Locations

- Official docs: `website/docs/user-guide/messaging/discord.md`
- Adapter code: `gateway/platforms/discord.py` (3486 lines)
- Auth logic: `gateway/run.py` lines 2652-2863
- Session source building: `discord.py` lines 2865-2889
- Toolset definition: `toolsets.py` lines 305-309
- Config loading: `gateway/config.py` lines 613-654