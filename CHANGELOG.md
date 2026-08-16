# Changelog

## 1.0.0 (2026-08-16)


### Features

* **adguardhome:** render config from sops secret ([5fd2122](https://github.com/Hovirix/netlab/commit/5fd212253e4342cec2cac849e8783d338b0fce46))
* **ci:** automate OpenWrt release checks with issue and PR ([a611502](https://github.com/Hovirix/netlab/commit/a611502ad6f0258c5e5f599ee52489cd5bf85ccf))
* **deploy:** add sysupgrade deploy script ([#13](https://github.com/Hovirix/netlab/issues/13)) ([2cb6bfe](https://github.com/Hovirix/netlab/commit/2cb6bfe88f6f63bbf34aa00434620c5395314443))
* **dhcp:** add static DHCP lease support ([#16](https://github.com/Hovirix/netlab/issues/16)) ([9c17103](https://github.com/Hovirix/netlab/commit/9c17103ec87e933c0e02f8aba285f427778a105d))
* **dhcp:** add Swarm static leases and VPN admin parity ([#17](https://github.com/Hovirix/netlab/issues/17)) ([5c3f929](https://github.com/Hovirix/netlab/commit/5c3f92927f8441769d56fa89fd49faa3441fc302))
* enforce zero-trust vlan policy ([#6](https://github.com/Hovirix/netlab/issues/6)) ([791c431](https://github.com/Hovirix/netlab/commit/791c431884326f1978e7ce88ad51472850280ab6))
* **firewall:** allow admin NFS access to storage ([8e69517](https://github.com/Hovirix/netlab/commit/8e69517aa4bdff788a934827bbb718b1e8c740aa))
* **network:** restructure VLANs with new naming and add clients VLAN ([#20](https://github.com/Hovirix/netlab/issues/20)) ([70e447d](https://github.com/Hovirix/netlab/commit/70e447df107f29142f0f61e8991d2cc2d4b24bf4))
* **openwrt:** add sysupgrade deployment task with confirmation ([5711b43](https://github.com/Hovirix/netlab/commit/5711b434017c883803bb0d01ad760dec5f7e8ce7))
* **openwrt:** add WireGuard admin VPN setup ([d1aa083](https://github.com/Hovirix/netlab/commit/d1aa0833b17a4d24fc81493ca35098128de971c0))
* **packages:** add Wake-on-LAN utility ([f9d8a62](https://github.com/Hovirix/netlab/commit/f9d8a62b459d02195f6d1fac96e1b3e71c9dc143))
* **task:** move OpenWrt pipeline to repository Taskfile ([7d05073](https://github.com/Hovirix/netlab/commit/7d05073163add3b9da3228969a0fa31a246cbe83))
* **vpn:** add WireGuard secret rotation tool ([f1b0c8a](https://github.com/Hovirix/netlab/commit/f1b0c8aa4a53c0c329ec8485dd8b0cd28a6bcad0))


### Bug Fixes

* **dns:** remove static AdGuard rewrites ([5409e87](https://github.com/Hovirix/netlab/commit/5409e87893e1ce71207a365b685f09f041fc0857))
* **firewall:** allow NFSv4 storage access to TrueNAS ([931a3eb](https://github.com/Hovirix/netlab/commit/931a3eb8ab1e9424f13072450468ad4b4dff09f1))
* **network:** align mini PC and storage access ([2c56657](https://github.com/Hovirix/netlab/commit/2c566579a1514158ca5e936fbbbbad282ceed423))
* **network:** make mini PC ports full trunks ([d578abf](https://github.com/Hovirix/netlab/commit/d578abf4775ef711ea54898d52a1e3212dced8a6))
* **network:** restrict AdGuard UI and update storage VLAN access ([88b2706](https://github.com/Hovirix/netlab/commit/88b27064d1b0e276c99673e3d0030ebc929dd262))
* **network:** restrict infra trunk VLANs ([a3d7d4d](https://github.com/Hovirix/netlab/commit/a3d7d4dd78b776621272d5c48f26207e0392454d))
* **nix:** keep secrets out of store ([#9](https://github.com/Hovirix/netlab/issues/9)) ([79cb973](https://github.com/Hovirix/netlab/commit/79cb9738ae7711251bf40a00fca2ec3fe7bdc75a))
* **nix:** resolve build paths from worktree root ([f8514a8](https://github.com/Hovirix/netlab/commit/f8514a837f417bd3ed244bfd708d0d050c894d3f))
* **openwrt:** align overlay layout and MAP-E wan6 ([#5](https://github.com/Hovirix/netlab/issues/5)) ([5c7fe92](https://github.com/Hovirix/netlab/commit/5c7fe920d5beacc05c0bd995b93c3401fbeff678))
* **openwrt:** harden update and sysupgrade ([2571946](https://github.com/Hovirix/netlab/commit/2571946fb72fb6d11dce2e1c3635d293519bb711))
* **task:** add check after rendering ([083d887](https://github.com/Hovirix/netlab/commit/083d887ca1eefde26a9699fa944b309266be7631))
* **vpn:** Allow AdGuardHome acess ([b11373b](https://github.com/Hovirix/netlab/commit/b11373b48704454e5c836bfa9033405295822e85))
* **vpn:** update WireGuard routing and management access ([ce1c378](https://github.com/Hovirix/netlab/commit/ce1c3780e1f5731701de59e30051e3f1ddd962c6))
* **wan:** refresh wan6 before ISP DHCPv6 lease expiry ([1b3ab7d](https://github.com/Hovirix/netlab/commit/1b3ab7d8043541f11924fd34c735df1b143a26f1))
* **wan:** restart map-e interfaces by cron ([40659b3](https://github.com/Hovirix/netlab/commit/40659b38619db22f03d7e11bd41ec6485fa53c6a))
