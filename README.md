# void-anchor

**void-anchor** 是一个运行在 OpenWrt 路由器上的守护进程：当指定的「锚点」手机在 WiFi 上时，外网正常开放；一旦手机离开超过宽限期，所有 LAN 客户端的外网流量立即被切断。与 OpenClash TProxy 兼容——封锁发生在 nftables raw/prerouting 阶段（优先级 -300），位于 TProxy 重定向之前。

---

## 功能特性

- **基于存在感的互联网控制**：通过 MAC 地址检测手机是否在线（本机 AP 关联列表 → LAN 邻居表 → ping 三层探测）
- **nftables 原生封锁**：独立 `inet void_anchor` 表，不干扰 fw4 规则链
- **优雅宽限期**：手机离开后等待可配置秒数再封锁，避免手机信号短暂波动误触
- **LuCI 管理界面**：通过 `Services → VOID ANCHOR` 查看实时状态、配置目标 MAC
- **procd 集成**：开机自启，服务崩溃自动重启，`uci commit void_anchor` 触发热重载
- **多锚点支持**：可配置多个 `target_mac`，任意一个在线即保持通道开放

---

## 文件结构

```
files/                          ← 部署到路由器的文件（与根目录一一对应）
├── etc/
│   ├── config/
│   │   └── void_anchor         ← UCI 配置文件
│   ├── init.d/
│   │   └── void_anchor         ← procd init 脚本
│   └── uci-defaults/
│       └── 50-luci-void-anchor.sh  ← 首次启动时自动 enable 服务并刷新 LuCI
├── usr/
│   ├── libexec/rpcd/
│   │   └── void-anchor         ← rpcd 后端（提供 ubus status/clients 方法）
│   ├── sbin/
│   │   └── void-anchor         ← 主守护进程
│   └── share/
│       ├── luci/menu.d/
│       │   └── luci-app-void-anchor.json   ← LuCI 菜单注册
│       └── rpcd/acl.d/
│           └── luci-app-void-anchor.json   ← rpcd ACL 权限定义
└── www/luci-static/resources/view/void-anchor/
    └── overview.js             ← LuCI 前端页面
```

---

## 部署方法

### 一键 scp 部署

```bash
ROUTER=root@192.168.0.1

# 上传所有文件
scp -r files/etc files/usr files/www "$ROUTER":/

# 设置执行权限
ssh "$ROUTER" '
  chmod 755 /usr/sbin/void-anchor
  chmod 755 /usr/libexec/rpcd/void-anchor
  chmod 755 /etc/init.d/void_anchor
  chmod 755 /etc/uci-defaults/50-luci-void-anchor.sh
'

# 首次初始化（enable 服务 + 刷新 LuCI 缓存）
ssh "$ROUTER" 'sh /etc/uci-defaults/50-luci-void-anchor.sh'

# 启动服务
ssh "$ROUTER" '/etc/init.d/void_anchor start'
```

### 配置锚点 MAC

```bash
ssh root@192.168.0.1 '
  uci set void_anchor.global.enabled=1
  uci set void_anchor.global.grace_period=300   # 离线后宽限秒数
  uci set void_anchor.global.poll_interval=10   # 探测间隔秒数
  uci add_list void_anchor.global.target_mac="xx:xx:xx:xx:xx:xx"  # 手机 MAC
  uci commit void_anchor
  /etc/init.d/void_anchor restart
'
```

也可以通过 LuCI → Services → VOID ANCHOR 图形界面配置。

---

## 卸载

```bash
ssh root@192.168.0.1 '
  /etc/init.d/void_anchor stop
  /etc/init.d/void_anchor disable
  rm -f /usr/sbin/void-anchor
  rm -f /usr/libexec/rpcd/void-anchor
  rm -f /etc/init.d/void_anchor
  rm -f /etc/config/void_anchor
  rm -f /etc/uci-defaults/50-luci-void-anchor.sh
  rm -f /usr/share/luci/menu.d/luci-app-void-anchor.json
  rm -f /usr/share/rpcd/acl.d/luci-app-void-anchor.json
  rm -rf /www/luci-static/resources/view/void-anchor
  rm -f /var/run/void-anchor.json
  /etc/init.d/rpcd reload
'
```

---

## 配置参考

| UCI 选项 | 默认值 | 说明 |
|---|---|---|
| `global.enabled` | `1` | 0=完全禁用（始终开放），1=启用 |
| `global.grace_period` | `300` | 手机离线后封锁宽限期（秒） |
| `global.poll_interval` | `10` | 存在感探测间隔（秒，最小 2） |
| `global.target_mac` | — | 锚点手机 MAC（可用 `list` 添加多个） |
| `global.monitor_iface` | — | 手动指定 AP 接口名；留空则自动发现所有 `hostapd.*` |

---

## 工作原理

```
每 poll_interval 秒:
  1. 检查手机 MAC 是否出现在本机 AP 关联列表
  2. 若未找到，检查 LAN 邻居表（ip neigh）是否 REACHABLE/DELAY/PROBE
  3. 若仍未找到但有 DHCP 租约/邻居记录，发送单次 ping 确认

手机在线 → 删除 nftables 封锁表 → 外网开放
手机离线 → 开始计时 → 超过 grace_period → 添加封锁表 → 所有 LAN 客户端断网

封锁实现（nftables）:
  table inet void_anchor {
    chain prerouting {  # priority -300，早于 fw4 和 OpenClash TProxy
      iifname "br-lan" ip  daddr <LAN子网> accept   # 放行局域网内通信
      iifname "br-lan" ip  daddr 224.0.0.0/4 accept # 放行组播
      iifname "br-lan" meta nfproto ipv4 counter drop # 丢弃其余 IPv4
      iifname "br-lan" ip6 daddr { fe80::/10, ff00::/8, <ULA> } accept
      iifname "br-lan" meta nfproto ipv6 counter drop # 丢弃其余 IPv6
    }
  }
```

---

## 系统要求

- OpenWrt（建议 23.05+，需要 nftables/fw4）
- `nftables`、`iwinfo`（通常已预装）
- `luci`（仅 LuCI 界面需要）
