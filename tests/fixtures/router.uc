const collect = loadfile(ARGV[0], { strict_declarations: true, raw_mode: true });
let metrics;

function run(networks, radios, leases) {
	metrics = {};
	return call(collect, null, {
		gauge: (name) => {
			assert(!(name in metrics), `Duplicate declaration: ${name}`);
			metrics[name] = [];
			return (labels, value) => push(metrics[name], { labels, value });
		},
		fs: { readfile: (path) => { assert(path == '/tmp/dhcp.leases'); return leases; } },
		ubus: { call: (object, method) => {
			if (object == 'network.interface') {
				assert(method == 'dump');
				return networks;
			}
			assert(object == 'network.wireless' && method == 'status');
			return radios;
		} },
	});
}

const networks = { interface: [
	{ interface: 'wan', up: true, uptime: 42, proto: 'map',
		device: 'eth1.836', l3_device: 'map-wan',
		'ipv4-address': [{ address: '192.0.2.1', mask: 32 }] },
	{ interface: 'wan6', up: false, uptime: 99, proto: 'dhcpv6',
		'ipv6-address': [{ address: '2001:db8::1', mask: 64 }] },
	{ interface: 'vlan30', up: true, device: 'br-lan.30', l3_device: 'br-lan.30' },
] };
const radios = { radio0: { up: true, config: { channel: 'auto', htmode: 'HE40' },
	interfaces: [{ ifname: 'phy0-ap0' }] }, radio1: { up: false } };
global.runtime = { 'phy0-ap0': { wiphy_freq: 2412, channel_width: 1, center_freq1: 2412 } };
const leases = sprintf('%d AA:BB:CC:DD:EE:01 10.30.0.101 host *\n', time() + 3600) +
	'0 aa:bb:cc:dd:ee:02 10.30.0.102 * *\n' +
	'1 aa:bb:cc:dd:ee:03 10.30.0.103 expired *\n' +
	'duid 00:01:02\nmalformed\n0 123 2001:db8::2 host *\n';
assert(run(networks, radios, leases));
assert(metrics.openwrt_network_up[1].value == 0);
assert(metrics.openwrt_network_uptime_seconds[0].value == 42);
assert(metrics.openwrt_network_uptime_seconds[1].value == 0);
assert(metrics.openwrt_network_info[0].labels.protocol == 'map');
assert(metrics.openwrt_network_info[0].labels.l3_device == 'map-wan');
assert(length(metrics.openwrt_network_device_info) == 3);
assert(metrics.openwrt_network_device_info[2].labels.name == 'Homelab');
assert(length(metrics.openwrt_network_address_info) == 1);
assert(metrics.openwrt_network_address_info[0].labels.prefix_length == '32');
assert(metrics.openwrt_dhcp_active_leases[0].value == 2);
assert(metrics.openwrt_dhcp_lease_info[0].labels.mac == 'aa:bb:cc:dd:ee:01');
assert(metrics.openwrt_dhcp_lease_info[1].labels.hostname == '');
assert(metrics.openwrt_dhcp_lease_expiry_timestamp_seconds[1].value == 0);
assert(metrics.openwrt_wifi_channel[0].value == 1);
assert(metrics.openwrt_wifi_channel_width_megahertz[0].value == 20);
assert(metrics.openwrt_wifi_frequency_hertz[0].value == 2412000000);
assert(length(metrics.openwrt_router_source_success) == 3);

networks.interface[1].up = true;
push(networks.interface[1]['ipv6-address'], { address: '2001:db8::2', mask: 128 });
assert(run(networks, radios, leases));
assert(length(metrics.openwrt_network_address_info) == 3);
assert(metrics.openwrt_network_address_info[1].labels.family == 'ipv6');

for (let sample in [
	[2484, 0, 14, 20], [5180, 3, 36, 80], [5500, 5, 100, 160],
	[5935, 1, 2, 20], [5955, 13, 1, 320], [6115, 4, 33, 160],
]) {
	global.runtime['phy0-ap0'] = { wiphy_freq: sample[0], channel_width: sample[1],
		center_freq1: sample[0], center_freq2: 6435 };
	assert(run(networks, radios, ''));
	assert(metrics.openwrt_wifi_channel[0].value == sample[2]);
	assert(metrics.openwrt_wifi_channel_width_megahertz[0].value == sample[3]);
	assert(metrics.openwrt_dhcp_active_leases[0].value == 0);
}
assert(metrics.openwrt_wifi_channel_info[0].labels.width == '80+80');
assert(length(metrics.openwrt_wifi_center_frequency_hertz) == 2);

global.runtime = {};
assert(!run(networks, radios, null));
assert(metrics.openwrt_network_up[0].value == 1);
assert(!('openwrt_dhcp_active_leases' in metrics));
assert(length(metrics.openwrt_wifi_channel) == 0);
for (let sample in metrics.openwrt_router_source_success)
	assert(sample.value == (sample.labels.source == 'networks' ? 1 : 0));
assert(!run(null, null, ''));
assert(metrics.openwrt_dhcp_active_leases[0].value == 0);
