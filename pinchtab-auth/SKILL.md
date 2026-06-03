---
name: pinchtab-auth
description: Use whenever the user needs to test or automate an authenticated web app via pinchtab — refreshing an expired SSO login, launching a visible Chrome window for interactive 2FA, managing per-app login profiles for headless testing, or troubleshooting why a saved login isn't working. Triggers on mentions of pinchtab, browser automation against an authenticated site, "the daemon is down," "the profile expired," visible-vs-headless Chrome for SSO, or the xhost-to-DISPLAY:0 dance on a multi-account Linux box. Also use when the user wants to bootstrap pinchtab on a fresh machine or set up a new project that will use pinchtab for automated testing.
---

# Pinchtab

Pinchtab is a lightweight automation bridge for Chromium. The common pattern: launch a headed browser to complete an SSO login interactively, save the session to a named profile, then drive the app headlessly using that profile for automated testing.

This skill covers a specific deployment pattern: **the user runs pinchtab from a development account reached over SSH, while the desktop X display is owned by a different local account.** Visible-Chrome operations therefore require an `xhost` grant from the desktop account. If the user's setup is different (single-account, headless-only, etc.), adapt — but ask before assuming.

## When this skill triggers

Read the project's pinchtab record first (see "Project state" below), then act. If no record exists, run discovery and setup (see "First-time setup in a project").

Common requests:
- "Run a smoke test against the app" → headless `pinchtab nav --snap` using the project's profile.
- "The profile is showing the login screen" → refresh SSO (see "Refreshing the SSO login").
- "Pinchtab isn't responding" → daemon diagnosis (see "Daemon lifecycle").
- "Set up pinchtab for this project" → first-time setup.
- "Set up pinchtab on this machine" → bootstrap (see `REFERENCE.md`).

## Project state

Pinchtab configuration is per-project and machine-local. Store and read it via Claude Code's auto memory.

**Read on every trigger:**
1. Check for `~/.claude/projects/<project>/memory/pinchtab.md`. If present, load it — it has the bindings (dev_user, desktop_user, display, app_name, app_url, profile, daemon_launch, last_refreshed).
2. If not present, check the project root for a fenced pinchtab block in `CLAUDE.local.md` (fallback for when auto memory is disabled). Block looks like:
   ```
   <!-- pinchtab-config:start -->
   ...
   <!-- pinchtab-config:end -->
   ```
3. If neither is present, run first-time setup (next section).

**Write when state changes:**
- After first-time setup: write the full record.
- After a successful SSO refresh: update `last_refreshed` to today's date.
- After daemon-launch-mode change (manual ↔ systemd): update that field.

If auto memory is enabled (default), write to `~/.claude/projects/<project>/memory/pinchtab.md` and add a one-line entry to `MEMORY.md`: `Pinchtab automation: see pinchtab.md`. Don't duplicate the full record in `MEMORY.md` — it's loaded into every session and should stay terse.

If auto memory is disabled, write the fallback block to `CLAUDE.local.md` at the project root. Make sure `CLAUDE.local.md` is in `.gitignore`; if not, propose adding it before writing.

**Record format:**
```markdown
# Pinchtab project configuration

- dev_user: <user>
- desktop_user: <user>
- display: <:0 or other>
- app_name: <name>
- app_url: <url>
- profile: <profile-name-or-hash>
- profile_id_mode: <name | hash>
- daemon_launch: <manual | systemd>
- auth_provider: <freeform note, e.g. "Keycloak realm X client Y">
- last_refreshed: <YYYY-MM-DD>
```

## First-time setup in a project

Run discovery before asking the user anything you can determine yourself.

**Discover without asking:**
- `echo $USER` → `dev_user`.
- `test -d ~/.pinchtab && echo yes` → does pinchtab init need to run?
- `pgrep -af 'pinchtab.*server' | grep "$USER"` → is the daemon up?
- `ls ~/.pinchtab/profiles/ 2>/dev/null` → existing profiles.
- `systemctl --user is-enabled pinchtab 2>/dev/null` → systemd status (if any).
- `test -f ~/.pinchtab/profiles/<id>/LABEL && cat ~/.pinchtab/profiles/<id>/LABEL` for each profile — sometimes labeled.

**Ask the user (in one batch, not one-by-one):**
- Which Linux account owns the X display this account needs to draw to? (`desktop_user`)
- Which display? Default `:0` unless they say otherwise.
- What's the app name and entry URL?
- Is there an existing profile to reuse, or should we create a new one named `<app>-<env>` (e.g. `omniagent-dev`)?
- Should the daemon run via systemd or be launched manually? (Manual is more reliable for the SSO-login path; systemd is better for unattended autostart. If unsure, default to manual.)

**If pinchtab is not installed at all**, see `REFERENCE.md` for the bootstrap procedure before proceeding.

**Create the profile** (if needed):
```bash
pinchtab profile create --name '<app>-<env>'
pinchtab profile list
```
After `profile list`, inspect the output:
- If your chosen name appears as the profile id, set `profile_id_mode: name` and use the name in `--profile` everywhere afterwards.
- If pinchtab returned a `prof_<8hex>` id and treats your name as a display label only, set `profile_id_mode: hash`, record the hash as `profile`, and also drop a label file: `echo '<app>-<env>' > ~/.pinchtab/profiles/<hash>/LABEL`.

**Authenticate the profile** — see "Refreshing the SSO login" below. After successful authentication, write the project record.

## Daemon lifecycle

**Check if running:**
```bash
pgrep -af 'pinchtab.*server' | grep "$DEV_USER"
```
A line ending with `pinchtab-linux-amd64 server` means up. The `bridge` process is separate and per-session.

**Start manually:**
```bash
DISPLAY=$DISPLAY pinchtab server &
```
Then confirm `server.log`:
```bash
tail -3 ~/.pinchtab/server.log
```
Look for `READY port=<port>`.

**Stop:**
```bash
pinchtab daemon stop
```
If that hangs: `pkill -f 'pinchtab.*server' -u "$DEV_USER"`.

**Restart cleanly:**
```bash
pinchtab daemon stop
DISPLAY=$DISPLAY pinchtab server &
```

**If `daemon_launch: systemd`** in the project record, use `systemctl --user {start,stop,restart,status} pinchtab` instead of the manual commands above. See `REFERENCE.md` for unit file details.

## Granting X display access

The SSO login flow needs a *visible* Chrome window. `$DEV_USER` has no X session of its own and must draw to `$DESKTOP_USER`'s display. This requires the user to run a command on the desktop account — Claude cannot do this from the SSH session.

**Tell the user to run, on the desktop account:**
```bash
xhost +SI:localuser:$DEV_USER
```
The grant lasts until the desktop user logs out. Narrower and safer than `xhost +local:` or `xhost +`.

**Verify from the SSH session:**
```bash
DISPLAY=$DISPLAY xset q | head -3
```
If it prints display info, access is granted. If it errors with "unable to open display," the grant hasn't propagated — ask the user to re-run the xhost command.

## Refreshing the SSO login

Use when the profile's session cookies have expired (login screen on snap, 401 redirects, etc.).

1. Verify daemon is up; start it if not (see "Daemon lifecycle").
2. Verify X access; instruct user to run `xhost` if needed (see "Granting X display access").
3. Launch a visible Chrome session against the profile, pointed at the app:
   ```bash
   DISPLAY=$DISPLAY pinchtab nav "$APP_URL" \
     --profile "$PROFILE" \
     --headless=false
   ```
   `--headless=false` is critical — pinchtab's default is headless, and most SSO 2FA flows won't complete in headless mode.
4. Tell the user to complete the SSO flow interactively in the Chrome window that appears on the desktop. Cookies persist back to the profile dir as login completes. If the IdP offers "stay signed in" / "remember this device," tick it.
5. After the user confirms login landed on the app shell and they've closed the window, verify headlessly:
   ```bash
   pinchtab nav "$APP_URL" --profile "$PROFILE" --snap
   ```
   The snap should show the app shell, not the SSO login screen. If it shows the login screen, the cookies didn't persist — restart from step 3.
6. Update `last_refreshed` in the project record.

**Don't try to refresh on top of a partially-stale session.** If a previous refresh failed mid-flow, the safer path is to start fresh — the new login's cookies will overwrite the old ones.

## Routine headless operations

For automated testing, navigation, and snapshots:
```bash
pinchtab nav "$APP_URL/path" --profile "$PROFILE" --snap
pinchtab session list
```
No `DISPLAY=$DISPLAY` prefix needed for headless mode — only for visible Chrome.

If a routine operation returns the login screen unexpectedly, run the refresh procedure. Don't loop on the same failing operation.

## Profile management

**List:**
```bash
pinchtab profile list
ls ~/.pinchtab/profiles/
```

**Create:** see "First-time setup."

**Identify an unknown profile** (when `profile_id_mode: hash` and no LABEL file):
```bash
DISPLAY=$DISPLAY pinchtab nav "<some-account-page>" --profile "<prof_id>" --snap
```
View the snap to see which account is logged in. Once identified, drop a LABEL file so this isn't needed again:
```bash
echo '<app>-<env>' > ~/.pinchtab/profiles/<prof_id>/LABEL
```

**Delete:**
```bash
pinchtab profile delete --profile "<id>"
# or:
rm -rf ~/.pinchtab/profiles/<id>/
```

## When things go wrong

Quick diagnostic order before reaching for `REFERENCE.md`:
1. `pgrep -af 'pinchtab.*server'` — is the daemon up? Is it the right user's binary?
2. `tail ~/.pinchtab/server.log` — last messages tell you a lot.
3. `DISPLAY=$DISPLAY xset q` — is the X grant in effect? (Only relevant for headed ops.)
4. `pinchtab session list` — any orphan sessions to clean up?

For specific symptoms (port conflicts, headless-mode SSO failures, multi-process confusion across both Linux accounts), see the troubleshooting matrix in `REFERENCE.md`.

## Reference

`REFERENCE.md` contains:
- Bootstrap from scratch: install pinchtab CLI, `pinchtab init`, systemd unit + DISPLAY drop-in.
- The full troubleshooting matrix.
- X11 / xhost details beyond the common case.
- Notes on running both accounts' pinchtab installs side-by-side without confusion.

Read it on demand — don't load it preemptively.
