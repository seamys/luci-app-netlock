# Configuration

NetLock stores all configuration in `/etc/config/netlock` using UCI format.

## UCI Config Structure

```
config netlock 'global'
    option enabled '1'
    option grace_period '300'
    option poll_interval '10'
    list target_mac 'aa:bb:cc:dd:ee:ff'
    list monitor_iface 'phy0-ap0'
```

## Options Reference

### Section: `config netlock 'global'`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `1` | Master switch. When `0`, firewall rules are removed and internet is open. |
| `grace_period` | integer | `300` | Seconds to wait after anchor goes offline before blocking. Prevents false triggers from screen-off sleep. |
| `poll_interval` | integer | `10` | How often (seconds) to scan for anchor presence. Minimum: 2. |
| `target_mac` | list | (empty) | MAC address(es) of anchor devices. Internet opens when ANY one is detected. |
| `monitor_iface` | list | (empty) | Restrict AP scanning to these interfaces. Empty = auto-detect all `hostapd.*` interfaces. |

## CLI Examples

```sh
# Enable the service
uci set netlock.global.enabled='1'

# Add anchor device MAC
uci add_list netlock.global.target_mac='aa:bb:cc:dd:ee:ff'

# Set grace period to 10 minutes
uci set netlock.global.grace_period='600'

# Set poll interval to 5 seconds
uci set netlock.global.poll_interval='5'

# Restrict to specific AP interface
uci add_list netlock.global.monitor_iface='phy0-ap0'

# Apply changes
uci commit netlock
/etc/init.d/netlock reload
```

## Important Notes

### MAC Address Format
- Use colon-separated lowercase hex: `aa:bb:cc:dd:ee:ff`
- The daemon normalizes to lowercase internally, but consistent input prevents confusion
- **Disable "Randomize MAC"** on the anchor device for the monitored WiFi network

### Grace Period
- `0` = immediate block when anchor goes offline (not recommended — phone sleep triggers it)
- `300` (5 min) = good default for most users
- `600` (10 min) = conservative, for phones with aggressive sleep

### Poll Interval
- `10` = good balance of responsiveness and CPU usage
- `5` = faster detection, slightly more CPU
- `2` = minimum allowed value

### Monitor Interface
- Leave empty for automatic detection (recommended)
- Set explicitly only if you have multiple APs and want to restrict scanning
- Interface names are hostapd interface names (e.g., `phy0-ap0`, `phy1-ap0`)
