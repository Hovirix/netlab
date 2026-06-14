{
  openwrtVersion = "25.12.4";
  openwrtTarget = "mediatek";
  openwrtSubtarget = "filogic";
  openwrtProfile = "glinet_gl-mt6000";
  openwrtPackages = "adguardhome etherwake irqbalance map kmod-wireguard wireguard-tools";
  imageBuilderHash = "sha256-ggfanWifAtQoM+Toq8nqu07GOkM6eiZHMpbT0sSJ4lc=";

  routerHost = "10.10.0.1";
  routerUser = "root";
  routerPort = "22";
}
