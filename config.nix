{
  openwrtVersion = "25.12.2";
  openwrtTarget = "mediatek";
  openwrtSubtarget = "filogic";
  openwrtProfile = "glinet_gl-mt6000";
  openwrtPackages = "adguardhome etherwake irqbalance map kmod-wireguard wireguard-tools";
  imageBuilderHash = "sha256-/n8Dt0jvac4L4RgvJ+PnLj3VJGMovQlB5CdKg3pWFCw=";

  routerHost = "10.10.0.1";
  routerUser = "root";
  routerPort = "22";
}
