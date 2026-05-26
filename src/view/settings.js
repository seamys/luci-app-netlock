'use strict';
'require view';
'require form';
'require uci';
'require rpc';

var callClients = rpc.declare({ object: 'netlock', method: 'clients' });

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('netlock'),
			callClients().catch(function() { return { clients: [] }; })
		]);
	},

	render: function(data) {
		var clients = (data[1] && data[1].clients) || [];

		var m, s, o;

		m = new form.Map('netlock', _('NetLock \u2014 Settings'),
			_('Configure anchor device and network lock behavior. The anchor device is typically your phone \u2014 when it is present on WiFi, internet is open for all LAN clients. When absent beyond the grace period, all external traffic is blocked.'));

		/* ── Service ────────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'netlock', _('Service'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable NetLock'),
			_('When disabled, internet access is immediately restored for all clients.'));
		o.rmempty = false;

		/* ── Anchor Device ──────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'netlock', _('Anchor Device'));
		s.anonymous = true;

		o = s.option(form.DynamicList, 'target_mac', _('Anchor Device MAC'),
			_('MAC address(es) of the anchor device (usually your phone). Multiple MACs supported \u2014 internet opens when ANY one is detected. Select from the dropdown (live WiFi clients) or enter manually. Important: disable "Randomize MAC" on the phone for this WiFi network.'));
		o.datatype = 'macaddr';
		o.validate = function(section_id, value) {
			if (!value || value === '')
				return true;
			var re = /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/;
			if (!re.test(value))
				return _('Invalid MAC address format');
			return true;
		};
		clients.forEach(function(c) {
			var label = c.mac;
			if (c.hostname) label += ' (' + c.hostname + ')';
			if (c.ip) label += ' \u00b7 ' + c.ip;
			if (c.signal) label += ' \u00b7 ' + c.signal + 'dBm';
			o.value(c.mac, label);
		});

		/* ── Timing ────────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'netlock', _('Timing'));
		s.anonymous = true;

		o = s.option(form.Value, 'grace_period', _('Grace Period (seconds)'),
			_('How long to wait after anchor goes offline before blocking internet. Prevents false triggers from phone screen-off sleep. Recommended: 300 (5 minutes).'));
		o.datatype = 'uinteger';
		o.placeholder = '300';

		o = s.option(form.Value, 'poll_interval', _('Poll Interval (seconds)'),
			_('How often to scan for anchor device presence. Lower values mean faster response but slightly higher CPU usage. Recommended: 10.'));
		o.datatype = 'uinteger';
		o.placeholder = '10';

		/* ── Advanced ──────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'netlock', _('Advanced'));
		s.anonymous = true;

		o = s.option(form.DynamicList, 'monitor_iface', _('Monitor Interfaces'),
			_('Restrict presence scanning to specific AP interfaces. Leave empty to auto-detect all hostapd interfaces. Example: phy0-ap0.'));
		o.optional = true;

		return m.render();
	}
});
