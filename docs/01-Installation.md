# Installation

## Prerequisites

- OpenWrt 23.x or later
- nftables (included by default in OpenWrt 22+)
- iwinfo (included by default)
- LuCI (luci-base)

## Method 1: Package Install (opkg/apk)

If you have the package feed configured:

```sh
opkg update
opkg install luci-app-netlock
```

## Method 2: Manual Deployment (scp)

Deploy directly from the source tree to a running router:

```sh
ROUTER=root@192.168.1.1

# Main daemon
scp src/bin/netlock $ROUTER:/usr/sbin/
ssh $ROUTER 'chmod +x /usr/sbin/netlock'

# rpcd backend
scp src/rpcd/netlock $ROUTER:/usr/libexec/rpcd/
ssh $ROUTER 'chmod +x /usr/libexec/rpcd/netlock'

# Init script
scp src/init/netlock $ROUTER:/etc/init.d/
ssh $ROUTER 'chmod +x /etc/init.d/netlock'

# UCI config (only if first install)
scp src/config/netlock $ROUTER:/etc/config/

# LuCI views
ssh $ROUTER 'mkdir -p /www/luci-static/resources/view/netlock'
scp src/view/*.js $ROUTER:/www/luci-static/resources/view/netlock/

# Menu and ACL
scp src/share/menu.d/luci-app-netlock.json $ROUTER:/usr/share/luci/menu.d/
scp src/share/acl.d/luci-app-netlock.json $ROUTER:/usr/share/rpcd/acl.d/

# Activate
ssh $ROUTER '
  /etc/init.d/netlock enable
  /etc/init.d/rpcd reload
  rm -rf /tmp/luci-*cache*
  /etc/init.d/netlock start
'
```

## Method 3: Build from Source (OpenWrt SDK)

```sh
# Clone into the SDK package directory
cd /path/to/openwrt
cp -r /path/to/luci-app-netlock package/

# Build
make package/luci-app-netlock/compile V=s

# Find the package
find bin/ -name 'luci-app-netlock*.ipk'
```

## Uninstall

```sh
# On the router
/etc/init.d/netlock stop
/etc/init.d/netlock disable

rm -f /usr/sbin/netlock
rm -f /usr/libexec/rpcd/netlock
rm -f /etc/init.d/netlock
rm -f /etc/config/netlock
rm -rf /www/luci-static/resources/view/netlock
rm -f /usr/share/luci/menu.d/luci-app-netlock.json
rm -f /usr/share/rpcd/acl.d/luci-app-netlock.json
rm -f /var/run/netlock.json

/etc/init.d/rpcd reload
rm -rf /tmp/luci-*cache*
```
