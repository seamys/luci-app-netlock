# Usage

## LuCI Web Interface

### Dashboard (`Services → NetLock → Dashboard`)

The dashboard shows real-time status updated every 5 seconds:

- **Anchor Device** — Online (green) / Offline (red) / Inactive (gray)
- **Internet Access** — Open (green) / Blocked (red)
- **Last Seen** — Time since anchor was last detected
- **Monitored MACs** — Configured target MAC addresses
- **Matched MACs** — Which targets are currently detected
- **Grace Period / Poll Interval** — Current timing settings

**Quick Actions:**
- **Reload Configuration** — Restarts the daemon to pick up config changes

### Settings (`Services → NetLock → Settings`)

Configure all options through the web form:

1. **Service** — Enable/disable the network lock
2. **Anchor Device** — Select MAC from live WiFi clients dropdown, or enter manually
3. **Timing** — Grace period and poll interval
4. **Advanced** — Monitor interface restriction

Changes are applied via the standard LuCI "Save & Apply" workflow.

## CLI Management

### Service Control

```sh
# Start/stop/restart
/etc/init.d/netlock start
/etc/init.d/netlock stop
/etc/init.d/netlock restart
/etc/init.d/netlock reload

# Enable/disable at boot
/etc/init.d/netlock enable
/etc/init.d/netlock disable
```

### Check Status

```sh
# Read status file directly
cat /var/run/netlock.json | jsonfilter -e '@'

# Via ubus (same as LuCI uses)
ubus call netlock status
ubus call netlock clients
```

### View Logs

```sh
# Recent netlock log entries
logread | grep netlock

# Follow live
logread -f | grep netlock
```

### Check Firewall State

```sh
# See if blocking rules are active
nft list table inet netlock 2>/dev/null && echo "BLOCKED" || echo "OPEN"

# Manually remove block (emergency)
nft delete table inet netlock
```

## How Detection Works

The daemon uses a 3-tier detection strategy (executed in order):

1. **AP Association** — Checks if the MAC is currently associated to any local WiFi AP via `iwinfo` and `hostapd` ubus calls
2. **Neighbor Table** — Checks if the kernel ARP/NDP table has the MAC in REACHABLE, DELAY, or PROBE state
3. **Ping Fallback** — Sends a single ICMP ping to wake the device from sleep

If **any** of the configured target MACs is detected by **any** method, the anchor is considered "present" and internet remains open.

## Fail-Safe Behavior

- On startup with `enabled=1` and targets configured: **starts blocked** until presence is confirmed
- On disable: **immediately unblocks**
- On daemon crash: procd auto-restarts; nft table persists until daemon cleanup
- On TERM/INT signal: daemon removes nft table before exiting (leaves internet open)
