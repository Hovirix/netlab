{
  pkgs,
  config,
  treefmtCheck,
  ...
}:
let
  inherit (config) openwrtVersion;

  renderFixtureFiles = pkgs.runCommand "render-fixture-files" { buildInputs = [ pkgs.gomplate ]; } ''
    mkdir -p "$out"
    gomplate \
      --datasource "network=file://${../tests/fixtures/network.yaml}" \
      --datasource "wireless=file://${../tests/fixtures/wireless.yaml}" \
      --datasource "adguardhome=file://${../tests/fixtures/adguardhome.yaml}" \
      --file "${../templates/network.tmpl}" \
      --out "$out/network"

    gomplate \
      --datasource "network=file://${../tests/fixtures/network.yaml}" \
      --datasource "wireless=file://${../tests/fixtures/wireless.yaml}" \
      --datasource "adguardhome=file://${../tests/fixtures/adguardhome.yaml}" \
      --file "${../templates/wireless.tmpl}" \
      --out "$out/wireless"

    gomplate \
      --datasource "adguardhome=file://${../tests/fixtures/adguardhome.yaml}" \
      --file "${../templates/adguardhome.yaml.tmpl}" \
      --out "$out/adguardhome.yaml"
  '';

  validateUci = pkgs.runCommand "validate-uci" { buildInputs = [ pkgs.uci ]; } ''
    uci -c "${renderFixtureFiles}" -q show network >/dev/null
    uci -c "${renderFixtureFiles}" -q show wireless >/dev/null
    test -s "${renderFixtureFiles}/adguardhome.yaml"

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
