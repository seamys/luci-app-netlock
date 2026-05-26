# luci-app-netlock

[![Test](https://github.com/seamys/luci-app-netlock/actions/workflows/test.yml/badge.svg)](https://github.com/seamys/luci-app-netlock/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/seamys/luci-app-netlock?display_name=tag&sort=semver)](https://github.com/seamys/luci-app-netlock/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%2B-00B5E2?logo=openwrt&logoColor=white)](https://openwrt.org)
[![Platform](https://img.shields.io/badge/Platform-LuCI-8B5CF6)](https://github.com/openwrt/luci)
[![Shell](https://img.shields.io/badge/Shell-POSIX%20sh-4EAA25?logo=gnubash&logoColor=white)](https://www.shellcheck.net/)
[![nftables](https://img.shields.io/badge/Firewall-nftables-EC6C35)](https://nftables.org)

> **Presence-based network control for OpenWrt** — Blocks internet for all LAN clients when the designated anchor device (typically a phone) is absent from WiFi beyond the grace period.

Compatible with OpenClash TProxy — blocking hooks at nftables raw/prerouting priority -300, before TProxy redirect.

## Features

- 🔒 **Presence-based internet control** — 3-tier MAC detection: AP association → neighbor table → ping
- 🛡️ **nftables native blocking** — Independent `inet netlock` table, does not interfere with fw4
- ⏱️ **Graceful grace period** — Configurable delay before blocking, avoids false triggers from phone sleep
- 🖥️ **LuCI web interface** — Real-time dashboard + settings page at `Services → NetLock`
- 🔄 **procd integration** — Auto-start on boot, auto-respawn on crash, hot-reload on `uci commit`
- 📱 **Multi-anchor support** — Multiple `target_mac` entries; internet opens when ANY one is detected
- 🌐 **i18n ready** — English base with Chinese Simplified translation

## Quick Install

```sh
ROUTER=root@192.168.1.1

scp src/bin/netlock $ROUTER:/usr/sbin/
scp src/rpcd/netlock $ROUTER:/usr/libexec/rpcd/
scp src/init/netlock $ROUTER:/etc/init.d/
scp src/config/netlock $ROUTER:/etc/config/
ssh $ROUTER 'mkdir -p /www/luci-static/resources/view/netlock'
scp src/view/*.js $ROUTER:/www/luci-static/resources/view/netlock/
scp src/share/menu.d/luci-app-netlock.json $ROUTER:/usr/share/luci/menu.d/
scp src/share/acl.d/luci-app-netlock.json $ROUTER:/usr/share/rpcd/acl.d/
ssh $ROUTER 'chmod +x /usr/sbin/netlock /usr/libexec/rpcd/netlock /etc/init.d/netlock && \
  /etc/init.d/netlock enable && /etc/init.d/rpcd reload && \
  rm -rf /tmp/luci-*cache* && /etc/init.d/netlock start'
```

Then configure via LuCI → Services → NetLock → Settings, or CLI:

```sh
uci add_list netlock.global.target_mac='aa:bb:cc:dd:ee:ff'
uci commit netlock
/etc/init.d/netlock reload
```

## Project Structure

```
├── Makefile                    # OpenWrt SDK build definition
├── AGENTS.md                   # Agent instructions & conventions
├── README.md                   # This file
├── src/
│   ├── bin/netlock             # Main daemon (presence detection + nft blocking)
│   ├── rpcd/netlock            # rpcd backend (ubus: status, clients)
│   ├── init/netlock            # procd init script
│   ├── config/netlock          # UCI default config
│   ├── uci-defaults/50-luci-netlock  # First-boot setup
│   ├── view/
│   │   ├── overview.js         # LuCI dashboard (real-time status)
│   │   └── settings.js         # LuCI settings form
│   ├── share/
│   │   ├── menu.d/             # LuCI menu registration
│   │   └── acl.d/              # rpcd ACL definitions
│   └── i18n/
│       ├── templates/netlock.pot   # Translation template
│       └── zh_Hans/netlock.po      # Chinese Simplified
├── tests/
│   ├── framework.sh            # Test assertion helpers
│   ├── mocks.sh                # Mock UCI/nft/iwinfo for testing
│   ├── test_presence.sh        # Presence detection tests
│   ├── test_firewall.sh        # Firewall rule tests
│   ├── test_config.sh          # Config loading tests
│   └── run_all.sh              # Test runner
└── docs/
    ├── 01-Installation.md
    ├── 02-Configuration.md
    ├── 03-Usage.md
    └── 04-Troubleshooting.md
```

## Tests

```sh
bash tests/run_all.sh           # Run all tests
bash tests/test_presence.sh     # Run single suite
```

## Documentation

See [docs/](docs/README.md) for detailed installation, configuration, usage, and troubleshooting guides.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Run tests: `bash tests/run_all.sh`
4. Commit and push
5. Open a Pull Request

## License

MIT

---

<p align="center">
  <sub>Built for OpenWrt · Powered by nftables · Made with ☕</sub>
</p>
