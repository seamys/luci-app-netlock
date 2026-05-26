'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require poll';

var callStatus = rpc.declare({ object: 'void-anchor', method: 'status' });
var callClients = rpc.declare({ object: 'void-anchor', method: 'clients' });

function ago(ts) {
	if (!ts) return '—';
	var d = Math.max(0, Math.floor(Date.now() / 1000) - ts);
	if (d < 60) return d + ' 秒前';
	if (d < 3600) return Math.floor(d / 60) + ' 分钟前';
	return Math.floor(d / 3600) + ' 小时前';
}

function badge(text, color) {
	return E('span', {
		'style': 'display:inline-block;padding:2px 10px;border-radius:10px;color:#fff;font-weight:bold;background:' + color
	}, text);
}

function renderStatus(st) {
	st = st || {};
	var present, net;

	if (!st.enabled)
		present = badge('锚点未激活', '#888');
	else if (st.present)
		present = badge('锚点就位', '#2e7d32');
	else
		present = badge('锚点漂失', '#c62828');

	if (st.blocked)
		net = badge('虚空封锁', '#c62828');
	else
		net = badge('通道开放', '#2e7d32');

	var matched = (st.matched && st.matched.length) ? st.matched.join(', ') : '—';

	return E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '33%' }, E('strong', {}, '锚点状态')),
			E('td', { 'class': 'td left' }, present)
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, '外网通道')),
			E('td', { 'class': 'td left' }, net)
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, '最近锚定')),
			E('td', { 'class': 'td left' }, ago(st.last_seen))
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, '已锁定设备')),
			E('td', { 'class': 'td left' }, matched)
		])
	]);
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('void_anchor'),
			callClients().catch(function () { return { clients: [] }; })
		]);
	},

	render: function (data) {
		var clients = (data[1] && data[1].clients) || [];
		var statusBox = E('div', {}, renderStatus(null));

		poll.add(function () {
			return callStatus().then(function (st) {
				var fresh = renderStatus(st);
				statusBox.replaceChild(fresh, statusBox.firstChild);
			});
		}, 5);

		var m, s, o;

		m = new form.Map('void_anchor', 'VOID ANCHOR · 虚空锚点',
			'将手机设为虚空锚点 —— 锚点就位时通道开放,锚点漂失超过宽限时间后所有客户端进入虚空封锁。' +
			'拦截在 prerouting 早期完成(priority -300),直连与 OpenClash 代理流量同步切断,局域网与路由器管理仍可用。');

		s = m.section(form.NamedSection, 'global', 'void_anchor', '设置');
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', '激活锚点',
			'关闭后立即解除封锁,恢复所有客户端联网。');
		o.rmempty = false;

		o = s.option(form.DynamicList, 'target_mac', '锚点设备 MAC',
			'作为虚空锚点的手机 MAC,可填多个(任一在场即开放通道)。下拉为当前在线设备,也可手动输入。' +
			'注意:请在手机端关闭该 WiFi 的"随机 MAC",否则锚点地址漂移会导致失效。');
		o.datatype = 'macaddr';
		clients.forEach(function (c) {
			var label = c.mac;
			if (c.hostname) label += ' (' + c.hostname + ')';
			if (c.ip) label += ' · ' + c.ip;
			if (c.signal) label += ' · ' + c.signal + 'dBm';
			o.value(c.mac, label);
		});

		o = s.option(form.Value, 'grace_period', '漂失宽限时间(秒)',
			'锚点持续漂失超过该秒数才触发封锁,避免手机锁屏休眠误断。默认 300(5 分钟)。');
		o.datatype = 'uinteger';
		o.placeholder = '300';

		o = s.option(form.Value, 'poll_interval', '轮询间隔(秒)',
			'每隔多少秒扫描一次锚点是否在场。默认 10。');
		o.datatype = 'uinteger';
		o.placeholder = '10';

		o = s.option(form.DynamicList, 'monitor_iface', '监控接口(可选)',
			'限定只在这些 AP 接口扫描,留空则自动检测全部。例如 phy0-ap0。');
		o.optional = true;

		return m.render().then(function (mapNode) {
			return E([], [
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, '实时状态'),
					statusBox
				]),
				mapNode
			]);
		});
	}
});
