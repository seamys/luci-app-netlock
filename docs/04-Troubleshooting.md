# Troubleshooting

## Common Issues

### Internet stays blocked even when phone is connected

**Cause 1: Randomized MAC address**
- Modern phones use a random MAC for each WiFi network
- The configured MAC won't match the randomized one
- **Fix:** Disable "Randomize MAC" / "Private Address" in phone WiFi settings for your home network

**Cause 2: Phone connected to a different AP/band**
- If you have multiple APs or mesh, the phone might connect to one not being monitored
- **Fix:** Leave `monitor_iface` empty (auto-detects all APs), or add all AP interfaces

**Cause 3: MAC case mismatch**
- The daemon normalizes to lowercase, but verify your config uses the correct format
- **Fix:** `uci get netlock.global.target_mac` — verify the MAC matches your phone

### Internet stays open when phone is away

**Cause 1: Grace period not elapsed**
- Check status: `cat /var/run/netlock.json`
- The `last_seen` timestamp shows when the phone was last detected
- **Fix:** Wait for the grace period to elapse, or reduce it

**Cause 2: Another device with the same MAC**
- Unlikely, but check for MAC conflicts
- **Fix:** Verify with `ubus call netlock clients`

**Cause 3: Phone responding to ping from cached IP**
- Even if not on WiFi, some phones respond to LAN ping briefly
- **Fix:** This is by design (3rd tier detection). Increase grace period.

### LuCI page not showing / menu missing

```sh
# Reload rpcd to register the netlock backend
/etc/init.d/rpcd reload

# Clear LuCI cache
rm -rf /tmp/luci-*cache*

# Verify ACL is in place
ls -la /usr/share/rpcd/acl.d/luci-app-netlock.json

# Verify menu is in place
ls -la /usr/share/luci/menu.d/luci-app-netlock.json
```

### Status shows "Inactive"

This means `enabled=0` in config:
```sh
uci set netlock.global.enabled='1'
uci commit netlock
/etc/init.d/netlock reload
```

### Conflict with OpenClash / passwall / other proxies

NetLock hooks at `prerouting priority -300`, which is **before** most proxy software:
- OpenClash TProxy typically at priority -150 to 0
- This means NetLock blocks traffic before it reaches the proxy

**This is intentional** — when the anchor is absent, ALL traffic (direct and proxied) is blocked.

If you need proxy traffic to bypass NetLock, this requires custom nftables rules and is not supported by the current design.

### Daemon crashes or high CPU

```sh
# Check if running
pidof netlock || echo "not running"

# Check recent crashes
logread | grep -E 'netlock|procd.*netlock'

# Verify poll_interval is reasonable (minimum 2s)
uci get netlock.global.poll_interval
```

## Diagnostic Commands

```sh
# Full status dump
echo "=== Config ===" && uci show netlock
echo "=== Status ===" && cat /var/run/netlock.json 2>/dev/null || echo "no status file"
echo "=== NFT ===" && nft list table inet netlock 2>/dev/null || echo "no rules (open)"
echo "=== Clients ===" && ubus call netlock clients
echo "=== Log ===" && logread | grep netlock | tail -20
```

## Emergency Recovery

If NetLock is blocking and you can't access LuCI:

```sh
# SSH into router (SSH uses a different port/path, usually not blocked)
ssh root@192.168.1.1

# Immediately remove block
nft delete table inet netlock

# Disable netlock
/etc/init.d/netlock stop
uci set netlock.global.enabled='0'
uci commit netlock
```

If SSH is also blocked (extreme case), you'll need physical console access or failsafe boot.
