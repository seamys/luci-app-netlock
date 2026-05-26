# luci-app-netlock — Agent Instructions

OpenWrt LuCI application: presence-based network control using nftables firewall rules.
When a designated "anchor" device is present on WiFi, all LAN clients have unrestricted internet.
Once the anchor is offline beyond the grace period, all external traffic is blocked.

See [README.md](README.md) for feature overview and installation.

## Build & Test

```sh
# Run unit tests (no router required)
bash tests/run_all.sh

# Build APK package (requires OpenWrt SDK)
make -C /path/to/openwrt package/luci-app-netlock/compile

# Deploy files directly to a router for live testing
ROUTER=root@192.168.0.1
scp src/bin/netlock $ROUTER:/usr/sbin/
scp src/rpcd/netlock $ROUTER:/usr/libexec/rpcd/
scp src/init/netlock $ROUTER:/etc/init.d/
scp src/config/netlock $ROUTER:/etc/config/
scp src/view/*.js $ROUTER:/www/luci-static/resources/view/netlock/
scp src/share/menu.d/luci-app-netlock.json $ROUTER:/usr/share/luci/menu.d/
scp src/share/acl.d/luci-app-netlock.json $ROUTER:/usr/share/rpcd/acl.d/
ssh $ROUTER '/etc/init.d/rpcd reload && rm -rf /tmp/luci-*cache*'
```

## CI / Release

GitHub Actions workflows at `.github/workflows/`:
- **test.yml** — Runs `bash tests/run_all.sh` on every push to `main` and on pull requests.
- **release.yml** — Triggers on pushing a `v*` tag (e.g. `git tag v1.0.0 && git push origin v1.0.0`).
  - Runs tests first; packages `src/` + `Makefile` into a source tarball.
  - Creates a GitHub Release with auto-generated release notes and the tarball attached.

## Architecture

Four layers interact at runtime:

| Layer | File(s) | Role |
|---|---|---|
| LuCI views | `src/view/*.js` | Browser UI; reads UCI via forms, calls rpcd via `rpc.declare()` |
| rpcd backend | `src/rpcd/netlock` | Protocol adapter; reads status file, enumerates WiFi clients |
| Main daemon | `src/bin/netlock` | Core logic: presence detection, nftables blocking, status file |
| UCI config | `src/config/netlock` | Source of truth for all settings |
| Init script | `src/init/netlock` | procd service; triggers daemon restart on UCI commit |

Data flow on "Save & Apply": UCI commit → `procd_add_reload_trigger` → daemon restarted → re-reads config on each poll loop.

## Key Conventions

### Shell scripts (`src/bin/`, `src/rpcd/`, `src/init/`)
- **POSIX sh only** (`#!/bin/sh`), no bash. busybox ash compatible.
- Constants in `UPPER_SNAKE_CASE`; functions named with verbs; private helpers prefixed `_`.
- JSON produced via `. /usr/share/libubox/jshn.sh` + `json_init` / `json_add_*` / `json_dump`.
- UCI access via `uci -q get` / `uci -q set` (standard for daemons).
- Logging via `logger -t "netlock"`.
- MAC addresses always normalized to lowercase for comparison.

### LuCI views (`src/view/*.js`)
- ES5 strict mode; LuCI module system (`'require view'`, `'require form'`, `'require rpc'`).
- DOM via `E(tag, attrs, children)` — no frameworks, no template literals.
- Translation via `_('...')` — every user-visible string must be in the POT/PO.
- Forms use `form.Map` / `form.NamedSection`.
- `o.validate` functions for client-side input validation.

### rpcd (`src/rpcd/netlock`)
- `list` method returns JSON method signatures; `call` dispatches to `method_*` functions.
- Status read from `/var/run/netlock.json` (written by daemon).
- Client enumeration from AP association + neighbor table + DHCP leases.

### UCI section types
| Section | Type name | Access pattern |
|---|---|---|
| Global settings | `netlock` | `uci -q get netlock.global.<option>` |

## Critical Pitfalls

- **nftables table ownership** — The daemon creates/deletes `table inet netlock` independently of fw4. Never manipulate this table externally while the daemon runs.
- **prerouting priority -300** — Hooks BEFORE fw4 and OpenClash TProxy. This is intentional for blocking both direct and proxied traffic simultaneously.
- **MAC case sensitivity** — All MAC comparisons must use lowercase. The daemon normalizes via `tr 'A-F' 'a-f'`. The form should enforce lowercase or auto-convert.
- **Grace period race** — The daemon starts in blocked state (fail-safe). If no anchor is detected within the first poll, traffic stays blocked until confirmed present.
- **Status file race** — Written atomically via tmp + mv to prevent partial reads by rpcd.
- **Monitor interfaces** — Optional; if empty, all `hostapd.*` ubus objects are scanned automatically.

## i18n Workflow

1. Use `_('English text')` in view JS files
2. Add `msgid "English text"` to `src/i18n/templates/netlock.pot`
3. Add translated `msgstr` to `src/i18n/zh_Hans/netlock.po`
4. Build: `po2lmo` converts `.po` → `.lmo` binary

No automated extraction — POT is maintained manually.

## Test Conventions

- Tests in `tests/test_*.sh`; each sources `framework.sh` + `mocks.sh`.
- Run individual suite: `bash tests/test_presence.sh`
- Run all: `bash tests/run_all.sh`
- Mocks simulate UCI, nftables, iwinfo, ip neigh — tests run on any dev machine.
