'use strict';
'require view';
'require uci';
'require rpc';
'require poll';
'require fs';

var callStatus  = rpc.declare({ object: 'netlock', method: 'status' });

function badge(text, color) {
	return E('span', {
		'style': 'display:inline-block;padding:2px 10px;border-radius:10px;' +
		         'color:#fff;font-weight:bold;background:' + color
	}, text);
}

function ago(ts) {
	if (!ts) return '\u2014';
	var d = Math.max(0, Math.floor(Date.now() / 1000) - ts);
	if (d < 60) return d + ' ' + _('seconds ago');
	if (d < 3600) return Math.floor(d / 60) + ' ' + _('minutes ago');
	return Math.floor(d / 3600) + ' ' + _('hours ago');
}

function makeFeedback() {
	return E('div', { 'style': 'display:none;margin-top:0.5em;padding:8px 12px;' +
	                            'border-radius:4px;white-space:pre-wrap' }, '');
}

function showFeedback(el, text, type) {
	var colors = {
		info:    { bg: '#e3f2fd', border: '#1976d2', fg: '#0d47a1' },
		success: { bg: '#e8f5e9', border: '#2e7d32', fg: '#1b5e20' },
		warning: { bg: '#fff8e1', border: '#f9a825', fg: '#e65100' },
		error:   { bg: '#ffebee', border: '#c62828', fg: '#b71c1c' }
	};
	var c = colors[type] || colors.info;
	el.style.display    = '';
	el.style.background = c.bg;
	el.style.borderLeft = '4px solid ' + c.border;
	el.style.color      = c.fg;
	el.innerText        = text;
}

function hideFeedback(el) {
	el.style.display = 'none';
	el.innerText     = '';
}

function renderCards(st) {
	st = st || {};
	var deviceColor, deviceText, netColor, netText;

	if (!st.enabled) {
		deviceColor = '#888';
		deviceText  = _('Inactive');
	} else if (st.present) {
		deviceColor = '#2e7d32';
		deviceText  = _('Device Online');
	} else {
		deviceColor = '#c62828';
		deviceText  = _('Device Offline');
	}

	if (st.blocked) {
		netColor = '#c62828';
		netText  = _('Network Blocked');
	} else {
		netColor = '#2e7d32';
		netText  = _('Network Open');
	}

	return E('div', { 'style': 'display:flex;gap:1em;flex-wrap:wrap;margin-bottom:1em' }, [
		E('div', { 'style': 'flex:1;min-width:130px;padding:12px 16px;border-radius:6px;' +
		           'background:#f5f5f5;border-left:4px solid ' + deviceColor }, [
			E('div', { 'style': 'font-size:0.8em;color:#666;margin-bottom:4px' }, _('Anchor Device')),
			E('div', { 'style': 'font-weight:bold;font-size:1.1em' }, deviceText)
		]),
		E('div', { 'style': 'flex:1;min-width:130px;padding:12px 16px;border-radius:6px;' +
		           'background:#f5f5f5;border-left:4px solid ' + netColor }, [
			E('div', { 'style': 'font-size:0.8em;color:#666;margin-bottom:4px' }, _('Internet Access')),
			E('div', { 'style': 'font-weight:bold;font-size:1.1em' }, netText)
		]),
		E('div', { 'style': 'flex:1;min-width:130px;padding:12px 16px;border-radius:6px;' +
		           'background:#f5f5f5;border-left:4px solid #1976d2' }, [
			E('div', { 'style': 'font-size:0.8em;color:#666;margin-bottom:4px' }, _('Last Seen')),
			E('div', { 'style': 'font-weight:bold;font-size:1.1em' }, ago(st.last_seen))
		])
	]);
}

function renderDetails(st) {
	st = st || {};
	var matched = (st.matched && st.matched.length) ? st.matched.join(', ') : '\u2014';
	var targets = (st.targets && st.targets.length) ? st.targets.join(', ') : '\u2014';

	return E('table', { 'class': 'table' }, [
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left', 'width': '33%' }, E('strong', {}, _('Monitored MACs'))),
			E('td', { 'class': 'td left' }, targets)
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, _('Matched MACs'))),
			E('td', { 'class': 'td left' }, matched)
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, _('Grace Period'))),
			E('td', { 'class': 'td left' }, (st.grace_period || 300) + ' ' + _('seconds'))
		]),
		E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td left' }, E('strong', {}, _('Poll Interval'))),
			E('td', { 'class': 'td left' }, (st.poll_interval || 10) + ' ' + _('seconds'))
		])
	]);
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('netlock'),
			callStatus().catch(function() { return {}; })
		]);
	},

	render: function(data) {
		var initialStatus = data[1] || {};

		/* ── Live-updating status containers ──────────────── */
		var cardsBox   = E('div', {}, renderCards(initialStatus));
		var detailsBox = E('div', {}, renderDetails(initialStatus));

		poll.add(function() {
			return callStatus().then(function(st) {
				var fresh;
				fresh = renderCards(st);
				cardsBox.innerHTML = '';
				cardsBox.appendChild(fresh);
				fresh = renderDetails(st);
				detailsBox.innerHTML = '';
				detailsBox.appendChild(fresh);
			});
		}, 5);

		/* ── Feedback panel ────────────────────────────── */
		var reloadFeedback = makeFeedback();

		/* ── Reload Configuration ─────────────────────── */
		var btnReload = E('button', {
			'class': 'btn cbi-button cbi-button-apply',
			'click': function() {
				var self = this;
				self.disabled  = true;
				self.innerText = _('Reloading...');
				hideFeedback(reloadFeedback);

				fs.exec('/etc/init.d/netlock', ['reload']).then(function() {
					showFeedback(reloadFeedback, _('Configuration reloaded successfully.'), 'success');
					self.disabled  = false;
					self.innerText = _('Reload Configuration');
				}, function(err) {
					showFeedback(reloadFeedback, _('Reload failed: ') + String(err), 'error');
					self.disabled  = false;
					self.innerText = _('Reload Configuration');
				});
			}
		}, _('Reload Configuration'));

		/* ── Getting started guide ─────────────────────── */
		var noTargets = !initialStatus.targets || !initialStatus.targets.length;
		var guideEl;
		if (noTargets) {
			guideEl = E('div', {
				'style': 'margin-top:1em;padding:12px 16px;background:#e8f5e9;' +
				         'border-left:4px solid #2e7d32;border-radius:4px'
			}, [
				E('strong', {}, _('Getting Started')),
				E('ol', { 'style': 'margin:8px 0 0 16px;padding:0' }, [
					E('li', {}, [
						E('a', { 'href': L.url('admin/services/netlock/settings') },
						  _('Settings')),
						E('span', {}, ' \u2014 ' +
						  _('Configure anchor device MAC address and timing parameters'))
					]),
					E('li', {}, E('span', {},
					  _('Return here to monitor real-time status')))
				])
			]);
		} else {
			guideEl = E('div', { 'style': 'display:none' }, '');
		}

		/* ── Layout ─────────────────────────────────────── */
		return E('div', { 'class': 'cbi-map' }, [
			E('h2', { 'style': 'margin-top:0' }, _('NetLock \u2014 Dashboard')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Presence-based network control: internet access is open when the anchor device is on WiFi, and blocked for all LAN clients when it has been absent beyond the grace period.')),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Service Status')),
				cardsBox,
				E('h4', {}, _('Details')),
				detailsBox,
				guideEl
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Quick Actions')),
				E('div', { 'style': 'display:flex;gap:0.5em;flex-wrap:wrap' }, [
					btnReload
				]),
				reloadFeedback
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
