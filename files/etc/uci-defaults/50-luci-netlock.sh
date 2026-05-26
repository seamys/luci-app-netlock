#!/bin/sh
/etc/init.d/netlock enable

# pick up the new rpcd acl/object and refresh the LuCI menu cache
/etc/init.d/rpcd reload 2>/dev/null
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null

exit 0
