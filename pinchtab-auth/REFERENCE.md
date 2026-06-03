# Pinchtab reference

Material that doesn't belong in `SKILL.md` because it's needed rarely or only during bootstrap. Read on demand.

## Table of contents

- [Bootstrap from scratch](#bootstrap-from-scratch)
- [systemd unit setup](#systemd-unit-setup)
- [Two installs on one machine](#two-installs-on-one-machine)
- [Troubleshooting matrix](#troubleshooting-matrix)
- [X11 details beyond the common case](#x11-details-beyond-the-common-case)

## Bootstrap from scratch

For a fresh `$DEV_USER` account, or after `~/.pinchtab/` has been destroyed.

### 1. Install pinchtab CLI (one-time per machine)

Verify the install command against pinchtab.com/docs before running. Roughly:
```bash
curl -fsSL https://pinchtab.com/install.sh | sh
```
This drops the binary at `/usr/local/bin/pinchtab` (root-owned) and is shared by any user accounts on the machine.

### 2. Per-user init

As `$DEV_USER`:
```bash
pinchtab init
```
Creates `~/.pinchtab/` with a fresh `config.json`, the `bin/<version>/` directory, and a `default` profile dir.

### 3. (Optional) systemd unit

Only if you've chosen `daemon_launch: systemd` for this project. See [systemd unit setup](#systemd-unit-setup) below.

### 4. Start the daemon manually (recommended baseline)

```bash
DISPLAY=$DISPLAY pinchtab server &
```

### 5. Have desktop user grant X access

On `$DESKTOP_USER`'s account:
```bash
xhost +SI:localuser:$DEV_USER
```

### 6. Create and authenticate the project's profile

Back to the main skill's "First-time setup in a project" flow.

## systemd unit setup

Use a `bin/current` symlink so version bumps don't require editing the unit file.

```bash
# Point bin/current at the latest installed version
ln -sfn "$(ls -1d ~/.pinchtab/bin/[0-9]* | sort -V | tail -1)" ~/.pinchtab/bin/current

mkdir -p ~/.config/systemd/user/pinchtab.service.d

cat > ~/.config/systemd/user/pinchtab.service <<'EOF'
[Unit]
Description=Pinchtab Browser Service
After=network.target

[Service]
Type=simple
ExecStart=%h/.pinchtab/bin/current/pinchtab-linux-amd64 server
Environment="PINCHTAB_CONFIG=%h/.pinchtab/config.json"
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Substitute the actual display the project uses
cat > ~/.config/systemd/user/pinchtab.service.d/display.conf <<EOF
[Service]
Environment="DISPLAY=:0"
EOF

systemctl --user daemon-reload
systemctl --user enable --now pinchtab
```

**Caveat:** the visible-Chrome SSO login path has historically been less reliable through systemd than via manual launch — environment inheritance for `DISPLAY` is one common failure mode. Re-enable the unit only after confirming the SSO flow works end-to-end through it. The default recommendation is manual launch for projects with frequent SSO refreshes.

To switch from systemd-managed back to manual:
```bash
systemctl --user disable --now pinchtab
DISPLAY=:0 pinchtab server &
```
The unit and drop-in can stay on disk in disabled state.

## Two installs on one machine

When both `$DESKTOP_USER` and `$DEV_USER` have pinchtab installed, they're fully independent installs sharing only the `/usr/local/bin/pinchtab` CLI symlink.

| What's shared | What's separate |
|---|---|
| `/usr/local/bin/pinchtab` (the CLI dispatcher) | `~/.pinchtab/` (each user's config, profiles, binary, daemon, logs) |
| The system-wide install of pinchtab itself | Each user's `~/.config/systemd/user/pinchtab.service` if used |

**Distinguishing them at runtime:**
```bash
pgrep -af pinchtab
```
The full path in the output (`/home/scott-co/.pinchtab/...` vs `/home/streamweaver/.pinchtab/...`) tells you whose daemon is whose.

**Port collision:** each install's `config.json` has its own port. By default they may collide. If you see `port already in use`, check both `~/.pinchtab/config.json` files and pick non-overlapping ports.

## Troubleshooting matrix

| Symptom | Cause | Fix |
|---|---|---|
| `pinchtab already running as a daemon on port <port>` | Orphan `server` process | `pgrep -af pinchtab` → `pinchtab daemon stop` or `pkill -f 'pinchtab.*server' -u $USER` |
| `unable to open display` from `$DEV_USER` | xhost grant expired (logout/login resets it) | Ask `$DESKTOP_USER` to re-run `xhost +SI:localuser:$DEV_USER` |
| `DISPLAY` is set but Chrome still won't open a window | Stale `+local:` from old session, or `xhost` grant for a different user | On `$DESKTOP_USER`, run plain `xhost` to list current grants; reset with `xhost -` then re-grant with `+SI:localuser:$DEV_USER` |
| SSO flow stuck on "verify you're a real browser" / bot-check | Headless mode | Re-launch with `--headless=false` and complete login in the visible window |
| Profile snap shows SSO login screen despite recent refresh | Token actually expired, or refresh was interrupted | Re-run refresh from scratch — don't try to refresh-on-top |
| Multiple chrome processes per profile | Normal — pinchtab spawns renderer/network/GPU subprocesses per tab | `pinchtab session list` shows the parent sessions; only worry if it grows unbounded |
| Confusion about whose pinchtab is which | Two installs on one machine | `pgrep -af pinchtab` — full path distinguishes |
| Daemon starts, exits within seconds | Port conflict, or another user's daemon already bound | Check `~/.pinchtab/server.log` for the actual error; check the other account's daemon |
| `pinchtab profile list` shows a profile but `--profile <name>` errors | `profile_id_mode: hash` — names are display-only | Use the `prof_<hash>` id, update the project record |
| Snap renders blank or partial page | App hasn't finished loading | Add `--wait-for <selector>` or `--delay <ms>` to the nav command |

## X11 details beyond the common case

**Multiple displays:** if `$DESKTOP_USER` runs more than one X display, repeat the xhost grant for each. Set `DISPLAY` explicitly on the dev side per operation.

**Wayland sessions:** if `$DESKTOP_USER`'s session is Wayland-native rather than Xorg, `xhost` doesn't apply the same way. The desktop user likely has an XWayland server for X11 compatibility — `DISPLAY=:0` (or `:1`) and `xhost +SI:localuser:$DEV_USER` typically still work because XWayland accepts the same authorization. If they don't, the desktop user needs to confirm `echo $WAYLAND_DISPLAY` is set and whether their session is providing XWayland. Pinchtab needs an X server (it drives Chromium via X), so a pure-Wayland setup without XWayland won't work.

**SSH X forwarding (`ssh -X`):** not relevant to this skill's pattern. SSH X forwarding would tunnel X traffic back to the SSH client's display — but here the agent operates on the SSH *server* side and needs to draw to the *server's* local display. `xhost` is the correct mechanism.

**Why `xhost +SI:localuser:<user>` and not `xhost +local:`:** `+local:` grants access to any local user, including any other accounts on the machine. `+SI:localuser:<user>` grants access to one specific Unix user. The narrower grant is the right default and is what should be documented to the user.

**`xhost` grant scope:** lasts until `$DESKTOP_USER` logs out of their X session, or runs `xhost -SI:localuser:<user>` to revoke. Survives `$DEV_USER` logging out/in.
