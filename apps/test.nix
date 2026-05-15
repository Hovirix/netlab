{
  pkgs,
  config,
  treefmtCheck,
  ...
}:
let
  inherit (config) openwrtVersion;

  renderFixtureUci = pkgs.runCommand "render-fixture-uci" { buildInputs = [ pkgs.gomplate ]; } ''
    mkdir -p "$out"
    gomplate \
      --datasource "network=file://${../tests/fixtures/network.yaml}" \
      --datasource "wireless=file://${../tests/fixtures/wireless.yaml}" \
      --file "${../templates/network.tmpl}" \
      --out "$out/network"

    gomplate \
      --datasource "network=file://${../tests/fixtures/network.yaml}" \
      --datasource "wireless=file://${../tests/fixtures/wireless.yaml}" \
      --file "${../templates/wireless.tmpl}" \
      --out "$out/wireless"
  '';

  validateUci = pkgs.runCommand "validate-uci" { buildInputs = [ pkgs.uci ]; } ''
    uci -c "${renderFixtureUci}" -q show network >/dev/null
    uci -c "${renderFixtureUci}" -q show wireless >/dev/null

    for file in ${../files/etc/config}/*; do
      if [ -f "$file" ]; then
        name="$(basename "$file")"
        uci -c "${../files/etc/config}" -q show "$name" >/dev/null
      fi
    done

    mkdir -p "$out"
    printf 'OpenWrt %s UCI validation passed\n' '${openwrtVersion}' > "$out/result"
  '';
in
{
  checks = {
    formatting = treefmtCheck;
    uci = validateUci;
  };
}
